# DQ Framework Creation (Watermark Incremental, No Truncate)

This framework is designed for very large tables where full truncate-and-reload of violation data is expensive. It is driven by a **source watermark** (`SystemModstamp`), not by a pending/done state machine.

## What this solves

1. New rule added:
- Rule is registered with watermark = NULL (never processed).
- First run scans all rows, inserts violations, and advances the watermark to the max `SystemModstamp` it processed.

2. Next run after no rule change:
- Only rows with `SystemModstamp` greater than the rule's watermark are checked.
- If nothing new arrived, the run checks 0 rows (status `CAUGHT_UP`). There is **no `DONE`** — the rule simply waits for new/changed rows.

3. Rule edited:
- Framework detects a **core-signature** change (fields that change pass/fail).
- The rule is flagged `reprocess_review_pending = 1` and logged. Old rows are **not** auto-rescanned.
- Operator decides: REPROCESS (reset watermark to NULL and re-run) vs JUST UPDATE the rule (new rows use the new logic going forward).

4. Failed run:
- `last_run_status = 'ERROR'` with `last_error_message`. The rule is retried on the next run (its watermark did not advance).

## Objects created

- dq.rule_execution_state
  - Per rule: `rule_signature`, `rule_core_signature`, `last_applied_core_signature`, `source_watermark_column`, `last_source_watermark_value` (the cursor), `reprocess_review_pending`, and run stats (`last_run_status`, `last_run_rows_checked`, `last_run_failed_count`, `last_error_message`, `run_count`).
- dq.rule_execution_audit
  - Rule lifecycle/audit trail (`RULE_DISCOVERED`, `RULE_CORE_CHANGED_REVIEW`, `RULE_METADATA_UPDATED`, `RULE_REJECTED_NO_WATERMARK`).
- dq.rule_action_config
  - Future extension for auto-fix UPDATE actions.
- dq.prepare_incremental_rule_queue (proc)
  - Registers rules, computes signatures, resolves the watermark column, flags core changes for review.
- dq.run_incremental_catalog_rules (proc)
  - Checks only rows newer than each rule's watermark, upserts dq results/exceptions, advances the watermark.
  - Supports both generic templates and CUSTOM_SQL rules.
- dq.apply_rule_updates (proc)
  - Optional future remediation runner (dry-run supported).

### Result and audit tables it uses (not created by this script)

- `dq.dq_results` — append-only history: one row per rule per run (`rows_checked`, `failed_count`, `check_status`, `details`, `checked_at`). The watermark runner writes here every run. **Keep it** — it is the evidence/history trail. `dq.rule_execution_state` only holds the current cursor/status (one row per rule); `dq.dq_results` holds the timeline.
- `dq.rule_action_config` — remediation config (`action_mode` DETECT_ONLY/AUTO_FIX, `update_sql`) consumed by `dq.apply_rule_updates`. Optional; unused until you configure AUTO_FIX rules. Keep as the detect→remediate extension point.
- `dq.technical_run` — a run-level log (`dq_run_id`, `started_at`, `completed_at`, `run_status`) written by the **legacy** DQ engine procedures, not by `dq.run_incremental_catalog_rules`. It is inert for this watermark framework; keep it only if the legacy engine is still used, otherwise it can be retired.

## Core behavior

- Incremental cursor is the **watermark value** (`last_source_watermark_value`), advanced to `MAX(SystemModstamp)` of each processed batch.
- Every rule must be batchable: its source must expose a datetime watermark column (`SystemModstamp` > `LastModifiedDate` > `_etl_loaded_at_utc`). Rules without one are rejected at prepare time.
- Rows checked so far = `COUNT(*) WHERE SystemModstamp <= last_source_watermark_value`.
- "Caught up" = `last_source_watermark_value = MAX(SystemModstamp)` in the source right now. New rows push MAX forward, so a rule is never permanently done.
- Core-signature change detection uses SHA2-256 over the pass/fail fields; cosmetic edits (description/severity) do not trigger review.
- Exception lifecycle is incremental (upsert; records that re-enter the window and pass are resolved).
- No wholesale truncate of dq.dq_exceptions.
- Supports existing check types currently in your engine:
  - NOT_NULL
  - VALID_DATETIME
  - VALID_SALESFORCE_ID
  - VALID_BOOLEAN
  - CUSTOM_SQL

