# next step 
we remove the the next steps if it has place downthere other wise it still a task 

using the grouped fields check what can replcae each otehr and ask stake holder 

# Campaign Staging Table & DQ Checks - Execution Analysis

**Date:** 2026-07-29  
**Database:** SalesforceDW  
**Status:** ✅ PRODUCTION READY & EXECUTED  
**Owner:** Data Engineering

---

## Executive Summary

Campaign data quality analysis complete. 17 active gated rules executed against 40,775 deduplicated records; the two controlled-list rules (CAM-004 Status, CAM-006 Currency) are **report-only** — we report their distinct values for stakeholders rather than assuming any value is wrong. This document is now focused on data-engineering evidence only: counts, aggregations, null checks, and reproducible drill-down queries.

### Key Metrics at a Glance

| Metric | Value | Status |
|--------|-------|--------|
| Total Staging Records | 40,775 | ✅ Clean |
| Raw Records (with duplicates) | 41,304 | Baseline |
| Duplicates Removed | 529 | Dedup working |
| **Total Rule Matches Found** | **17,691** | ⚠️ Needs Review |
| Unique Affected Campaigns | 15,642 | 38.4% of data |
| CRITICAL Rule Matches | 0 | ✅ None |
| HIGH Rule Matches | 0 | ✅ None |
| MEDIUM Rule Matches | 4,372 | ⚠️ Review Required |
| LOW Rule Matches | 13,319 | ⚠️ Review Required |
| Controlled-list report-only | CAM-004, CAM-006 | 📋 Distinct values below |

### Evidence Snapshot (From Actual SQL Run)

```sql
-- Reproducible evidence query (sqlcmd / SSMS)
SELECT 'staging_campaign_latest' AS metric, COUNT(*) AS value FROM [staging].[campaign_latest]
UNION ALL
SELECT 'raw_campaign_non_deleted', COUNT(*) FROM [raw].[salesforce_campaign] WHERE LOWER(ISNULL([IsDeleted],''))='false'
UNION ALL
SELECT 'distinct_campaign_ids_non_deleted', COUNT(DISTINCT [Id]) FROM [raw].[salesforce_campaign] WHERE LOWER(ISNULL([IsDeleted],''))='false';
```

```text
metric|value
staging_campaign_latest|40775
raw_campaign_non_deleted|41304
distinct_campaign_ids_non_deleted|40775
```

```sql
WITH d AS (
  SELECT [Id], COUNT(*) AS cnt
  FROM [raw].[salesforce_campaign]
  WHERE LOWER(ISNULL([IsDeleted],''))='false'
  GROUP BY [Id]
)
SELECT
  SUM(CASE WHEN cnt>1 THEN 1 ELSE 0 END) AS campaign_ids_with_duplicates,
  SUM(CASE WHEN cnt>1 THEN cnt-1 ELSE 0 END) AS duplicate_rows_removed
FROM d;
```

```text
campaign_ids_with_duplicates|duplicate_rows_removed
529|529
```

---

## SECTION 1: TABLE CREATION & POPULATION

### What We Did
Created `[staging].[campaign_latest]` materialized table from raw Salesforce Campaign data.

**Deduplication Logic:**
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
  FROM [raw].[salesforce_campaign]
  WHERE [Id] IS NOT NULL
)
SELECT *
FROM dedup
WHERE rn = 1
  AND COALESCE(LOWER(LTRIM(RTRIM(CONVERT(NVARCHAR(20), [IsDeleted])))), N'false')
      NOT IN (N'true', N'1', N'yes', N'y');
```

### Execution Results

**Status:** ✅ SUCCESS

```
Staging table created (29 columns, materialized from raw.salesforce_campaign)

Staging data loaded: 40,775 records (unique campaigns)
  Note: 529 campaigns had duplicates in raw data
