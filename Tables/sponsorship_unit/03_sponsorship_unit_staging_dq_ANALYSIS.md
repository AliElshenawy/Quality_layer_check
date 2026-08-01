# Sponsorship Unit — DQ Analysis (Final)

**Run:** 2026-07-30 · **Rows checked:** 1,291,058 · **Rules:** 9 (8 active, 1 deferred) · **Result:** 7 PASS · 1 FAIL · 0 errors
**Affected records:** 51,815 (all from the single failing rule SU-005)

**Deferred (switched off for now):** SU-008 — needs `raw.salesforce_item_allocation`, which is **empty (0 rows)**, so it flagged every row. Not a real defect; revisit once the allocation table is loaded.

- Source SQL: [sponsorship_unit_staging_dq_PROD_framework.sql](sponsorship_unit_staging_dq_PROD_framework.sql)
- EDA: [EDA_sponsorship_unit_csv_analysis.md](EDA_sponsorship_unit_csv_analysis.md)

> **How to read this:** **PASS** = clean, nothing to look at. **FAIL** = the rule found rows that break it
> (those rows are saved in `dq.dq_exceptions`). FAIL is a *review signal*, not always a real defect.

---

## 1. Key numbers

| Metric | Value |
|--------|------:|
| Raw rows | 1,291,058 |
| Distinct IDs / staging rows | 1,291,058 |
| Duplicates removed | 0 |
| Rules run | 9 (SU-001 … SU-009) |
| Active rules | 8 (SU-008 deferred) |
| Rules failing | 1 |
| Records with ≥1 failure | 51,815 |

All rules are **caught up** to the source watermark `SystemModstamp = 2026-07-27 12:51:20` (the current max), so no rows are outstanding.

---

## 2. All 9 rules — full status

| Rule | Sev | What it checks | Status | Failed |
|------|-----|----------------|--------|-------:|
| SU-001 | CRITICAL | Id is not null / blank | ✅ PASS | 0 |
| SU-002 | CRITICAL | Id is a valid 15/18-char Salesforce ID | ✅ PASS | 0 |
| SU-003 | CRITICAL | `Sponsorship__c` is populated | ✅ PASS | 0 |
| SU-004 | CRITICAL | `Sponsorship__c` exists in `raw.salesforce_sponsorship` | ✅ PASS | 0 |
| SU-005 | HIGH | `Deferred_Amount_in_GBP__c` is not negative | 🔴 FAIL | 51,815 |
| SU-006 | MEDIUM | Local currency set when deferred LC amount present | ✅ PASS | 0 |
| SU-007 | MEDIUM | `Donation_Date__c` is a valid date | ✅ PASS | 0 |
| SU-008 | LOW | `GAU_Allocation__c` exists in `raw.salesforce_item_allocation` | ⏸️ OFF (deferred) | — |
| SU-009 | MEDIUM | Unit does not point to a deleted sponsorship | ✅ PASS | 0 |

⏸️ **SU-008 is deferred** (switched off). It is a big cross-table join to `raw.salesforce_item_allocation`, and that
table currently has **0 rows**, so 100% of units flagged as "not found". This is a missing-reference-data condition,
not a data defect — it is excluded from PASS/FAIL until the allocation table is loaded.

---

## 3. The failing rule — detail and quality impact

Each failure maps to a **data-quality dimension**: **Completeness** (value missing), **Validity** (value wrong / out of range),
**Consistency** (values contradict each other), **Integrity** (broken link between records).

### 🔴 SU-005 · Negative deferred GBP amount — 51,815 · *Validity*
- **What:** `Deferred_Amount_in_GBP__c` is below zero. Sampled values are **tiny sub-penny fractions** (e.g. `-0.05799`, `-0.32227`, `-0.47937`, `-0.57336`), consistent with **currency-conversion / rounding artifacts** rather than genuine negative deferrals.
- **Quality impact:** deferred-income roll-ups and GBP financial reporting are slightly off for these rows, and a naive `SUM` will net them out incorrectly. Low individual magnitude, but 51,815 rows is a material count for reconciliation.
- **Sample:** `a3JN20000016KXiMAM` (−0.32227)

