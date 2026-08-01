<!-- AI created but i reviewed it -->


# EDA: Sponsorship — CSV Data Analysis

## Object Overview

| Attribute | Value |
|-----------|-------|
| **Salesforce API Name** | `Sponsorship__c` |
| **Package** | Custom object (Human Appeal specific) |
| **SQL Raw Table** | `raw.salesforce_sponsorship` |
| **CSV File** | Loaded directly via Python ETL (no standalone CSV on disk) |
| **Expected Rows** | ~226,975 |
| **File Size** | ~2.2 GB (when exported) |
| **Total Columns** | 94 (+ 3 ETL metadata) |

**What it represents:** Sponsorships link a donor (Contact) to an orphan beneficiary. They track the ongoing relationship including sponsorship status, annual reports, financial commitments via Recurring Donations, and communication between donor and orphan. This is a core business object for the charity.

## Sampling Note

The table (~227K rows) is above the 200,000-row large-table threshold, so exploratory profiling may use a
200K sample. However, the **DQ framework ran full-population** (all 227,244 staged rows) — the null counts
and rule results in this folder are complete, not sampled.

---

## Column Inventory (94 Columns)

### System / Audit Fields (12)

| Column | Purpose |
|--------|---------|
| `Id` | Primary key — 18-char Salesforce ID |
| `IsDeleted` | Soft-delete flag |
| `Name` | Auto-number or custom sponsorship name |
| `CurrencyIsoCode` | Currency code |
| `CreatedDate` | Record creation |
| `CreatedById` | Creator |
| `LastModifiedDate` | Last modification |
| `LastModifiedById` | Editor |
| `SystemModstamp` | System watermark |
| `LastActivityDate` | Last activity |
| `LastViewedDate` | Last viewed |
| `LastReferencedDate` | Last referenced |

### Donor / Contact Fields (11)

| Column | Purpose |
|--------|---------|
| `Donor__c` | FK to Contact — the sponsoring donor |
| `Donor_Organization__c` | If org is the sponsor |
| `Donor_ID__c` | Donor's Salesforce ID reference |
| `Donor_Record_Id__c` | Alternative donor ID |
| `Donor_FirstName__c` | Donor first name (denormalized) |
| `Donor_LastName__c` | Donor last name (denormalized) |
| `Donor_Regional_Office_Code__c` | Donor's regional office |
| `Donor_Care_team_Email__c` | Care team email for donor |
| `Donor_Receipt_via_Email__c` | Email receipt preference |
| `Donor_Receipt_via_Post__c` | Postal receipt preference |
| `Donor_Language__c` | Donor language preference |
| `Donor_Match__c` | Donor matching flag |

### Orphan / Beneficiary Fields (15)

| Column | Purpose |
|--------|---------|
| `Orphan__c` | FK to orphan/beneficiary record |
| `OrphanAccountID__c` | Orphan account reference |
| `Orphan_Account_Name__c` | Orphan account name |
| `Orphan_First_Name__c` | Orphan first name |
| `Orphan_Last_Name__c` | Orphan last name |
| `Orphan_Full_Name__c` | Full name (formula) |
| `Orphan_Gender__c` | Gender |
| `Orphan_Age__c` | Age |
| `Orphan_Country__c` | Country where orphan resides |
| `Orphan_Id__c` | Orphan reference ID |
| `Orphan_Field_Office_Reference__c` | Field office ref |
| `Orphan_First_Sponsorship_Date__c` | When orphan was first sponsored |
| `Orphan_Visit_Status__c` | Visit program status |
| `Orphan_Visit_ID__c` | Visit tracking |
| `Orphan_Visit_Due_Date__c` | Next visit due |
| `Field_Office_Orphan__c` | Field office orphan flag |

### Status & Lifecycle Fields (5)

| Column | Purpose |
|--------|---------|
| `Status__c` | Sponsorship status (Active, Terminated, etc.) |
| `IsActive__c` | Boolean active flag |
| `Start_Date_Time__c` | Sponsorship start date |
| `End_Date_Time__c` | Sponsorship end date |
| `Renewal_Due_Date__c` | When renewal is due |
| `Sponsorship_Deactivation_Reason__c` | Why deactivated |

### Financial / Donation Fields (4)

| Column | Purpose |
|--------|---------|
| `Recurring_Donation__c` | FK to Recurring Donation |
| `Recurring_Donation_Status__c` | Denormalized RD status |
| `Donation__c` | Related donation/opportunity |
| `Recurring_Donation_Campaign__c` | Campaign linked via RD |
| `Campaign_Source__c` | Source campaign |

### Termination Fields (4)

| Column | Purpose |
|--------|---------|
| `Terminated_Orphan_Gender__c` | Gender at termination |
| `Terminated_Orphan_Name__c` | Name at termination |
| `Terminated_Orphan_Reason__c` | Reason for termination |
| `Terminated_Orphan_Sponsoree_id__c` | Sponsoree ID at termination |
| `Terminated_Orphan_Termination_date__c` | Date of termination |