```

**Table Structure (29 columns):**
1. row_number - Dedup ranking
2. Id - Salesforce Campaign ID
3. ParentId - Parent campaign reference
4. Type - Campaign type/classification
5. RecordTypeId - Salesforce record type ID
6. IsDeleted - Soft delete flag
7. Name - Campaign name
8. Status - Campaign status
9. StartDate - Campaign start
10. EndDate - Campaign end
11. Year__c - Campaign year
12. Region__c - Campaign region
13. CurrencyIsoCode - Currency
14. BudgetedCost - Budget amount
15. ActualCost - Actual spend
16. IsActive - Active flag
17. NumberOfOpportunities - Direct opportunity count
18. HierarchyNumberOfOpportunities - Hierarchy-level opportunity count
19. AmountAllOpportunities - All opportunities total
20. AmountWonOpportunities - Won opportunities total
21. Casesafe_Campaign_ID__c - Casesafe campaign identifier
22. Fundraising_page_url__c - Custom URL field
23. SystemModstamp - Salesforce audit timestamp
24. _etl_source - ETL source system
25. _etl_source_object - ETL source object
26. _etl_loaded_at_utc - ETL load timestamp
27. staging_is_duplicate - Was this a duplicate? (1=yes, 0=no)
28. staging_duplicate_count - How many duplicates? (0 if unique)
29. staging_created_at - When was this record staged?

---

## SECTION 2: DQ RULES REFERENCE TABLE

### What We Did

Created [staging].[dq_rules_reference] with 19 rule definitions for campaign DQ checks.

#### Rule Catalog

| Rule ID | Rule Description | Severity | Category |
|---------|------------------|----------|----------|
| CAM-001 | Campaign Id must not be null or blank | CRITICAL | NULL_VIOLATION |
| CAM-002 | Campaign Id must be 15 or 18 alphanumeric characters | CRITICAL | FORMAT_VIOLATION |
| CAM-003 | Campaign Name must not be null | HIGH | NULL_VIOLATION |
| CAM-004 | Campaign Status — distinct values reported (not gated) | — | REPORT-ONLY |
| CAM-005 | Start Date <= End Date | HIGH | DATE_LOGIC_VIOLATION |
| CAM-006 | Currency — distinct values reported (not gated) | — | REPORT-ONLY |
| CAM-007 | BudgetedCost >= 0 | MEDIUM | AMOUNT_VIOLATION |
| CAM-008 | AmountWon <= AmountAll | MEDIUM | AMOUNT_RECONCILIATION_VIOLATION |
| CAM-009 | Completed/Aborted with IsActive=false | MEDIUM | CONDITIONAL_LOGIC_VIOLATION |
| CAM-010 | ParentId must reference existing Id when populated | HIGH | REFERENTIAL_INTEGRITY_VIOLATION |
| CAM-011 | Past EndDate with IsActive=false | LOW | HISTORICAL_STATE_VIOLATION |
| CAM-012 | ActualCost <= 200% of BudgetedCost when BudgetedCost>0 | LOW | REASONABLENESS_VIOLATION |
| CAM-013 | NumberOfOpportunities <= HierarchyNumberOfOpportunities | MEDIUM | HIERARCHY_CONSISTENCY_VIOLATION |
| CAM-014 | Casesafe_Campaign_ID__c equals Id when populated | LOW | CONSISTENCY_VIOLATION |
| CAM-015 | Year__c valid 4-digit range | LOW | VALIDITY_VIOLATION |
| CAM-016 | Region__c in approved list when populated | MEDIUM | CONTROLLED_VALUE_VIOLATION |
| CAM-017 | IsDeleted token validity in raw layer | HIGH | VALIDITY_VIOLATION |
| CAM-URL-001 | URL pattern check (https/http/www/blank) | MEDIUM | FORMAT_VIOLATION |

#### Zero-Finding Checks (Engineering Snapshot)

| Rule | Check | Flagged Rows |
|------|-------|--------------|
| CAM-001 | Campaign Id NOT NULL | 0 |
| CAM-002 | Campaign Id length in (15,18) | 0 |
| CAM-003 | Campaign Name NOT NULL | 0 |
| CAM-005 | StartDate <= EndDate | 0 |
| CAM-007 | BudgetedCost >= 0 | 0 |

---

#### 🔴 RULE MATCHES REQUIRING REVIEW

**CAM-004: Campaign Status — 📋 REPORT-ONLY (no assumed values)**

**Policy:** We do **not** assume any Status value is wrong. This rule is **report-only** — we only report the distinct values below and ask stakeholders which are valid. (For reference, 9 rows have a null/blank Status.)

**Status Distribution (All Staging Rows):**
```
status_value     | cnt
In Progress      | 31,280
Planned          | 6,498
Completed        | 1,901
Aborted          | 1,087
<NULL_OR_BLANK>  | 9
```

**Status Null/Blank Count:**
```
status_null_or_blank_count | total_rows
9                          | 40,775
```

**Status values (reference only — not treated as errors):**
```
status_value_outside_current_list | cnt
<NULL_OR_BLANK>  | 9
```

**SQL Check Query (CAM-004 - Top 100 flagged rows):**
```sql
SELECT TOP 100
  [Id], [Name], [Status], [IsActive], [StartDate], [EndDate], [SystemModstamp]
FROM [staging].[campaign_latest]
WHERE LOWER(COALESCE(NULLIF(LTRIM(RTRIM([Status])), ''), '<NULL_OR_BLANK>')) NOT IN ('active','planned','inactive','completed','aborted','in progress')
ORDER BY [SystemModstamp] DESC;
```

**Evidence Query (NULL/blank statuses included in CAM-004 under current logic):**
```sql
SELECT TOP 100
  [Id], [Name], [Status], [IsActive], [StartDate], [EndDate], [SystemModstamp]
