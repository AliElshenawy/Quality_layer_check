# EDA: Campaign — CSV Data Analysis

## Object Overview

| Attribute | Value |
|-----------|-------|
| **Salesforce API Name** | `Campaign` |
| **SQL Raw Table** | `raw.salesforce_campaign` |
| **CSV File** | `salesforce_campaign_20260727_154510.csv` |
| **Expected Rows** | ~40,753 |
| **File Size** | ~50 MB |
| **Total Columns** | 122 |

**What it represents:** Campaigns track fundraising initiatives, events, marketing efforts, and volunteer activities. They form a parent-child hierarchy and link to Opportunities (donations), Contacts (donors), and Leads.

---

## Column Inventory (122 Columns)

### STG Campaign Coverage (29 Columns) - Full Marker List

Reference target: `staging.campaign_latest` in `campaign_staging_dq_PROD.sql`.

| STG Column | Status | Why in STG |
|------------|--------|------------|
| `row_number` 🟢 | 🟢 Added | Keeps latest-row selector (`ROW_NUMBER`) for dedup traceability. |
| `Id` 🟢 | 🟢 Added | Primary campaign key; required by nearly all DQ checks. |
| `ParentId` 🟢 | 🟢 Added | Needed for CAM-010 parent referential integrity check. |
| `Type` 🟢 | 🟢 Added | Preserved for campaign classification and downstream analysis context. |
| `RecordTypeId` 🟢 | 🟢 Added | Preserved for record-type segmentation and diagnostics. |
| `IsDeleted` 🟢 | 🟢 Added | Needed for deleted-token normalization and CAM-017 raw token checks. |
| `Name` 🟢 | 🟢 Added | Needed for CAM-003 mandatory name check and review readability. |
| `Status` 🟢 | 🟢 Added | Needed for CAM-004 and CAM-009 lifecycle logic checks. |
| `StartDate` 🟢 | 🟢 Added | Needed for CAM-005 date-order check. |
| `EndDate` 🟢 | 🟢 Added | Needed for CAM-005 and CAM-011 historical-active checks. |
| `Year__c` 🟢 | 🟢 Added | Needed for CAM-015 year-range validity check. |
| `Region__c` 🟢 | 🟢 Added | Needed for CAM-016 governed region-list check. |
| `CurrencyIsoCode` 🟢 | 🟢 Added | Needed for CAM-006 controlled currency check. |
| `BudgetedCost` 🟢 | 🟢 Added | Needed for CAM-007 and CAM-012 reasonableness checks. |
| `ActualCost` 🟢 | 🟢 Added | Needed for CAM-012 reasonableness checks. |
| `IsActive` 🟢 | 🟢 Added | Needed for CAM-009 and CAM-011 active-state checks. |
| `NumberOfOpportunities` 🟢 | 🟢 Added | Needed for CAM-013 hierarchy consistency check. |
| `HierarchyNumberOfOpportunities` 🟢 | 🟢 Added | Needed for CAM-013 hierarchy consistency check. |
| `AmountAllOpportunities` 🟢 | 🟢 Added | Needed for CAM-008 reconciliation check. |
| `AmountWonOpportunities` 🟢 | 🟢 Added | Needed for CAM-008 reconciliation check. |
| `Casesafe_Campaign_ID__c` 🟢 | 🟢 Added | Needed for CAM-014 id-consistency check. |
| `Fundraising_page_url__c` 🟢 | 🟢 Added | Needed for CAM-URL-001 URL pattern validation. |
| `SystemModstamp` 🟢 | 🟢 Added | Needed for dedup ordering and run auditing. |
| `_etl_source` 🟢 | 🟢 Added | Lineage field for source-system traceability. |
| `_etl_source_object` 🟢 | 🟢 Added | Lineage field for object-level provenance. |
| `_etl_loaded_at_utc` 🟢 | 🟢 Added | ETL load timestamp for reproducibility and auditing. |
| `staging_is_duplicate` 🟢 | 🟢 Added | Duplicate-pressure indicator after raw dedup. |
| `staging_duplicate_count` 🟢 | 🟢 Added | Number of raw duplicates collapsed into latest row. |
| `staging_created_at` 🟢 | 🟢 Added | Staging materialization timestamp for run traceability. |

Summary: all 29 columns in `staging.campaign_latest` are explicitly marked above.

### System / Audit Fields (10)

