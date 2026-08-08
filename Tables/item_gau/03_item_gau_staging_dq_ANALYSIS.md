# Item / GAU — Staging & DQ Framework Analysis

Object: `Item_GAU` · Source: `raw.salesforce_item` · Staging: `staging.item_gau_latest`
Framework run: **2026-07-30** (read from `dq.dq_results` / `dq.rule_execution_state` on 2026-08-01).
Status: **Framework executed — final results below.** No re-run performed for this document.

## 0. Validation-rule additions — 2026-08-07 (Salesforce active validation rules)

Source: `shared files/The Team/20260804 active validation rules.tsv` (live Salesforce org validation
rules). One GAU rule was mapped into `dq.dq_rule_catalog` using the `-VR-` provenance namespace and run
incrementally full-population. GAU rule count **26 → 27**.

| Rule | Source SF validation rule | Type | Severity | Open exceptions |
|------|---------------------------|------|----------|----------------:|
| `GAU-VR-001` | `Deactivate_Item_After_Emptying_Funds` | CUSTOM_SQL | MEDIUM | **448** |
| `GAU-VR-002` | `Ticket_Items_Gift_Eligibility` | CUSTOM_SQL | MEDIUM | **0** (PASS — clean) |

GAU-VR-002 required widening `staging.item_gau_latest` with `Gift_Aid_Eligible__c`; the full-population scan
of 30,832 rows returned **0** — no Ticket item is flagged Gift-Aid-Eligible. GAU rule count **27 → 28**
(26 original + GAU-VR-001 + GAU-VR-002).

This is a **financial-governance check**: an item marked inactive (`npsp__Active__c = false`) that still
holds unspent Zakat or Non-Zakat credit (> 0). Salesforce blocks deactivation until funds are spent, so
these 448 are historical records that violate that rule — a real review item, not a format defect.

```sql
SELECT TOP 10 [Id], [npsp__Active__c], [Total_Zakat_Credit__c], [Total_Non_Zakat_Credit__c]
FROM   staging.item_gau_latest
WHERE  LOWER(LTRIM(RTRIM(COALESCE([npsp__Active__c],'false')))) = 'false'
  AND (TRY_CONVERT(DECIMAL(18,2),[Total_Zakat_Credit__c]) > 0
       OR TRY_CONVERT(DECIMAL(18,2),[Total_Non_Zakat_Credit__c]) > 0);
```
| Id | Active | Zakat | NonZakat |
|----|--------|------:|---------:|
| a0ZN2000001Md3lMAC | false | 0.0 | 10,965.0 |
| a0Z8e000000UcKTEA0 | false | 0.0 | 3,530.0 |
| a0ZN2000000VPOjMAO | false | 0.0 | 395.5 |

**Business action:** review — why are inactive items still holding unspent funds? Owner: Programmes /
Finance. Not auto-fixable (funds must be reallocated via Concept Notes); tag for stakeholder review, keep
`OPEN`.

### Salesforce validation rules NOT implemented (and why)

All in-scope Item/GAU validation rules from the TSV are now implemented — `Deactivate_Item_After_Emptying_Funds`
(GAU-VR-001) and `Ticket_Items_Gift_Eligibility` (GAU-VR-002, enabled by staging `Gift_Aid_Eligible__c`).
No Item/GAU rule requires a join, so the complicated-join / empty-table skip rule does not apply here.

## 1. Executive Summary

| Metric | Value |
|---|---|
| Run date | 2026-07-30 |
| Raw rows (non-deleted) | 30,832 |
| Staging rows (latest per Id) | 30,815 |
| Items with duplicate raw versions | 574 (latest kept) |
| Active items | 25,833 |
| Rules in framework | 26 (GAU-001..026) — 20 active gated · 6 controlled-list report-only |
| PASS / FAIL (active gated) | 14 PASS / 6 FAIL |
| Total open exceptions | 1,537 |
| Distinct affected items | 1,506 (some fail >1 rule) |
| Controlled-list report-only | GAU-007, GAU-008, GAU-009, GAU-015, GAU-016, GAU-017 (no assumed values — distinct values in §7b) |