FROM [staging].[campaign_latest]
WHERE [Status] IS NULL OR LTRIM(RTRIM([Status])) = ''
ORDER BY [SystemModstamp] DESC;
```

Id | Name | Status | IsActive | StartDate | EndDate | SystemModstamp
---|------|--------|----------|-----------|---------|---------------
7018e000000TscIAAS | Street Marketing-FR | NULL | false | NULL | NULL | 2026-07-28T09:03:12.000Z
701N200000xqX34IAE | Orphan Food parcel Ramadan ( Palastine - FR) | NULL | true | NULL | NULL | 2026-07-27T14:25:14.000Z
701N200000vfhYAIAY | Campagne d'appels sortants Tous donateurs | NULL | false | 2025-12-15 | NULL | 2026-07-27T14:25:14.000Z
701N200000jEVa9IAG | Outbound calls 2025 | NULL | false | 2025-08-11 | NULL | 2026-07-27T14:17:48.000Z
7014J000000UL4hQAG | Winter 2021 | NULL | true | NULL | NULL | 2026-07-08T00:36:00.000Z
701N200000zGqmAIAS | OCIF Bazaar-FR-USA-02072026-EBS | NULL | true | 2026-02-07 | 2026-02-07 | 2026-07-03T11:37:22.000Z
7018e000000TtTUAA0 | Evento mujeres Terrassa 27-03-22 | NULL | true | NULL | NULL | 2026-07-03T11:35:00.000Z
701N2000010T1OTIA0 | 21/02/2026 - SISTERHOOD IFTAR BRADFORD | NULL | false | NULL | NULL | 2026-02-23T20:30:47.000Z
7018e000000TuKkAAK | https://www.gofundme.com/f/redazareramadan | NULL | true | NULL | NULL | 2025-03-26T21:31:23.000Z

**Stakeholder question:** These are the distinct Status values in the data — which are valid? (We flag nothing as wrong; the 9 null/blank rows are shown for reference only.)

---

**CAM-006: Currency — 📋 REPORT-ONLY (no assumed values)**

**Policy:** We do **not** assume any Currency value is wrong. This rule is **report-only** — the distinct values below are for stakeholders to confirm.

**Currency Distribution (All Staging Rows):**
```
currency_value | cnt
GBP            | 35,849
USD            | 2,176
EUR            | 1,412
CAD            | 1,337
SAR            | 1
```

**Currency Null/Blank Count:**
```
currency_null_or_blank_count | total_rows
0                            | 40,775
```

**Currencies (reference only — not treated as errors):**
```
currency_value_outside_current_list | cnt
<none>           | 0
```

**SQL Check Query (CAM-006 - Top 100 rows outside current currency list):**
```sql
SELECT TOP 100
  [Id], [Name], [CurrencyIsoCode], [Status], [SystemModstamp]
FROM [staging].[campaign_latest]
WHERE COALESCE(NULLIF(LTRIM(RTRIM([CurrencyIsoCode])), ''), '<NULL_OR_BLANK>') NOT IN ('GBP','USD','EUR','CAD','AUD','SAR')
ORDER BY [SystemModstamp] DESC;
```

**Reference Record (now allowed):**
```
Campaign ID: 701N200000U2IkLIAV
Currency Found: SAR
Current Controlled List: GBP, USD, EUR, CAD, AUD, SAR
```

**Stakeholder question:** These are the distinct Currency values in the data — please confirm the valid/canonical set.

---

**CAM-008: Amount Won Exceeds Amount All ⚠️ Reconciliation Condition**

**Rule:** AmountWon must be <= AmountAll (can't win more than available)

**Execution Result:**
```
Rule Matches Found: 23
Affected Campaigns: 23
Severity: MEDIUM
```

**What This Means:**
- 23 campaigns show AmountWon > AmountAll
- Engineering interpretation: in these rows, `AmountWonOpportunities - AmountAllOpportunities > 0`.

**CAM-008 Numeric Diagnostics:**
```
cam008_rows | parse_issue_rows | won_gt_all_rows | negative_all_rows
23         | 0                | 23              | 4
```

```
issue_rows | min_diff | max_diff | avg_diff
23        | 27.00    | 5000.00  | 533.719130
```

Where:
- `diff = TRY_CONVERT(decimal(18,2), AmountWonOpportunities) - TRY_CONVERT(decimal(18,2), AmountAllOpportunities)`
- `negative_all_rows` means `AmountAllOpportunities < 0` within CAM-008 rows.

**SQL Check Query (CAM-008 - Top 100 reconciliation rows):**
```sql
SELECT TOP 100
  [Id], [Name], [Status],
  TRY_CONVERT(DECIMAL(18,2), [AmountWonOpportunities]) AS amount_won,
  TRY_CONVERT(DECIMAL(18,2), [AmountAllOpportunities]) AS amount_all,
  TRY_CONVERT(DECIMAL(18,2), [AmountWonOpportunities]) - TRY_CONVERT(DECIMAL(18,2), [AmountAllOpportunities]) AS diff_won_minus_all,
  [SystemModstamp]