| Column | Purpose |
|--------|---------|
| `Id` 🟢 | Primary key — 18-char Salesforce ID |
| `IsDeleted` 🟢 | Soft-delete flag (true/false as text) |
| `OwnerId` | User who owns the campaign |
| `RecordTypeId` 🟢 | Record type assignment |
| `CreatedDate` | Record creation timestamp |
| `CreatedById` | User who created |
| `LastModifiedDate` | Last edit timestamp |
| `LastModifiedById` | User who last edited |
| `SystemModstamp` 🟢 | System-level last-modified (watermark) |
| `CampaignMemberRecordTypeId` | Record type for campaign members |

### Hierarchy / Relationship Fields (4)

| Column | Purpose |
|--------|---------|
| `ParentId` 🟢 | Self-referencing FK to parent campaign |
| `Parent_Campaign_CasesafeID__c` | 18-char safe ID of parent |
| `Grandparent_Campaign_Casesafe_Id__c` | Grandparent hierarchy link |
| `Item__c` | Link to Item/GAU object |

### Status / Classification Fields (7)

| Column | Purpose |
|--------|---------|
| `Name` 🟢 | Campaign name |
| `Type` 🟢 | Campaign type picklist |
| `Status` 🟢 | Campaign status (Planned, In Progress, Completed, Aborted) |
| `IsActive` 🟢 | Whether campaign is active (true/false) |
| `Source__c` | Acquisition source |
| `Department__c` | Responsible department |
| `Income_Stream__c` | Income classification |

### Date Fields (8)

| Column | Purpose |
|--------|---------|
| `StartDate` 🟢 | Campaign start date |
| `EndDate` 🟢 | Campaign end date |
| `LastActivityDate` | Most recent activity |
| `LastViewedDate` | Last viewed by a user |
| `LastReferencedDate` | Last referenced |
| `Created_Date_Time__c` | Custom creation datetime |
| `Arrival_Time__c` | Event arrival time |
| `Email_Acknowledgement_Date__c` | When email ack sent |

### Financial / Amount Fields (18)

| Column | Purpose |
|--------|---------|
| `ExpectedRevenue` | Expected income |
| `BudgetedCost` 🟢 | Planned budget |
| `ActualCost` 🟢 | Actual spend |
| `AmountAllOpportunities` 🟢 | Total linked opportunity amount |
| `AmountWonOpportunities` 🟢 | Won opportunity amount |
| `HierarchyAmountAllOpportunities` | Hierarchy rollup — all opp amounts |
| `HierarchyAmountWonOpportunities` | Hierarchy rollup — won amounts |
| `HierarchyExpectedRevenue` | Hierarchy expected revenue |
| `HierarchyBudgetedCost` | Hierarchy budgeted cost |
| `HierarchyActualCost` | Hierarchy actual cost |
| `Money_Saved__c` | Funds saved |
| `Achieved_Target__c` | Achieved fundraising target |
| `Pledged_Amount__c` | Total pledged |
| `Remaining_Pledge_Amount__c` | Pledges yet to collect |
| `Remaining_Target__c` | Remaining to reach target |
| `Available_Amount__c` | Funds available |
| `Total_Funds_Allocated__c` | Funds allocated |
| `Donation_Value__c` | Total donation value |

### Financial / Amount Fields (18) - STG Coverage and Rationale

Scope: campaign-only, read-only profiling against `raw.salesforce_campaign` (no truncate/rebuild).