## Rule migration file from existing PROD scripts

- mohey_work/DQ Frame work/DQ_framework_seed_checks_from_existing_prod.sql
  - Loads current checks from campaign, sponsorship, sponsorship_unit, recurring_donation, item_gau.
  - Uses generic check types when possible.
  - Uses CUSTOM_SQL for multi-column/join/conditional rules.

## How to run

1. Execute once:
- mohey_work/DQ Frame work/DQ_framework_creation_incremental.sql

1.1. Seed current rules into dq catalog:
- mohey_work/DQ Frame work/DQ_framework_seed_checks_from_existing_prod.sql

2. Daily incremental run:
```sql
EXEC dq.run_incremental_catalog_rules
     @MaxRowsPerRule = 100000,
     @MaxExceptionsPerRule = 500;
```

2.1. Daily incremental run for one large object only:
```sql
EXEC dq.run_incremental_catalog_rules
  @ObjectNameFilter = N'Campaign',
  @MaxRowsPerRule = 100000,
  @MaxExceptionsPerRule = 500;
```

3. Drain all new rows for an object (no batch cap):
```sql
EXEC dq.run_incremental_catalog_rules
     @MaxRowsPerRule = 0,
     @MaxExceptionsPerRule = 2000,
  @ObjectNameFilter = N'Campaign',
     @ResolveWhenFull = 1;
```

4. Force one rule (still watermark-driven):
```sql
EXEC dq.run_incremental_catalog_rules
     @ForceRuleId = 12,
     @MaxRowsPerRule = 0;
```

5. Force a FULL re-scan of a rule (operator decision after a core change):
```sql
UPDATE dq.rule_execution_state
SET last_source_watermark_value = NULL, reprocess_review_pending = 0
WHERE rule_id = 12;
EXEC dq.run_incremental_catalog_rules @ForceRuleId = 12, @MaxRowsPerRule = 0;
```

## Is it expandable?

Yes. This pattern is expandable in 3 directions:

1. More rule types:
- Add more check_type templates in dq.run_incremental_catalog_rules.

2. Object-level partitioning:
- Run by object batches (campaign, sponsorship, etc.) for operational windows.

3. Detection to remediation:
- Keep detect in dq_rule_catalog.
- Configure update actions in dq.rule_action_config.
- Run dq.apply_rule_updates in dry-run first, then controlled execute.

## End-to-end lifecycle (your requested behavior)

1. Add a new rule in dq.dq_rule_catalog:
- prepare registers it with watermark = NULL and resolves its watermark column.
- run procedure scans all rows, inserts/upserts violations, advances the watermark.

2. Add another new rule later:
- caught-up rules just check any rows newer than their watermark (0 if none).
- the new rule scans from the beginning on its first run.

3. Edit an existing active rule (core change):
- core signature changes; rule is flagged `reprocess_review_pending = 1` and logged.
- old rows are NOT auto-rescanned; ASK the operator: reprocess vs just update.
- new rows are checked with the new logic regardless.

4. Rerun after no data change:
- every rule checks for rows past its watermark; caught-up rules do 0 work.

## What to review before production

1. Confirm object names in dq.dq_rule_catalog.object_name match your filter values.
2. Confirm source_view values resolve correctly (example: staging.vw_campaign_latest).
3. Confirm rule definitions for changed rules are final before first full run.
4. Decide per object whether daily runs are sample (@MaxRowsPerRule > 0) or full (0).
5. Keep full-run cadence (weekly or monthly) for stale exception resolution.

## Suggested operating model for huge tables