### Severity split (open exceptions)
| Severity | Count |
|---|---:|
| CRITICAL | 0 |
| HIGH | 965 |
| MEDIUM | 239 |
| LOW | 333 |
| **Total** | **1,537** |

## 2. Null Analysis (RAW vs Staging)

Reused from the EDA `Top Null Columns` (staging, 30,815 rows):

| Column | Null % | Staged? | Verdict |
|---|---:|:---:|---|
| `Country__c` | 62.6% | Yes | concern **only** for active non-Pledge (955 real fails); rest expected |
| `Status__c` | 12.4% | Yes | all nulls are inactive → GAU-019 passes (not a concern) |
| `Product_Type__c` | 5.7% | Yes | concern for active items (GAU-014 passes → active items are covered) |
| 5 financial totals | 0–0.01% | Yes | effectively complete |

## 3. Evidence Snapshot

Reproducible (SSMS-ready):

```sql
-- Staging count + active + key nulls
SELECT (SELECT COUNT(*) FROM staging.item_gau_latest) AS staging_rows,
       SUM(CASE WHEN LOWER(LTRIM(RTRIM(COALESCE([npsp__Active__c],'false'))))='true' THEN 1 ELSE 0 END) AS active_items
FROM staging.item_gau_latest;

-- Sample a staged record
SELECT TOP (2) [Id],[Name],[npsp__Active__c],[Product_Type__c],[Country__c],[Status__c]
FROM staging.item_gau_latest ORDER BY staging_created_at DESC;

-- Framework result per rule
SELECT r.check_name, r.severity, dr.check_status, dr.failed_count
FROM dq.dq_rule_catalog r
JOIN (SELECT check_name, check_status, failed_count,
             ROW_NUMBER() OVER (PARTITION BY check_name ORDER BY checked_at DESC) rn
      FROM dq.dq_results WHERE object_name='Item_GAU') dr
  ON dr.check_name=r.check_name AND dr.rn=1
WHERE r.object_name='Item_GAU' ORDER BY r.check_name;
```

Observed: `staging_rows = 30,815`, `active_items = 25,833`.

## 4. Table Creation and Population

`staging.item_gau_latest` rebuilt from `raw.salesforce_item`, deduped by `Id` (latest `SystemModstamp`),
excluding soft-deleted rows → **30,815 rows, 31 columns** (incl. 5 financial totals added in the latest
cycle). 574 items had multiple raw versions; the latest was kept and flagged via `staging_is_duplicate`.

**Deduplication logic:**
```sql
WITH dedup AS (
  SELECT
    [Id], [IsDeleted], [SystemModstamp],
    ROW_NUMBER() OVER (
      PARTITION BY CONVERT(VARCHAR(18), [Id])
      ORDER BY COALESCE(
        TRY_CONVERT(DATETIME2(7), [SystemModstamp], 127),
        TRY_CONVERT(DATETIME2(7), [SystemModstamp])
      ) DESC
    ) AS rn
  FROM [raw].[salesforce_item]
  WHERE [Id] IS NOT NULL
)
SELECT *
FROM dedup
WHERE rn = 1
  AND COALESCE(LOWER(LTRIM(RTRIM(CONVERT(NVARCHAR(20), [IsDeleted])))), N'false')
      NOT IN (N'true', N'1', N'yes', N'y');
```

**Table structure (31 columns):**

