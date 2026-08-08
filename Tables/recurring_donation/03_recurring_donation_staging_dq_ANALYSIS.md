# Recurring Donation — DQ Analysis (Final)

**Run:** 2026-08-01 · **Rows checked:** 258,465 · **Rules:** 21 total — 14 active gated · 7 controlled-list report-only · **Result:** 11 PASS · 3 FAIL · 0 errors
**Affected records:** 54,631 (a record can break more than one rule)

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
| Rules run | 21 |
| Active gated rules | 14 |
| Controlled-list report-only | 7 (RD-005, RD-010–014, RD-021) |
| Rules failing | 3 |
| Records with ≥1 failure | 54,631 |

---

## 2. All 21 rules — full status

| Rule | Sev | What it checks | Status | Failed |
|------|-----|----------------|--------|-------:|
| RD-001 | CRITICAL | Id is not null | ✅ PASS | 0 |
| RD-002 | CRITICAL | Id is a valid 15/18-char Salesforce ID | ✅ PASS | 0 |
| RD-004 | HIGH | Active donation has amount > 0 | ✅ PASS | 0 |
| RD-005 | — | Status — distinct values reported (not gated) | 📋 REPORT-ONLY | — |
| RD-006 | MEDIUM | Day of month is 1–31 or Last_Day | ✅ PASS | 0 |
| RD-007 | HIGH | Start date ≤ End date | 🔴 FAIL | 19,864 |
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

📋 **RD-005, RD-010, RD-011, RD-012, RD-013, RD-014, RD-021** are **report-only** (controlled-list fields — no assumed values; distinct values in §3b), not counted in PASS/FAIL. RD-018–RD-023 were added after the data
investigation: RD-018–RD-022 are clean guards (0 failures), RD-023 found 90 real issues.

---

## 2b. Table creation, dedup & staged-row evidence

`staging.recurring_donation_latest` is rebuilt from `raw.salesforce_recurring_donation`, deduped by `Id`
(latest `SystemModstamp`), excluding soft-deleted rows → **258,465 rows, 31 columns** (3,112 duplicates collapsed).

**Dedup logic:**
```sql
WITH dedup AS (
  SELECT [Id],[IsDeleted],[SystemModstamp],
    ROW_NUMBER() OVER (
      PARTITION BY CONVERT(VARCHAR(18),[Id])
      ORDER BY COALESCE(TRY_CONVERT(DATETIME2(7),[SystemModstamp],127),
                        TRY_CONVERT(DATETIME2(7),[SystemModstamp])) DESC) AS rn
  FROM [raw].[salesforce_recurring_donation]
  WHERE [Id] IS NOT NULL
)
SELECT * FROM dedup
WHERE rn=1
  AND COALESCE(LOWER(LTRIM(RTRIM(CONVERT(NVARCHAR(20),[IsDeleted])))),N'false')
      NOT IN (N'true',N'1',N'yes',N'y');
```

**Staging columns (31):**

| # | Column | # | Column |
|---|--------|---|--------|
| 1 | `row_number` | 17 | `npe03__Installment_Period__c` |
| 2 | `Id` | 18 | `npsp__Day_of_Month__c` |
| 3 | `IsDeleted` | 19 | `npe03__Next_Payment_Date__c` |
| 4 | `Name` | 20 | `Donation_Type__c` |
| 5 | `CurrencyIsoCode` | 21 | `npsp__PaymentMethod__c` |
| 6 | `npe03__Contact__c` | 22 | `Regional_Office_Code__c` |
| 7 | `npe03__Organization__c` | 23 | `npe03__Recurring_Donation_Campaign__c` |
| 8 | `npe03__Amount__c` | 24 | `Number_of_Failed_Payments__c` |
| 9 | `npe03__Installment_Amount__c` | 25 | `SystemModstamp` |
| 10 | `npe03__Paid_Amount__c` | 26 | `_etl_source` |
| 11 | `Total_Donation_Amount__c` | 27 | `_etl_source_object` |
| 12 | `npsp__Status__c` | 28 | `_etl_loaded_at_utc` |
| 13 | `npsp__RecurringType__c` | 29 | `staging_is_duplicate` |
| 14 | `npsp__StartDate__c` | 30 | `staging_duplicate_count` |
| 15 | `npsp__EndDate__c` | 31 | `staging_created_at` |
| 16 | `npsp__ClosedReason__c` | | |

