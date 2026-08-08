# Azure Data Factory — Ingestion & ETL Pipelines

This folder holds the ADF artifacts (as JSON) that move Salesforce data into `SalesforceDW` and run the
quality chain. Everything is **incremental** (watermark-driven) and **parameterized** so one set of pieces
serves all 9 objects.

---

## 1. What is in this folder

| File | Artifact | Type | Purpose |
| --- | --- | --- | --- |
| [pl_object_etl.json](pl_object_etl.json) | `pl_object_etl` | Pipeline (child) | Full ETL for **one** object: ingest → stage → DQ → clean |
| [pl_run_all.json](pl_run_all.json) | `pl_run_all` | Pipeline (parent) | Loops every active object and calls `pl_object_etl` |
| [pipeline.json](pipeline.json) | `pl_ingest_campaign` | Pipeline (legacy) | The original Campaign-only pipeline (kept as the proven reference) |
| [ds_sql.json](ds_sql.json) | `ds_sql` | Dataset | Generic Azure SQL table (`p_schema`, `p_table`) |
| [sales_force_object.JSON](sales_force_object.JSON) | `ds_sf` | Dataset | Generic Salesforce object (`p_object`) |

> **Naming:** `pl_` = pipeline, `ds_` = dataset, `ls_` = linked service.

---

## 2. The pieces and how they connect

```text
pl_run_all  (parent)
  └─ LookupObjects  → reads ctl.object_registry (active objects + API-name mapping)
  └─ ForEach        → for each object, runs:
        pl_object_etl  (child, parameterized)
          ValidateObject → confirm raw.<table> exists + object is active in ctl.object_registry
          GetFields      → build the SOQL column list from raw.<table>
          GetWatermark   → read ctl.watermark_control cursor (NULL ⇒ full from start)
          StartRun       → open a run row in ctl.etl_run_control, capture upper bound
          CopyObject     → Salesforce (SOQL, incremental) ─► raw.salesforce_<obj>
          FinishRun      → close the run row + advance ctl.watermark_control
          RefreshStaging → EXEC staging.refresh_<obj>_latest
          RunDQ          → EXEC dq.run_incremental_catalog_rules @ObjectNameFilter='<Object>'
          RunClean       → EXEC clean.refresh_<obj>   (blocks itself if any CRITICAL is open)
```

Two generic datasets serve everything:

- **`ds_sf`** — Salesforce source. Parameter `p_object` (e.g. `Campaign`).
- **`ds_sql`** — Azure SQL, used for the raw sink **and** the control-table lookups. Parameters
  `p_schema`, `p_table`.

---

## 3. How to use each pipeline

### `pl_object_etl` — run ONE object

Use it to ingest/process a single object (or to test).

1. Open the pipeline → **Debug** (or **Add trigger → Trigger now**).
2. Supply the three parameters (defaults are Campaign):

   | Parameter | Meaning | Example (Campaign) |
   | --- | --- | --- |
   | `p_object` | Salesforce API name (used in SOQL + control tables) | `Campaign` |
   | `p_raw_table` | Raw sink table name (under `raw`) | `salesforce_campaign` |
   | `p_short` | Short name (used in `staging.refresh_<short>_latest`, `clean.refresh_<short>`) | `campaign` |

3. Watch the run: it should end with a fresh `ctl.watermark_control` row for the object.

#### What each step does (in order)

All 8 activities are chained on **Succeeded**, so they run strictly sequentially and **fail-fast** — any
failure stops the chain and leaves the `ctl.etl_run_control` row as `Running` (visible for triage).

1. **`GetFields`** (Lookup) — SOQL has no `SELECT *`, so this builds the column list. It reads
   `sys.columns` for `raw.<p_raw_table>` and `STRING_AGG`s the names in `column_id` order, **excluding**
   the 3 lineage columns (`_etl_run_id`, `_etl_extracted_at_utc`, `_etl_source_object`) — those are added
   by the Copy, not pulled from Salesforce. Returns one row: `fields`.

   ```sql
   SELECT STRING_AGG(CONVERT(NVARCHAR(MAX), name), ', ') WITHIN GROUP (ORDER BY column_id) AS fields
   FROM sys.columns
   WHERE object_id = OBJECT_ID(N'raw.<p_raw_table>')
     AND name NOT IN (N'_etl_run_id', N'_etl_extracted_at_utc', N'_etl_source_object');
   ```

2. **`GetWatermark`** (Lookup) — reads `ctl.watermark_control` for this object and returns the last cursor
   as ISO `…Z`, or `1900-01-01T00:00:00Z` when there is none (⇒ **full load from the start**). This is the
   **lower bound** of the pull.

   ```sql
   SELECT COALESCE(CONVERT(VARCHAR(19), MAX(last_watermark_value), 126) + 'Z', '1900-01-01T00:00:00Z') AS wm
   FROM ctl.watermark_control
   WHERE object_name = N'<p_object>';
   ```

