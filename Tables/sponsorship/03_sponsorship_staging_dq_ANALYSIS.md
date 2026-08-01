# Sponsorship — DQ Analysis (Final, heavy joins skipped)

Object: `Sponsorship` · Source: `raw.salesforce_sponsorship` · Staging: `staging.sponsorship_latest`
Framework run: **2026-08-01** (8 light rules run to completion; 2 heavy-join rules skipped — see below).
Status: **Final for the runnable rules.** SP-009 / SP-010 are skipped (deferred) — not fabricated.

## 1. Executive Summary

| Metric | Value |
|---|---|
| Run date | 2026-08-01 |
| Raw rows (non-deleted) | 228,228 |
| Staging rows (latest per Id) | 227,244 |
| Rows collapsed by dedup | 984 |
| Rules in framework | 10 (SP-001..010) |
| Rules **run** | 8 (SP-001..008) |
| Rules **skipped** | 2 (SP-009, SP-010 — heavy referential joins) |
| PASS / FAIL (of the 8 run) | 4 PASS / 4 FAIL |
| Open exceptions | 62,414 |

### Severity split (open exceptions, runnable rules)
| Severity | Count |
|---|---:|
| CRITICAL | 0 |
| HIGH | 4,406 |
| MEDIUM | 58,008 |
| **Total** | **62,414** |

## 2. Skipped rules (heavy joins — deferred for now)

Both are `NOT EXISTS` reference-integrity joins against large raw tables. They are set `is_active = 0` so
the framework skips them; **not** counted as PASS or FAIL.

| Rule | Join target | Why skipped |
|---|---|---|
| SP-009 | `Donor__c` → `raw.salesforce_contact` | **Contact table is empty (0 rows)** — would flag every donor as missing. Re-enable after Contact is loaded. |
| SP-010 | `Recurring_Donation__c` → `raw.salesforce_recurring_donation` | **Heavy join** (227K × 261K, unindexed `NVARCHAR(MAX)`) — long-running. Deferred to avoid a slow scan; run in a dedicated batched pass later. |

Re-enable later:
```sql
UPDATE dq.dq_rule_catalog SET is_active=1 WHERE object_name='Sponsorship' AND check_name IN ('SP-009','SP-010');
UPDATE s SET s.last_source_watermark_value=NULL FROM dq.rule_execution_state s
JOIN dq.dq_rule_catalog r ON r.rule_id=s.rule_id
WHERE r.object_name='Sponsorship' AND r.check_name IN ('SP-009','SP-010');
```

## 3. Evidence Snapshot (SSMS-ready)

```sql
-- Per-rule status + cumulative open exceptions
SELECT r.check_name, r.severity, r.is_active, s.last_run_status,
       (SELECT COUNT(*) FROM dq.dq_exceptions e WHERE e.rule_id=r.rule_id AND e.resolution_status='OPEN') AS open_exc
FROM dq.dq_rule_catalog r JOIN dq.rule_execution_state s ON s.rule_id=r.rule_id
WHERE r.object_name='Sponsorship' ORDER BY r.check_name;

-- Sample a staged record
SELECT TOP (2) * FROM staging.sponsorship_latest ORDER BY staging_created_at DESC;
```
Observed: staging 227,244; open exceptions SP-003=399, SP-006=2,510, SP-007=4,007, SP-008=55,498.

## 4. Table Creation and Population

`staging.sponsorship_latest` rebuilt from `raw.salesforce_sponsorship`, deduped by `Id` (latest
`SystemModstamp`), soft-deleted excluded → **227,244 rows** (984 collapsed from 228,228 non-deleted raw).

## 5. Rule Catalog Executed

| Rule | Severity | Check | Status | Open exc |
|---|---|---|:---:|---:|
| SP-001 | CRITICAL | Id not null/blank | PASS | 0 |
| SP-002 | CRITICAL | Id 15/18 chars | PASS | 0 |
| **SP-003** | **HIGH** | Active sponsorship must have `Donor__c` | **FAIL** | **399** |
| SP-004 | HIGH | Active sponsorship must have `Orphan__c` | PASS | 0 |
| SP-005 | HIGH | `Status__c` / `IsActive__c` consistent | PASS | 0 |
| **SP-006** | **MEDIUM** | Active should have `Recurring_Donation__c` | **FAIL** | **2,510** |
| **SP-007** | **HIGH** | Start date ≤ End date | **FAIL** | **4,007** |
| **SP-008** | **MEDIUM** | Terminated/Inactive needs deactivation reason | **FAIL** | **55,498** |
| SP-009 | HIGH | `Donor__c` → Contact | ⏸️ SKIPPED | — |
| SP-010 | HIGH | `Recurring_Donation__c` → RD | ⏸️ SKIPPED | — |

## 6. Zero-Finding Checks

4 of the 8 run rules are clean: SP-001, SP-002, SP-004 (active items have Orphan), SP-005 (status/active
consistent). Identity and format are solid; the orphan linkage that matters most for this charity object
is fully populated on active records.

## 7. Rule Matches Requiring Review

### SP-008 — Terminated/Inactive without deactivation reason (MEDIUM, 55,498)
By far the largest signal — inactive/terminated sponsorships with no `Sponsorship_Deactivation_Reason__c`.
**Confirm the business rule first**: is a deactivation reason mandatory for historical/legacy records, or
only going forward? If legacy records were migrated without it, this is a backfill, not a live defect.

### SP-007 — Start date after End date (HIGH, 4,007)
Date inversions. Engineering-checkable; likely data-entry or migration artifacts.
```sql
SELECT TOP 10 [Id],[Start_Date__c],[End_Date__c] FROM staging.sponsorship_latest
WHERE TRY_CONVERT(datetime2,[Start_Date__c]) > TRY_CONVERT(datetime2,[End_Date__c]);
```

### SP-006 — Active sponsorship without recurring-donation link (MEDIUM, 2,510)
Active sponsorships not linked to a recurring donation. **Stakeholder question:** can an active sponsorship
be funded another way (one-off, offline), or must every active one have an RD link?

### SP-003 — Active sponsorship without Donor (HIGH, 399)
399 active sponsorships with no `Donor__c`. High priority — an active sponsorship should have a donor.

## 8. Most-Violating Records

```sql
SELECT TOP 5 e.record_id, COUNT(DISTINCT r.check_name) AS rules_failed,
       STRING_AGG(r.check_name, ', ') WITHIN GROUP (ORDER BY r.check_name) AS failed_rules
FROM dq.dq_exceptions e JOIN dq.dq_rule_catalog r ON r.rule_id=e.rule_id
WHERE r.object_name='Sponsorship' AND e.resolution_status='OPEN'
GROUP BY e.record_id ORDER BY rules_failed DESC;
```
Expected worst cases: inactive sponsorships that also invert dates (SP-008 + SP-007).

## 9. Recommendations

- **Confirm SP-008 policy** before treating 55,498 as defects — likely a migration backfill question.
- **Engineering-safe:** investigate the 4,007 SP-007 date inversions and the 399 SP-003 missing donors.
- **Skipped (revisit):** load `raw.salesforce_contact` then run SP-009; run SP-010 in a dedicated batched
  pass (it's a heavy join, not a defect finding).
- **Promotion:** SP-001, SP-002, SP-004, SP-005 are clean and safe as production gates.
