
<!-- AI created but i reviewed it -->

# EDA: Sponsorship Unit - CSV Data Analysis

## Object Overview

| Attribute | Value |
|-----------|-------|
| Salesforce API Name | `Sponsorship_Unit__c` |
| Package | Custom object (Human Appeal specific) |
| SQL Raw Table | `raw.salesforce_sponsorship_unit` |
| CSV File | `salesforce_sponsorship_unit_20260727_155432.csv` |
| Raw Rows | 1,291,058 |
| Distinct IDs | 1,291,058 |
| Total Columns | 25 including ETL metadata |
| Null Profile CSV | `null_analysis_salesforce_sponsorship_unit.csv` |

What it represents: Sponsorship Unit is a high-volume child/detail table under Sponsorship. It tracks unit-level allocation/payment periods, GAU allocation links, deferred amounts, local currency context, and orphan/sponsorship references.

## Sampling Note

This table is above the large-table threshold. For exploratory EDA, a 200,000-row sample is enough for now. The null-profile CSV currently records full raw counts from the available raw-layer profile. Final production DQ evidence should be captured from the actual staging/framework run.

---

## Column Inventory

### Identity and System Fields

| Column | Purpose | Stage Candidate |
|--------|---------|-----------------|
| `Id` | Primary Sponsorship Unit key | Yes |
| `IsDeleted` | Soft-delete state | Yes |
| `Name` | Unit display/auto-number value | Yes |
| `CurrencyIsoCode` | Org currency code | Yes |
| `SystemModstamp` | Watermark for latest-row selection | Yes |
| `_etl_loaded_at_utc` | Load timestamp | Yes |
| `_etl_source` | ETL lineage | Yes |
| `_etl_source_object` | Source object lineage | Yes |

### Relationship Fields

| Column | Purpose | Stage Candidate |
|--------|---------|-----------------|
| `Sponsorship__c` | Parent Sponsorship reference | Yes |
| `GAU_Allocation__c` | Allocation reference | Yes |
| `GAU_Name__c` | Denormalized GAU label | Yes |
| `OrphanAccountID__c` | Orphan account reference, currently fully blank | Review only |
| `Orphan_Id__c` | Orphan reference / business id | Yes |
| `Orphan_Account_Name__c` | Denormalized orphan name | Review only |
| `Casesafe_Id__c` | 18-character safe id | Yes |

### Payment and Amount Fields

| Column | Purpose | Stage Candidate |
|--------|---------|-----------------|
| `Payment_Period__c` | Period represented by the unit | Yes |
| `Donation_Date__c` | Donation date for the unit | Yes |
| `Deferred_Amount_in_GBP__c` | Deferred GBP value | Yes |
| `Deferred_Amount_in_LC__c` | Deferred local-currency value | Yes |
| `Local_Currency_Of_Deferred_Funds__c` | Currency for local deferred amount | Yes |

---

## Relationship Map

```text
Sponsorship_Unit__c
    ├── Sponsorship__c        -> parent Sponsorship (Donor, Orphan)
    ├── GAU_Allocation__c     -> GAU / Item fund designation
    └── Orphan refs (OrphanAccountID__c, Orphan_Id__c) -> denormalized orphan
```

Junction/detail table: one Sponsorship has multiple units (~1.3M units over ~227K sponsorships ≈ 5.7 per
sponsorship), typically one per payment period. Expected values: `CurrencyIsoCode` GBP/USD/EUR;
`Local_Currency_Of_Deferred_Funds__c` country currencies (PKR, SYP, JOD, …).

## Key Risks (from raw profile)

| Risk | Impact | Priority |
|------|--------|----------|
| Orphan parent — `Sponsorship__c` missing in parent table | referential break | CRITICAL |
| Deferred GBP vs LC consistency | financial accuracy | HIGH |
| Units for terminated/deleted sponsorships | stale allocations | HIGH |
| `GAU_Allocation__c` points to a deleted allocation | referential | MEDIUM |
| `Local_Currency_Of_Deferred_Funds__c` required when LC amount is set | consistency | MEDIUM |
| Denormalized `GAU_Name__c` / `Orphan_Account_Name__c` staleness | review noise | LOW |