1. Business hours:
- run pending-only with sampling and object filter.

2. Off-hours:
- run full mode per object (or all objects) to resolve stale opens.

3. Rule deployment flow:
- add/edit rule.
- run object-specific full for that object.
- review dq_results and dq_exceptions.
- then resume pending-only cycle.

## Recommended guardrails for remediation mode

- Start with dry-run only.
- Require approval status in dq_rule_catalog before AUTO_FIX.
- Wrap each rule update in transaction.
- Log affected row counts and error details.
- Keep backup/restore strategy for high-risk objects.

## How to check rule status and watermark progress

Use these queries to see framework execution status clearly.

1. Rule state dashboard (all objects)

```sql
SELECT
  r.object_name,
  r.check_name,
  r.check_type,
  s.last_run_status,
  s.last_source_watermark_value,
  s.reprocess_review_pending,
  s.last_run_started_at,
  s.last_run_completed_at,
  s.run_count,
  s.last_run_failed_count,
  s.last_error_message
FROM dq.dq_rule_catalog r
LEFT JOIN dq.rule_execution_state s
  ON s.rule_id = r.rule_id
WHERE r.process_name = N'DQ_FRAMEWORK'
  AND r.is_active = 1
ORDER BY r.object_name, r.check_name;
```

Status meaning (`last_run_status`):
- CAUGHT_UP: no rows past the watermark last run (waiting for new data), or caught up with 0 failures.
- BATCHED: more rows remain past the watermark; re-run to continue draining.
- FAIL: caught up but the latest checked rows contain failures.
- ERROR: last run threw; see `last_error_message`. Retried next run.
- RUNNING: currently executing.
- NULL: never run yet (watermark still NULL).

`reprocess_review_pending = 1` means the rule's core logic changed and you must decide whether to reset its watermark and re-scan.

2. Summary by run status

```sql
SELECT
  s.last_run_status,
  COUNT(*) AS rules_count
FROM dq.rule_execution_state s
GROUP BY s.last_run_status
ORDER BY s.last_run_status;
```

3. Object-level status (example: Campaign)

```sql
SELECT
  r.object_name,
  s.last_run_status,
  COUNT(*) AS rule_count
FROM dq.dq_rule_catalog r
JOIN dq.rule_execution_state s
  ON s.rule_id = r.rule_id
WHERE r.process_name = N'DQ_FRAMEWORK'
  AND r.object_name = N'Campaign'
GROUP BY r.object_name, s.last_run_status
ORDER BY s.last_run_status;
```

4. Latest rule results (pass/fail and counts)

```sql
WITH latest_result AS
(
  SELECT
    dr.object_name,
    dr.check_name,
    dr.severity,
    dr.failed_count,
    dr.check_status,
    dr.checked_at,
    ROW_NUMBER() OVER
    (
      PARTITION BY dr.object_name, dr.check_name
      ORDER BY dr.checked_at DESC, dr.dq_result_id DESC
    ) AS rn
  FROM dq.dq_results dr
)
SELECT
  object_name,
  check_name,
  severity,
  failed_count,
  check_status,
  checked_at
FROM latest_result
WHERE rn = 1
ORDER BY object_name, check_name;
```

5. Open exceptions by rule

```sql
SELECT
  r.object_name,
  r.check_name,
  COUNT(*) AS open_exceptions
FROM dq.dq_exceptions e
JOIN dq.dq_rule_catalog r
  ON r.rule_id = e.rule_id
WHERE r.process_name = N'DQ_FRAMEWORK'
  AND e.resolution_status = N'OPEN'
GROUP BY r.object_name, r.check_name
ORDER BY r.object_name, r.check_name;
```

6. Live progress for one object (caught up vs needs attention)