| # | Column | # | Column |
|---|--------|---|--------|
| 1 | `row_number` (dedup rank) | 17 | `Stipulation__c` |
| 2 | `Id` | 18 | `Regional_Office_Code__c` |
| 3 | `IsDeleted` | 19 | `Total_Non_Zakat_Credit__c` |
| 4 | `Name` | 20 | `Total_Zakat_Credit__c` |
| 5 | `CurrencyIsoCode` | 21 | `Total_funds_available_sadaqa__c` |
| 6 | `npsp__Active__c` | 22 | `Total_funds_available_zakat__c` |
| 7 | `Product_Type__c` | 23 | `npsp__Total_Allocations__c` |
| 8 | `Programme_Category__c` | 24 | `npsp__Description__c` |
| 9 | `Donation_Type__c` | 25 | `SystemModstamp` |
| 10 | `Country__c` | 26 | `_etl_source` |
| 11 | `Status__c` | 27 | `_etl_source_object` |
| 12 | `Campaign__c` | 28 | `_etl_loaded_at_utc` |
| 13 | `Donation_Item_Code__c` | 29 | `staging_is_duplicate` |
| 14 | `Allow_Single__c` | 30 | `staging_duplicate_count` |
| 15 | `Allow_Recurring__c` | 31 | `staging_created_at` |
| 16 | `HA_Donation_Frequency__c` | | |

## 5. Rule Catalog Executed (26 rules)

| Rule | Severity | Check | Status | Failed |
|---|---|---|:---:|---:|
| GAU-001 | CRITICAL | Id not null/blank | PASS | 0 |
| GAU-002 | CRITICAL | Id 15/18 chars | PASS | 0 |
| GAU-003 | HIGH | Name not null/blank | PASS | 0 |
| GAU-004 | MEDIUM | Active is boolean token | PASS | 0 |
| GAU-005 | MEDIUM | Currency populated for active | PASS | 0 |
| GAU-006 | HIGH | IsDeleted boolean token | PASS | 0 |
| GAU-007 | — | Product_Type — distinct values reported (not gated) | 📋 REPORT-ONLY | — |
| GAU-008 | — | Programme_Category — distinct values reported (not gated) | 📋 REPORT-ONLY | — |
| GAU-009 | — | Donation_Type — distinct values reported (not gated) | 📋 REPORT-ONLY | — |
| **GAU-010** | **HIGH** | **Active non-Pledge must have Country** | **FAIL** | **955** |
| **GAU-011** | **MEDIUM** | **Status consistent with active flag** | **FAIL** | **231** |
| GAU-012 | MEDIUM | Campaign exists in raw.salesforce_campaign | PASS | 0 |
| GAU-013 | HIGH | Donation_Item_Code unique | PASS | 0 |
| GAU-014 | HIGH | Active item has Product_Type | PASS | 0 |
| GAU-015 | — | HA_Donation_Frequency — distinct values reported (not gated) | 📋 REPORT-ONLY | — |
| GAU-016 | — | Stipulation — distinct values reported (not gated) | 📋 REPORT-ONLY | — |
| GAU-017 | — | Regional_Office_Code — distinct values reported (not gated) | 📋 REPORT-ONLY | — |
| **GAU-018** | **LOW** | **Active Sponsorship/Ticket allow-flag set** | **FAIL** | **333** |
| GAU-019 | MEDIUM | Active item has Status | PASS | 0 |
| GAU-020 | HIGH | Total_Non_Zakat_Credit not null | PASS | 0 |
| GAU-021 | HIGH | Total_Zakat_Credit not null | PASS | 0 |
| GAU-022 | HIGH | funds_available_sadaqa not null | PASS | 0 |
| GAU-023 | HIGH | funds_available_zakat not null | PASS | 0 |
| **GAU-024** | **HIGH** | **Total_Non_Zakat_Credit numeric** | **FAIL** | **8** |
| **GAU-025** | **HIGH** | **Total_Zakat_Credit numeric** | **FAIL** | **2** |
| **GAU-026** | **MEDIUM** | **npsp__Total_Allocations numeric** | **FAIL** | **8** |

## 6. Zero-Finding Checks

14 active gated rules returned **0** failures: GAU-001..006, 012..014, 019..023. These confirm identity,
uniqueness, financial not-null, and Campaign referential integrity are clean at the current population. The
6 controlled-list rules (GAU-007, 008, 009, 015, 016, 017) are **report-only** — not gated; their distinct values
are reported in §7b for stakeholders to confirm (we do not assume any value is wrong).

## 7. Rule Matches Requiring Review

### GAU-010 — Active non-Pledge item missing `Country__c` (HIGH, 955)

