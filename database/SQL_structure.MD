# SQL file structure — `Quality_layer_check/database`

Every object is one file. The build order lives in **`_deploy.sql`** (schemas → tables → views →
procedures). To add anything, create the file in its schema folder and add a `:r <path>` line to
`_deploy.sql` in the right section. Naming: `<name>_table.sql` (persistent table), `<name>_SP.sql`
(procedure, `CREATE OR ALTER`), `<name>_view.sql` (view).

Deploy: `sqlcmd -S <server> -d SalesforceDW -i _deploy.sql` (or the pre-merged `deploy_merged.sql` in the
Portal). Re-runnable: tables use `IF OBJECT_ID ... IS NULL`, procs use `CREATE OR ALTER`.

---

## Root

| File | For | Use / add |
| --- | --- | --- |
| `_deploy.sql` | The ordered include list — the deploy entry point | Run it to build everything; add a `:r` line for each new file |
| `deploy_merged.sql` | Single pre-merged file (all `:r` inlined) for the Portal Query editor | Regenerate via `scripts/merge_sql_deploy.py` after changing `database/**` |
| `00_database.sql` | `CREATE DATABASE` + settings (environment-specific) | Run **manually** once on a brand-new server; not in `_deploy.sql` |
| `00_schemas.sql` | Creates schemas: `ctl, dq, mart, raw, staging, writeback, clean` | First include in `_deploy.sql` |
| `SQL_structure.MD` | This inventory | Keep in sync when files are added |
| `_migrations/2026-08-06_cleanup.sql` | One-off migration (drop legacy tables, CAM-016 report-only) | Run once against an existing DB; not part of the fresh build |

## `raw/` — landing tables (append-only, all `NVARCHAR(MAX)` + `_etl_*` lineage)

One table per object; ingest **appends** (never dropped). Section 2 of `_deploy.sql`.

| File | Table |
| --- | --- |
| `salesforce_campaign_table.sql` | `raw.salesforce_campaign` |
| `salesforce_contact_table.sql` | `raw.salesforce_contact` |
| `salesforce_item_table.sql` | `raw.salesforce_item` (GAU) |
| `salesforce_item_allocation_table.sql` | `raw.salesforce_item_allocation` |
| `salesforce_opportunity_table.sql` | `raw.salesforce_opportunity` |
| `salesforce_payment_table.sql` | `raw.salesforce_payment` |
| `salesforce_recurring_donation_table.sql` | `raw.salesforce_recurring_donation` |
| `salesforce_sponsorship_table.sql` | `raw.salesforce_sponsorship` |
| `salesforce_sponsorship_unit_table.sql` | `raw.salesforce_sponsorship_unit` |

**Add an object:** create `raw/salesforce_<obj>_table.sql`, add to `_deploy.sql` section 2.

## `ctl/` — control (run log, watermarks, registry, orchestration)

| File | Object | For |
| --- | --- | --- |
| `etl_run_control_table.sql` | `ctl.etl_run_control` | Run log (open/close each ingest run, row counts) |
| `watermark_control_table.sql` | `ctl.watermark_control` | Ingest cursor per object (`SystemModstamp`) |
| `staging_state_table.sql` | `ctl.staging_state` | Incremental **staging** watermark per object |
| `clean_state_table.sql` | `ctl.clean_state` | Incremental **clean** watermark per object |
| `object_registry_table.sql` | `ctl.object_registry` | Active objects + metadata; drives the per-object loop |
| `loaded_salesforce_opportunity_ids_table.sql` | `ctl.loaded_salesforce_opportunity_ids` | ResumeMissing ids (large object) |
| `loaded_salesforce_item_allocation_ids_table.sql` | `ctl.loaded_salesforce_item_allocation_ids` | ResumeMissing ids (large object) |
| `refresh_latest_views_SP.sql` | `ctl.refresh_latest_views` | (Legacy) rebuild the `vw_*_latest` views |
| `refresh_object_registry_SP.sql` | `ctl.refresh_object_registry` | Seed/refresh `ctl.object_registry` |
| `validate_pipeline_metadata_SP.sql` | `ctl.validate_pipeline_metadata` | Preflight checks on registry/metadata |
| `run_object_pipeline_SP.sql` | `ctl.run_object_pipeline` | Orchestrator: runs staging → DQ → clean for one object with gates |
| `create_adf_sql_user.sql` | (script) | Creates the ADF managed-identity DB user; run manually on Azure |

## `staging/` — dedup views + incremental "latest" builders

Each curated object is **two files**: `<obj>_latest_table.sql` (persistent table DDL, `IF NOT EXISTS`,
computed `Id18` + unique index) and `<obj>_latest_SP.sql` (the incremental builder
`staging.refresh_<obj>_latest`). The builder is delete-changed + insert-dedup by the
`ctl.staging_state` watermark; `@FullRebuild=1` truncates + reloads. No `DROP` in the normal path.