```sql
SELECT
  r.object_name,
  SUM(CASE WHEN s.last_run_status = 'CAUGHT_UP' THEN 1 ELSE 0 END) AS caught_up_rules,
  SUM(CASE WHEN s.last_run_status IN ('BATCHED', 'ERROR') OR s.last_run_status IS NULL THEN 1 ELSE 0 END) AS need_more_runs,
  SUM(CASE WHEN s.reprocess_review_pending = 1 THEN 1 ELSE 0 END) AS awaiting_reprocess_review,
  COUNT(*) AS total_rules
FROM dq.dq_rule_catalog r
JOIN dq.rule_execution_state s
  ON s.rule_id = r.rule_id
WHERE r.process_name = N'DQ_FRAMEWORK'
  AND r.object_name = N'Sponsorship_Unit'
GROUP BY r.object_name;
```

7. What is running right now

```sql
SELECT
  r.object_name,
  r.check_name,
  s.last_run_status,
  s.last_run_started_at,
  s.last_run_completed_at
FROM dq.dq_rule_catalog r
JOIN dq.rule_execution_state s
  ON s.rule_id = r.rule_id
WHERE r.process_name = N'DQ_FRAMEWORK'
  AND s.last_run_status = 'RUNNING'
ORDER BY s.last_run_started_at DESC;
```

8. Last completed checks timeline (most recent first)

```sql
SELECT TOP 30
  dr.object_name,
  dr.check_name,
  dr.check_status,
  dr.failed_count,
  dr.checked_at
FROM dq.dq_results dr
WHERE dr.object_name = N'Sponsorship_Unit'
ORDER BY dr.checked_at DESC, dr.dq_result_id DESC;
```

9. SQL Server engine-level active requests (session and statement)

```sql
SELECT
  r.session_id,
  s.login_name,
  s.host_name,
  s.program_name,
  r.status,
  r.command,
  r.start_time,
  r.wait_type,
  r.wait_time,
  r.blocking_session_id,
  DB_NAME(r.database_id) AS database_name,
  SUBSTRING(t.text, (r.statement_start_offset/2)+1,
    ((CASE r.statement_end_offset WHEN -1 THEN DATALENGTH(t.text) ELSE r.statement_end_offset END - r.statement_start_offset)/2) + 1) AS running_statement
FROM sys.dm_exec_requests r
JOIN sys.dm_exec_sessions s
  ON s.session_id = r.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE s.program_name LIKE '%sqlcmd%'
ORDER BY r.start_time DESC;
```
```

## How to add a new rule

There are two patterns: generic rule types and CUSTOM_SQL.

1. Generic rule (example: NOT_NULL)

```sql
INSERT INTO dq.dq_rule_catalog
(
  object_name,
  source_view,
  check_name,
  check_type,
  target_column,
  severity,
  description,
  is_active,
  created_at,
  rule_source,
  approval_status,
  process_name,
  rule_definition
)
VALUES
(
  N'Campaign',
  N'staging.campaign_latest',
  N'CAM-NEW-001',
  N'NOT_NULL',
  N'Name',
  N'HIGH',
  N'Campaign Name must not be null or blank',
  1,
  SYSUTCDATETIME(),
  N'MANUAL_ADD',
  N'Approved',
  N'DQ_FRAMEWORK',
  NULL
);
```

2. CUSTOM_SQL rule

Notes:
- Return columns exactly as: record_id, exception_value, exception_details, etl_run_id.
- Use {{SOURCE_VIEW}} token in query body so framework can inject object source.

```sql
INSERT INTO dq.dq_rule_catalog
(
  object_name,
  source_view,
  check_name,
  check_type,
  target_column,
  severity,
  description,
  is_active,
  created_at,
  rule_source,
  approval_status,
  process_name,
  rule_definition
)
VALUES
(
  N'Campaign',
  N'staging.campaign_latest',
  N'CAM-NEW-URL-002',
  N'CUSTOM_SQL',
  NULL,
  N'MEDIUM',
  N'URL must contain org domain when populated',
  1,
  SYSUTCDATETIME(),
  N'MANUAL_ADD',
  N'Approved',
  N'DQ_FRAMEWORK',
  N'SELECT [Id] AS record_id, [Fundraising_page_url__c] AS exception_value, N''URL missing domain token'' AS exception_details, NULL AS etl_run_id FROM {{SOURCE_VIEW}} WHERE NULLIF(LTRIM(RTRIM([Fundraising_page_url__c])), '''') IS NOT NULL AND LOWER([Fundraising_page_url__c]) NOT LIKE ''%yourdomain%''' 
);
```

## How to apply the new rule and verify

1. Apply for one object (recommended)

```sql
EXEC dq.run_incremental_catalog_rules
  @ObjectNameFilter = N'Campaign',
  @MaxRowsPerRule = 0,
  @MaxExceptionsPerRule = 20000,
  @ResolveWhenFull = 1;