955 active, non-Pledge items have no Country. (`Country__c` is 62.6% null overall, but the rule correctly
excludes Pledge and inactive items — down from the pre-fix ~17,320.)

**SQL check query (top rows):**
```sql
SELECT TOP 10 [Id],[Name],[Product_Type__c],[Country__c],[npsp__Active__c]
FROM staging.item_gau_latest
WHERE LOWER(LTRIM(RTRIM(COALESCE([npsp__Active__c],'false'))))='true'
  AND UPPER(LTRIM(RTRIM(COALESCE([Product_Type__c],''))))<>'PLEDGE'
  AND NULLIF(LTRIM(RTRIM(COALESCE([Country__c],''))),'') IS NULL
ORDER BY [Name];
```

**Sample rule matches (actual output — top 8):**

| Id | Name | Product_Type__c | Country__c | Active |
|----|------|-----------------|-----------|--------|
| a0Z8e000000GrRzEAK | (DO NOT USE) Water, Sanitation and Hygiene Fund | Fund | NULL | true |
| a0Z4J000002KDZgUAO | 10 Days Food Fund | Fund | NULL | true |
| a0Z8e000000gPH2EAM | 10 Days Food Fund | Fund | NULL | true |
| a0Z8e000000gPT6EAM | 10 Days Food Fund | Fund | NULL | true |
| a0Z8e000000gUjGEAU | 10 Days Food Fund | Fund | NULL | true |
| a0Z8e000000gV1SEAU | 10 Days Food Fund | Fund | NULL | true |
| a0Z4J000002KDZhUAO | 10 Days Orphans and Children Fund | Fund | NULL | true |
| a0Z8e000000gPH3EAM | 10 Days Orphans and Children Fund | Fund | NULL | true |

**Stakeholder question:** Should active non-Pledge items require a Country, or are some global/HQ items exempt?

---

### GAU-011 — Status inconsistent with active flag (MEDIUM, 231)

231 items are `npsp__Active__c = true` while `Status__c = 'Inactive'` — a direct flag/status conflict.

**Diagnostic — Status distribution for active items (actual output):**
```
status_val | cnt
Active     | 25,602
Inactive   | 231
```

**SQL check query (top rows):**
```sql
SELECT TOP 10 [Id],[Name],[npsp__Active__c],[Status__c]
FROM staging.item_gau_latest
WHERE LOWER(LTRIM(RTRIM(COALESCE([npsp__Active__c],'false'))))='true'
  AND UPPER(LTRIM(RTRIM(COALESCE([Status__c],'')))) IN ('INACTIVE','CLOSED','ARCHIVED')
ORDER BY [Name];
```

**Stakeholder question:** Which field is authoritative — `npsp__Active__c` or `Status__c`? (All 231 are active-flagged but status=Inactive.)

---

### GAU-018 — Active Sponsorship/Ticket with no allow-flag (LOW, 333)

333 active Sponsorship/Ticket items have both `Allow_Single__c` and `Allow_Recurring__c` false (scoped to
those two types by design — the sample is dominated by ticket items).

**SQL check query (top rows):**
```sql
SELECT TOP 10 [Id],[Name],[Product_Type__c],[Allow_Single__c],[Allow_Recurring__c]
FROM staging.item_gau_latest
WHERE LOWER(LTRIM(RTRIM(COALESCE([npsp__Active__c],'false'))))='true'
  AND UPPER(LTRIM(RTRIM(COALESCE([Product_Type__c],'')))) IN ('SPONSORSHIP','TICKET')
  AND LOWER(LTRIM(RTRIM(COALESCE([Allow_Single__c],'false'))))='false'
  AND LOWER(LTRIM(RTRIM(COALESCE([Allow_Recurring__c],'false'))))='false'
ORDER BY [Name];
```

**Sample rule matches (actual output — top 8):**

