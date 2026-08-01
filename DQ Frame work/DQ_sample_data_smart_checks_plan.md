# DQ Execution Status + Sample-Data Smart Checks Plan

Date: 2026-07-30
Database: SalesforceDW

## 1) Current completion status (what is complete vs not)

### Legacy object-level temp scripts (done-marker based)

- campaign: INCOMPLETE (done marker missing)
- item_gau: COMPLETED (done marker exists)
- recurring_donation: INCOMPLETE (done marker missing)
- sponsorship: INCOMPLETE (done marker missing)
- sponsorship_unit: INCOMPLETE (done marker missing)

### Evidence from current temp exception rows

- staging.campaign_dq_exceptions_temp: 17,699 rows
- staging.item_gau_dq_exceptions_temp: 1 row
- staging.recurring_donation_dq_exceptions_temp: 278,300 rows
- staging.sponsorship_dq_exceptions_temp: 306,503 rows
- staging.sponsorship_unit_dq_exceptions_temp: 0 rows

Interpretation:
- recurring_donation and sponsorship appear to have large prior runs but are not marked done.
- campaign has substantial rows but no done marker.
- sponsorship_unit appears not executed or yielded no inserts.
- item_gau has only done marker row and likely no meaningful rule results currently persisted in temp.

### New incremental framework deployment status

Not deployed yet in database:
- dq.rule_execution_state: MISSING
- dq.rule_execution_audit: MISSING
- dq.rule_action_config: MISSING
- dq.prepare_incremental_rule_queue: MISSING
- dq.run_incremental_catalog_rules: MISSING
- dq.apply_rule_updates: MISSING

Seed migration status:
- dq.dq_rule_catalog total rows: 0
- dq.dq_rule_catalog rows where process_name='DQ_FRAMEWORK': 0

Interpretation:
- framework SQL and seed files exist in workspace, but have not been applied to the DB yet.

## 2) Sample-data execution plan (safe and controlled)

Goal: validate rule behavior and performance without full-table reruns.

Target sample size for this cycle: 100,000 rows per rule.

### Phase A: Bootstrap framework objects

1. Apply framework DDL/procs:
- mohey_work/DQ Frame work/DQ_framework_creation_incremental.sql

2. Seed migrated rules:
- mohey_work/DQ Frame work/DQ_framework_seed_checks_from_existing_prod.sql

3. Verify:
- dq_rule_catalog has 52 rules with process_name='DQ_FRAMEWORK'.

### Phase B: Run on sample first

Use a row cap for small controlled runs:
- @MaxRowsPerRule = 100000
- @MaxExceptionsPerRule = 300
- @ObjectNameFilter per object

Recommended object order:
1. item_gau (smallest complexity)
2. sponsorship_unit
3. campaign
4. recurring_donation
5. sponsorship

Reason:
- Progress from low-risk to high-volume/high-join objects.

### 100k command pack (object-by-object)

Run after framework objects and seed are applied.

```sql
EXEC dq.run_incremental_catalog_rules
	@ObjectNameFilter = N'Item_GAU',
	@MaxRowsPerRule = 100000,
	@MaxExceptionsPerRule = 300;

EXEC dq.run_incremental_catalog_rules
	@ObjectNameFilter = N'Sponsorship_Unit',
	@MaxRowsPerRule = 100000,
	@MaxExceptionsPerRule = 300;

EXEC dq.run_incremental_catalog_rules
	@ObjectNameFilter = N'Campaign',
	@MaxRowsPerRule = 100000,
	@MaxExceptionsPerRule = 300;

EXEC dq.run_incremental_catalog_rules
	@ObjectNameFilter = N'Recurring_Donation',
	@MaxRowsPerRule = 100000,
	@MaxExceptionsPerRule = 300;

EXEC dq.run_incremental_catalog_rules
	@ObjectNameFilter = N'Sponsorship',
	@MaxRowsPerRule = 100000,
	@MaxExceptionsPerRule = 300;
```

### Phase C: Validate sample quality

For each object sample run, review:
1. dq.dq_results
- failed_count distribution by severity/check
2. dq.dq_exceptions
- sample of exception_details for false positives
3. dq.rule_execution_state
- expected transitions to CAUGHT_UP (or BATCHED for large tables mid-drain)

Acceptance gate before expanding volume:
- no procedure errors
- no invalid custom SQL failures
- expected rule hit patterns align with historical behavior

### Phase D: Expand sample to medium and full

Ramp profile:
1. 100k rows per rule
2. full scan (@MaxRowsPerRule = 0) for selected object only

Do full scan per object one at a time during low-load window.

## 3) Make checks smarter (next improvements)

### A) Smarter by confidence and noise control

1. Add confidence tier to rule metadata
- HIGH_CONFIDENCE, REVIEW_REQUIRED, EXPERIMENTAL
2. Route EXPERIMENTAL to separate review bucket (not production alerting)
3. Add minimum violation threshold before raising certain MEDIUM/LOW checks

### B) Smarter by change-awareness

1. Add optional delta predicate support in CUSTOM_SQL using _etl_run_id/SystemModstamp
2. Skip unchanged partitions for heavy referential checks
3. Recheck only affected record_ids after rule edits where possible

### C) Smarter by explainability

1. Standardize exception_details payload
- include key compared fields and decision reason
2. Add check_version hash to details for traceability
3. Add top-N example cache per rule for fast QA

### D) Smarter by performance

1. Add/verify indexes on raw/staging join keys used by custom rules
2. For heavy existence checks, precompute compact lookup temp tables within run scope
3. Keep @MaxExceptionsPerRule bounded for large tables

### E) Smarter by remediation readiness

1. Keep detect rules in dq_rule_catalog
2. Add auto-fix candidates in dq.rule_action_config with DryRun mandatory first
3. Enforce approval_status gate for AUTO_FIX rules only

## 4) Concrete 2-week execution plan

### Week 1

1. Deploy framework objects and seed rules.
2. Run sample mode for item_gau and sponsorship_unit.
3. Fix any CUSTOM_SQL syntax/logic mismatches.
4. Run sample mode for campaign.

### Week 2

1. Run sample then medium for recurring_donation and sponsorship.
2. Add 3 smart upgrades:
- confidence tier
- standardized exception_details format
- index tuning for top 3 slow custom rules
3. Run one full scan per object in off-hours.
4. Freeze baseline and hand over runbook.

## 5) Success criteria

1. Framework fully deployed and seeded (52 rules).
2. All rules move to DONE at least once in sample mode.
3. No recurring ERROR status in rule_execution_state.
4. Full scans complete object-by-object without truncate strategy.
5. False-positive rate reduced via confidence and threshold tuning.