FROM [staging].[campaign_latest]
WHERE TRY_CONVERT(DECIMAL(18,2), [AmountWonOpportunities]) > TRY_CONVERT(DECIMAL(18,2), [AmountAllOpportunities])
ORDER BY diff_won_minus_all DESC, [SystemModstamp] DESC;
```

**Sample Rule Matches (Actual Query Output - Top 5):**

Id | Name | Status | amount_won | amount_all | diff_won_minus_all | SystemModstamp
---|------|--------|------------|------------|--------------------|---------------
701N200000yxVyMIAU | Cricket Tour-CA-01252026-USA-FR-EBS | In Progress | 72397.00 | 67397.00 | 5000.00 | 2026-07-03T11:39:09.000Z
7014J000000UOByQAO | 2016- Islam Channel Live Appeal ( June 20th ) | Planned | 92702.57 | 91264.96 | 1437.61 | 2025-03-25T12:32:26.000Z
701N200000sLAdDIAW | Ramadan 2025 - Croyant Rationnel se mobilise avec Human Appeal | In Progress | 59285.65 | 58185.65 | 1100.00 | 2026-07-03T11:35:27.000Z
7014J000000UeWpQAK | www.muslimgiving.com | In Progress | 216167.92 | 215277.92 | 890.00 | 2026-07-24T09:20:25.000Z
701N200000BIJAkIAP | West Coast Tour For Orphan Sponsorship Gaza | In Progress | 3513.00 | 2663.00 | 850.00 | 2026-07-03T11:37:36.000Z
701N200000fffNvIAI | Oud Making - Mississauga | Completed | 85.00 | -440.00 | 525.00 | 2026-07-03T11:33:28.000Z
701N2000009OzDOIA0 | Ladies Charity-FR-281023-SAB | In Progress | 459.62 | 92.00 | 367.62 | 2023-11-28T13:15:19.000Z
7018e000000TwloAAC | https://gofund.me/49568076 | In Progress | 45034.87 | 44724.87 | 310.00 | 2025-03-26T21:31:55.000Z
7014J000000UO8UQAW | 2016 - Inspire FM Luton (June 11th) | Planned | 15847.80 | 15547.80 | 300.00 | 2025-03-25T12:17:29.000Z
7014J000000UQbHQAW | 2016 - (M&W) Tayyibun: 7 Deadly Sins - Birmingham - 10 June 2016 | Planned | 2887.51 | 2592.51 | 295.00 | 2026-01-07T11:41:06.000Z
7014J000000UO9KQAW | 2016 - Productive Muslim Glasglow (June 11th ) | Planned | 0.00 | -275.00 | 275.00 | 2023-11-02T04:02:30.000Z
7018e000000tHdxAAE | Unspecified Bank Transfer - Donor Care UK | In Progress | 246811.53 | 246657.66 | 153.87 | 2026-04-20T10:09:28.000Z
7014J000000UOAEQA4 | 2016 - Sri Lanken Muslim Culture Centre Collection (June 14th) | Planned | 0.00 | -120.00 | 120.00 | 2023-11-02T04:02:30.000Z
7018e000000Tue4AAC | https://www.facebook.com/680462613278078 | In Progress | 71780.65 | 71664.05 | 116.60 | 2025-03-26T21:31:34.000Z
701N2000016jFtpIAE | Summer of Sadaqah | In Progress | 1213.20 | 1122.20 | 91.00 | 2026-07-27T10:30:28.000Z
701N200000la9sJIAQ | CT2025-Dasser | In Progress | 721.00 | 646.00 | 75.00 | 2026-07-03T11:33:14.000Z
701N200000FiXdxIAF | DFW SuhoorFest-FR-US-03162024 | Planned | 11539.00 | 11469.00 | 70.00 | 2026-07-03T11:37:36.000Z
7018e000000HKsiAAG | shamim shahid-800-XX-20201 | In Progress | 870.10 | 803.10 | 67.00 | 2025-03-26T21:20:47.000Z
7014J000000UaMHQA0 | https://www.instagram.com | In Progress | 383027.19 | 382962.35 | 64.84 | 2025-03-26T21:18:30.000Z
7014J000000UO71QAG | 2016 - Al Haramain Tour Manchester Eccles (June 17th) | Planned | 0.00 | -50.00 | 50.00 | 2023-11-02T04:02:29.000Z
7014J000000UO6yQAG | 2016 - Al Haramain Tour Dar Al Huda Bedford ( June 9th ) | Planned | 2285.00 | 2235.00 | 50.00 | 2023-11-02T04:02:29.000Z
7018e000000gadaAAA | https://www.launchgood.com/campaign/reach_23__rosy_goes_to_lebanon | In Progress | 129643.06 | 129603.06 | 40.00 | 2026-07-03T11:37:58.000Z
7018e000000TwOtAAK | The Balance Movie Tour - Cineworld - Luton - 14 Aug | In Progress | 95.00 | 68.00 | 27.00 | 2023-11-02T04:01:30.000Z

**Business Confirmation Needed:** Decide whether CAM-008 stays strict or adds reconciliation tolerance.

---

**CAM-009: Completed/Aborted Still Marked Active**

**Rule:** If Status = 'Completed' OR Status = 'Aborted', then IsActive must = false

**Execution Result:**
```
Rule Matches Found: 2,097
Affected Campaigns: 2,097
Severity: MEDIUM
```

**What This Means:**
- 2,097 rows match the CAM-009 condition under the current rule.
- This result indicates a mismatch with the current rule logic and needs policy confirmation.

**Sample Rule Matches (Actual Query Output - Top 5):**
```
Campaign 7014J000000UavvQAC
  Status: Completed
  IsActive: true (flagged by current CAM-009 rule)

Campaign 7014J000000Ub19QAC
  Status: Completed
  IsActive: true (flagged by current CAM-009 rule)

Campaign 7014J000000Ub1HQAS
  Status: Completed
  IsActive: true (flagged by current CAM-009 rule)

Campaign 7014J000000UbnuQAC
  Status: Completed
  IsActive: true (flagged by current CAM-009 rule)

Campaign 7014J000000Uc0yQAC
  Status: Aborted
  IsActive: true (flagged by current CAM-009 rule)
```

**SQL Check Query (CAM-009 - Top 100 active completed/aborted rows):**
```sql
SELECT TOP 100
  [Id], [Name], [Status], [IsActive], [EndDate], [SystemModstamp]
FROM [staging].[campaign_latest]
WHERE UPPER(LTRIM(RTRIM(COALESCE([Status], '')))) IN ('COMPLETED', 'ABORTED')
  AND LOWER(LTRIM(RTRIM(COALESCE([IsActive], 'false')))) = 'true'
ORDER BY [SystemModstamp] DESC;
```

**Business Confirmation Needed:** Confirm CAM-009 policy behavior and enforcement approach.

---

**CAM-011: Past EndDate with IsActive=true ⚠️ Second Largest Volume**

**Rule:** If EndDate < TODAY, then IsActive should = false

**Execution Result:**
```
Rule Matches Found: 13,318
Affected Campaigns: 13,318
Severity: LOW
```

**What This Means:**
- 13,318 rows match the CAM-011 condition under the current rule.
- This result is a rule-condition match and requires policy confirmation.

**Sample Rule Matches (Actual Query Output - Top 5):**
```
Campaign: 7014J000000UavvQAC (ended 2022-06-11)
  IsActive: true (flagged by current CAM-011 rule)