| Id | Name | Product_Type__c | Allow_Single__c | Allow_Recurring__c |
|----|------|-----------------|-----------------|--------------------|
| a0Z8e000000poiyEAA | Adult Entrance Ticket | Ticket | false | false |
| a0Z8e000000UcH7EAK | Adult Entrance Ticket | Ticket | false | false |
| a0Z8e000000UOCtEAO | Adult Entrance Ticket | Ticket | false | false |
| a0Z8e000000UOCuEAO | Adult Entrance Ticket | Ticket | false | false |
| a0Z8e000000UOCvEAO | Adult Entrance Ticket | Ticket | false | false |
| a0Z8e000000UOCyEAO | Adult Entrance Ticket | Ticket | false | false |
| a0Z8e000000UODDEA4 | Adult Entrance Ticket | Ticket | false | false |
| a0ZN20000000tqvMAA | Black Friday Family (5 Tickets) | Ticket | false | false |

**Stakeholder question:** Should active Sponsorship/Ticket items with both allow-flags false accept donations at all?

---

### GAU-024 / 025 / 026 — "Non-numeric" financial totals (HIGH/MEDIUM, 8 / 2 / 8)

18 items carry values that fail a `DECIMAL` cast in `Total_Non_Zakat_Credit__c` (8), `Total_Zakat_Credit__c`
(2), `npsp__Total_Allocations__c` (8).

> **Root cause (engineering finding):** these are **not garbage** — they are large numbers stored in
> **scientific / exponential notation** (e.g. `1.31987012E7` = 13,198,701.2). Confirmed:
> `TRY_CONVERT(DECIMAL(18,2),'1.31987012E7')` → `NULL`, but `TRY_CONVERT(FLOAT,'1.31987012E7')` → `13198701.2`.
> Fix either at source (store plain decimal) **or** relax the rule to parse via `FLOAT` before `DECIMAL`.

**SQL check query (GAU-024 shown; swap the column for 025/026):**
```sql
SELECT TOP 10 [Id],[Name],[Total_Non_Zakat_Credit__c]
FROM staging.item_gau_latest
WHERE NULLIF(LTRIM(RTRIM([Total_Non_Zakat_Credit__c])),'') IS NOT NULL
  AND TRY_CONVERT(DECIMAL(18,2),[Total_Non_Zakat_Credit__c]) IS NULL
ORDER BY [Name];
```

**Sample rule matches (actual output):**

| Rule | Id | Name | Raw value (E-notation) |
|------|----|------|------------------------|
| GAU-024 | a0Z8e000000gP5fEAE | Gaza Emergency | `1.31987012E7` |
| GAU-024 | a0Z8e000000gPNgEAM | Gaza Emergency | `1.85423558E7` |
| GAU-024 | a0Z8e000000UuBUEA0 | Gift Aid Income - HMRC | `1.396747239E7` |
| GAU-025 | a0ZN2000000taKbMAI | 100% Zakat for Gaza Emergency | `1.340112775E7` |
| GAU-025 | a0Z8e000000gPOAEA2 | Zakat Fund | `1.443536126E7` |
| GAU-026 | a0Z4J000002KDiaUAG | Food Fund | `1.059147774E7` |
| GAU-026 | a0ZN20000000pDpMAI | HA France Project Fund | `5.072538999E7` |
| GAU-026 | a0Z4J000002KDzFUAW | Where Most Needed | `1.170510097E7` |

**Recommendation:** normalize the 18 values to plain decimal at source (or widen the rule to `FLOAT`); no business decision needed — mechanical, engineering-safe.

## 7b. Controlled-list fields — distinct values for stakeholder review

> We do **not** assume any of these values is wrong. The rules that used to gate them (GAU-007, GAU-008,
> GAU-009, GAU-015, GAU-016, GAU-017) are **report-only** (not gated). Below are the actual distinct values and counts —
> please confirm which are valid / canonical.

