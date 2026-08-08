# Expanding the POC — From Campaign to the Other 8 Objects

**Date:** 2026-08-06
**Read this after** [campaign_azure_poc.md](campaign_azure_poc.md) (technical) and
[campaign_poc_business.md](campaign_poc_business.md) (business). This doc **starts where Campaign
finished** — it does **not** repeat the Azure setup. It is the "do the same for the next object" recipe.

> **Tested-on-Azure status (be honest about this).** Only **Campaign** has actually run on Azure — a
> single **manual** run (clean stage demonstrated 2026-08-05, ADF linked-service tests `Succeeded`). The
> other 8 objects below are **recipe-only** (not yet run on Azure), and **no scheduler is built** — every
> run so far was triggered by hand (`Debug` / `Trigger now`). Anywhere this doc says "nightly" or "daily
> incremental," treat it as *the target after adding an ADF schedule trigger*, not something in place.
>
> **Update (2026-08-07):** the generic, **watermark-incremental** pipelines are now **built and published**
> — `pl_object_etl` (one object) + `pl_run_all` (loops `ctl.object_registry`), with reusable datasets
> `ds_sf` and `ds_sql`. `ctl.object_registry` is **seeded (9 rows)** and Campaign raw was truncated +
> reloaded (the old doubling is resolved). **Incremental, no-drop staging builders now exist for
> `campaign`, `contact`, `item_gau`, `recurring_donation`** (`staging.refresh_<obj>_latest`, split into
> `<obj>_latest_table.sql` + `<obj>_latest_SP.sql`) plus a generic `staging.refresh_object_latest` for the
> rest. **DQ rules are seeded for 6 objects** (Campaign 18, Contact 14, Item_GAU 28, Recurring_Donation 23,
> Sponsorship 10, Sponsorship_Unit 9), including validation-rule checks mined from the Salesforce org export
> (`<OBJ>-VR-*`, sourced from `shared files/The Team/20260804 active validation rules.tsv`). **Clean + alert
> are still Campaign-only.** See [../Azure/README.md](../Azure/README.md) — the ADF folder: `pl_object_etl`
> (child) + `pl_run_all` (parent) + `ds_sf` / `ds_sql` datasets, with per-step run queries.

---

## 0. What is already done (do NOT redo)

These exist from the Campaign run and are **shared** by every object — skip them:

- Azure infra: resource group, SQL server + `SalesforceDW`, storage, Data Factory, the ADF SQL principal.
- SQL objects deployed (`_deploy.sql` / `deploy_merged.sql`): all **raw tables**, all **`staging.vw_*_latest`
  dedup views**, the **control** tables (`ctl.*`), the **DQ framework** (`dq.dq_rule_catalog`,
  `dq.run_incremental_catalog_rules`, `dq.dq_exceptions`, `dq.rule_execution_state`), and **`dq.alert`**.
- The Campaign pattern files you will copy per object:
  - staging build → `database/staging/campaign_latest_table.sql` + `database/staging/campaign_latest_SP.sql`
  - clean build   → `database/clean/campaign_table.sql`
  - alert table   → `database/dq/dq_alert_table.sql` (reused as-is; one table for all objects)

So per new object you only add: **an ingest pipeline**, **a staging materialize proc**, **DQ rules**, and
**a clean proc** — all by renaming the Campaign versions.

### 0.1 Pre-flight checklist — confirm the shared pieces actually exist

Run these once before starting any new object. Each row should return the expected result; if not, that
shared piece is missing and must be deployed/created before the recipe will work.

**Azure infra (Portal — RG `Quality-check-poc`):**

[x] Resource group `Quality-check-poc` exists
[ ] SQL logical server `quality-check-poc-sql` + database `SalesforceDW` exist and are reachable
[ ] Storage account (ADLS Gen2) exists
[ ] Data Factory instance exists
[ ] ADF SQL principal (`quality-check-poc-adf`) is a DB user with execute rights
[ ] ADF linked services `ls_salesforce_poc` + `ls_sql_salesforcedw_POC` test = Succeeded
[ ] Campaign pipeline `pl_ingest_campaign` exists (the template to clone/parameterize)

**Deployed SQL objects (run in `SalesforceDW` Query editor — all should return the listed rows):**

