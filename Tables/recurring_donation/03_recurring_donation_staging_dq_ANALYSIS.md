# Recurring Donation — DQ Analysis (Final)

**Run:** 2026-08-01 · **Rows checked:** 258,465 · **Rules:** 23 total — 14 active gated · 2 deferred · 7 controlled-list report-only · **Result:** 11 PASS · 3 FAIL · 0 errors
**Affected records:** 54,631 (a record can break more than one rule)

**Deferred (switched off for now):** RD-003 and RD-008 — both need donor / Contact data that isn't loaded yet.

**Controlled-list rules — report-only (no assumed values):** RD-005, RD-010, RD-011, RD-012, RD-013, RD-014, RD-021. We do **not** assume any value is wrong for these picklist fields; we list the distinct values in §3b and ask stakeholders which are valid.

- Source SQL: [recurring_donation_staging_dq_PROD_framework.sql](recurring_donation_staging_dq_PROD_framework.sql)
- EDA: [EDA_recurring_donation_csv_analysis.md](EDA_recurring_donation_csv_analysis.md)

> **How to read this:** **PASS** = clean, nothing to look at. **FAIL** = the rule found rows that break it
> (those rows are saved in `dq.dq_exceptions`). FAIL is a *review signal*, not always a real defect.

---

## 1. Key numbers

| Metric | Value |
|--------|------:|
| Raw rows | 261,577 |
| Distinct IDs / staging rows | 258,465 |
| Duplicates removed | 3,112 |
| Rules run | 23 (RD-001 … RD-023) |
| Active gated rules | 14 |
| Deferred | 2 (RD-003, RD-008) |
| Controlled-list report-only | 7 (RD-005, RD-010–014, RD-021) |
| Rules failing | 3 |
| Records with ≥1 failure | 54,631 |

---

## 2. All 23 rules — full status

| Rule | Sev | What it checks | Status | Failed |
|------|-----|----------------|--------|-------:|
| RD-001 | CRITICAL | Id is not null | ✅ PASS | 0 |
| RD-002 | CRITICAL | Id is a valid 15/18-char Salesforce ID | ✅ PASS | 0 |
| RD-003 | HIGH | Contact **or** Organization is populated | ⏸️ OFF (deferred) | — |
| RD-004 | HIGH | Active donation has amount > 0 | ✅ PASS | 0 |
| RD-005 | — | Status — distinct values reported (not gated) | 📋 REPORT-ONLY | — |
| RD-006 | MEDIUM | Day of month is 1–31 or Last_Day | ✅ PASS | 0 |
| RD-007 | HIGH | Start date ≤ End date | 🔴 FAIL | 19,864 |
| RD-008 | HIGH | Contact exists in `raw.salesforce_contact` | ⏸️ OFF (deferred) | — |
| RD-009 | MEDIUM | Campaign exists in `raw.salesforce_campaign` | ✅ PASS | 0 |
| RD-010 | — | Installment period — distinct values reported (not gated) | 📋 REPORT-ONLY | — |
| RD-011 | — | Recurring type — distinct values reported (not gated) | 📋 REPORT-ONLY | — |
| RD-012 | — | Payment method — distinct values reported (not gated) | 📋 REPORT-ONLY | — |
| RD-013 | — | Donation type — distinct values reported (not gated) | 📋 REPORT-ONLY | — |
| RD-014 | — | Regional office code — distinct values reported (not gated) | 📋 REPORT-ONLY | — |
| RD-015 | MEDIUM | Closed donation has a Closed Reason | 🔴 FAIL | 79,000 |
| RD-016 | HIGH | Paid amount is numeric | ✅ PASS | 0 |
| RD-017 | HIGH | Total donation amount is numeric | ✅ PASS | 0 |
| RD-018 | HIGH | Amount is numeric *(new)* | ✅ PASS | 0 |
| RD-019 | MEDIUM | Installment amount is numeric *(new)* | ✅ PASS | 0 |
| RD-020 | MEDIUM | Failed-payments count is a non-negative number *(new)* | ✅ PASS | 0 |
| RD-021 | — | Currency code — distinct values reported (not gated) | 📋 REPORT-ONLY | — |
| RD-022 | MEDIUM | Start/End/Next dates are parseable *(new)* | ✅ PASS | 0 |
| RD-023 | HIGH | Active donation has a Next Payment Date *(new)* | 🔴 FAIL | 90 |