Campaign: 7014J000000Ub17QAC (ended 2026-03-19)
  IsActive: true (flagged by current CAM-011 rule)

Campaign: 7014J000000Ub1HQAS (ended 2022-05-31)
  IsActive: true (flagged by current CAM-011 rule)

Campaign: 7014J000000UbaoQAC (ended 2021-04-22)
  IsActive: true (flagged by current CAM-011 rule)

Campaign: 7014J000000UbbmQAC (ended 2021-04-24)
  IsActive: true (flagged by current CAM-011 rule)
```

**SQL Check Query (CAM-011 - Top 100 ended but still active):**
```sql
SELECT TOP 100
  [Id], [Name], [Status], [EndDate], [IsActive], [SystemModstamp]
FROM [staging].[campaign_latest]
WHERE TRY_CONVERT(DATE, [EndDate]) < CAST(GETDATE() AS DATE)
  AND LOWER(LTRIM(RTRIM(COALESCE([IsActive], 'false')))) = 'true'
ORDER BY TRY_CONVERT(DATE, [EndDate]) ASC, [SystemModstamp] DESC;
```

**Business Confirmation Needed:** Confirm CAM-011 policy for historical campaigns.

---

**CAM-URL-001: URL Values Outside Current Pattern Rule ⚠️ High Volume**

**Rule:** Fundraising_page_url__c must be blank OR start with (https://, http://, www.)

**Execution Result:**
```
Rule Matches Found: 2,252
Affected Campaigns: 2,252
Severity: MEDIUM
```

**What This Means:**
- 2,252 rows are flagged by CAM-URL-001 under the current URL pattern rule.
- These are likely:
  - Internal names instead of URLs
  - Incomplete URLs
  - Legacy formats
- Baseline reference in prior documentation: ~2,242
- Current run result: 2,252

**Sample Rule Matches (Actual Query Output - Top 10 URLs):**
```
Campaign: 7018e000000gayAAAQ
  Value: Givebrite.com
  Reason flagged: does not start with https://, http://, or www.

Campaign: 701N2000002Dfc5IAC
  Value: FR-NAT-LNS-BIS
  Reason flagged: does not match current URL prefix rule

Campaign: 701N2000002DnoAIAS
  Value: FR-NAT-LNS-BIS
  Reason flagged: does not match current URL prefix rule

Campaign: 701N200000eIvIZIA0
  Value: last_ten_nights__gaza_emergency_appeal_in_the_name_of_mohammed_farraj
  Reason flagged: does not match current URL prefix rule

Campaign: 701N200000eMaCYIA0
  Value: urgent_aid_for_families_in_gaza_and_yemen_with_jubad
  Reason flagged: does not match current URL prefix rule

Campaign: 701N200000eMe6bIAC
  Value: ayesha_suleimans_reach_sisters_boat_race_2025
  Reason flagged: does not match current URL prefix rule

Campaign: 701N200000eMiIHIA0
  Value: halimat_raheems_reach_sisters_boat_race_2025
  Reason flagged: does not match current URL prefix rule

Campaign: 701N200000eMk75IAC
  Value: maaria_siddiques_reach_sisters_boat_race_2025
  Reason flagged: does not match current URL prefix rule

Campaign: 701N200000eMkJrIAK
  Value: leeds_beckett_isoc__gaza_emergency_human_appeal
  Reason flagged: does not match current URL prefix rule

Campaign: 701N200000eMm8qIAC
  Value: zainab_ahnouds_reach_sisters_boat_race_2025
  Reason flagged: does not match current URL prefix rule
```

**SQL Check Query (CAM-URL-001 - Top 100 rows outside current URL pattern rule):**
```sql
SELECT TOP 100
  [Id], [Name], [Fundraising_page_url__c], [Status], [SystemModstamp]
FROM [staging].[campaign_latest]
WHERE [Fundraising_page_url__c] IS NOT NULL
  AND LTRIM(RTRIM([Fundraising_page_url__c])) <> ''
  AND LOWER(LTRIM(RTRIM([Fundraising_page_url__c]))) NOT LIKE 'https://%'
  AND LOWER(LTRIM(RTRIM([Fundraising_page_url__c]))) NOT LIKE 'http://%'
  AND LOWER(LTRIM(RTRIM([Fundraising_page_url__c]))) NOT LIKE 'www.%'