| Field | Distinct values (count) |
|-------|-------------------------|
| `Product_Type__c` | Pledge 18,322 · Fund 4,557 · Qty-based 2,977 · Project 2,069 · `<NULL/BLANK>` 1,763 · Sponsorship 510 · Qty-based (Special Request) 315 · Ticket 188 · Medical 59 · Bundle 42 · Deductions 6 · Other Income 5 · Fees Charged 2 |
| `Programme_Category__c` | General 10,219 · UnAllocated Funds 9,962 · Food 3,493 · Emergency 1,532 · Medical 1,085 · Orphans and Children 713 · Livelihoods 561 · WASH 508 · Education 416 · Development 410 · OCW 382 · EmergencyResponse 347 · SeasonalRamadan 232 · Shelter 214 · SeasonalQurbani 128 · `<NULL/BLANK>` 125 · Gifts 113 · SpecialRequest 90 · Integrated Development 76 · Children 67 · SeasonalWinterisation 57 · SeasonalRamadan(ZAF) 56 · SeasonalBacktoSchool 26 · Fees Charged 2 · SeasonalEidGifts 1 |
| `Donation_Type__c` | `<NULL/BLANK>` 27,928 · Single 1,726 · Single;Recurring 998 · Recurring 163 |
| `HA_Donation_Frequency__c` | Monthly 29,021 · `<NULL/BLANK>` 1,786 · Monthly;Daily 8 |
| `Stipulation__c` | SD 21,481 · SD;ZK 3,742 · SD;ZK;XX 3,539 · `<NULL/BLANK>` 1,621 · XX 270 · ZK 87 · SD;XX 75 |
| `Regional_Office_Code__c` | UK 16,305 · All 3,150 · `<NULL/BLANK>` 1,963 · US 1,802 · CA 1,700 · FR 1,680 · BE 1,178 · ES 1,033 · IE 937 · AR 909 · TR 132 · WQ 26 |

```sql
-- Re-run the distinct list for any controlled-list field (change the column)
SELECT COALESCE(NULLIF(LTRIM(RTRIM([Product_Type__c])),''),'<NULL/BLANK>') AS value, COUNT(*) AS cnt
FROM staging.item_gau_latest
GROUP BY COALESCE(NULLIF(LTRIM(RTRIM([Product_Type__c])),''),'<NULL/BLANK>')
ORDER BY cnt DESC;
```

## 8. Rule Match Summary (ranked)

**Totals:** 1,537 open exceptions across **1,506 distinct affected items** (overlap: some items fail
more than one rule). Only the 6 active gated rules below produced matches; the other 14 gated rules PASS
with 0 and the 6 controlled-list rules are report-only.

### By severity (open exceptions)

| Severity | Count | % of Total |
|----------|------:|-----------:|
| CRITICAL | 0 | 0.0% |
| HIGH | 965 | 62.8% |
| MEDIUM | 239 | 15.6% |
| LOW | 333 | 21.7% |
| **TOTAL** | **1,537** | **100.0%** |

### By rule (ranked)

| Rank | Rule | Description | Matches | Severity |
|------|------|-------------|--------:|----------|
| 1 | GAU-010 | Active non-Pledge item missing Country | 955 | HIGH |
| 2 | GAU-018 | Active Sponsorship/Ticket, no allow-flag | 333 | LOW |
| 3 | GAU-011 | Status inconsistent with active flag | 231 | MEDIUM |
| 4 | GAU-024 | Total_Non_Zakat_Credit not numeric (E-notation) | 8 | HIGH |
| 5 | GAU-026 | npsp__Total_Allocations not numeric (E-notation) | 8 | MEDIUM |
| 6 | GAU-025 | Total_Zakat_Credit not numeric (E-notation) | 2 | HIGH |
| **TOTAL** | | | **1,537** | |

---

## 9. Business Actions Required

| Rule | Count | Stakeholder question | Decision options | Owner | Deadline |
|------|------:|----------------------|------------------|-------|----------|
| GAU-010 | 955 | Must active non-Pledge items have a Country? | Require Country; exempt global/HQ items; remediate at source | Item/GAU Business Owner | This week |
| GAU-011 | 231 | Which is authoritative — `npsp__Active__c` or `Status__c`? | Trust active flag; trust status; reconcile at source | Item & Process Owner | This week |
| GAU-018 | 333 | Should active Sponsorship/Ticket with both allow-flags false accept donations? | Set an allow-flag; deactivate; allow as-is | Fundraising Owner | Next week |
| GAU-024/025/026 | 18 | (Engineering) Normalize E-notation financials? | Fix at source to decimal; widen rule to FLOAT | Data Engineering | This week |
| GAU-007/008/009/015/016/017 | report-only | Which controlled-list values are canonical? | Confirm/curate allowed lists (see §7b) | Item/GAU Business Owner | Next week |