⏸️ **RD-003 and RD-008 are deferred** (switched off) until donor / Contact data is available. 📋 **RD-005, RD-010, RD-011, RD-012, RD-013, RD-014, RD-021** are **report-only** (controlled-list fields — no assumed values; distinct values in §3b). Neither group is counted in PASS/FAIL. RD-018–RD-023 were added after the data
investigation: RD-018–RD-022 are clean guards (0 failures), RD-023 found 90 real issues.

---

## 3. The 3 failing rules — detail and quality impact

Each failure maps to a **data-quality dimension**: **Completeness** (value missing), **Validity** (value wrong / out of range),
**Consistency** (values contradict each other), **Integrity** (broken link between records).

### 🔴 RD-015 · Closed donation with no Closed Reason — 79,000 · *Completeness*
- **What:** donation is `Closed` but `npsp__ClosedReason__c` is blank (42% of all Closed).
- **Quality impact:** churn/retention reporting is **blind** — we can’t tell *why* recurring gifts ended (card failure vs donor cancel vs migration). Cripples win-back targeting, lapse forecasting, and “reason for leaving” dashboards. The data isn’t wrong, but this is the single biggest completeness gap in the object.
- **Sample:** `a094J00000d01lk`

```sql
-- RD-015: Closed with no Closed Reason (raw + staging, top 10)
SELECT TOP 10 s.[Id],
       s.[npsp__Status__c] AS stg_status, s.[npsp__ClosedReason__c] AS stg_closed_reason,
       r.[npsp__Status__c] AS raw_status, r.[npsp__ClosedReason__c] AS raw_closed_reason
FROM staging.recurring_donation_latest s
OUTER APPLY (SELECT TOP 1 r0.[npsp__Status__c], r0.[npsp__ClosedReason__c]
             FROM raw.salesforce_recurring_donation r0
             WHERE LTRIM(RTRIM(r0.[Id])) = LTRIM(RTRIM(s.[Id]))
             ORDER BY TRY_CONVERT(DATETIME2, r0.[SystemModstamp]) DESC) r
WHERE UPPER(LTRIM(RTRIM(COALESCE(s.[npsp__Status__c],'')))) = 'CLOSED'
  AND NULLIF(LTRIM(RTRIM(COALESCE(s.[npsp__ClosedReason__c],''))),'') IS NULL;
```

### 🔴 RD-007 · Start date after End date — 19,864 · *Consistency*
- **What:** `npsp__StartDate__c` is later than `npsp__EndDate__c` on the same row.
- **Quality impact:** every duration / active-period calculation breaks (tenure, lifetime-value windows, “active on date X”). Time-series and cohort analytics silently return wrong numbers for these rows. Most likely a migration artifact, but it corrupts any date-range logic until fixed or excluded.
- **Sample:** `a094J00000Zmsjc` (Start 2021-07-09 / End 2021-07-08)

```sql
-- RD-007: Start date after End date (raw + staging, top 10)
SELECT TOP 10 s.[Id],
       s.[npsp__StartDate__c] AS stg_start, s.[npsp__EndDate__c] AS stg_end,
       r.[npsp__StartDate__c] AS raw_start, r.[npsp__EndDate__c] AS raw_end
FROM staging.recurring_donation_latest s
OUTER APPLY (SELECT TOP 1 r0.[npsp__StartDate__c], r0.[npsp__EndDate__c]
             FROM raw.salesforce_recurring_donation r0
             WHERE LTRIM(RTRIM(r0.[Id])) = LTRIM(RTRIM(s.[Id]))
             ORDER BY TRY_CONVERT(DATETIME2, r0.[SystemModstamp]) DESC) r
WHERE NULLIF(LTRIM(RTRIM(COALESCE(s.[npsp__StartDate__c],''))),'') IS NOT NULL
  AND NULLIF(LTRIM(RTRIM(COALESCE(s.[npsp__EndDate__c],''))),'') IS NOT NULL
  AND TRY_CONVERT(DATETIME2, s.[npsp__StartDate__c]) > TRY_CONVERT(DATETIME2, s.[npsp__EndDate__c]);
```