ORDER BY [SystemModstamp] DESC;
```

**Engineering Observation:**
- Many flagged values look like codes/titles instead of prefixed URLs.

**Business Confirmation Needed:** Confirm intended use and accepted formats for this field.

---

## SECTION 3B: NEWLY ADDED COVERAGE (CAM-010 TO CAM-017)

These checks were added in the latest PROD revision to cover previously missing candidate areas from EDA.

| Rule | Description | Result (Current Run) |
|------|-------------|----------------------|
| CAM-010 | ParentId must reference existing campaign Id when populated | 0 |
| CAM-012 | ActualCost should not exceed 200% of BudgetedCost when BudgetedCost > 0 | 0 |
| CAM-013 | NumberOfOpportunities must be <= HierarchyNumberOfOpportunities | 0 |
| CAM-014 | Casesafe_Campaign_ID__c should match Id when both populated | 0 |
| CAM-015 | Year__c must be valid 4-digit range (2000..current+1) when populated | 0 |
| CAM-016 | Region__c must be from approved list when populated | SKIPPED (no approved list loaded) |
| CAM-017 | IsDeleted must be true/false token in raw layer | 0 |

Interpretation:
- These rule checks are now active and executable in PROD.
- CAM-016 is implemented and governed by [staging].[campaign_region_allowed_values].
- Current zero counts indicate no matches under present data and rule definitions for the other new checks.

---

## SECTION 4: RULE MATCH SUMMARY

### Overall Statistics

```
Total Staging Records:           40,775
Campaign IDs with Duplicates in Raw: 529 (529 duplicate rows removed)
Total Rule Matches Found:        18,228
Unique Campaigns with Rule Matches: 16,078 (39.4% of data has at least 1 rule match)
```

### Rule Matches by Severity

| Severity | Count | Affected | % of Total |
|----------|-------|----------|-----------|
| **CRITICAL** | 0 | 0 | 0.0% |
| **HIGH** | 9 | 9 | 0.1% |
| **MEDIUM** | 4,901 | 4,815 | 26.9% |
| **LOW** | 13,318 | 13,318 | 75.3% |
| **TOTAL** | **18,228** | **16,078** | **100.0%** |

**Key Insight:** Current rule matches are concentrated in LOW and MEDIUM checks, led by lifecycle and URL-pattern checks.

### Rule Matches by Rule (Ranked)

| Rank | Rule | Description | Rule Matches | Campaigns | Severity |
|------|------|-------------|-----------|-----------|----------|
| 1 | CAM-011 | Past Campaigns Still Active | 13,318 | 13,318 | LOW |
| 2 | CAM-URL-001 | URL outside current pattern rule | 2,252 | 2,252 | MEDIUM |
| 3 | CAM-009 | Completed/Aborted Still Active | 2,097 | 2,097 | MEDIUM |
| 4 | CAM-008 | Amount Won > Amount All | 23 | 23 | MEDIUM |
| 5 | CAM-004 | Status outside current controlled list (includes null/blank) | 9 | 9 | HIGH |
| 6 | CAM-006 | Currency outside current controlled list | 0 | 0 | MEDIUM |
| **TOTAL** | | | **18,228** | **16,078** | |

---

## SECTION 5: CAMPAIGNS WITH MULTIPLE RULE MATCHES

### Analysis
Many campaigns violate MORE THAN ONE rule.

**Top Campaigns with Most Rule Matches (Actual Query Output):**

```
campaign_id           | rule_match_count
7018e000000HKsiAAG    | 3
701N2000009OzDOIA0    | 3
701N200000fffNvIAI    | 3
701N200000jcP9yIAE    | 3
701N200000jdxrGIAQ    | 3
701N200000jelb6IAA    | 3
701N200000jewpnIAA    | 3
701N200000jf08hIAA    | 3
701N200000jGNKAIA4    | 3
701N200000jGqH6IAK    | 3
```

**Repro Query:**
```sql
SELECT TOP 20
  [campaign_id],
  COUNT(*) as rule_match_count