### Annual Report Fields (12)

| Column | Purpose |
|--------|---------|
| `Annual_Report_Sent__c` | Whether report was sent |
| `Annual_Report_Status__c` | Report status |
| `Annual_Report_Public_Link__c` | Public link to report |
| `Annual_Report_File_Name__c` | File name |
| `Send_File_to_SharePoint_UK__c` | UK SharePoint flag |
| `Send_File_to_SharePoint_US__c` | US SharePoint flag |
| `Send_File_to_SharePoint_IE__c` | Ireland SharePoint flag |
| `Send_File_to_SharePoint_FR__c` | France SharePoint flag |
| `Send_File_to_SharePoint_ES__c` | Spain SharePoint flag |
| `Send_File_to_SharePoint_AR__c` | Arabic SharePoint flag |
| `Send_File_to_SharePoint_CA__c` | Canada SharePoint flag |
| `UK_Send_Annual_Report_to_Salesforce_File__c` | UK file save |
| `CA_Send_Annual_Report_to_Salesforce_File__c` | Canada file save |
| `US_Send_Annual_Report_to_Salesforce_File__c` | US file save |
| `FR_Send_Annual_Report_to_Salesforce_File__c` | France file save |
| `ES_Send_Annual_Report_to_Salesforce_File__c` | Spain file save |
| `AR_Save_Annual_Report_to_Salesforce_File__c` | Arabic file save |

### Other Fields

| Column | Purpose |
|--------|---------|
| `DMS_Sponsorship_ID__c` | Legacy DMS system ID |
| `DMS_ID__c` | Another legacy ID |
| `Acknowledgment_Status__c` | Acknowledgment tracking |
| `CaseSafeOrphanId__c` | 18-char safe orphan ID |
| `Country_Logo__c` | Country logo reference |
| `Orphan_Detail_Email__c` | Email template flag |
| `Current_Year__c` | Current year reference |
| `Orphan_Postal_Conga__c` | Postal merge flag |
| `Regional_Office_Code_Donor__c` | Donor regional code |
| `Sponsorship_Id_18__c` | 18-char self-reference |
| `Instruction__c` | Fund instruction |
| `Notes_on_Donor_Preferences__c` | Donor preference notes |
| `Review_Required__c` | Review flag |
| `Sponsorship_Duration_Months__c` | Duration in months |
| `Sponsorship_duration_in_years__c` | Duration in years |
| `Postal_Donor_Letter_Conga__c` | Conga merge flag |
| `Postal_Sponsorship_Price_Increase_Letter__c` | Price increase letter |
| `DateToday__c` | Formula: today's date |
| `DateUS__c` | US date format |
| `Test_Conga_Batch_Formula__c` | Test field |
| `UK_Send_Postal_Report_to_Files__c` | Postal report flag |
| `UK_Send_Postal_Reports_COver_Letter__c` | Cover letter flag |
| `Save_Gaza_Orphan_Report_to_Files__c` | Gaza report flag |
| `AR_Save_Gaza_Orphan_Report_to_FIles__c` | Arabic Gaza report |
| `Forgotten_Women_Orphan_Reports__c` | Special report flag |

---

## Ordered Null and Data Presence Review

### Top Null Columns (staging, 227,244 rows)
| Rank | Column | Null/blank | Null % | Why we care |
|---|---|---:|---:|---|
| 1 | `Sponsorship_Deactivation_Reason__c` | 190,668 | 83.9% | Required for terminated/inactive (SP-008). 55,498 are real fails; the rest are active records (expected empty). |
| 2 | `Recurring_Donation__c` | 113,414 | 49.9% | Funding link. 2,510 **active** sponsorships lack it (SP-006). |
| 3 | `Donor__c` | 68,495 | 30.1% | Donor link. 399 **active** sponsorships lack it (SP-003) — the concerning subset. |
| 4 | `End_Date_Time__c` | 48,608 | 21.4% | Ongoing/open sponsorships (expected empty); feeds SP-007 date logic. |
| 5 | `Orphan_Country__c` | 35 | 0.02% | Geography — near-complete. |
| 6 | `Status__c` | 3 | 0.001% | Lifecycle — essentially complete. |
| 7 | `Orphan__c` | 0 | 0.00% | Beneficiary link — fully populated (SP-004 clean). |

`concerning empty`: active-record `Donor__c` and `Recurring_Donation__c`.
`expected empty`: `Sponsorship_Deactivation_Reason__c` on active records, `End_Date_Time__c` on ongoing sponsorships.
Active records: **49,830** of 227,244.

## STG Sponsorship Coverage (16 business columns staged)