---

## 10. Most-Violating Records

```sql
SELECT TOP 5 e.record_id, COUNT(DISTINCT r.check_name) AS rules_failed,
       STRING_AGG(r.check_name, ', ') WITHIN GROUP (ORDER BY r.check_name) AS failed_rules
FROM dq.dq_exceptions e JOIN dq.dq_rule_catalog r ON r.rule_id=e.rule_id
WHERE r.object_name='Item_GAU' AND e.resolution_status='OPEN'
GROUP BY e.record_id ORDER BY rules_failed DESC;
```

**Actual output (top 5):**

| record_id | rules_failed | failed_rules |
|-----------|-------------:|--------------|
| a0Z8e000000gPLGEA2 | 3 | GAU-018, GAU-024, GAU-026 |
| a0Z8e000000gP3FEAU | 2 | GAU-018, GAU-024 |
| a0Z8e000000gP9CEAU | 2 | GAU-018, GAU-026 |
| a0Z8e000000UuBUEA0 | 2 | GAU-024, GAU-026 |
| a0ZN20000000pCDMAY | 2 | GAU-024, GAU-026 |

Worst cases are active Sponsorship items that also carry an E-notation financial value (GAU-018 + GAU-024/026).

---

## 11. What's Stored Where

### Framework status (from live `dq` tables, read 2026-08-01)

- ✅ Item/GAU **is registered in the DQ framework** — 26 rules in `dq.dq_rule_catalog` (rule_ids 19–24, 53–72).
- ✅ The framework **has executed** (run 2026-07-30) and written **1,537 open Item_GAU exceptions** to
  `dq.dq_exceptions` (the official DQ layer): GAU-010 = 955, GAU-018 = 333, GAU-011 = 231, GAU-024 = 8,
  GAU-026 = 8, GAU-025 = 2; the other 14 gated rules PASS with 0.
- ✅ 6 controlled-list rules (GAU-007/008/009/015/016/017) are **report-only** (not gated).
- ⚠️ **Business review / sign-off is still pending** — exceptions remain `OPEN` until reviewed/resolved.
- ❌ **No corrections written back to Salesforce yet** (writeback not enabled).

| Table | Rows | Status |
|-------|-----:|--------|
| `staging.item_gau_latest` | 30,815 | Materialized latest-per-Id (31 columns) |
| `dq.dq_exceptions` (Item_GAU, OPEN) | 1,537 | Official DQ layer — awaiting business review |
| `dq.dq_rule_catalog` (Item_GAU) | 26 | 20 gated + 6 report-only |

---

## 12. Sign-off & Next Meeting

### What we accomplished
- ✅ Staged 30,815 items (574 duplicates collapsed)
- ✅ Executed 26 rules (20 gated / 6 report-only)
- ✅ Found 1,537 matches across 1,506 items; 0 CRITICAL
- ✅ Identified 4 business decision areas + 1 engineering fix

### Decisions needed
- [ ] GAU-010 Country requirement: _______________
- [ ] GAU-011 active vs status authority: _______________
- [ ] GAU-018 Sponsorship/Ticket allow-flags: _______________
- [ ] GAU-024/025/026 E-notation financials — normalize at source or widen rule: _______________
- [ ] Controlled-list canonical values (§7b): _______________

**Date:** _______________  **Attendees:** _______________

---

## 13. Recommendations

- **Stakeholder decisions:** GAU-010 (Country requirement), GAU-011 (active vs status authority),
  GAU-018 (Sponsorship/Ticket allow-flags) — each needs a policy answer before it becomes a hard gate.
- **Controlled-list fields (report-only):** GAU-007/008/009/015/016/017 are report-only — we do not assume valid
  values. See §7b distinct-value lists and ask stakeholders which are canonical.