### 🔴 RD-023 · Active donation with no Next Payment Date — 90 · *Completeness (new rule)*
- **What:** status is `Active` but `npe03__Next_Payment_Date__c` is blank.
- **Quality impact:** collections and cash-flow forecasting **miss these gifts** — an active recurring donation with no scheduled next charge won’t be billed or projected. Low count but high operational value: this is direct **lost-revenue risk**, not just a reporting gap.
- **Sample:** `a094J00000UJmhq`

```sql
-- RD-023: Active donation with no Next Payment Date (raw + staging, top 10)
SELECT TOP 10 s.[Id],
       s.[npsp__Status__c] AS stg_status, s.[npe03__Next_Payment_Date__c] AS stg_next_payment,
       r.[npsp__Status__c] AS raw_status, r.[npe03__Next_Payment_Date__c] AS raw_next_payment
FROM staging.recurring_donation_latest s
OUTER APPLY (SELECT TOP 1 r0.[npsp__Status__c], r0.[npe03__Next_Payment_Date__c]
             FROM raw.salesforce_recurring_donation r0
             WHERE LTRIM(RTRIM(r0.[Id])) = LTRIM(RTRIM(s.[Id]))
             ORDER BY TRY_CONVERT(DATETIME2, r0.[SystemModstamp]) DESC) r
WHERE UPPER(LTRIM(RTRIM(COALESCE(s.[npsp__Status__c],'')))) = 'ACTIVE'
  AND NULLIF(LTRIM(RTRIM(COALESCE(s.[npe03__Next_Payment_Date__c],''))),'') IS NULL;
```

### Worst records (concrete examples for stakeholders)
Among the active rules, the worst records break **2 rules** — **RD-007 + RD-015** (bad dates + no closed reason), e.g.
`a094J00000d0Y5z`, `a094J00000MryeX`, `a094J00000MryYo`. Use one of these as the “look how bad a single record can be” example.

**Net quality read:** the object is **structurally sound** (all identity, format, and numeric rules pass). The real issues are **completeness** (RD-015, RD-023) and **consistency** (RD-007) — mostly governance and
migration cleanup, plus one operational revenue risk (RD-023). Controlled-list fields (Status, Payment Method, etc.) are **not gated** — their distinct values are listed in §3b for stakeholders to confirm.

---

## 3b. Controlled-list fields — distinct values for stakeholder review

> We do **not** assume any of these values is wrong. The rules for these fields (RD-005, RD-010, RD-011, RD-012, RD-013, RD-014, RD-021) are **report-only** (not gated). Below are the actual distinct values and counts — please confirm which are valid / canonical (and whether near-duplicates like `SEPA` vs `sepa_debit` should be merged).

| Field | Distinct values (count) |
|-------|-------------------------|
| `npsp__Status__c` | Closed 188,618 · Active 69,817 · Paused 27 · Lapsed 2 · `<NULL/BLANK>` 1 |
| `npe03__Installment_Period__c` | Monthly 180,606 · `<NULL/BLANK>` 45,487 · Daily 16,351 · Yearly 13,004 · Weekly 3,017 |
| `npsp__RecurringType__c` | Open 203,915 · Fixed 54,548 · `<NULL/BLANK>` 2 |
| `npsp__PaymentMethod__c` | card 97,802 · Direct Debit 66,863 · Card Payment 52,734 · `<NULL/BLANK>` 29,812 · sepa_debit 10,778 · us_bank_account 232 · SEPA 129 · bacs_debit 34 · Cash 19 · ach_debit 17 · acss_debit 16 · Check 14 · Bank Transfer 6 · ACH 4 · Cheque 2 · Credit Card 1 · Card Terminal 1 · BankTransfer 1 |
| `Donation_Type__c` | RD 177,586 · 10N 37,357 · 30N 13,433 · RDA 12,887 · 10D 11,048 · EMI 3,136 · TJC 3,017 · `<NULL/BLANK>` 1 |
| `Regional_Office_Code__c` | UK 134,715 · FR 88,007 · US 20,467 · AR 7,437 · CA 3,283 · ES 2,146 · BE 1,351 · IE 1,002 · WQ 51 · `<NULL/BLANK>` 6 |
| `CurrencyIsoCode` | GBP 133,633 · EUR 93,488 · USD 27,211 · CAD 3,280 · AED 648 · SAR 139 · QAR 66 |