| File | Object | For |
| --- | --- | --- |
| `vw_<obj>_latest_view.sql` (9) | `staging.vw_<obj>_latest` | Dedup view: `ROW_NUMBER() PARTITION BY Id ORDER BY SystemModstamp DESC`, excludes deleted |
| `campaign_latest_table.sql` / `campaign_latest_SP.sql` | `staging.campaign_latest` / `staging.refresh_campaign_latest` | Curated table + incremental builder |
| `contact_latest_table.sql` / `contact_latest_SP.sql` | `staging.contact_latest` / `staging.refresh_contact_latest` | Curated table + incremental builder |
| `item_gau_latest_table.sql` / `item_gau_latest_SP.sql` | `staging.item_gau_latest` / `staging.refresh_item_gau_latest` | Curated table + incremental builder |
| `recurring_donation_latest_table.sql` / `recurring_donation_latest_SP.sql` | `staging.recurring_donation_latest` / `staging.refresh_recurring_donation_latest` | Curated table + incremental builder |
| `refresh_object_latest_SP.sql` | `staging.refresh_object_latest` | **Generic incremental** builder over `vw_<obj>_latest` (view-based; `@object_short`) — used by sponsorship, sponsorship_unit, etc. |
| `salesforce_opportunity_resume_*_table.sql` (2) | resume batch/ids | Large-object ResumeMissing state |
| `salesforce_item_allocation_resume_*_table.sql` (2) | resume batch/ids | Large-object ResumeMissing state |

**Run staging (incremental):** `EXEC staging.refresh_<obj>_latest;` (curated objects) or
`EXEC staging.refresh_object_latest @object_short=N'<obj>';` (generic). `@FullRebuild=1` truncates + reloads.
**Add a curated object:** copy `campaign_latest_table.sql` + `campaign_latest_SP.sql`, swap the column
list (source of truth = `Tables/<obj>/02_<obj>_staging_dq_PROD_framework.sql`), the raw source table, and
the `object_name` key; add both files to `_deploy.sql` section 6b. Objects without a curated column set
(sponsorship, sponsorship_unit) just use the generic `refresh_object_latest`.

## `dq/` — data-quality framework

| File | Object | For |
| --- | --- | --- |
| `dq_rule_catalog_table.sql` | `dq.dq_rule_catalog` | Rule definitions (one row per rule) |
| `dq_exceptions_table.sql` | `dq.dq_exceptions` | Per-record violations (upserted state) |
| `dq_results_table.sql` | `dq.dq_results` | Append-only per-run history |
| `dq_alert_table.sql` | `dq.alert` | Business action list (`cleaned` flag) |
| `rule_execution_state_table.sql` | `dq.rule_execution_state` | Per-rule watermark cursor + run stats |
| `rule_execution_audit_table.sql` | `dq.rule_execution_audit` | Rule lifecycle audit |
| `field_mapping_table.sql` | `dq.field_mapping` | Source→semantic column mapping (rule bootstrap) |
| `field_profile_table.sql` / `profile_run_table.sql` | `dq.field_profile`, `dq.profile_run` | Profiling output (nulls/distinct/patterns) |
| `technical_result_table.sql` / `technical_run_table.sql` | `dq.technical_*` | Legacy generic technical-check output |
| `run_incremental_catalog_rules_SP.sql` | `dq.run_incremental_catalog_rules` | **The main runner** (watermark-incremental) |
| `prepare_incremental_rule_queue_SP.sql` | `dq.prepare_incremental_rule_queue` | Registers rules, signatures, watermark column |
| `run_active_catalog_rules_SP.sql` | `dq.run_active_catalog_rules` | Legacy full-scan runner |
| `analyze_object_SP.sql`, `run_dynamic_field_profile_SP.sql`, `run_dynamic_technical_checks_SP.sql` | profiling procs | Bootstrap new objects (profile → suggest checks) |
| `suggest_field_mappings_SP.sql`, `apply_high_confidence_mappings_SP.sql` | mapping procs | Seed rules faster |
| `vw_rule_readiness_view.sql` | `dq.vw_rule_readiness` | Which rules are ready to run |

**Run DQ (incremental):** `EXEC dq.run_incremental_catalog_rules @ObjectNameFilter=N'<Object>', @MaxRowsPerRule=100000, @MaxExceptionsPerRule=500;`
**Add a rule:** `INSERT INTO dq.dq_rule_catalog (...)` — no redeploy (rules are data).

## `clean/` — final gated, incremental output

| File | Object | For |
| --- | --- | --- |
| `campaign_table.sql` | `clean.campaign` | Persistent clean table (DDL only, `IF NOT EXISTS`, unique `Id18`) |
| `refresh_campaign_SP.sql` | `clean.refresh_campaign` | **Incremental MERGE** build (gate at 0 CRITICAL; `@FullRebuild` reset); writes `dq.alert` (CAM-008) |