```sql
-- Control tables (expect all 4)
SELECT s.name + '.' + t.name AS object_present
FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE s.name = 'ctl'
  AND t.name IN ('etl_run_control','watermark_control','object_registry','loaded_salesforce_campaign_ids')
ORDER BY 1;

-- DQ framework tables (expect all 4)
SELECT s.name + '.' + t.name AS object_present
FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE s.name = 'dq'
  AND t.name IN ('dq_rule_catalog','dq_exceptions','rule_execution_state','alert')
ORDER BY 1;

-- DQ runner proc (expect 1 row)
SELECT SCHEMA_NAME(schema_id) + '.' + name AS proc_present
FROM sys.procedures
WHERE SCHEMA_NAME(schema_id) = 'dq' AND name = 'run_incremental_catalog_rules';

-- All 9 raw tables loaded (expect 9 rows; note any with 0 rows to reload)
SELECT s.name AS sch, t.name AS raw_table, SUM(p.rows) AS row_count
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1)
WHERE s.name = 'raw' AND t.name LIKE 'salesforce_%'
GROUP BY s.name, t.name ORDER BY t.name;

-- All 9 dedup latest-views (expect 9 rows)
SELECT s.name + '.' + v.name AS latest_view
FROM sys.views v JOIN sys.schemas s ON s.schema_id = v.schema_id
WHERE s.name = 'staging' AND v.name LIKE 'vw_%_latest'
ORDER BY 1;

-- object_registry seeded for all 9 objects (expect 9 active rows)
SELECT object_name, source_schema, source_table, is_active
FROM ctl.object_registry WHERE is_active = 1 ORDER BY source_table;
```


object_present
--------------
ctl.etl_run_control
ctl.object_registry
ctl.watermark_control


object_present
--------------
dq.alert
dq.dq_exceptions
dq.dq_rule_catalog
dq.rule_execution_state

proc_present
------------
dq.run_incremental_catalog_rules

sch | raw_table | row_count
----|-----------|----------
raw | salesforce_campaign | 81694
raw | salesforce_contact | 0
raw | salesforce_item | 0
raw | salesforce_item_allocation | 0
raw | salesforce_opportunity | 0
raw | salesforce_payment | 0
raw | salesforce_recurring_donation | 0
raw | salesforce_sponsorship | 0
raw | salesforce_sponsorship_unit | 0

latest_view
-----------
staging.vw_campaign_latest
staging.vw_contact_latest
staging.vw_item_allocation_latest
staging.vw_item_latest
staging.vw_opportunity_latest
staging.vw_payment_latest
staging.vw_recurring_donation_latest
staging.vw_sponsorship_latest
staging.vw_sponsorship_unit_latest



object_name | source_schema | source_table | is_active
------------|---------------|--------------|----------


**Campaign pattern files present in the repo (clone these per object):**

```text
[ ] database/staging/campaign_latest_table.sql   (curated staging table pattern)
[ ] database/staging/campaign_latest_SP.sql      (incremental staging builder pattern)
[ ] database/clean/campaign_table.sql            (clean proc pattern)
[ ] database/dq/dq_alert_table.sql               (shared alert table — reused as-is)
[ ] Tables/campaign/02_campaign_staging_dq_PROD_framework.sql  (DQ rule seed pattern)
```

> If any control/DQ table or the runner proc is missing, deploy `database/_deploy.sql` (or
> `deploy_merged.sql`) first. If a `raw.*` table shows **0 rows**, reload it before running its object
> (Contact, Payment, Opportunity, Item Allocation were empty as of the last status check).

> **Seed `ctl.object_registry` if it is empty.** The last query above can return **0 rows** even though the
> table exists (it was empty before 2026-08-07; it is **now seeded with 9 rows**). The registry
> auto-discovers all `raw.salesforce_*` tables — seed/refresh it in one call, then re-run the last check:
>
> ```sql
> EXEC ctl.refresh_object_registry;   -- fills id_column, watermark_column, IsDeleted, latest_view_name for all 9
> SELECT object_name, source_schema, source_table, is_active
> FROM ctl.object_registry WHERE is_active = 1 ORDER BY source_table;  -- expect 9 rows now
> ```
>
> This must pass **before** the metadata-driven ADF template (Stage 1) can loop over the objects.