```sql
-- Re-run the distinct list for any controlled-list field (change the column)
SELECT COALESCE(NULLIF(LTRIM(RTRIM([npsp__PaymentMethod__c])),''),'<NULL/BLANK>') AS value, COUNT(*) AS cnt
FROM staging.recurring_donation_latest
GROUP BY COALESCE(NULLIF(LTRIM(RTRIM([npsp__PaymentMethod__c])),''),'<NULL/BLANK>')
ORDER BY cnt DESC;
```

---

## 4. What we need from the stakeholders

| # | Question | Why it matters | Rule |
|---|----------|----------------|------|
| Q1 | Is **Closed Reason mandatory** for Closed donations? | 79,000 rows (42% of Closed) are blank — either enforce it, or we drop the rule | RD-015 |
| Q2 | Are **Start > End** dates a migration artifact or real errors? | 19,864 rows; decide fix-at-source vs accept | RD-007 |
| Q3 | Which **controlled-list values** are canonical? See the distinct-value lists in §3b (Status, Payment Method, Installment Period, Recurring Type, Donation Type, Regional Office, Currency). e.g. is `SEPA` (129) the same as `sepa_debit`? | We report the values only — you confirm the valid set; nothing is treated as a defect | §3b |
| Q4 | Should an **Active** donation always have a **Next Payment Date**? | 90 rows have none — collections/reporting risk | RD-023 |

> **Deferred rules:** RD-003 (no donor, 57) and RD-008 (contact link) are switched off for now because donor / Contact data isn't loaded. Revisit both once Contact is available.

### Open questions found in the data (not yet rules — need a decision)
- **`Total_Donation_Amount__c` meaning:** it is **not** the lifetime total. Evidence shows Paid (e.g. 2,125) far exceeds Total (35); `Total_Donation_Amount__c` tracks the **recurring/installment amount**, and **`npe03__Paid_Amount__c`** is the lifetime paid. Please confirm the intended meaning before any "paid vs total" rule.
- **At-risk donors:** 3,286 Active donations have **≥3 failed payments** — do you want an alert/monitoring rule and at what threshold?
- **Open vs Fixed lifecycle:** 97,271 "Open" have an End date and 24,151 "Fixed" have none — confirm the expected rule before enforcing.

---

## 5. Re-check any time (SSMS-ready)

```sql
-- Per-rule status + failures
SELECT r.check_name, r.severity, s.last_run_status,
       ISNULL(dr.failed_count,0) AS failed_count
FROM dq.dq_rule_catalog r
JOIN dq.rule_execution_state s ON s.rule_id = r.rule_id
LEFT JOIN (
    SELECT check_name, failed_count,
           ROW_NUMBER() OVER (PARTITION BY check_name ORDER BY checked_at DESC) AS rn
    FROM dq.dq_results WHERE object_name = 'Recurring_Donation'
) dr ON dr.check_name = r.check_name AND dr.rn = 1
WHERE r.object_name = 'Recurring_Donation'
ORDER BY r.check_name;

-- See the actual failing rows for one rule (change RD-007)
SELECT TOP 50 e.record_id, e.exception_value
FROM dq.dq_exceptions e
JOIN dq.dq_rule_catalog r ON r.rule_id = e.rule_id
WHERE e.object_name = 'Recurring_Donation' AND r.check_name = 'RD-007';

-- Worst records (most rules broken)
SELECT TOP 10 e.record_id, COUNT(DISTINCT e.rule_id) AS rules_failed,
       STRING_AGG(r.check_name, ', ') WITHIN GROUP (ORDER BY r.check_name) AS failed_rules
FROM dq.dq_exceptions e
JOIN dq.dq_rule_catalog r ON r.rule_id = e.rule_id
WHERE e.object_name = 'Recurring_Donation'
GROUP BY e.record_id
ORDER BY rules_failed DESC;
```

**Re-run all rules:** execute [recurring_donation_staging_dq_PROD_framework.sql](recurring_donation_staging_dq_PROD_framework.sql)
(rebuilds staging, seeds 16 rules — the 7 controlled-list fields are report-only (not seeded), resets watermarks, runs). All active rules are currently `CAUGHT_UP` with 0 rows behind.