| Column | In STG `staging.campaign_latest` | Why Added / Why Not Added Yet |
|--------|----------------------------------|-------------------------------|
| `ExpectedRevenue` | Not added | Not needed by current active campaign DQ set after RAW-duplicate rule removal. |
| `BudgetedCost` 🟢 | 🟢 Added | Needed for CAM-007 (non-negative budget) and CAM-012 (reasonableness vs actual cost). |
| `ActualCost` 🟢 | 🟢 Added | Needed for CAM-012 and financial reasonableness checks. |
| `AmountAllOpportunities` 🟢 | 🟢 Added | Needed for CAM-008 reconciliation with won amount. |
| `AmountWonOpportunities` 🟢 | 🟢 Added | Needed for CAM-008 reconciliation rule. |
| `HierarchyAmountAllOpportunities` | Not added | Hierarchy rollup comparison is diagnostic/monitoring; not required for current DQ decisions. |
| `HierarchyAmountWonOpportunities` | Not added | Same reason as hierarchy all-opportunities; not part of active exception rules. |
| `HierarchyExpectedRevenue` | Not added | Near-duplicate signal with `ExpectedRevenue`; currently profiling-only. |
| `HierarchyBudgetedCost` | Not added | Near-duplicate signal with `BudgetedCost` 🟢; low additional DQ value at this stage. |
| `HierarchyActualCost` | Not added | Near-duplicate signal with `ActualCost` 🟢; low additional DQ value at this stage. |
| `Money_Saved__c` | Not added | Business-derived metric; rule definition not yet approved by stakeholders. |
| `Achieved_Target__c` | Not added | KPI/output metric rather than a foundational DQ control input. |
| `Pledged_Amount__c` | Not added | Candidate cross-field rule exists but weak consistency signal in current data. |
| `Remaining_Pledge_Amount__c` | Not added | Depends on pledge lifecycle logic and allocation semantics not yet governed. |
| `Remaining_Target__c` | Not added | Can be negative by design for over-achievement; requires business policy before DQ enforcement. |
| `Available_Amount__c` | Not added | Semantics overlap with other amount fields but not consistently equivalent in current data. |
| `Total_Funds_Allocated__c` | Not added | Requires allocation-process policy to define valid reconciliation thresholds. |
| `Donation_Value__c` | Not added | Useful for analytics; not yet mapped to a mandatory campaign DQ rule. |

### Standalone Financial Equivalence Check (No Truncate / No Rebuild)

Use this query by itself to test whether selected amount columns are effectively the same signal.