| STG column(s) | Why staged |
|---|---|
| `Id`, `SystemModstamp`, `row_number` | PK + latest-row dedup |
| `IsDeleted` | soft-delete filter |
| `Status__c`, `IsActive__c` | lifecycle + consistency (SP-005); gate active-record rules |
| `Donor__c` | SP-003 (active needs donor); SP-009 referential (deferred) |
| `Orphan__c` | SP-004 (active needs orphan) |
| `Recurring_Donation__c`, `Recurring_Donation_Status__c` | SP-006 link; SP-010 referential (deferred) |
| `Start_Date_Time__c`, `End_Date_Time__c` | SP-007 date logic |
| `Sponsorship_Deactivation_Reason__c` | SP-008 (terminated needs reason) |
| `Campaign_Source__c`, `Orphan_Country__c` | future validity/segmentation rules |
| `CurrencyIsoCode`, `Name` | currency context / readability |
| `_etl_*`, `staging_*` | lineage, dedup pressure, audit |

Not staged: the other ~78 raw columns (annual-report SharePoint flags, denormalized donor/orphan names,
legacy DMS IDs) — no rule depends on them yet.

---

## Relationship Map

```
Sponsorship__c
    │
    ├── Donor (Donor__c) ──────────────── Contact
    │
    ├── Orphan (Orphan__c) ─────────────── Custom Orphan Object / Account
    │
    ├── Recurring Donation (Recurring_Donation__c) ── npe03__Recurring_Donation__c
    │       └── Opportunity (installments)
    │               └── Payment
    │
    ├── Campaign (Campaign_Source__c) ──── Campaign
    │
    └── Sponsorship Units (child records) ── Sponsorship_Unit__c
```

---

## Initial Risk Areas

| Risk | Impact | Priority |
|------|--------|----------|
| **Status vs IsActive inconsistency** | Active flag may disagree with Status picklist | HIGH |
| **Orphan contact integrity** | `Orphan__c` may reference deleted or moved records | HIGH |
| **Donor linkage** | `Donor__c` must exist in Contact table | HIGH |
| **Recurring Donation linkage** | Active sponsorships without a valid Active RD | HIGH |
| **Terminated data completeness** | Terminated sponsorships missing reason/date | MEDIUM |
| **Annual report distribution logic** | Multiple country-specific SharePoint flags — which apply? | LOW |
| **Duration calculation** | `Sponsorship_Duration_Months__c` vs actual date difference | MEDIUM |
| **Legacy DMS IDs** | `DMS_Sponsorship_ID__c` — data migration artifacts | LOW |
| **Multi-country operations** | Country-specific fields (UK, US, FR, ES, AR, CA, IE) | MEDIUM |
| **Denormalized donor data** | Donor name/office stored on Sponsorship — may be stale | LOW |

---

## Initial DQ Rule Candidates

| # | Rule | Type | Severity |
|---|------|------|----------|
| 1 | Every Sponsorship must have a non-NULL `Id` | Completeness | CRITICAL |
| 2 | `Id` must be unique | Uniqueness | CRITICAL |
| 3 | Active Sponsorships must have `Donor__c` populated | Completeness | HIGH |
| 4 | Active Sponsorships must have `Orphan__c` populated | Completeness | HIGH |
| 5 | `Status__c` and `IsActive__c` must be consistent | Consistency | HIGH |
| 6 | Active Sponsorships should have `Recurring_Donation__c` populated | Completeness | MEDIUM |
| 7 | `Start_Date_Time__c` should not be after `End_Date_Time__c` | Consistency | HIGH |
| 8 | Terminated Sponsorships must have `Sponsorship_Deactivation_Reason__c` | Completeness | MEDIUM |
| 9 | `Donor__c` must exist in `raw.salesforce_contact` | Referential | HIGH |
| 10 | `Recurring_Donation__c` must exist in `raw.salesforce_recurring_donation` | Referential | HIGH |
| 11 | Active Sponsorships with `Recurring_Donation_Status__c = 'Closed'` are inconsistent | Consistency | HIGH |
| 12 | `Orphan_Country__c` should be from approved list | Validity | MEDIUM |
| 13 | Duration months/years should match date difference | Consistency | LOW |

> **Skipped for now — heavy referential joins (candidates #9 and #10 → rules SP-009 / SP-010).**
> - **SP-009** (`Donor__c` → `raw.salesforce_contact`): **skipped now** because the **Contact table is empty
>   (0 rows)** — it would flag every donor as missing. Re-enable once Contact is loaded.
> - **SP-010** (`Recurring_Donation__c` → `raw.salesforce_recurring_donation`): **skipped now due to being a
>   heavy join** (227K × 261K on unindexed `NVARCHAR(MAX)`, long-running). Run it later in a dedicated
>   batched pass.
>
> Candidates #1–#8 (SP-001..SP-008) ran to completion — results in `03_sponsorship_staging_dq_ANALYSIS.md`.

---

## Notes for Next Step (SQL QA)

- Status distribution is critical — Active vs Terminated vs other
- Cross-reference `Recurring_Donation_Status__c` with actual RD status
- Check orphan data completeness (name, country, gender)
- Profile annual report coverage (how many sent, what %)
- Geographic distribution by Orphan_Country__c
- Duration analysis — average sponsorship length
- Termination reason patterns
- Donor-to-sponsorship cardinality (1:1 or 1:many?)