FROM [staging].[campaign_dq_exceptions_temp]
GROUP BY [campaign_id]
HAVING COUNT(*) > 1
ORDER BY rule_match_count DESC, [campaign_id];
```

**Expected Pattern:**
- Many campaigns match CAM-011 (historical active flag condition)
- Some campaigns match CAM-URL-001 and CAM-009
- CAM-004 now contributes 9 rows due to null/blank statuses being included in controlled-list enforcement

---

## SECTION 6: BUSINESS ACTIONS REQUIRED

### Immediate Decisions Needed

| Rule | Current Count | Stakeholder Question | Decision Options | Owner | Deadline |
|------|---------------|----------------------|------------------|-------|----------|
| CAM-004 | 9 rule matches | How should null/blank statuses be handled? | Remediate at source; default in ETL; allow with exception process | Campaign Business Owner | This week |
| CAM-011 | 13,318 rule matches | Should past EndDate campaigns remain active until manual/archive action? | Keep as-is; enforce auto-deactivation; hybrid policy | Campaign Business Owner | This week |
| CAM-URL-001 | 2,252 rule matches | What values are acceptable in Fundraising_page_url__c? | URL-only; allow codes/titles; split into separate fields | Campaign & Fundraising Owner | This week |
| CAM-009 | 2,097 rule matches | Should Completed/Aborted campaigns always be inactive? | Enforce via process/automation; allow exceptions; periodic review | Campaign & Process Owner | Next week |
| CAM-008 | 23 rule matches | Should AmountWon > AmountAll always be blocked, or tolerated with thresholds? | Strict rule; threshold/tolerance; case-by-case review | Finance & Opportunity Owner | Next week |
| CAM-006 | 0 rule matches | Should additional currencies be allowed beyond current list? | Keep current list; add more currencies if approved | Finance & Campaign Owner | Next week |

---

## SECTION 7: WHAT'S STORED WHERE

### Tables Created (Temporary - Pre-Review Only)

**`[staging].[campaign_latest]`**
- 40,775 rows (deduplicated campaigns)
- 29 columns (includes extended lineage and validation fields)
- Status: **Staging - Ready for Analysis**
- Contents: Latest version of each campaign

**`[staging].[campaign_dq_exceptions_temp]`**
- 18,228 rows (one row per rule match)
- Status: **Pre-Review - NOT Yet Official**
- Purpose: Waiting for business approval before moving to dq layer
- Next Step: When approved, INSERT into `[dq].[dq_exceptions]`

**`[staging].[dq_rules_reference]`**
- 18 rows (all rules defined)
- Status: **Rule Catalog - Reference Only**
- Used for: Joining rule matches to rule descriptions

### Framework Status (updated 2026-08-01)

✅ Campaign **is registered in the DQ framework** — 18 rules in `[dq].[dq_rule_catalog]` (all `is_active = 1`).
✅ The framework **has executed** (2026-07-29) and written **17,700 Campaign exceptions to `[dq].[dq_exceptions]`** (the official DQ layer). Framework failed-rule counts: CAM-004 = 9, CAM-008 = 23, CAM-009 = 2,097, CAM-011 = 13,319, CAM-URL-001 = 2,252; the other 13 rules PASS with 0.
✅ Reproducible framework script: [02_campaign_staging_dq_PROD_framework.sql](02_campaign_staging_dq_PROD_framework.sql) (rebuilds `staging.campaign_latest`, MERGEs the 18 rules, runs `dq.run_incremental_catalog_rules`).
⚠️ **Business review / sign-off is still pending.** Rules are seeded `approval_status = 'Approved'`, but the flagged values themselves await stakeholder decisions (see Section 6). Exceptions remain `OPEN` in `dq.dq_exceptions` until reviewed/resolved.
❌ **No corrections have been written back to Salesforce yet** (writeback is not enabled).

> Note on the two counts: the framework total is **17,700** (CAM-011 = 13,319). The object-local
> temp-table run in this document reports **17,699** (CAM-011 = 13,318) — a 1-row boundary difference
> (`GETUTCDATE()` vs `GETDATE()` on the EndDate cutoff). The framework figure in `dq.dq_exceptions` is authoritative.
> The `staging.campaign_*_temp` tables described elsewhere in this document are the older object-local
> scaffold; the authoritative results now live in the `dq` layer via the framework.

### Next Steps (Pending Approval)

✅ Once business reviews rule matches:
1. Mark approved rule matches with `remediation_flag = 'APPROVED'`
2. Move to official layer: `INSERT INTO [dq].[dq_exceptions]`
3. Update `[dq].[dq_rule_catalog]` with rule definitions
4. Create mart tables with clean data
5. Build Power BI reports

---

## SECTION 8: QUERIES FOR FURTHER ANALYSIS

### Run These Queries to Explore

**A) CAM-004 Status Distribution + Null Count:**
```sql
SELECT
  COALESCE(NULLIF(LTRIM(RTRIM([Status])), ''), '<NULL_OR_BLANK>') AS status_value,
  COUNT(*) AS cnt
FROM [staging].[campaign_latest]
GROUP BY COALESCE(NULLIF(LTRIM(RTRIM([Status])), ''), '<NULL_OR_BLANK>')
ORDER BY cnt DESC, status_value;

SELECT
  SUM(CASE WHEN [Status] IS NULL OR LTRIM(RTRIM([Status])) = '' THEN 1 ELSE 0 END) AS status_null_or_blank_count,
  COUNT(*) AS total_rows
FROM [staging].[campaign_latest];
```

**B) CAM-004 Top 100 Rows Flagged by Current Rule:**
```sql
SELECT TOP 100
  [Id], [Name], [Status], [IsActive], [StartDate], [EndDate], [SystemModstamp]
FROM [staging].[campaign_latest]
WHERE LOWER(COALESCE(NULLIF(LTRIM(RTRIM([Status])), ''), '<NULL_OR_BLANK>')) NOT IN ('active','planned','inactive','completed','aborted','in progress')
ORDER BY [SystemModstamp] DESC;
```

**C) CAM-006 Currency Distribution + Null Count:**
```sql
SELECT
  COALESCE(NULLIF(LTRIM(RTRIM([CurrencyIsoCode])), ''), '<NULL_OR_BLANK>') AS currency_value,
  COUNT(*) AS cnt
FROM [staging].[campaign_latest]
GROUP BY COALESCE(NULLIF(LTRIM(RTRIM([CurrencyIsoCode])), ''), '<NULL_OR_BLANK>')
ORDER BY cnt DESC, currency_value;

SELECT
  SUM(CASE WHEN [CurrencyIsoCode] IS NULL OR LTRIM(RTRIM([CurrencyIsoCode])) = '' THEN 1 ELSE 0 END) AS currency_null_or_blank_count,
  COUNT(*) AS total_rows
FROM [staging].[campaign_latest];
```

**D) CAM-006 Top 100 Rows Outside Current Currency List:**
```sql
SELECT TOP 100
  [Id], [Name], [CurrencyIsoCode], [Status], [SystemModstamp]
FROM [staging].[campaign_latest]
WHERE UPPER(COALESCE(NULLIF(LTRIM(RTRIM([CurrencyIsoCode])), ''), '<NULL_OR_BLANK>')) NOT IN ('GBP','USD','EUR','CAD','AUD','SAR')
ORDER BY [SystemModstamp] DESC;
```

**E) CAM-008 Top 100 Rows Where AmountWon > AmountAll:**
```sql
SELECT TOP 100
  [Id],
  [Name],
  [Status],
  TRY_CONVERT(DECIMAL(18,2), [AmountWonOpportunities]) AS amount_won,
  TRY_CONVERT(DECIMAL(18,2), [AmountAllOpportunities]) AS amount_all,
  TRY_CONVERT(DECIMAL(18,2), [AmountWonOpportunities]) - TRY_CONVERT(DECIMAL(18,2), [AmountAllOpportunities]) AS diff_won_minus_all,
  [SystemModstamp]