3. **`StartRun`** (Lookup) — inserts a `Running` row into `ctl.etl_run_control` (`load_type = Incremental`),
   captures `@now = SYSUTCDATETIME()` as the run's **upper bound**, and returns `run_id` + `run_start`.
   Fixing the upper bound at run start means rows modified *during* the run aren't missed or double-counted.

   ```sql
   DECLARE @now DATETIME2(7) = SYSUTCDATETIME();
   INSERT INTO ctl.etl_run_control (object_name, load_type, start_time, status)
   VALUES (N'<p_object>', N'Incremental', @now, N'Running');
   SELECT CAST(SCOPE_IDENTITY() AS BIGINT) AS run_id, CONVERT(VARCHAR(19), @now, 126) + 'Z' AS run_start;
   ```

4. **`CopyObject`** (Copy) — the extract + load. Source = Salesforce (`ds_sf`), sink = `raw.<p_raw_table>`
   (`ds_sql`), **append-only** (`writeBehavior = insert`). It stamps the 3 canonical lineage columns as
   *additional columns* (`_etl_run_id` = the run id, `_etl_extracted_at_utc` = `@utcnow()`,
   `_etl_source_object` = the object). The `> wm AND <= run_start` window is what makes it **incremental and
   non-overlapping**.

   ```sql
   -- SOQL against Salesforce
   SELECT <fields from GetFields>
   FROM <p_object>
   WHERE SystemModstamp > <wm from GetWatermark> AND SystemModstamp <= <run_start from StartRun>
   ```

5. **`FinishRun`** (Script) — closes the run: sets the `ctl.etl_run_control` row to `Succeeded` with
   `rows_extracted`/`rows_loaded = rowsCopied`, then **MERGE**s `ctl.watermark_control` to advance
   `last_watermark_value` to this run's upper bound (`run_start`) and record `last_success_run_id`. The next
   run therefore begins exactly where this one ended.

   ```sql
   UPDATE ctl.etl_run_control
   SET status = N'Succeeded', end_time = SYSUTCDATETIME(),
       rows_extracted = <CopyObject.rowsCopied>, rows_loaded = <CopyObject.rowsCopied>
   WHERE run_id = <StartRun.run_id>;

   MERGE ctl.watermark_control AS t
   USING (SELECT N'<p_object>' AS object_name) AS s ON t.object_name = s.object_name
   WHEN MATCHED THEN UPDATE SET
       last_watermark_value = CONVERT(DATETIME2(7), '<StartRun.run_start>', 127),
       watermark_column = N'SystemModstamp', last_success_run_id = <StartRun.run_id>,
       updated_at = SYSUTCDATETIME()
   WHEN NOT MATCHED THEN INSERT (object_name, watermark_column, last_watermark_value, last_success_run_id, updated_at)
       VALUES (N'<p_object>', N'SystemModstamp', CONVERT(DATETIME2(7), '<StartRun.run_start>', 127), <StartRun.run_id>, SYSUTCDATETIME());
   ```

6. **`RefreshStaging`** (Script) — materializes the deduped "latest" snapshot (one row per `Id`).

   ```sql
   EXEC staging.refresh_<p_short>_latest;
   ```

7. **`RunDQ`** (Script) — runs the object's DQ rules incrementally, writing violations to `dq.dq_exceptions`.

   ```sql
   EXEC dq.run_incremental_catalog_rules @ObjectNameFilter = N'<p_object>', @MaxRowsPerRule = 100000, @MaxExceptionsPerRule = 500;
   ```

8. **`RunClean`** (Script) — builds `clean.<obj>` (the proc **blocks itself** if any CRITICAL exception is
   open, so a failed gate stops here).

   ```sql
   EXEC clean.refresh_<p_short>;
   ```

> **Note:** the current JSON starts at `GetFields` — there is **no `ValidateObject` activity** yet, despite
> the mentions in §2/§8. Add it (a preflight Lookup that checks the raw table exists + the object is active
> in `ctl.object_registry`) if you want the fail-fast preflight, or treat those references as planned.

> **Reset to full reload:** `UPDATE ctl.watermark_control SET last_watermark_value = NULL WHERE
> object_name = N'<Object>';` — the next run pulls everything from the start.

### `pl_run_all` — run ALL objects

The master. Before the first run:

1. **Seed the registry:** `EXEC ctl.refresh_object_registry;` then confirm 9 active rows in
   `ctl.object_registry`.
2. **Trigger** `pl_run_all` (Debug or Trigger now). It reads the registry and runs `pl_object_etl` per
   object, **sequentially**.

> **Today only Campaign has** staging/DQ/clean procs. So `pl_run_all` ingests raw for every object, but the
> other 8 will **fail at `RefreshStaging`** until their per-object procs exist. That is the intended
> per-object rollout — build each object's staging/DQ/clean, then it flows end-to-end.

### `pl_ingest_campaign` — legacy (reference only)

