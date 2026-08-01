# DQ Framework Review Checklist (No-Run)

Use this checklist to review the framework artifacts before execution.

## Files to review

1. mohey_work/DQ Frame work/DQ_framework_creation_incremental.sql
2. mohey_work/DQ Frame work/DQ_framework_creation.md
3. mohey_work/DQ Frame work/DQ_framework_seed_checks_from_existing_prod.sql

## Design checks

1. Watermark model exists and is clear:
- `last_source_watermark_value`: the per-rule cursor (max `SystemModstamp` processed).
- `source_watermark_column`: resolved watermark column (`SystemModstamp` > `LastModifiedDate` > `_etl_loaded_at_utc`).
- `last_run_status`: `CAUGHT_UP` | `BATCHED` | `FAIL` | `ERROR` | `RUNNING`.
- `reprocess_review_pending`: core logic changed; operator must decide reprocess vs update.
- There is NO pending/done state machine — a rule waits for rows past its watermark.

2. Incremental model stays simple:
- Each run checks only rows with `SystemModstamp` greater than the rule's watermark.
- Caught up = watermark equals the source max right now; new rows make work appear automatically.
- Rows checked so far = `COUNT(*) WHERE SystemModstamp <= last_source_watermark_value`.
- Every rule must have a datetime watermark column or it is rejected at prepare time.

3. Core-change detection uses a deterministic CORE signature (pass/fail fields only):
- object_name
- source_view
- check_type
- target_column
- rule_definition
- is_active

   (Cosmetic fields — check_name, severity, description — are tracked separately and do not trigger reprocess review.)

4. Exception cleanup is incremental, never a full truncate:
- records that re-enter the watermark window and pass are resolved
- forcing a clean re-scan = reset `last_source_watermark_value` to NULL

5. Runner executes every eligible rule; caught-up rules do 0 work:
- optional object filter
- optional force rule
- optional object filter

6. Full mode resolves stale exceptions only for executed rules.

## Operational checks

1. Verify indexing strategy:
- IX_rule_execution_state_watermark
- IX_dq_exceptions_rule_record_status

2. Verify current catalog check types covered:
- NOT_NULL
- VALID_DATETIME
- VALID_SALESFORCE_ID
- VALID_BOOLEAN

3. Verify remediation extension is gated:
- dq.rule_action_config action_mode
- dry-run option in dq.apply_rule_updates

## Rollout recommendation

1. Apply SQL in non-prod first.
2. Run object-by-object for biggest tables.
3. Validate dq_results and dq_exceptions behavior.
4. Schedule full runs for stale-exception resolution windows.
5. Enable AUTO_FIX only after governance approval.