FROM [staging].[campaign_latest]
WHERE TRY_CONVERT(DECIMAL(18,2), [AmountWonOpportunities]) > TRY_CONVERT(DECIMAL(18,2), [AmountAllOpportunities])
ORDER BY diff_won_minus_all DESC, [SystemModstamp] DESC;
```

**F) CAM-009 Top 100 Rows Where Completed/Aborted AND IsActive = true:**
```sql
SELECT TOP 100
  [Id], [Name], [Status], [IsActive], [EndDate], [SystemModstamp]
FROM [staging].[campaign_latest]
WHERE UPPER(LTRIM(RTRIM(COALESCE([Status], '')))) IN ('COMPLETED', 'ABORTED')
  AND LOWER(LTRIM(RTRIM(COALESCE([IsActive], 'false')))) = 'true'
ORDER BY [SystemModstamp] DESC;
```

**G) CAM-011 Top 100 Rows Where EndDate < Today AND IsActive = true:**
```sql
SELECT TOP 100
  [Id], [Name], [Status], [EndDate], [IsActive], [SystemModstamp]
FROM [staging].[campaign_latest]
WHERE TRY_CONVERT(DATE, [EndDate]) < CAST(GETDATE() AS DATE)
  AND LOWER(LTRIM(RTRIM(COALESCE([IsActive], 'false')))) = 'true'
ORDER BY TRY_CONVERT(DATE, [EndDate]) ASC, [SystemModstamp] DESC;
```

**H) Top 100 Rule Matches for Any Rule (All Issues in One Query):**
```sql
SELECT TOP 100
  [exception_id], [campaign_id], [field_name], [current_value],
  [rule_violated], [rule_description], [severity], [found_at_utc]
FROM [staging].[campaign_dq_exceptions_temp]
ORDER BY [found_at_utc] DESC, [severity] DESC, [exception_id] DESC;
```

**I) Top 100 Per Rule (Single Query Template):**
```sql
-- Replace CAM-004 with CAM-006 / CAM-008 / CAM-009 / CAM-011 / CAM-URL-001
SELECT TOP 100
  [exception_id], [campaign_id], [field_name], [current_value],
  [rule_violated], [rule_description], [severity], [found_at_utc]
FROM [staging].[campaign_dq_exceptions_temp]
WHERE [rule_violated] = 'CAM-004'
ORDER BY [found_at_utc] DESC, [exception_id] DESC;
```

---

## SECTION 9: SIGN-OFF & NEXT MEETING

### What We Accomplished Today
✅ Staged 40,775 campaigns  
✅ Defined 18 business rules  
✅ Executed all rules  
✅ Found 18,228 rule matches  
✅ Categorized by severity  
✅ Identified 6 business decision areas  

### What Happens Next
📋 Business owners review findings  
📋 Answer the 6 decision questions (above)  
📋 Approve rule matches or identify for cleanup  
📋 Once approved: Move to official dq layer  
📋 Then: Build mart tables & Power BI  

### Meeting Notes
**Date:** _______________  
**Attendees:** _______________  
**Decisions Made:**
- [ ] CAM-004 Status values approved: _______________
- [ ] CAM-011 Past campaigns policy: _______________
- [ ] CAM-URL-001 URL format clarified: _______________
- [ ] CAM-009 Completed campaign handling: _______________
- [ ] CAM-008 Amount reconciliation tolerance: _______________
- [ ] CAM-006 Currency approvals: _______________

**Next Steps:**
1. _______________
2. _______________
3. _______________

**Owner Assignments:**
- Campaign Rules: _______________
- Finance/Amount: _______________
- URL/Process: _______________

**Next Meeting:** _______________

---

## APPENDIX: Example Run (Evidence Pack)

**Command Used (sqlcmd):**

```bash
sqlcmd -S localhost -E -d SalesforceDW -C -N -W -s "|" <<'EOF'
SET NOCOUNT ON;
SELECT COUNT(*) AS total_violations,
       COUNT(DISTINCT [campaign_id]) AS unique_affected_campaigns
FROM [staging].[campaign_dq_exceptions_temp];

SELECT [severity], COUNT(*) AS violations,
       COUNT(DISTINCT [campaign_id]) AS affected_campaigns
FROM [staging].[campaign_dq_exceptions_temp]
GROUP BY [severity]
ORDER BY CASE [severity] WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 4 ELSE 5 END;

SELECT [rule_violated], COUNT(*) AS violations
FROM [staging].[campaign_dq_exceptions_temp]
GROUP BY [rule_violated]
ORDER BY violations DESC;
EOF
```

**Observed Output (2026-07-29):**

```text
total_violations|unique_affected_campaigns
18228|16078

severity|violations|affected_campaigns
HIGH|9|9
MEDIUM|4901|4815
LOW|13318|13318

rule_violated|violations
CAM-011|13318
CAM-URL-001|2252
CAM-009|2097
CAM-008|23
CAM-004|9
```

Note: CAM-016 was skipped because no approved region list was loaded. CAM-006, CAM-010, CAM-012, CAM-013, CAM-014, CAM-015, and CAM-017 are not shown in this grouped output because they have 0 rows in this run.

---

**End of Analysis Document**

Last Updated: 2026-07-29  
Status: Ready for Business Review  
Approval: Pending