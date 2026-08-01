# Item / GAU — Staging & DQ Framework Analysis

Object: `Item_GAU` · Source: `raw.salesforce_item` · Staging: `staging.item_gau_latest`
Framework run: **2026-07-30** (read from `dq.dq_results` / `dq.rule_execution_state` on 2026-08-01).
Status: **Framework executed — final results below.** No re-run performed for this document.

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
excludes Pledge and inactive items — down from the pre-fix ~17,320.) Sample check:
```sql
SELECT TOP 10 [Id],[Name],[Product_Type__c],[Country__c],[npsp__Active__c]
FROM staging.item_gau_latest
WHERE LOWER(LTRIM(RTRIM(COALESCE([npsp__Active__c],'false'))))='true'
  AND UPPER(LTRIM(RTRIM(COALESCE([Product_Type__c],''))))<>'PLEDGE'
  AND NULLIF(LTRIM(RTRIM(COALESCE([Country__c],''))),'') IS NULL;
```
**Stakeholder question:** Should active non-Pledge items require a Country, or are some global/HQ items exempt?

### GAU-011 — Status inconsistent with active flag (MEDIUM, 231)
231 items where active=true but status is Inactive/Closed/Archived (or missing where flagged).
**Stakeholder question:** Which is authoritative — `npsp__Active__c` or `Status__c`?

### GAU-018 — Active Sponsorship/Ticket with no allow-flag (LOW, 333)
333 active Sponsorship/Ticket items have both `Allow_Single__c` and `Allow_Recurring__c` false (scoped to
those two types by design). **Stakeholder question:** Should these accept donations at all?

### GAU-024 / 025 / 026 — Non-numeric financial totals (HIGH/MEDIUM, 8 / 2 / 8)
18 items total carry non-numeric values in `Total_Non_Zakat_Credit__c` (8), `Total_Zakat_Credit__c` (2),
`npsp__Total_Allocations__c` (8). These are data-entry/format defects, engineering-fixable at source.

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

## 8. Most-Violating Records

```sql
SELECT TOP 5 e.record_id, COUNT(DISTINCT r.check_name) AS rules_failed,
       STRING_AGG(r.check_name, ', ') WITHIN GROUP (ORDER BY r.check_name) AS failed_rules
FROM dq.dq_exceptions e JOIN dq.dq_rule_catalog r ON r.rule_id=e.rule_id
WHERE r.object_name='Item_GAU' AND e.resolution_status='OPEN'
GROUP BY e.record_id ORDER BY rules_failed DESC;
```
Expected worst cases: active non-Pledge items that also carry a status/active mismatch (GAU-010 + GAU-011).

## 9. Recommendations

- **Engineering-safe now:** fix the 18 non-numeric financial values (GAU-024/025/026) at source; they are
  unambiguous defects.
- **Stakeholder decisions:** GAU-010 (Country requirement), GAU-011 (active vs status authority),
  GAU-018 (Sponsorship/Ticket allow-flags) — each needs a policy answer before it becomes a hard gate.
- **Controlled-list fields (report-only):** GAU-007/008/009/015/016/017 are report-only — we do not assume valid
  values. See §7b distinct-value lists and ask stakeholders which are canonical.
- **Deferred:** none.