object_name | source_schema | source_table | is_active
------------|---------------|--------------|----------
campaign | raw | salesforce_campaign | True
contact | raw | salesforce_contact | True
item | raw | salesforce_item | True
item_allocation | raw | salesforce_item_allocation | True
opportunity | raw | salesforce_opportunity | True
payment | raw | salesforce_payment | True
recurring_donation | raw | salesforce_recurring_donation | True
sponsorship | raw | salesforce_sponsorship | True
sponsorship_unit | raw | salesforce_sponsorship_unit | True


---

## 1. The object inventory (order = smallest first, biggest last)

| # | Salesforce API name | Raw table | Rough size | Recommended order | Status |
| --- | --- | --- | --- | --- | --- |
| 1 | `Campaign` | `raw.salesforce_campaign` | ~41K | **done** | ✅ proven |
| 2 | `Sponsorship_Unit__c` | `raw.salesforce_sponsorship_unit` | small | 1st next | ☐ |
| 3 | `Sponsorship__c` | `raw.salesforce_sponsorship` | small | 2nd | ☐ |
| 4 | `npsp__General_Accounting_Unit__c` | `raw.salesforce_item` | small/med | 3rd | ☐ |
| 5 | `npe01__OppPayment__c` | `raw.salesforce_payment` | medium | 4th | ☐ |
| 6 | `Contact` | `raw.salesforce_contact` | medium | 5th | ☐ |
| 7 | `npe03__Recurring_Donation__c` | `raw.salesforce_recurring_donation` | medium | 6th | ☐ |
| 8 | `Opportunity` | `raw.salesforce_opportunity` | **large** | 7th (late) | ☐ |
| 9 | `npsp__Allocation__c` | `raw.salesforce_item_allocation` | **largest** | last | ☐ |

> Do the big two (**Opportunity**, **Item Allocation**) last — they already have dedicated **resume**
> tables (`ctl.loaded_salesforce_*_ids`, `staging.*_resume_*`) because a full reload can be interrupted.

---

## 2. The repeatable recipe (per object)

For each object, repeat the same five stages. Everywhere below, replace the placeholders:

- `<Object>`   = Salesforce API name (e.g. `Sponsorship_Unit__c`)
- `<raw>`      = raw table (e.g. `raw.salesforce_sponsorship_unit`)
- `<obj>`      = short name for SQL objects (e.g. `sponsorship_unit`)

```text
[1 INGEST]  <Object> -> raw.<...>            (ADF Copy pipeline, append-only)
[2 STAGE]   staging.<obj>_latest             (dedup, 1 row per Id)      -- GATE
[3 CHECK]   dq rules over staging            (0 CRITICAL to proceed)    -- GATE
[4 CLEAN]   clean.<obj>                       (auto-fix + dq.alert)
[5 READY]   writeback.<obj>_pending           (queued, sign-off later)
```

### Stage 1 — Ingest (copy the Campaign pipeline)

> **✅ Already built (2026-08-07) — use the generic pipeline, don't clone.** The parameterized,
> watermark-incremental ingest is done: **`pl_object_etl`** (one object) and **`pl_run_all`** (loops
> `ctl.object_registry`), plus reusable datasets **`ds_sf`** (`p_object`) and **`ds_sql`**
> (`p_schema`/`p_table`). Run one object with `pl_object_etl` (params `p_object` / `p_raw_table` /
> `p_short`) or all via `pl_run_all`. Full how-to: [../Azure/README.md](../Azure/README.md). The manual
> "clone per object" steps below are kept only as the fallback and as an explanation of what the pipeline
> does internally.

- In ADF Studio, **clone `pl_ingest_campaign`** to `pl_ingest_<obj>` (or use the Campaign one as a template).
- Change three things only: the Copy **Source** object (`<Object>`), the Copy **Sink** table (`<raw>`), and
  the `StartRun`/`FinishRun` `object_name` literal (`N'<Object>'`).
- Reuse the same linked services (`ls_salesforce_poc`, `ls_sql_salesforcedw_POC`). Keep the mapping **empty**
  (auto-map by name), same as Campaign.
- **Gate:** run succeeded; `raw.<...>` has rows; a `Succeeded` row exists in `ctl.etl_run_control` for
  `<Object>`.