**Staged-row evidence (SSMS-ready):**
```sql
SELECT TOP (2) [Id],[npsp__Status__c],[npe03__Amount__c],[npsp__StartDate__c],[npsp__EndDate__c],[npe03__Next_Payment_Date__c]
FROM staging.recurring_donation_latest ORDER BY staging_created_at DESC;
```

| Id | Status | Amount | StartDate | EndDate | NextPayment |
|----|--------|-------:|-----------|---------|-------------|
| a094J00000d03BWQAY | Closed | 40.0 | 2021-09-01 | 2025-12-02 | NULL |
| a094J00000Ms41cQAB | Closed | 35.0 | 2020-06-01 | 2021-10-25 | NULL |

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

**Sample rule matches (actual output — top 8):**

| Id | npsp__Status__c | npsp__ClosedReason__c |
|----|-----------------|-----------------------|
| a094J00000d01lkQAA | Closed | NULL |
| a094J00000d02swQAA | Closed | NULL |
| a094J00000d02WgQAI | Closed | NULL |
| a094J00000d03BMQAY | Closed | NULL |
| a094J00000d0645QAA | Closed | NULL |
| a094J00000d06reQAA | Closed | NULL |
| a094J00000d07w4QAA | Closed | NULL |
| a094J00000d07y5QAA | Closed | NULL |

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

**Sample rule matches (actual output — top 8):**

| Id | npsp__StartDate__c | npsp__EndDate__c |
|----|--------------------|------------------|
| a094J00000d03Q3QAI | 2021-08-01 | 2021-07-27 |
| a094J00000d06AyQAI | 2021-09-01 | 2021-08-11 |
| a094J00000d0HWpQAM | 2021-09-01 | 2021-07-30 |
| a094J00000d0lkPQAQ | 2021-09-01 | 2021-08-18 |
| a094J00000d0O33QAE | 2021-09-01 | 2021-08-04 |
| a094J00000d0Y5zQAE | 2021-09-01 | 2021-08-12 |
| a094J00000d14mLQAQ | 2021-09-01 | 2021-08-12 |
| a094J00000Mryd4QAB | 2021-03-09 | 2021-03-04 |

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

**Sample rule matches (actual output — top 8):**

| Id | npsp__Status__c | npe03__Next_Payment_Date__c |
|----|-----------------|------------------------------|
| a094J00000UJmhqQAD | Active | NULL |
| a094J00000UJnBGQA1 | Active | NULL |
| a094J00000UJpDCQA1 | Active | NULL |
| a094J00000UJpeNQAT | Active | NULL |
| a094J00000UJvAKQA1 | Active | NULL |
| a094J00000UJwJxQAL | Active | NULL |
| a094J00000UJxV7QAL | Active | NULL |
| a094J00000UJxxXQAT | Active | NULL |

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

## 3c. Rule match summary (ranked)

**Authoritative failed counts (framework run, `dq.dq_results`):** 98,954 matches across **54,631 distinct
records** (one record can break more than one rule). Only the 3 active gated rules below failed; the other
11 active gated rules PASS with 0.

### By severity (active failing rules)

| Severity | Matches | % of fail total |
|----------|--------:|----------------:|
| CRITICAL | 0 | 0.0% |
| HIGH | 19,954 | 20.2% |
| MEDIUM | 79,000 | 79.8% |
| LOW | 0 | 0.0% |
| **Total** | **98,954** | **100.0%** |

### By rule (ranked)

| Rank | Rule | Description | Matches | Severity |
|------|------|-------------|--------:|----------|
| 1 | RD-015 | Closed donation with no Closed Reason | 79,000 | MEDIUM |
| 2 | RD-007 | Start date after End date | 19,864 | HIGH |
| 3 | RD-023 | Active donation with no Next Payment Date | 90 | HIGH |
| **Total** | | | **98,954** | |

> `dq.dq_exceptions` stores a **capped subset** of these rows (RD-015 capped at 50,000) — see §4c.
> The counts above (from `dq.dq_results`) are the authoritative run results.

---

## 4. Business Actions Required