```sql
SET NOCOUNT ON;

WITH base AS (
    SELECT *
    FROM [raw].[salesforce_campaign]
    WHERE COALESCE(LOWER(LTRIM(RTRIM(CONVERT(NVARCHAR(20), [IsDeleted])))), 'false') NOT IN ('true','1','yes','y')
),
vals AS (
    SELECT
        TRY_CONVERT(DECIMAL(19,4), NULLIF(LTRIM(RTRIM([ExpectedRevenue])), '')) AS ExpectedRevenue,
        TRY_CONVERT(DECIMAL(19,4), NULLIF(LTRIM(RTRIM([BudgetedCost])), '')) AS BudgetedCost,
        TRY_CONVERT(DECIMAL(19,4), NULLIF(LTRIM(RTRIM([ActualCost])), '')) AS ActualCost,
        TRY_CONVERT(DECIMAL(19,4), NULLIF(LTRIM(RTRIM([AmountAllOpportunities])), '')) AS AmountAllOpportunities,
        TRY_CONVERT(DECIMAL(19,4), NULLIF(LTRIM(RTRIM([AmountWonOpportunities])), '')) AS AmountWonOpportunities,
        TRY_CONVERT(DECIMAL(19,4), NULLIF(LTRIM(RTRIM([HierarchyExpectedRevenue])), '')) AS HierarchyExpectedRevenue,
        TRY_CONVERT(DECIMAL(19,4), NULLIF(LTRIM(RTRIM([HierarchyBudgetedCost])), '')) AS HierarchyBudgetedCost,
        TRY_CONVERT(DECIMAL(19,4), NULLIF(LTRIM(RTRIM([HierarchyActualCost])), '')) AS HierarchyActualCost,
        TRY_CONVERT(DECIMAL(19,4), NULLIF(LTRIM(RTRIM([HierarchyAmountAllOpportunities])), '')) AS HierarchyAmountAllOpportunities,
        TRY_CONVERT(DECIMAL(19,4), NULLIF(LTRIM(RTRIM([HierarchyAmountWonOpportunities])), '')) AS HierarchyAmountWonOpportunities,
        TRY_CONVERT(DECIMAL(19,4), NULLIF(LTRIM(RTRIM([Pledged_Amount__c])), '')) AS Pledged_Amount__c,
        TRY_CONVERT(DECIMAL(19,4), NULLIF(LTRIM(RTRIM([Remaining_Pledge_Amount__c])), '')) AS Remaining_Pledge_Amount__c,
        TRY_CONVERT(DECIMAL(19,4), NULLIF(LTRIM(RTRIM([Available_Amount__c])), '')) AS Available_Amount__c,
        TRY_CONVERT(DECIMAL(19,4), NULLIF(LTRIM(RTRIM([Total_Funds_Allocated__c])), '')) AS Total_Funds_Allocated__c,
        TRY_CONVERT(DECIMAL(19,4), NULLIF(LTRIM(RTRIM([Donation_Value__c])), '')) AS Donation_Value__c
    FROM base
),
pairs AS (
    SELECT 'ExpectedRevenue = HierarchyExpectedRevenue' AS rule_name,
                 COUNT(*) AS comparable_rows,
                 SUM(CASE WHEN ExpectedRevenue = HierarchyExpectedRevenue THEN 1 ELSE 0 END) AS equal_rows
    FROM vals WHERE ExpectedRevenue IS NOT NULL AND HierarchyExpectedRevenue IS NOT NULL
    UNION ALL
    SELECT 'BudgetedCost = HierarchyBudgetedCost', COUNT(*), SUM(CASE WHEN BudgetedCost = HierarchyBudgetedCost THEN 1 ELSE 0 END)
    FROM vals WHERE BudgetedCost IS NOT NULL AND HierarchyBudgetedCost IS NOT NULL
    UNION ALL
    SELECT 'ActualCost = HierarchyActualCost', COUNT(*), SUM(CASE WHEN ActualCost = HierarchyActualCost THEN 1 ELSE 0 END)
    FROM vals WHERE ActualCost IS NOT NULL AND HierarchyActualCost IS NOT NULL
    UNION ALL
    SELECT 'AmountAllOpportunities = HierarchyAmountAllOpportunities', COUNT(*), SUM(CASE WHEN AmountAllOpportunities = HierarchyAmountAllOpportunities THEN 1 ELSE 0 END)
    FROM vals WHERE AmountAllOpportunities IS NOT NULL AND HierarchyAmountAllOpportunities IS NOT NULL
    UNION ALL
    SELECT 'AmountWonOpportunities = HierarchyAmountWonOpportunities', COUNT(*), SUM(CASE WHEN AmountWonOpportunities = HierarchyAmountWonOpportunities THEN 1 ELSE 0 END)
    FROM vals WHERE AmountWonOpportunities IS NOT NULL AND HierarchyAmountWonOpportunities IS NOT NULL
    UNION ALL
    SELECT 'Available_Amount__c = Donation_Value__c', COUNT(*), SUM(CASE WHEN Available_Amount__c = Donation_Value__c THEN 1 ELSE 0 END)
    FROM vals WHERE Available_Amount__c IS NOT NULL AND Donation_Value__c IS NOT NULL
    UNION ALL
    SELECT 'Pledged_Amount__c = Remaining_Pledge_Amount__c + Total_Funds_Allocated__c', COUNT(*),
                 SUM(CASE WHEN ABS(Pledged_Amount__c - (Remaining_Pledge_Amount__c + Total_Funds_Allocated__c)) < 0.0001 THEN 1 ELSE 0 END)
    FROM vals
    WHERE Pledged_Amount__c IS NOT NULL AND Remaining_Pledge_Amount__c IS NOT NULL AND Total_Funds_Allocated__c IS NOT NULL
)
SELECT
    rule_name,
    comparable_rows,
    equal_rows,
    CAST(CASE WHEN comparable_rows = 0 THEN 0 ELSE (100.0 * equal_rows / comparable_rows) END AS DECIMAL(6,2)) AS equal_pct
FROM pairs
ORDER BY rule_name;
```

### Financial Equivalence Results (Current Snapshot)

| Candidate Rule | comparable_rows | equal_rows | equal_pct | Same Signal? |
|---|---:|---:|---:|---|
| `ExpectedRevenue = HierarchyExpectedRevenue` | 10,679 | 10,464 | 97.99% | Near-same, not strict same |
| `BudgetedCost = HierarchyBudgetedCost` | 1 | 1 | 100.00% | Insufficient sample |
| `ActualCost = HierarchyActualCost` | 1 | 1 | 100.00% | Insufficient sample |
| `AmountAllOpportunities = HierarchyAmountAllOpportunities` | 41,293 | 39,357 | 95.31% | Near-same, not strict same |
| `AmountWonOpportunities = HierarchyAmountWonOpportunities` | 41,296 | 39,365 | 95.32% | Near-same, not strict same |
| `Available_Amount__c = Donation_Value__c` | 41,283 | 16,447 | 39.84% | Not same |
| `Pledged_Amount__c = Remaining_Pledge_Amount__c + Total_Funds_Allocated__c` | 2,148 | 233 | 10.85% | Not same |