```

2. Force one specific rule (optional)

```sql
DECLARE @rule_id INT;

SELECT @rule_id = rule_id
FROM dq.dq_rule_catalog
WHERE object_name = N'Campaign'
  AND check_name = N'CAM-NEW-001'
  AND process_name = N'DQ_FRAMEWORK';

EXEC dq.run_incremental_catalog_rules
  @ForceRuleId = @rule_id,
  @MaxRowsPerRule = 0,
  @MaxExceptionsPerRule = 20000,
  @ResolveWhenFull = 1;
```

3. Verify the rule ran and its watermark advanced

```sql
SELECT
  r.object_name,
  r.check_name,
  s.last_run_status,
  s.last_source_watermark_value,
  s.last_run_completed_at,
  s.last_run_failed_count
FROM dq.dq_rule_catalog r
JOIN dq.rule_execution_state s
  ON s.rule_id = r.rule_id
WHERE r.process_name = N'DQ_FRAMEWORK'
  AND r.check_name IN (N'CAM-NEW-001', N'CAM-NEW-URL-002');
```

4. Verify latest result row and open exceptions

```sql
SELECT TOP 20
  dr.object_name,
  dr.check_name,
  dr.failed_count,
  dr.check_status,
  dr.checked_at
FROM dq.dq_results dr
WHERE dr.object_name = N'Campaign'
  AND dr.check_name IN (N'CAM-NEW-001', N'CAM-NEW-URL-002')
ORDER BY dr.checked_at DESC, dr.dq_result_id DESC;

SELECT
  e.object_name,
  e.record_id,
  e.exception_value,
  e.exception_details,
  e.last_detected_at,
  e.resolution_status
FROM dq.dq_exceptions e
JOIN dq.dq_rule_catalog r
  ON r.rule_id = e.rule_id
WHERE r.object_name = N'Campaign'
  AND r.check_name IN (N'CAM-NEW-001', N'CAM-NEW-URL-002')
  AND e.resolution_status = N'OPEN'
ORDER BY e.last_detected_at DESC;
```

Operational tip:
- If you edit a **core** field of a rule (definition, source, check type, target column, active flag), the core signature changes and the rule is flagged `reprocess_review_pending = 1` and logged as `RULE_CORE_CHANGED_REVIEW`. It does NOT auto-rescan old rows — you decide whether to reset the watermark and re-scan. Cosmetic edits (description, severity, check name) are logged as `RULE_METADATA_UPDATED` and change nothing about processing.

## Campaign Implementation Evidence (2026-07-30)

Objective:
- Implement the incremental framework on Campaign only.
- Validate that framework outputs match legacy campaign temp DQ outputs.

Execution performed:
1. Deployed framework objects and procedures from:
  - mohey_work/DQ Frame work/DQ_framework_creation_incremental.sql
2. Seeded migrated rules from:
  - mohey_work/DQ Frame work/DQ_framework_seed_checks_from_existing_prod.sql
3. Ran Campaign-only full framework execution:

```sql
EXEC dq.run_incremental_catalog_rules
  @MaxRowsPerRule = 0,
  @MaxExceptionsPerRule = 20000,
  @ObjectNameFilter = N'Campaign',
  @ResolveWhenFull = 1;