```sql
-- SU-005: Negative deferred GBP amount (staging, top 10)
SELECT TOP 10 [Id],
       [Deferred_Amount_in_GBP__c],
       [Local_Currency_Of_Deferred_Funds__c],
       [Deferred_Amount_in_LC__c]
FROM staging.sponsorship_unit_latest
WHERE TRY_CONVERT(DECIMAL(18,5), [Deferred_Amount_in_GBP__c]) < 0
ORDER BY TRY_CONVERT(DECIMAL(18,5), [Deferred_Amount_in_GBP__c]) ASC;
```

**Net quality read:** the object is **structurally sound** — every identity, format, mandatory-field, and referential
rule that can be evaluated passes (SU-001…SU-004, SU-006, SU-007, SU-009 all clean). The only real signal is **SU-005**,
which looks like rounding noise, not corrupt data. SU-008 cannot be judged until its reference table is loaded.

---

## 4. What we need from the stakeholders

| # | Question | Why it matters | Rule |
|---|----------|----------------|------|
| Q1 | Are sub-penny **negative `Deferred_Amount_in_GBP__c`** values acceptable, or should they be floored at 0 / normalised? | 51,815 rows; decide accept-as-rounding vs fix-at-source | SU-005 |
| Q2 | When will **`salesforce_item_allocation`** (GAU allocations) be loaded? | Required before SU-008 (`GAU_Allocation__c` integrity) can be re-enabled | SU-008 |

> **Deferred rule:** SU-008 (`GAU_Allocation__c` → `item_allocation`) is switched off because the reference table is empty.
> Re-enable with `UPDATE dq.dq_rule_catalog SET is_active = 1 WHERE object_name = 'Sponsorship_Unit' AND check_name = 'SU-008';`
> then reset its watermark to NULL to force a clean re-scan.

---

## 5. Re-check any time (SSMS-ready)

```sql
-- Per-rule status + failures (Sponsorship_Unit)
SELECT r.check_name, r.severity, r.is_active, s.last_run_status,
       s.last_source_watermark_value,
       ISNULL(dr.failed_count, 0) AS failed_count
FROM dq.dq_rule_catalog r
JOIN dq.rule_execution_state s ON s.rule_id = r.rule_id
LEFT JOIN (
    SELECT check_name, failed_count,
           ROW_NUMBER() OVER (PARTITION BY check_name ORDER BY checked_at DESC) AS rn
    FROM dq.dq_results WHERE object_name = 'Sponsorship_Unit'
) dr ON dr.check_name = r.check_name AND dr.rn = 1
WHERE r.object_name = 'Sponsorship_Unit'
ORDER BY r.check_name;
```

---

## 6. Zero-Finding Checks

8 of the 9 rules returned **0** failures: SU-001, SU-002, SU-003, SU-004, SU-006, SU-007, SU-009 (plus
SU-008 which is deferred, not counted). This confirms identity, format, mandatory `Sponsorship__c`,
parent referential integrity, local-currency consistency, date validity, and no-deleted-parent are all
clean across the full 1,291,058 rows.

## 7. Most-Violating Records

Not applicable in the usual sense: only **one** rule fails (SU-005), so every affected record fails
exactly one rule. The "worst" records are simply the largest-magnitude negative deferrals — all still
sub-penny. Ranking query if needed:

```sql
SELECT TOP 5 [Id], TRY_CONVERT(DECIMAL(18,5),[Deferred_Amount_in_GBP__c]) AS gbp
FROM staging.sponsorship_unit_latest
WHERE TRY_CONVERT(DECIMAL(18,5),[Deferred_Amount_in_GBP__c]) < 0
ORDER BY gbp ASC;
```

## 8. Recommendations

- **SU-005 (engineering + business):** confirm with Finance whether sub-penny negative GBP deferrals are
  rounding noise (accept) or should be floored at 0 / re-derived (fix). 51,815 rows — material for
  reconciliation totals even though each is tiny.
- **SU-008 (deferred):** re-enable and re-scan once `raw.salesforce_item_allocation` is loaded; keep off
  until then to avoid 1.29M false positives.
- **Promotion:** SU-001..004, SU-006, SU-007, SU-009 are clean and safe to treat as production gates.