The original Campaign-only pipeline. `pl_object_etl` with `p_object=Campaign` replaces it; keep it as the
proven baseline or delete once `pl_object_etl` is validated.

---

## 4. How to add / edit an object

**You do NOT create new pipelines or datasets per object.** To onboard an object:

1. **Ensure the raw table exists** (`raw.salesforce_<obj>`) and is registered:
   `EXEC ctl.refresh_object_registry;`.
2. **Confirm the API-name mapping** in `pl_run_all` → `LookupObjects` (the `CASE`). Add the object there if
   it is new. *(Cleaner long-term: add a `salesforce_api_name` column to `ctl.object_registry` and select
   it instead of the CASE.)*
3. **Build the object's procs** (copy the Campaign pattern): `staging.refresh_<short>_latest`, the DQ rules
   in `dq.dq_rule_catalog`, and `clean.refresh_<short>`.
4. Run `pl_object_etl` for that object, or re-run `pl_run_all`.

**To edit the pipelines:** open in ADF Studio and use the visual editor, or the top-right **`{}`** code
view to paste updated JSON. Keep the JSON files in this folder in sync (re-export after publishing).

---

## 5. Databases, tables & schemas used

**Database:** `SalesforceDW` on server `quality-check-poc-sql.database.windows.net` (Azure SQL,
serverless, auto-pause).

| Schema.table / proc | Used by | Role |
| --- | --- | --- |
| `raw.salesforce_<obj>` | CopyObject (sink) | Append-only landing (all `NVARCHAR(MAX)` + 3 `_etl_*` lineage cols) |
| `ctl.watermark_control` | GetWatermark, FinishRun | Incremental cursor per object |
| `ctl.etl_run_control` | StartRun, FinishRun | Run log (open/close each run) |
| `ctl.object_registry` | LookupObjects | Drives the per-object loop (seed with `refresh_object_registry`) |
| `staging.refresh_<obj>_latest` | RefreshStaging | Materialize deduped latest snapshot |
| `dq.run_incremental_catalog_rules` | RunDQ | Runs the object's DQ rules → `dq.dq_exceptions` |
| `clean.refresh_<obj>` | RunClean | Builds `clean.<obj>` (gated at 0 CRITICAL) |

---

## 6. Linked services used

| Linked service | Connects to | Used by |
| --- | --- | --- |
| `ls_salesforce_poc` | Salesforce (V2 connector) | `ds_sf` (source) |
| `ls_sql_salesforcedw_POC` | Azure SQL `SalesforceDW` | `ds_sql`, and the Script activities (FinishRun, RefreshStaging, RunDQ, RunClean) |

Both must exist in the factory before publishing. They already do (used by the Campaign POC). If a linked
service is missing:

- **Salesforce:** Manage → Linked services → New → **Salesforce V2** → supply consumer key/secret + token;
  inject the secret at runtime (not stored in the repo).
- **Azure SQL:** Manage → Linked services → New → **Azure SQL Database** → server
  `quality-check-poc-sql.database.windows.net`, database `SalesforceDW`, auth = the ADF managed identity
  (`quality-check-poc-adf`, already a DB user) or SQL auth.

---

## 7. Cost (rough, USD — not a quote)

Cost is driven by **serverless SQL compute while active** (auto-pauses to ~$0 when idle) plus small ADF
per-activity and Copy DIU charges.

| Scenario | Rough cost |
| --- | --- |
| One object, one incremental run | pennies (a few active SQL minutes + 1 Copy + a few Script activities) |
| All 9 objects, one full build | ~$20–45 one-time (dominated by the two large objects) |
| All 9 objects, daily incremental (needs a schedule trigger — not built yet) | ~$35–65 / month |

**Keep it low:** leave SQL **auto-pause ON**, run on a real schedule (nightly, not every few minutes), do
the big objects (Opportunity, Item Allocation) incrementally, and set a **Budget + alert** on resource
group `Quality-check-poc` (Cost Management → Budgets). See
[../DOCS/poc_expand_to_all_objects.md](../DOCS/poc_expand_to_all_objects.md) §6 for the full breakdown.

---

## 8. Publish order & gotchas

1. **Linked services** must exist first (`ls_salesforce_poc`, `ls_sql_salesforcedw_POC`).
2. **Datasets** before pipelines (`ds_sf`, `ds_sql`).
3. **Child before parent** (`pl_object_etl` before `pl_run_all`).
4. Dataset references pass required parameters — a name mismatch causes
   *"No value provided for parameter …"*. Keep `ds_sql` params exactly `p_schema`/`p_table` and `ds_sf`
   param exactly `p_object`.
5. **SOQL has no `SELECT *`** — `GetFields` builds the column list from the raw table, so `raw.<table>`
   must exist with columns matching Salesforce field names.
6. **Fail-fast preflight** — `pl_object_etl` starts with `ValidateObject`: if the object's raw table is
   missing or it is not active in `ctl.object_registry`, the run stops immediately with a clear message
   (run `EXEC ctl.refresh_object_registry;` to map objects).