> **✅ Incremental is now implemented in `pl_object_etl` (2026-08-07)** — the note below explains the
> pattern and how the original `pl_ingest_campaign` was full-load. Campaign raw was already truncated +
> reloaded, so the ~81,694 doubling described here is **resolved**.
>
> **⚠️ Why it mattered — the original cloned Campaign pipeline was NOT incremental.** As built, `CopyCampaign` reads
> the **whole** object (Source = Object API name `Campaign`, `load_type = N'Full'`) and **appends** it, so
> every run re-copies all rows. That is why `raw.salesforce_campaign` grew to **~81,694 (≈2× the ~41K
> real rows)** after a second run. Dedup still collapses it, but raw balloons each run — unacceptable for
> the two big objects. Wire the watermark cursor (`ctl.watermark_control`) into the Copy **before**
> templating:
>
> 1. **`GetWatermark` (Lookup, first activity)** — read the object's cursor, with a floor so a NULL means
>    "full from the start":
>
>    ```sql
>    SELECT COALESCE(CONVERT(VARCHAR(33), last_watermark_value, 126), '1900-01-01T00:00:00Z') AS wm
>    FROM ctl.watermark_control WHERE object_name = N'<Object>';
>    ```
>
>    (Tick **First row only**. If the object has no row yet, seed one: `INSERT ctl.watermark_control
>    (object_name, watermark_column) VALUES (N'<Object>', N'SystemModstamp');`.)
> 2. **Capture an upper bound once** so rows modified mid-run aren't missed or double-counted — use one
>    `@utcnow()` (e.g. a `SetVariable` `runStart`) as the `<= now` edge.
> 3. **`CopyCampaign` Source → SOQL Query** (not "Object"): filter by the watermark. Salesforce wants ISO
>    8601 with `Z`, unquoted:
>
>    ```text
>    SELECT Id, Name, ..., SystemModstamp
>    FROM   <Object>
>    WHERE  SystemModstamp > @{activity('GetWatermark').output.firstRow.wm}
>      AND  SystemModstamp <= @{variables('runStart')}
>    ```
>
>    Set `StartRun` `load_type` to `Incremental` (or `Full` when the cursor is the `1900` floor).
> 4. **`FinishRun` → advance the cursor** in the same script that closes the run row:
>
>    ```sql
>    UPDATE ctl.watermark_control
>    SET last_watermark_value = @{variables('runStart')},
>        last_success_run_id  = @{activity('StartRun').output.firstRow.run_id},
>        updated_at = SYSUTCDATETIME()
>    WHERE object_name = N'<Object>';
>    ```
>
> **Reset-to-start any time:** `UPDATE ctl.watermark_control SET last_watermark_value = NULL WHERE
> object_name = N'<Object>';` → the next run reloads everything from the beginning. To fix the already
> doubled Campaign raw, `TRUNCATE TABLE raw.salesforce_campaign`, set its watermark NULL, and run once.

> **✅ Built as `pl_object_etl` + `pl_run_all`.** Rather than a copy-per-object pipeline, a single
> **parameterized** child (`pl_object_etl`, params `p_object` / `p_raw_table` / `p_short`) does the whole
> chain, and a parent (`pl_run_all`) drives it **metadata-first** off `ctl.object_registry` — a `Lookup`
> (active registry rows) → `ForEach` → `Execute pl_object_etl`. Adding an object is just a registry row.
> Attaching a schedule trigger to `pl_run_all` also closes the "no scheduler" gap above.
>
> **Prerequisite (done):** the registry is **seeded (9 rows as of 2026-08-07)**. If it ever reads empty,
> run `EXEC ctl.refresh_object_registry;` (see §0.1) before running `pl_run_all`.

### Stage 2 — Stage / dedup (materialize the latest view)

The dedup **view** `staging.vw_<obj>_latest` already exists. Materialize it into a table so DQ/clean read a
stable snapshot. Copy the Campaign proc and point it at the view (generic — no per-column list needed):

```sql
CREATE OR ALTER PROCEDURE [staging].[refresh_<obj>_latest]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DROP TABLE IF EXISTS [staging].[<obj>_latest];

    SELECT
        v.*,
        SYSUTCDATETIME() AS [staging_created_at]
    INTO [staging].[<obj>_latest]
    FROM [staging].[vw_<obj>_latest] AS v;
END;
GO
EXEC [staging].[refresh_<obj>_latest];
```