Conclusion for this phase:
- Keep current STG financial set focused on columns required by active DQ rules.
- Treat hierarchy and pledge/allocation amount pairs as monitoring candidates, not hard equality rules.

### Metrics / Count Fields (18)

| Column | Purpose |
|--------|---------|
| `NumberSent` | Outreach/messages sent |
| `ExpectedResponse` | Expected response rate |
| `NumberOfLeads` | Leads generated |
| `NumberOfConvertedLeads` | Leads converted |
| `NumberOfContacts` | Contacts associated |
| `NumberOfResponses` | Responses received |
| `NumberOfOpportunities` 🟢 | Linked opportunities |
| `NumberOfWonOpportunities` | Won opportunities |
| `HierarchyNumberOfLeads` | Hierarchy — leads |
| `HierarchyNumberOfConvertedLeads` | Hierarchy — converted |
| `HierarchyNumberOfContacts` | Hierarchy — contacts |
| `HierarchyNumberOfResponses` | Hierarchy — responses |
| `HierarchyNumberOfOpportunities` 🟢 | Hierarchy — opportunities |
| `HierarchyNumberOfWonOpportunities` | Hierarchy — won |
| `HierarchyNumberSent` | Hierarchy — sent |
| `Number_of_attendees__c` | Attendees at event |
| `Response_Percentage__c` | Response rate % |
| `Campaign_Count__c` | Child campaign count |

### Geographic / Location Fields (8)

| Column | Purpose |
|--------|---------|
| `Region__c` 🟢 | Geographic region |
| `Sub_Region__c` | Sub-region |
| `Country__c` | Country |
| `City__c` | City |
| `City_Code__c` | City code |
| `Regional_Office_Code__c` | Office code |
| `Campaign_Location__c` | Event/campaign location |
| `Year__c` 🟢 | Campaign year |

### Volunteer Fields (GW_Volunteers Package) (6)

| Column | Purpose |
|--------|---------|
| `GW_Volunteers__Volunteer_Website_Time_Zone__c` | Volunteer timezone |
| `GW_Volunteers__Number_of_Volunteers__c` | Volunteer count |
| `GW_Volunteers__Volunteer_Completed_Hours__c` | Hours completed |
| `GW_Volunteers__Volunteer_Jobs__c` | Jobs created |
| `GW_Volunteers__Volunteer_Shifts__c` | Shifts assigned |
| `GW_Volunteers__Volunteers_Still_Needed__c` | Remaining volunteer need |

### Fundraising / Custom Fields (20+)

| Column | Purpose |
|--------|---------|
| `Campaign_Title__c` | Display title |
| `Unique_Name__c` | Unique business name |
| `Code__c` | Campaign code |
| `Long_Name_Field__c` | Long descriptive name |
| `DMS_Campaign_ID__c` | Legacy DMS system ID |
| `Casesafe_Campaign_ID__c` 🟢 | 18-char safe ID |
| `FR_Unique_Number__c` | Fundraising unique number |
| `Fundraiser_Code__c` | Fundraiser code |
| `Fundraiser__c` | Linked fundraiser |
| `Fundraising_page_url__c` 🟢 | Online fundraising page |
| `Fundraising_Objective_Purpose__c` | Fundraising purpose |
| `Fundraising_Team_Code__c` | Team code |
| `FundraisingCode__c` | Alt fundraising code |
| `Event_Type_Code__c` | Event type classification |
| `Event_Acronym__c` | Event short name |
| `Event_Location_Code__c` | Event location code |
| `Max_Call_Retry__c` | Dialer max retries |
| `Retry_Intervals__c` | Dialer retry intervals |
| `Dialer_Queue__c` | Dialer queue assignment |
| `Email_Notification__c` | Email notification flag |
| `Donor__c` | Linked donor contact |
| `Fundraiser_Person__c` | Fundraiser contact |

### Other Fields

| Column | Purpose |
|--------|---------|
| `CurrencyIsoCode` 🟢 | Transaction currency (expected: GBP) |
| `Description` | Free-text description |
| `CampaignImageId` | Image asset reference |
| `Notes__c` | Additional notes |
| `Description_detail__c` | Extended description |
| `Stipulation__c` | Fund restriction/stipulation |
| `Upload_Transaction_ID__c` | Batch upload ID |
| `External_Id__c` | External system ID |
| `Call_List_Clearing_In_Progress__c` | Process flag |
| `Priority__c` | Priority level |
| `Reviewed__c` | Review status |
| `Page_Type__c` | Fundraising page type |
| `Patient__c` | Patient link (medical campaigns?) |
| `Speaker_Artist__c` | Event speaker/artist |