**Run clean (incremental):** `EXEC clean.refresh_campaign;` (`@FullRebuild=1` to reset).
**Add an object:** copy `campaign_table.sql` + `refresh_campaign_SP.sql` → `<obj>_table.sql` +
`refresh_<obj>_SP.sql`, adapt columns + fixes.

## `mart/` — reporting models

| File | Object | For |
| --- | --- | --- |
| `dim_campaign_table.sql` | `mart.dim_campaign` | Campaign reporting dimension (Power BI reads the mart) |
| `.gitkeep` | — | keeps the folder |

## `writeback/` — approved corrections queue (design stage)

| File | For |
| --- | --- |
| `.gitkeep` | Placeholder — `writeback.<obj>_pending` tables + enqueue/apply procs not built yet |

## `dbo/` — utilities

| File | Object | For |
| --- | --- | --- |
| `usp_null_analysis_SP.sql` | `dbo.usp_null_analysis` | Per-column null/blank profiling for any table |

---

## How to add a new file (checklist)
1. Create it in the matching schema folder with the naming convention.
2. Table = persistent (`IF OBJECT_ID ... IS NULL`); proc = `CREATE OR ALTER`; builders MERGE/upsert (no `DROP` in the normal path — `@FullRebuild` truncates for reset).
3. Add a `:r <folder>\<file>` line to `_deploy.sql` in the correct dependency section.
4. Regenerate `deploy_merged.sql` (`scripts/merge_sql_deploy.py`) if you use the Portal path.
5. Update this file.

---

## How to add rules (DQ, clean-fix, and check/alert)

> These three are **data + proc edits**, not schema changes. The authoritative, worked-example docs are
> [../DQ Frame work/DQ_framework_creation.md](../DQ%20Frame%20work/DQ_framework_creation.md) ("How to add a
> new rule" + "How to apply and verify") and [../DOCS/dq_framework_reference.md](../DOCS/dq_framework_reference.md)
> (§4 rule types, §6 the alert concept). Clean-layer intent is in
> [../DOCS/dq_clean_staging_approach.md](../DOCS/dq_clean_staging_approach.md). This section is the short map;
> read those for detail.

### 1. Add a **DQ rule** (detection) — *rules are data, no redeploy*
`INSERT` one row into `dq.dq_rule_catalog`, then run the incremental runner. On its first run a new rule
scans from the beginning (its cursor starts NULL).
```sql
INSERT INTO dq.dq_rule_catalog
    (object_name, source_view, check_name, check_type, target_column, severity,
     description, is_active, created_at, rule_source, approval_status, process_name, rule_definition)
VALUES
    (N'Campaign', N'staging.campaign_latest', N'CAM-NEW-001', N'NOT_NULL', N'Name', N'HIGH',
     N'Campaign Name must not be null', 1, SYSUTCDATETIME(), N'MANUAL_ADD', N'Approved', N'DQ_FRAMEWORK', NULL);

EXEC dq.run_incremental_catalog_rules @ObjectNameFilter = N'Campaign';
```
- Built-in `check_type`: `NOT_NULL`, `VALID_DATETIME`, `VALID_SALESFORCE_ID`, `VALID_BOOLEAN`.
- `CUSTOM_SQL`: put the query in `rule_definition`, use the `{{SOURCE_VIEW}}` token, and return exactly
  `record_id, exception_value, exception_details, etl_run_id`.
- `check_name` = `<OBJ>-NNN`; unique on (`object_name`, `check_name`). Editing a rule's pass/fail logic
  changes its core signature and flags it `reprocess_review_pending` (forward-only unless you reset the cursor).

### 2. Add a **clean auto-fix rule** (correction) — *edit the object's clean proc*
Auto-fixes live inline in `clean/refresh_<obj>_SP.sql` (persistent MERGE, gated at 0 CRITICAL). Only
**safe/deterministic** transforms belong here (e.g. Campaign: currency `UPPER`, status trim→canonical,
`IsActive` boolean, `Year` from `StartDate`). Anything judgemental must **not** be silently overwritten —
tag it `REVIEW` or raise an alert (step 3). Add the fix expression in the MERGE `SET`/`SELECT`, keeping the
pre-fix value visible in `dq.dq_exceptions`.

### 3. Add a **check/alert** (human action) — *upsert into `dq.alert` from the clean proc*
Alerts are written **inline by each object's clean proc** (no generic router yet). Upsert keyed on
`object_name + record_id + check_name`, set `cleaned = 0` for "needs a person" (e.g. Campaign CAM-008
`won > all`), `cleaned = 1` for informational auto-corrected. `alert_status` moves `Open → Reviewed →
Resolved`. New objects add their business-logic alerts the same way Campaign adds CAM-008, reusing the one
shared `dq.alert` table.

**Is this documented elsewhere?** Yes — DQ-rule addition and verification is fully covered in
`DQ_framework_creation.md`; the alert concept and the (design-stage) writeback/decision loop are in
`dq_framework_reference.md` §6 and `poc_expand_to_all_objects.md`. This section only cross-links them so the
file inventory is self-contained.