```

Framework execution proof:
- Campaign rules executed in this run: CAM-004..CAM-016 and CAM-URL-001 (14 CUSTOM_SQL rules).
- Previously executed Campaign generic rules: CAM-001, CAM-002, CAM-003, CAM-017.
- Total Campaign rules covered: 18.
- Runner summary on custom batch: passed=9, failed=5, errors=0.

Baseline (legacy) vs framework parity by rule:

| check_name | legacy_count | framework_count | delta |
|---|---:|---:|---:|
| CAM-001 | 0 | 0 | 0 |
| CAM-002 | 0 | 0 | 0 |
| CAM-003 | 0 | 0 | 0 |
| CAM-004 | 9 | 9 | 0 |
| CAM-005 | 0 | 0 | 0 |
| CAM-006 | 0 | 0 | 0 |
| CAM-007 | 0 | 0 | 0 |
| CAM-008 | 23 | 23 | 0 |
| CAM-009 | 2097 | 2097 | 0 |
| CAM-010 | 0 | 0 | 0 |
| CAM-011 | 13318 | 13319 | 1 |
| CAM-012 | 0 | 0 | 0 |
| CAM-013 | 0 | 0 | 0 |
| CAM-014 | 0 | 0 | 0 |
| CAM-015 | 0 | 0 | 0 |
| CAM-016 | 0 | 0 | 0 |
| CAM-017 | 0 | 0 | 0 |
| CAM-URL-001 | 2252 | 2252 | 0 |

Summary totals:
- Legacy total exceptions: 17699
- Framework total open exceptions: 17700
- Delta: +1
- Legacy unique campaigns: 15649
- Framework unique campaigns: 15650

Result:
- Framework implementation for Campaign is successful.
- Rule-level parity achieved for 17 of 18 rules.
- One variance remains on CAM-011 (+1 record), likely due runtime timing/date-evaluation edge behavior.

CAM-011 delta evidence:
- Record only in framework: 701N2000019UrsYIAS
- Current values in staging.campaign_latest during test:
  - EndDate = 2026-07-29
  - IsActive = true
- CAM-011 logic flags records where EndDate < CAST(GETUTCDATE() AS DATE) and IsActive=true.
- This indicates the framework run happened after date rollover, while legacy temp results were from an earlier snapshot.

Notes from implementation fixes:
- Fixed SQL Server MERGE compatibility issue in queue preparation logic by consolidating duplicate WHEN MATCHED UPDATE branches.
- Updated queue/readiness logic so CUSTOM_SQL rules run from catalog metadata while generic checks still respect readiness validation.

## Item_GAU No-Rerun Migration Evidence (2026-07-30)

Objective:
- Item_GAU was already complete in legacy temp tables.
- Move Item_GAU data into framework tables without executing `dq.run_incremental_catalog_rules` again.

Approach used:
1. Source legacy outputs from:
  - `staging.item_gau_dq_exceptions_temp`
  - `staging.item_gau_latest`
2. Execute backfill script only:
  - `mohey_work/item_gau/item_gau_framework_backfill_no_rerun.sql`
3. Script actions:
  - Sets Item_GAU framework rules (`GAU-001..GAU-006`) to `DONE` in `dq.rule_execution_state`.
  - Inserts `dq.dq_results` rows from legacy rule counts.
  - Upserts/resolves `dq.dq_exceptions` for Item_GAU based on legacy temp records.

Observed source snapshot before backfill:
- raw rows: 31391
- staging rows: 30815
- legacy temp rows: 1
- legacy marker rows (`GAU-DONE`): 1
- legacy business-rule violations: 0

Outcome after backfill:
- `GAU-001..GAU-006`: `DONE`
- `last_run_status`: `SUCCESS`
- Item_GAU open framework exceptions: 0

Important:
- This migration path avoided framework re-execution for Item_GAU and only synchronized framework tables from legacy completed outputs.