- **Gate:** `staging.<obj>_latest` has **0 duplicate Ids**:

  ```sql
  SELECT CONVERT(VARCHAR(18), Id) AS Id, COUNT(*) n
  FROM staging.<obj>_latest GROUP BY CONVERT(VARCHAR(18), Id) HAVING COUNT(*) > 1;  -- expect 0
  ```

### Stage 3 — Check (define + run DQ rules)

- Campaign had 19 rules seeded. **Each new object needs its own rules** in `dq.dq_rule_catalog`
  (`object_name = '<Object>'`, `source_view = 'staging.<obj>_latest'`). Copy the Campaign seed pattern
  (`Quality_layer_check/Tables/campaign/02_campaign_staging_dq_PROD_framework.sql`, Step 2) and adapt the
  columns/rules to the object.
- Run the incremental runner:

  ```sql
  EXEC dq.run_incremental_catalog_rules @ObjectNameFilter='<Object>', @MaxRowsPerRule=100000, @MaxExceptionsPerRule=500;
  ```

- **Gate:** 0 CRITICAL open exceptions for `<Object>`:

  ```sql
  SELECT COUNT(*) AS critical_open
  FROM dq.dq_exceptions e JOIN dq.dq_rule_catalog r ON r.rule_id = e.rule_id
  WHERE e.object_name='<Object>' AND r.severity='CRITICAL' AND e.resolution_status='Open';
  ```

> **Force a real check on first run:** the DQ runner is watermark-incremental. On a brand-new object the
> cursor starts empty so it scans everything; if you re-materialize staging and see `rows_checked = 0`,
> reset the cursor to NULL (see Campaign doc, Stage 3) to force a full re-scan.

### Stage 4 — Clean (copy + adapt the Campaign clean proc)

- Copy `database/clean/campaign_table.sql` → `database/clean/<obj>_table.sql`, rename the proc to
  `clean.refresh_<obj>` and the table to `clean.<obj>`, and **adapt the field transformations** to the
  object's real fields. Keep the safe pattern:
  - normalize obvious formats (currency/upper, boolean text → 1/0, dates via `TRY_CONVERT`),
  - keep original + cleaned side by side,
  - **never drop rows** — tag non-critical breaks with `clean_flag='REVIEW'` + `review_reason`,
  - **raise business-logic issues to `dq.alert`** (`cleaned = 0`) instead of editing them.
- Keep the **critical gate** at the top (refuse to build while any CRITICAL exception is open).
- **Gate:** `clean.<obj>` is unique per Id and no critical-failing Id leaked (same two checks as Campaign).

### Stage 5 — Push-ready

- Same as Campaign: queue approved corrections in `writeback.<obj>_pending`; the actual Salesforce
  write-back stays out of scope (needs admin support + sign-off).

---

## 3. Per-object checklist (copy one block per object)

```text
Object: <Object>   Raw: raw.<...>   Short: <obj>
[ ] 1 Ingest    pl_ingest_<obj> ran; raw rows present; ctl.etl_run_control Succeeded
[ ] 2 Stage     staging.refresh_<obj>_latest built; 0 duplicate Ids
[ ] 3 Check     DQ rules defined for <Object>; runner executed; 0 CRITICAL open
[ ] 4 Clean     clean.refresh_<obj> built clean.<obj>; unique Ids; no critical leak
[ ] 5 Alerts    dq.alert reviewed for <Object> (cleaned vs needs-a-person)
[ ] Ready       writeback.<obj>_pending queued (push-back deferred)
```

---

## 4. What differs per object (watch-outs)

- **Columns differ** — the generic Stage-2 `SELECT v.*` handles any column set, but the **clean proc and
  DQ rules are object-specific**; you must map each object's real fields.
- **DQ rules are not auto-created** — only Campaign is seeded. Budget time to define rules per object.
- **Alerts are object-specific** — add the object's business-logic checks to `dq.alert` the same way
  Campaign adds CAM-008 (won > all). Reuse the one shared `dq.alert` table.
- **Big objects (Opportunity, Item Allocation)** — prefer the **python.py container path (Path B)** for
  ingest so you get Full / Incremental / **ResumeMissing** and crash resume; ADF Copy also works but the
  resume proof matters most on the large objects.
