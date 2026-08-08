# ETL lineage standard (canonical `_etl_*` columns)

**Date:** 2026-08-08. The single written standard for the ETL lineage columns on every `raw.*` table.
Referenced by `Files.MD` (gap #1), the raw DDLs, `python.py`, and the ADF pipelines.

---

## The standard — three columns, on every raw table

| Column | Type | Meaning |
| --- | --- | --- |
| `_etl_run_id` | `BIGINT` | Foreign key into `ctl.etl_run_control.run_id` — the run that loaded this row. |
| `_etl_extracted_at_utc` | `DATETIME2(7)` | When the row was **extracted from Salesforce** (source-side freshness). |
| `_etl_source_object` | `NVARCHAR(MAX)` | The Salesforce object the row came from. |

**Deprecated (do not use):** `_etl_source`, `_etl_loaded_at_utc`.

## Why these three (and why not the old two)

- **`_etl_run_id` beats `_etl_source`.** `_etl_run_id` is a **joinable key** into `ctl.etl_run_control`, so
  a row can be traced to its full run: load type, status, row counts, timestamps, errors. The old
  `_etl_source` was only a free-text label ("salesforce") — not joinable and redundant (the table already
  tells you the source).
- **`_etl_extracted_at_utc` beats `_etl_loaded_at_utc`.** Extract time reflects **data freshness** and lines
  up with the `SystemModstamp` watermark. Load time (sink-side) is **already derivable** from the run row,
  so storing it per row duplicates data.
- **Normalized:** heavy run metadata lives **once** in `ctl.etl_run_control`; each raw row carries only the
  compact `run_id`. This also matches **ADF** (pipeline/run id → `_etl_run_id`) and the repo DDL.

## Where it is enforced

- **`python.py`** — `prepare_dataframe()` stamps the three columns (with a review comment explaining why).
- **ADF** — `pl_object_etl` opens a run in `ctl.etl_run_control` (`StartRun`) and the Copy maps the run id.
- **Repo DDL** — every `database/raw/salesforce_<obj>_table.sql` declares the three columns.

## Migration — the one open divergence

**Current:** 5 raw tables in the live local DB (`campaign, contact, recurring_donation, sponsorship,
sponsorship_unit`) still carry the **old** `_etl_source` / `_etl_loaded_at_utc`; the other 4 + the whole
repo use the canonical three.

**Note:** this does **not** block staging/DQ — the staging builders read only business columns +
`SystemModstamp`, and clean carries only `SystemModstamp`. It is a **lineage-consistency** fix, not a
blocker.

**To reconcile (repo wins):**
1. `python.py` already writes the canonical three — no code change needed.
2. Re-load the 5 old raw tables from the repo DDL (`database/raw/salesforce_<obj>_table.sql`) so their
   columns match, then re-run ingestion.
3. Redeploy any `staging.vw_<obj>_latest` view that referenced an old column name.
4. Verify with `scripts/db_inventory.sql` (section 2, columns) that all 9 raw tables show the same three.

## Related docs
- `Quality_layer_check/DOCS/dq_clean_staging_approach.md` — how staging/clean deliberately avoid `_etl_*`.
- `Quality_layer_check/DOCS/dq_framework_reference.md` — the DQ map + doc inventory.
- `Files.MD` — gap #1 (current / need / why).