---

## Key Observations from Sample Data

### Row 1 Sample: "Winter 2021"

| Observation | Detail |
|-------------|--------|
| ID format | `7014J000000UL4hQAG` — valid 18-char SF ID |
| ParentId | `7014J000000UL6OQAW` — has parent campaign |
| Status | Empty string (not set) |
| CurrencyIsoCode | `GBP` |
| IsActive | `true` |
| IsDeleted | `false` |
| CreatedDate format | `2020-11-05T14:25:39.000Z` (ISO 8601) |
| Amount pattern | `1877.0` — decimal with .0 suffix even for whole numbers |
| Hierarchy totals present | `1307804.33` — shows rollup working |
| Source__c | `Post – direct mail, door drops` |
| Department__c | `Comms` |
| Region__c | Empty |
| Year__c | `2021` |
| Country__c | `UK` |
| Remaining_Target__c | `-1188080.23` — **negative** (over-achieved?) |

### Row 2 Sample: "Child Welfare"

| Observation | Detail |
|-------------|--------|
| ParentId | Empty (root campaign) |
| Type | `Always on` |
| Status | `Planned` |
| All metrics | `0` — no linked activity |
| Source__c | Empty |
| Remaining_Target__c | `0.0` |

---

## Relationship Map

```
Campaign (self-referencing hierarchy via ParentId)
    │
    ├── Opportunity (Campaign field on Opportunity)
    │       └── Payment (via Opportunity)
    │
    ├── Campaign Member (Contact + Campaign junction)
    │
    ├── Recurring Donation (npe03__Recurring_Donation_Campaign__c)
    │
    ├── Item/GAU (Campaign__c field on Item)
    │
    └── Sponsorship (Campaign_Source__c)
```

---

## Initial Risk Areas

| Risk | Impact | Priority |
|------|--------|----------|
| **Empty Status fields** | Many campaigns have blank Status — can't filter by lifecycle stage | HIGH |
| **Negative financial values** | `Remaining_Target__c = -1188080.23` — may indicate over-achievement or data entry error | MEDIUM |
| **All columns are NVARCHAR(MAX)** | Numeric comparisons require TRY_CAST; performance risk on large queries | HIGH |
| **Soft-deleted records included** | `IsDeleted = false` in sample, but true rows may exist | MEDIUM |
| **ParentId hierarchy integrity** | Orphan parents, circular references, deep hierarchies | HIGH |
| **122 columns, many sparse** | Volunteer fields may be 90%+ NULL for non-volunteer campaigns | LOW |
| **Currency assumption** | All GBP? Or mixed currencies? Amount comparisons need currency awareness | MEDIUM |
| **Duplicate campaign names** | `Unique_Name__c` exists but may not be enforced | MEDIUM |
| **Year__c as text** | May have inconsistent values (2021, "2021", "FY2021") | LOW |

---

## Initial DQ Rule Candidates

| # | Rule | Type | Severity |
|---|------|------|----------|
| 1 | Every Campaign must have a non-NULL `Id` 🟢 | Completeness | CRITICAL |
| 2 | `Id` 🟢 must be unique across all rows | Uniqueness | CRITICAL |
| 3 | `IsDeleted` 🟢 must be 'true' or 'false' only | Validity | HIGH |
| 4 | If `ParentId` 🟢 is not NULL, it must exist as an `Id` 🟢 in the same table | Referential | HIGH |
| 5 | `CurrencyIsoCode` 🟢 must be a valid ISO 4217 code | Validity | MEDIUM |
| 6 | `StartDate` 🟢 should not be after `EndDate` 🟢 | Consistency | HIGH |
| 7 | `BudgetedCost` 🟢 should not be negative | Validity | MEDIUM |
| 8 | `ActualCost` 🟢 should not exceed `BudgetedCost` 🟢 by >200% | Reasonableness | LOW |
| 9 | Active campaigns (`IsActive = true`) should have a non-empty `Status` 🟢 | Completeness | MEDIUM |
| 10 | `NumberOfOpportunities` 🟢 should not exceed `HierarchyNumberOfOpportunities` 🟢 | Consistency | MEDIUM |
| 11 | `Casesafe_Campaign_ID__c` 🟢 should equal `Id` 🟢 | Consistency | LOW |
| 12 | `Year__c` 🟢 should be a valid 4-digit year between 2000 and current year+1 | Validity | LOW |
| 13 | `Region__c` 🟢 should be from an approved list of regions | Validity | MEDIUM |
| 14 | `AmountWonOpportunities` 🟢 should not exceed `AmountAllOpportunities` 🟢 | Consistency | MEDIUM |