---

## Ordered Null and Data Presence Review

| Priority | Column | Null/Empty | Null % | Distinct Values | Stage? | Why |
|----------|--------|-----------:|-------:|----------------:|--------|-----|
| 1 | `Id` | 0 | .00% | 1,291,058 | Yes | Primary key and dedup key |
| 2 | `Sponsorship__c` | 0 | .00% | 101,491 | Yes | Parent reference, critical DQ input |
| 3 | `GAU_Allocation__c` | 0 | .00% | 1,016,008 | Yes | Allocation referential check |
| 4 | `SystemModstamp` | 0 | .00% | 10,628 | Yes | Latest-row ordering |
| 5 | `Donation_Date__c` | 41,834 | 3.24% | 987 | Yes | Date validity and period review |
| 6 | `Deferred_Amount_in_GBP__c` | 1,202,297 | 93.12% | 496 | Yes | Amount validity when populated |
| 7 | `Deferred_Amount_in_LC__c` | 1,202,300 | 93.13% | 558 | Yes | LC/GBP consistency when populated |
| 8 | `Local_Currency_Of_Deferred_Funds__c` | 1,197,062 | 92.72% | 13 | Yes | Required when LC amount exists |
| 9 | `OrphanAccountID__c` | 1,291,058 | 100.00% | 0 | No | Fully blank in current raw layer |
| 10 | `LastActivityDate` | 1,291,058 | 100.00% | 0 | No | Fully blank activity field |

---

## STG Sponsorship Unit Coverage

Reference build script: `sponsorship_unit_staging_dq_PROD.sql`.

| STG Column | Why in STG |
|------------|------------|
| `row_number` | Dedup rank / latest-row selector |
| `Id` | Primary key for all rules |
| `IsDeleted` | Soft-delete filter and token review |
| `Name` | Human-readable unit label |
| `CurrencyIsoCode` | Currency context |
| `Sponsorship__c` | Parent integrity rule SU-003/SU-004 |
| `GAU_Allocation__c` | Allocation integrity rule SU-008 |
| `GAU_Name__c` | Review context for allocation failures |
| `Payment_Period__c` | Period distribution and future format rules |
| `Donation_Date__c` | Date validity rule SU-007 |
| `Deferred_Amount_in_GBP__c` | Amount validity rule SU-005 |
| `Deferred_Amount_in_LC__c` | LC consistency rule SU-006 |
| `Local_Currency_Of_Deferred_Funds__c` | Currency requirement for LC amount |
| `OrphanAccountID__c` | Included for review but currently fully blank |
| `Orphan_Id__c` | Orphan context |
| `Casesafe_Id__c` | Safe-id consistency context |
| `SystemModstamp` | Dedup ordering |
| `_etl_source`, `_etl_source_object`, `_etl_loaded_at_utc` | Lineage and audit |
| `staging_is_duplicate`, `staging_duplicate_count`, `staging_created_at` | Duplicate pressure and staging audit |

---

## Candidate Rule Ideas

| Rule | Purpose | Status |
|------|---------|--------|
| SU-001 | Id must not be null | Engineering-safe |
| SU-002 | Id must be 15 or 18 characters | Engineering-safe |
| SU-003 | Sponsorship__c must be populated | Engineering-safe |
| SU-004 | Sponsorship__c must exist in sponsorship raw/staging | Framework-ready |
| SU-005 | Deferred GBP amount must not be negative | Needs business confirmation |
| SU-006 | Local currency required when LC amount is populated | Engineering-safe |
| SU-007 | Donation date must be valid when populated | Engineering-safe |
| SU-008 | GAU allocation reference must exist | Framework-ready after allocation source confirmed |
| SU-009 | Unit must not point to deleted sponsorship | Framework-ready |

## Notes

High-volume joins for SU-004 and SU-008 should be tested with `@MaxRowsPerRule = 200000` before a full uncapped run.
