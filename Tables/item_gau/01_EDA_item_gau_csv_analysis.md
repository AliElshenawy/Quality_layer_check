
<!-- AI created but i reviewed it -->


# EDA: Item / GAU — CSV Data Analysis

## 1. Object Overview

| Attribute | Value |
|-----------|-------|
| Salesforce API Name | `npsp__General_Accounting_Unit__c` |
| Package | NPSP (Nonprofit Success Pack) |
| SQL Raw Table | `raw.salesforce_item` |
| CSV File | `salesforce_item_20260727_155541.csv` |
| Raw rows (non-deleted) | 30,832 |
| Staging rows (latest per Id) | 30,815 |
| Total staging columns | 31 (incl. ETL + staging metadata) |
| Null profile CSV | `00_null_analysis_salesforce_item.csv` |

**What it represents:** A GAU (General Accounting Unit), called "Item" here, is a fund/accounting bucket
that donations and allocations are attributed to. Each item defines a product type, programme category,
donation type, geography, allow-single/recurring behaviour, and carries rolled-up financial totals
(Zakat / non-Zakat credit, funds available, total allocations).

## 2. Sampling Note

The table is small (~31K rows), well below the 200,000-row large-table threshold, so **all EDA and DQ
runs are full-population** — no sampling. Counts in this file are from the actual raw/staging tables.

## 3. Column Inventory

Staging carries 31 columns. 🟢 = selected into `staging.item_gau_latest`.

### Identity & system
| Column | Purpose | Stage |
|--------|---------|:---:|
| `Id` | Primary key (18-char SF Id) | 🟢 |
| `IsDeleted` | Soft-delete flag | 🟢 |
| `Name` | Item name | 🟢 |
| `CurrencyIsoCode` | Currency code | 🟢 |
| `npsp__Active__c` | Active flag (drives most active-item rules) | 🟢 |
| `SystemModstamp` | Watermark for latest-row selection | 🟢 |

### Classification
| Column | Purpose | Stage |
|--------|---------|:---:|
| `Product_Type__c` | Product type (Fund, Pledge, Sponsorship, Ticket, …) | 🟢 |
| `Programme_Category__c` | Programme bucket (distinct values reported — not gated) | 🟢 |
| `Donation_Type__c` | Single / Recurring / both | 🟢 |
| `Country__c` | Geography (required for active non-Pledge) | 🟢 |
| `Status__c` | Lifecycle status | 🟢 |
| `Campaign__c` | Campaign FK | 🟢 |

### Allocation flags & codes
| Column | Purpose | Stage |
|--------|---------|:---:|
| `Donation_Item_Code__c` | Unique item code | 🟢 |
| `Allow_Single__c` / `Allow_Recurring__c` | Allowed donation modes | 🟢 |
| `HA_Donation_Frequency__c` | Frequency (Monthly / Monthly;Daily) | 🟢 |
| `Stipulation__c` | Stipulation tokens (SD/ZK/XX…) | 🟢 |
| `Regional_Office_Code__c` | Office code | 🟢 |

### Financial totals
| Column | Purpose | Stage |
|--------|---------|:---:|
| `Total_Non_Zakat_Credit__c` | Non-Zakat credit total | 🟢 |
| `Total_Zakat_Credit__c` | Zakat credit total | 🟢 |
| `Total_funds_available_sadaqa__c` | Sadaqa funds available | 🟢 |
| `Total_funds_available_zakat__c` | Zakat funds available | 🟢 |
| `npsp__Total_Allocations__c` | Total allocations rollup | 🟢 |

### Description & ETL
`npsp__Description__c` 🟢, `_etl_source` 🟢, `_etl_source_object` 🟢, `_etl_loaded_at_utc` 🟢,
`staging_is_duplicate` 🟢, `staging_duplicate_count` 🟢, `staging_created_at` 🟢.

## 4. Ordered Null and Data Presence Review

Full column profile: `00_null_analysis_salesforce_item.csv`. Highest-priority staged columns (from
`staging.item_gau_latest`, 30,815 rows):

### Top Null Columns (RAW/staging, DQ-relevant)
| Rank | Column | Null/blank | Null % | Why we care |
|---|---|---:|---:|---|
| 1 | `Country__c` | 19,285 | 62.6% | Required for **active non-Pledge** items (GAU-010). Most nulls are inactive/Pledge — only 955 are real failures. |
| 2 | `Status__c` | 3,816 | 12.4% | Required for **active** items (GAU-019). All 3,816 nulls are inactive → GAU-019 passes. |
| 3 | `Product_Type__c` | 1,763 | 5.7% | Required for active items (GAU-014) and gates Pledge/Sponsorship logic. |
| 4 | `npsp__Total_Allocations__c` | 2 | 0.01% | Financial rollup; also numeric-checked (GAU-026). |

`concerning empty`: `Country__c`, `Status__c`, `Product_Type__c` on active items.
`expected empty`: financial totals are essentially fully populated (0–2 nulls).

Key presence facts: **25,833 active items**; **574 items carried duplicate raw versions** (latest kept);
`staging_is_duplicate` flags them.

## 5. STG Item_GAU Coverage

`staging.item_gau_latest` (31 columns). Every staged column supports a rule, dedup, or lineage:

| STG column(s) | Why staged |
|---|---|
| `Id` | PK for every rule + dedup |
| `SystemModstamp`, `row_number` | latest-row selection |
| `IsDeleted` | soft-delete filter |
| `npsp__Active__c` | gates all active-item rules (GAU-010/011/014/018/019) |
| `Product_Type__c`, `Programme_Category__c`, `Donation_Type__c` | report-only distinct values (GAU-007/008/009 — no assumed list) |
| `Country__c`, `Status__c` | required-field rules GAU-010/019 |
| `Campaign__c` | referential rule GAU-012 |
| `Donation_Item_Code__c` | uniqueness rule GAU-013 |
| `Allow_Single__c`, `Allow_Recurring__c` | GAU-018 consistency |
| `HA_Donation_Frequency__c`, `Stipulation__c`, `Regional_Office_Code__c` | report-only distinct values (GAU-015/016/017 — no assumed list) |
| 5 financial totals | null + numeric rules GAU-020..026 |
| `_etl_*`, `staging_*` | lineage, dedup pressure, audit |

Not staged: the remaining ~100 raw columns (deprecated NPSP fields, address/system columns) — no rule
depends on them yet; add later only if a rule needs them.

## 6. Candidate Rule Ideas

All promoted rules are live in the framework (see `02_item_gau_staging_dq_PROD_framework.sql`, GAU-001..026)
and their post-run results are in `03_item_gau_staging_dq_ANALYSIS.md`. Summary of design intent:

- **Engineering-safe (live):** Id null/format (GAU-001/002), Name (GAU-003), boolean tokens (GAU-004/006),
  uniqueness (GAU-013), numeric guards (GAU-024/025/026),
  financial not-null (GAU-020..023).
- **Report-only (no assumed values):** Product_Type/Programme_Category/Donation_Type
  (GAU-007/008/009) and HA_Donation_Frequency/Stipulation/Regional_Office_Code (GAU-015/016/017) —
  distinct values are reported for stakeholders, nothing is treated as wrong.
- **Stakeholder-owned (live, need policy confirm):** active non-Pledge Country requirement (GAU-010),
  status/active consistency (GAU-011), Sponsorship/Ticket allow-flag rule (GAU-018).
- **Controlled-list fields** are **report-only** — we do **not** assume the valid values. Distinct observed
  values are reported for stakeholders to confirm (e.g. Programme_Category has 24+ distinct values).