| Rule | Count | Stakeholder question | Decision options | Owner | Deadline |
|------|------:|----------------------|------------------|-------|----------|
| RD-015 | 79,000 | Is **Closed Reason mandatory** for Closed donations? | Enforce at source; make optional (drop rule); backfill from history | RD Business Owner | This week |
| RD-007 | 19,864 | Are **Start > End** dates a migration artifact or real errors? | Fix at source; accept as legacy; exclude from date logic | RD Business + Data Eng | This week |
| RD-023 | 90 | Should an **Active** donation always have a **Next Payment Date**? | Require it; allow blank; auto-derive next date | Collections Owner | This week |
| RD-005/010–014/021 | report-only | Which **controlled-list values** are canonical (§3b)? e.g. is `SEPA` = `sepa_debit`? | Confirm/curate allowed list; merge near-duplicates | RD Business Owner | Next week |

### Open questions found in the data (not yet rules — need a decision)
- **`Total_Donation_Amount__c` meaning:** it is **not** the lifetime total. Evidence shows Paid (e.g. 2,125) far exceeds Total (35); `Total_Donation_Amount__c` tracks the **recurring/installment amount**, and **`npe03__Paid_Amount__c`** is the lifetime paid. Please confirm the intended meaning before any "paid vs total" rule.
- **At-risk donors:** 3,286 Active donations have **≥3 failed payments** — do you want an alert/monitoring rule and at what threshold?
- **Open vs Fixed lifecycle:** 97,271 "Open" have an End date and 24,151 "Fixed" have none — confirm the expected rule before enforcing.

---

## 4b. Most-violating records

Ranked over the **active** failing rules (RD-007 / RD-015 / RD-023):

```sql
SELECT TOP 5 e.record_id, COUNT(DISTINCT r.check_name) AS rules_failed,
       STRING_AGG(r.check_name, ', ') WITHIN GROUP (ORDER BY r.check_name) AS failed_rules
FROM dq.dq_exceptions e JOIN dq.dq_rule_catalog r ON r.rule_id=e.rule_id
WHERE r.object_name='Recurring_Donation' AND e.resolution_status='OPEN'
  AND r.check_name IN ('RD-007','RD-015','RD-023')
GROUP BY e.record_id ORDER BY rules_failed DESC;
```

**Actual output (top 5):**

| record_id | rules_failed | failed_rules |
|-----------|-------------:|--------------|
| a094J00000d0Y5zQAE | 2 | RD-007, RD-015 |
| a094J00000MryeXQAR | 2 | RD-007, RD-015 |
| a094J00000MryYoQAJ | 2 | RD-007, RD-015 |
| a094J00000MryZAQAZ | 2 | RD-007, RD-015 |
| a094J00000MrzhIQAR | 2 | RD-007, RD-015 |

Worst case = a closed donation with **inverted dates AND no closed reason** — a consistency *and* a
completeness defect on the same record.

---

## 4c. What's stored where + framework status

- ✅ Registered in `dq.dq_rule_catalog` — 21 active RD rules. Framework run **2026-08-01**.
- ✅ 14 active gated · 7 report-only (RD-005/010–014/021).
- ⚠️ **`dq.dq_exceptions` holds 69,954 OPEN rows for the active failing rules, not the authoritative 98,954** —
  the runner **capped RD-015 at 50,000** (`MaxExceptionsPerRule`). Authoritative failed counts live in
  `dq.dq_results`. **Cleanup task:** re-run RD-015 uncapped if full exception rows are needed.
- ⚠️ Business review pending — exceptions stay `OPEN` until reviewed.
- ❌ No writeback to Salesforce (not enabled).

| Table | Rows | Status |
|-------|-----:|--------|
| `staging.recurring_donation_latest` | 258,465 | latest-per-Id, 31 columns |
| `dq.dq_exceptions` (RD, OPEN) | 69,954 | RD-015 capped at 50k (from 79k) |
| `dq.dq_rule_catalog` (RD) | 21 | 14 gated · 7 report-only |

---

## 4d. Sign-off & next meeting

**What we accomplished**
- Staged 258,465 donations (3,112 duplicates collapsed).
- Ran 21 rules (14 gated · 7 report-only); 3 failing, 0 CRITICAL.
- 98,954 matches across 54,631 records; identified 4 decisions + 1 exceptions-cleanup task.

**Decisions needed**
- [ ] RD-015 Closed Reason mandatory? _______________
- [ ] RD-007 Start>End fix-at-source vs accept? _______________
- [ ] RD-023 Active must have Next Payment Date? _______________
- [ ] Controlled-list canonical values (§3b)? _______________
- [ ] Approve exceptions cleanup (uncap RD-015)? _______________

---