- **Deploy wiring** — add each new `staging/<obj>_latest_table.sql` and `clean/<obj>_table.sql` to
  `_deploy.sql` (and `deploy_merged.sql` if you use the Portal one), mirroring the Campaign entries.

---

## 5. Definition of done (per object)

- Raw has the object's rows (duplicates/history allowed).
- `staging.<obj>_latest` is unique per Id, deleted rows excluded.
- DQ rules exist and report **0 CRITICAL** in scope.
- `clean.<obj>` exists, unique per Id, no critical-failing record; auto-fixes applied; the rest tagged.
- `dq.alert` carries the object's business-logic issues with the `cleaned` flag.
- State is provable from the control tables at any point.

When all 9 objects pass, the quality layer is complete and the same chain runs for every object by name.

---

## 6. Pricing — running all 9 objects

Relative estimate in **USD**, **not a quote** — confirm with the
[Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/). The Campaign POC was ~$8–13
for 3 days on one small object; scaling to all 9 changes the numbers mainly through the **two large
objects** (Opportunity, Item Allocation), not the small ones.

### 6.1 One-time full build (load + dedup + DQ + clean, all 9 objects)

| Service | What drives cost | One-time estimate |
| --- | --- | --- |
| Azure SQL Database (serverless, GP 1 vCore, auto-pause) | vCore-seconds **while active** — dominated by the 2 big objects' dedup/DQ/clean | ~$15–35 |
| Azure Data Factory | 9 ingest pipelines × (activity runs + Copy DIU-hours) | ~$3–8 |
| ADLS Gen2 storage | total raw + staging + clean (still small, ~1–3 GB) | < $0.50 |
| Log Analytics (if enabled) | ingested log volume | < $1 |
| **Total (one-time)** | | **~$20–45** |

### 6.2 Ongoing (daily incremental refresh of all 9 objects)

> **Not built yet.** This assumes a recurring **ADF schedule trigger** driving the nightly run — that
> trigger does **not** exist today (all runs so far were manual). The numbers below are the *target*
> ongoing cost once a schedule is added; until then, ongoing cost is $0 because nothing runs on its own.

| Service | What drives cost | Monthly estimate |
| --- | --- | --- |
| Azure SQL Database (serverless, auto-pause) | ~1–2 active vCore-hours/day for the nightly run; **~$0 while paused** | ~$25–45 |
| Azure Data Factory | ~9 pipelines/day × ~30 days (activity runs + small delta DIU-hours) | ~$8–18 |
| ADLS Gen2 storage | steady ~1–3 GB | < $1 |
| Log Analytics (if enabled) | small daily log volume | < $2 |
| **Total (monthly)** | | **~$35–65 / month** |

### 6.3 Why these numbers (the drivers explained)

- **Serverless SQL is the bill.** You pay **per vCore-second only while the database is active**, and it
  **auto-pauses to ~$0 when idle**. All the work (dedup, DQ rules, clean) is SQL, so total cost tracks how
  long compute runs — which is driven by the **two large objects**, not the seven small ones.
- **Incremental keeps it cheap.** After the first full build, each object only re-checks rows past its DQ
  watermark and re-materializes deterministically, so daily runs are short — the DB wakes, works for
  minutes, and pauses again.
- **ADF is pennies at this scale.** Cost is per **activity run** plus **Copy DIU-hours**; the datasets are
  small, so even 9 daily pipelines stay low.
- **Storage and logs are rounding error** at a few GB.

### 6.4 Keep it low

- Leave SQL **auto-pause ON** (biggest saver — idle ≈ $0).
- Run pipelines **on a schedule you actually need** (nightly, not every few minutes) — this requires
  **adding an ADF schedule trigger** (not yet built; runs are manual today).
- Do the **big objects last** and, for them, prefer **incremental** loads over repeated full reloads.
- If a registry is used for the python container path, **delete the ACR** when not running Path B (or use
  a public Docker Hub image) — see the Campaign doc, Part G.
- **Delete the resource group** entirely if the environment is only a POC.

> Rule of thumb: the **small 7 objects together** cost about the same as **Campaign alone**; the **2 big
> objects** roughly double the compute time. Budget accordingly and validate on the calculator.