---

## Candidate Coverage vs Current PROD Script

Reference implementation checked: [campaign_staging_dq_PROD.sql](campaign_staging_dq_PROD.sql)

| Candidate # | Candidate Rule | Current Status | Implemented As | Notes |
|---|---|---|---|---|
| 1 | Campaign must have non-NULL Id | Done | CAM-001 | Enforced in staging DQ exceptions |
| 2 | Id must be unique across all rows | Done | Staging dedup metadata | Handled by `ROW_NUMBER` latest-row logic plus `staging_is_duplicate` 🟢 / `staging_duplicate_count` 🟢 |
| 3 | IsDeleted must be true/false | Done | CAM-017 | Explicit IsDeleted token validity check added in raw layer |
| 4 | ParentId must exist in same table | Done | CAM-010 | ParentId added to staging and referential check implemented |
| 5 | CurrencyIsoCode valid ISO code | Report-only | CAM-006 | No assumed list; distinct currency values reported for stakeholders |
| 6 | StartDate <= EndDate | Done | CAM-005 | Implemented with TRY_CONVERT date logic |
| 7 | BudgetedCost >= 0 | Done | CAM-007 | Implemented |
| 8 | ActualCost <= 200% of BudgetedCost | Done | CAM-012 | Implemented as reasonableness check when BudgetedCost > 0 |
| 9 | Active campaigns must have non-empty Status | Report-only | CAM-004 | No assumed list; distinct Status values reported for stakeholders |
| 10 | NumberOfOpportunities <= HierarchyNumberOfOpportunities | Done | CAM-013 | Implemented with numeric TRY_CONVERT comparison |
| 11 | Casesafe_Campaign_ID__c == Id | Done | CAM-014 | Implemented when both values are populated |
| 12 | Year__c in valid range | Done | CAM-015 | Implemented as 4-digit year between 2000 and current year + 1 |
| 13 | Region__c in approved list | Partial | CAM-016 | Rule and governance table exist; execution is gated until approved region list is loaded |
| 14 | AmountWonOpportunities <= AmountAllOpportunities | Done | CAM-008 | Implemented |

Summary:
- Done: 13 of 14
- Partial: 2 of 14
- Missing: 0 of 14

---

## Recommended Next Checks (High Value)

1. Load approved Region values into [staging].[campaign_region_allowed_values] to activate CAM-016 evaluation.
2. CAM-004 (Status) and CAM-006 (Currency) are **report-only** — no assumed value list; their distinct values are reported for stakeholders to confirm.

Operational note:
- CAM-016 is implemented in PROD and reads from [staging].[campaign_region_allowed_values].
- If no approved values exist in that table, CAM-016 is intentionally skipped to avoid assumptions.

---

## Recommended Extra Staging Columns

Columns already added to [staging].[campaign_latest] in PROD to enable the new checks:

1. ParentId
2. Casesafe_Campaign_ID__c
3. NumberOfOpportunities
4. HierarchyNumberOfOpportunities
5. Year__c
6. Region__c
7. Type
8. RecordTypeId
9. _etl_loaded_at_utc
10. _etl_source
11. _etl_source_object

Why these first:
- They unlocked 5 previously-missing candidate rules.
- They improve lineage and reproducibility for debugging.
- They avoid over-expanding staging while still supporting business-critical controls.

---

## Notes for Next Step (SQL QA)

- All 122 columns are `NVARCHAR(MAX)` in raw — every numeric/date check needs `TRY_CAST`
- Focus financial reconciliation on: Budget vs Actual vs Won amounts
- Check hierarchy integrity: `ParentId` 🟢 → `Id` 🟢 self-join
- Investigate the empty `Status` 🟢 pattern — how many records?
- Check `CurrencyIsoCode` 🟢 distribution — is it all GBP?
- Profile `Type` 🟢 picklist — what campaign types exist?
