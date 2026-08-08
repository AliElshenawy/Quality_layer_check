# DQ · Staging · Clean — Recommended Approach

Date: 2026-08-06. Companion to [campaign_azure_poc.md](campaign_azure_poc.md) and
[poc_expand_to_all_objects.md](poc_expand_to_all_objects.md). This is the **engineering design** for the
three middle layers so they work as one coherent unit for every object.

---

## The layered flow (one responsibility per layer)

```text
raw.salesforce_<obj>      append-only, all NVARCHAR(MAX), duplicates + history allowed
        │  dedup (1 row / Id, latest by SystemModstamp, deleted excluded)
        ▼
staging.<obj>_latest      the "current truth" — everything downstream reads THIS, never raw
        │  DQ rules run HERE
        ▼
dq.dq_exceptions          per-rule violations + severity (via dq.dq_rule_catalog)
        │  gate: 0 CRITICAL
        ▼
clean.<obj>               gated, auto-fixed, original + cleaned side by side
        │  issues that can't be auto-fixed
        ▼
dq.alert                  business action list (cleaned flag: auto-fixed vs needs-a-person)
```

**Golden rule:** validate and clean the **deduped current truth (staging)**, never raw.

---

## 1. Staging — how to build "latest"

- **Views** `staging.vw_<obj>_latest` (already deployed) do the dedup:
  `ROW_NUMBER() PARTITION BY Id ORDER BY SystemModstamp DESC`, excluding soft-deleted rows.
- **Materialize** the view into a table so DQ/clean read a stable snapshot:
  - **Generic** builder for every object: `EXEC staging.refresh_object_latest @object_short='<obj>';`
    (`SELECT v.* … INTO staging.<obj>_latest FROM staging.vw_<obj>_latest`). One proc, all objects.
  - **Campaign** keeps a curated builder (`staging.refresh_campaign_latest`) for its specific 26-col shape.
- **Gate 2 (must pass):** `staging.<obj>_latest` has **0 duplicate Ids**.
- **Why a table, not just the view?** deterministic snapshot, faster repeated DQ scans, and a place to add
  provenance (`staging_created_at`, and for Campaign `staging_is_duplicate` / `staging_duplicate_count`).

> **Prerequisite:** the raw + view **ETL column naming must match** per object. Today `contact` (raw old /
> view new) and `item` (raw new / view old) are misaligned, so their views can't materialize. Standardize
> on `_etl_run_id` / `_etl_extracted_at_utc` / `_etl_source_object` first (see `Files.md`).

## 2. DQ — how to run the rules

- **Rules live in `dq.dq_rule_catalog`** (one row per rule: `object_name`, `source_view` =
  `staging.<obj>_latest`, `check_name` = `<OBJ>-NNN`, `check_type`, `severity`, `rule_definition`).
- **Run on staging**, incrementally: `EXEC dq.run_incremental_catalog_rules @ObjectNameFilter='<Object>' …`.
  The runner scans only rows past each rule's watermark and writes violations to `dq.dq_exceptions`.
- **Rule types:**
  - **Enforced** — fail rows that break a hard rule (nulls, invalid Id, start>end, won>all).
  - **Report-only / listing** — surface values for human review without a controlled list (e.g. **CAM-016
    Region** now lists distinct populated regions; **CAM-004 Status** / **CAM-006 Currency** are report-only).
    Prefer report-only when there is no approved reference list — avoids false positives.
- **Severity drives behaviour:** `CRITICAL` blocks the clean build; `HIGH/MEDIUM/LOW` are recorded and route
  to review/alert. Keep CRITICAL for true data-integrity breaks only.
- **First run:** the watermark starts empty so everything is scanned; if you rebuild staging and see
  `rows_checked = 0`, reset the rule cursors to NULL to force a full re-scan.

## 3. Clean — how to build the final set

- **Split into two files** (repo convention): the **persistent table** `clean/campaign_table.sql`
  (created once, never dropped) and the **build proc** `clean/refresh_campaign_SP.sql`.
- **Incremental by MERGE (upsert by `Id`)** — the proc reads only staging rows changed since the
  `ctl.clean_state` watermark and **MERGEs** them into `clean.campaign`, then advances the watermark.
  - **No full DROP/rebuild** each run — so approved write-back corrections applied to clean **survive**.
  - **No end-dedup needed** — staging is already unique per `Id` and MERGE upserts by `Id`, so duplicates
    never accumulate. (Staging *does* dedup because raw has real duplicates; clean does not.)
  - `EXEC clean.refresh_campaign;` = incremental; `EXEC clean.refresh_campaign @FullRebuild = 1;` =
    truncate + rebuild (reset).
- **Gate:** builds **only at 0 CRITICAL** — the proc counts open critical exceptions
  (`dq.dq_exceptions` JOIN `dq.dq_rule_catalog` on severity) and `RAISERROR`s if any exist.
- **Auto-fix only safe, deterministic things** (keep original + cleaned side by side):
  - format/trim/case (currency → UPPER, status whitespace/case),
  - boolean text → `1/0`, dates via `TRY_CONVERT` (invalid → NULL),
  - derivable values (Year from StartDate),
  - **safe business defaults** (blank Status → `Aborted`).
- **Never auto-change judgemental/business values.** Rows that fail non-critical rules are **kept and
  tagged** (`clean_flag='REVIEW'`, `review_reason`), never dropped.
- **Keys/lineage** (`Id`, `SystemModstamp`) carried unchanged. (ETL columns are omitted until naming is
  standardized, so clean stays independent of raw's split-brain.)
- **Not yet handled incrementally:** hard-deletes (an Id dropping out of staging). Use `@FullRebuild = 1`
  periodically, or add a delete-sync, to remove stale rows.

## 4. Alerts — how humans take action, and how it flows back to clean

- **`dq.alert`** is the business action list: one row per issue that **can't** be auto-fixed, with a
  **`cleaned` flag** (`1` = auto-fixed/informational, `0` = needs a person) and an `alert_status`
  (Open → Reviewed → Approved/Rejected → Resolved). Today it carries **CAM-008 (won > all)**.
- **Action loop (make it easy + auditable):**
  1. Reviewer queries `dq.alert WHERE cleaned = 0 AND alert_status = 'Open'`.
  2. Sets `alert_status = 'Approved'` with a decided value (add `decided_value` / `decided_by` columns).
  3. `writeback.<obj>_pending` receives the approved correction (Id, field, old → new, approver, status).
  4. An **apply** proc writes the approved value into `clean.<obj>` and marks the alert `Resolved`.
  5. (Later, gated) a job pushes `Approved` writeback rows to Salesforce and marks them `Pushed`.
- **Invariant:** auto-fixes are deterministic; everything judgemental is an **approved, logged action** —
  no silent edits.

## 5. Run logging — do we save every run? (and ADF)

- **Yes, but in ONE generic place:** `ctl.etl_run_control` (run id, object, load type, status, row counts,
  timestamps) + `ctl.watermark_control` (incremental cursor). The Campaign-specific `ctl.save_campaign_run`
  proc is **not needed** — use the generic control tables for all objects.
- **With ADF:** the pipeline opens/closes a run row via the `StartRun` (Lookup) / `FinishRun` (Script)
  activities (already in `pl_ingest_campaign`), and **ADF Monitor** captures pipeline/activity status +
  errors natively. For deeper logs, wire ADF diagnostics to **Log Analytics**. So: **ADF Monitor for
  orchestration logs + `ctl.etl_run_control` for the data-run audit trail** — no custom per-object logger.

---

## Worked example — Campaign (end to end)

One Campaign record as it moves through the layers (illustrative values).

**1. `raw.salesforce_campaign`** — append-only; two versions of the same `Id`, latest wins:

| Id | Name | Status | CurrencyIsoCode | AmountWonOpportunities | AmountAllOpportunities | SystemModstamp |
| --- | --- | --- | --- | ---: | ---: | --- |
| 701…AAA | Ramadan 2026 | completed | gbp | 1200 | 1000 | 2026-07-29 04:42 |
| 701…AAA | Ramadan 2026 | | gbp | 900 | 1000 | 2026-07-10 09:15 |

**2. `staging.campaign_latest`** — 1 row/Id, latest by `SystemModstamp`, deleted excluded:

| Id | Name | Status | CurrencyIsoCode | AmountWonOpportunities | AmountAllOpportunities |
| --- | --- | --- | --- | ---: | ---: |
| 701…AAA | Ramadan 2026 | completed | gbp | 1200 | 1000 |

**3. `dq.dq_exceptions`** — rules run on staging; this row fails **CAM-008** (won > all):

| check_name | record_id | exception_value | severity | resolution_status |
| --- | --- | --- | --- | --- |
| CAM-008 | 701…AAA | Won=1200; All=1000 | MEDIUM | Open |

**4. `clean.campaign`** — built at 0 CRITICAL; safe auto-fixes applied (currency → `GBP`, status → canonical `Completed`); CAM-008 is judgemental → **not** auto-fixed, row kept + flagged:

| Id | Name | Status | CurrencyIsoCode | clean_flag | review_reason |
| --- | --- | --- | --- | --- | --- |
| 701…AAA | Ramadan 2026 | Completed | GBP | REVIEW | CAM-008 won>all |

**5. `dq.alert`** — business action list; CAM-008 can't be auto-fixed → needs a person:

| object_name | record_id | check_name | issue | current_value | cleaned | alert_status |
| --- | --- | --- | --- | --- | --- | --- |
| Campaign | 701…AAA | CAM-008 | Won amount exceeds All amount | Won=1200; All=1000 | 0 | Open |

The reviewer decides the fix → it flows to `writeback.campaign_pending` → an apply proc writes it into
`clean.campaign` and marks the alert `Resolved` (see §4).

---

## Best-practice checklist (per object)

- [ ] raw + view ETL columns aligned (canonical `_etl_*`).
- [ ] `staging.<obj>_latest` built; 0 duplicate Ids.
- [ ] rules defined in `dq.dq_rule_catalog` (enforced vs report-only chosen deliberately).
- [ ] DQ run executed; 0 CRITICAL.
- [ ] `clean.<obj>` built (gated); auto-fixes applied; non-critical tagged REVIEW.
- [ ] `dq.alert` carries the object's judgemental issues (cleaned flag set).
- [ ] run logged in `ctl.etl_run_control`; ADF Monitor green.
