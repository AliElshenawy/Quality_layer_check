<!-- AI created but i reviewed it -->


# EDA: Recurring Donation — CSV Data Analysis

## Object Overview

| Attribute | Value |
|-----------|-------|
| **Salesforce API Name** | `npe03__Recurring_Donation__c` |
| **Package** | NPSP (Nonprofit Success Pack) |
| **SQL Raw Table** | `raw.salesforce_recurring_donation` |
| **CSV File** | `salesforce_recurring_donation_20260727_151628.csv` |
| **Expected Rows** | ~258,368 |
| **File Size** | ~219 MB |
| **Total Columns** | 93 (90 business + 3 ETL metadata) |

**What it represents:** Recurring Donations track pledged ongoing giving commitments from donors. Each record represents a donor's commitment to give a specific amount at regular intervals (monthly, quarterly, annually). They generate child Opportunity records for each installment.

---

| # | Column | Type | Null/Empty | Null % | Distinct Values | Flag |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `Id` | nvarchar | 0 | .00% | 258465 | ✅ clean |
| 2 | `OwnerId` | nvarchar | 0 | .00% | 537 | ✅ clean |
| 3 | `IsDeleted` | nvarchar | 0 | .00% | 1 | ✅ clean |
| 4 | `Name` | nvarchar | 0 | .00% | 252725 | ✅ clean |
| 5 | `CurrencyIsoCode` | nvarchar | 0 | .00% | 7 | ✅ clean |
| 6 | `CreatedDate` | nvarchar | 0 | .00% | 223453 | ✅ clean |
| 7 | `CreatedById` | nvarchar | 0 | .00% | 537 | ✅ clean |
| 8 | `LastModifiedDate` | nvarchar | 0 | .00% | 50373 | ✅ clean |
| 9 | `LastModifiedById` | nvarchar | 0 | .00% | 202 | ✅ clean |
| 10 | `SystemModstamp` | nvarchar | 0 | .00% | 25952 | ✅ clean |
| 11 | `LastActivityDate` | nvarchar | 252294 | 96.45% | 733 | 🔴 high |
| 12 | `LastViewedDate` | nvarchar | 261574 | 100.00% | 3 | 🔴 high |
| 13 | `LastReferencedDate` | nvarchar | 261574 | 100.00% | 3 | 🔴 high |
| 14 | `npe03__Amount__c` | nvarchar | 0 | .00% | 1565 | ✅ clean |
| 15 | `npe03__Contact__c` | nvarchar | 87 | .03% | 188357 | 🟡 low |
| 16 | `npe03__Date_Established__c` | nvarchar | 0 | .00% | 2000 | ✅ clean |
| 17 | `npe03__Donor_Name__c` | nvarchar | 57 | .02% | 166069 | 🟡 low |
| 18 | `npe03__Installment_Amount__c` | nvarchar | 0 | .00% | 1725 | ✅ clean |
| 19 | `npe03__Installment_Period__c` | nvarchar | 45488 | 17.39% | 4 | 🟠 medium |
| 20 | `npe03__Installments__c` | nvarchar | 161391 | 61.70% | 48 | 🔴 high |
| 21 | `npe03__Last_Payment_Date__c` | nvarchar | 13149 | 5.03% | 2940 | 🟠 medium |
| 22 | `npe03__Next_Payment_Date__c` | nvarchar | 153206 | 58.57% | 202 | 🔴 high |
| 23 | `npe03__Open_Ended_Status__c` | nvarchar | 0 | .00% | 3 | ✅ clean |
| 24 | `npe03__Organization__c` | nvarchar | 98 | .04% | 186791 | 🟡 low |
| 25 | `npe03__Paid_Amount__c` | nvarchar | 3665 | 1.40% | 6150 | 🟡 low |
| 26 | `npe03__Recurring_Donation_Campaign__c` | nvarchar | 141 | .05% | 2665 | 🟡 low |
| 27 | `npe03__Schedule_Type__c` | nvarchar | 261577 | 100.00% | 0 | 🔴 high |
| 28 | `npe03__Total_Paid_Installments__c` | nvarchar | 2200 | .84% | 189 | 🟡 low |
| 29 | `npe03__Total__c` | nvarchar | 0 | .00% | 1 | ✅ clean |
| 30 | `npsp__Always_Use_Last_Day_Of_Month__c` | nvarchar | 0 | .00% | 1 | ✅ clean |
| 31 | `npsp__Day_of_Month__c` | nvarchar | 93130 | 35.60% | 31 | 🔴 high |
| 32 | `npsp__CurrentYearValue__c` | nvarchar | 45515 | 17.40% | 1096 | 🟠 medium |
| 33 | `npsp__NextYearValue__c` | nvarchar | 45514 | 17.40% | 640 | 🟠 medium |
| 34 | `npsp__CommitmentId__c` | nvarchar | 261577 | 100.00% | 0 | 🔴 high |
| 35 | `npsp__EndDate__c` | nvarchar | 133830 | 51.16% | 1945 | 🔴 high |
| 36 | `Card_Payment_Detail__c` | nvarchar | 96967 | 37.07% | 160766 | 🔴 high |
| 37 | `npsp__InstallmentFrequency__c` | nvarchar | 45518 | 17.40% | 4 | 🟠 medium |
| 38 | `npsp__PaymentMethod__c` | nvarchar | 29815 | 11.40% | 17 | 🟠 medium |
| 39 | `npsp__RecurringType__c` | nvarchar | 2 | .00% | 2 | ✅ clean |
| 40 | `npsp__StartDate__c` | nvarchar | 0 | .00% | 3686 | ✅ clean |
| 41 | `npsp__Status__c` | nvarchar | 1 | .00% | 4 | ✅ clean |
| 42 | `npsp__ClosedReason__c` | nvarchar | 151725 | 58.00% | 20 | 🔴 high |
| 43 | `Direct_Debit_Detail__c` | nvarchar | 198919 | 76.05% | 62607 | 🔴 high |
| 44 | `Donation_Type__c` | nvarchar | 1 | .00% | 7 | ✅ clean |
| 45 | `GAU_Allocation__c` | nvarchar | 261577 | 100.00% | 0 | 🔴 high |
| 46 | `Opportunity__c` | nvarchar | 58 | .02% | 258366 | 🟡 low |
| 47 | `npsp__DisableFirstInstallment__c` | nvarchar | 0 | .00% | 2 | ✅ clean |
| 48 | `npsp__CardExpirationMonth__c` | nvarchar | 173330 | 66.26% | 12 | 🔴 high |
| 49 | `npsp__CardExpirationYear__c` | nvarchar | 173330 | 66.26% | 25 | 🔴 high |
| 50 | `npsp__CardLast4__c` | nvarchar | 173318 | 66.26% | 9982 | 🔴 high |
| 51 | `npsp__LastElevateEventPlayed__c` | nvarchar | 243828 | 93.21% | 189 | 🔴 high |
| 52 | `Source_Donation_Transaction_Id__c` | nvarchar | 64394 | 24.62% | 194510 | 🟠 medium |
| 53 | `npsp__ACH_Last_4__c` | nvarchar | 261329 | 99.91% | 214 | 🔴 high |
| 54 | `npsp__LastElevateVersionPlayed__c` | nvarchar | 261577 | 100.00% | 0 | 🔴 high |
| 55 | `Medium__c` | nvarchar | 48784 | 18.65% | 8 | 🟠 medium |
| 56 | `Regional_Code__c` | nvarchar | 32045 | 12.25% | 9 | 🟠 medium |
| 57 | `Source__c` | nvarchar | 69209 | 26.46% | 25 | 🟠 medium |
| 58 | `Department__c` | nvarchar | 1540 | .59% | 8 | 🟡 low |
| 59 | `Website_Code__c` | nvarchar | 32045 | 12.25% | 9 | 🟠 medium |
| 60 | `Regional_Office_Code__c` | nvarchar | 6 | .00% | 9 | ✅ clean |
| 61 | `npsp__ChangeType__c` | nvarchar | 261577 | 100.00% | 0 | 🔴 high |
| 62 | `DD_Hold_Reason__c` | nvarchar | 239379 | 91.51% | 25 | 🔴 high |
| 63 | `Account_mismatch_temp__c` | nvarchar | 0 | .00% | 2 | ✅ clean |
| 64 | `Campaign_Department__c` | nvarchar | 1526 | .58% | 8 | 🟡 low |
| 65 | `Basket__c` | nvarchar | 200793 | 76.76% | 59352 | 🔴 high |
| 66 | `External_Id__c` | nvarchar | 155219 | 59.34% | 103331 | 🔴 high |
| 67 | `Payment_Method_Id__c` | nvarchar | 114618 | 43.82% | 141685 | 🔴 high |
| 68 | `Total_Amount_Percentage_Paid__c` | nvarchar | 60 | .02% | 4223 | 🟡 low |
| 69 | `Total_Donation_Amount__c` | nvarchar | 0 | .00% | 1483 | ✅ clean |
| 70 | `Bank_Name__c` | nvarchar | 261294 | 99.89% | 59 | 🔴 high |
| 71 | `Routing_Number__c` | nvarchar | 249804 | 95.50% | 377 | 🔴 high |
| 72 | `Date_Established_Region_Format__c` | nvarchar | 0 | .00% | 2810 | ✅ clean |
| 73 | `Start_Date_Region_Format__c` | nvarchar | 0 | .00% | 4496 | ✅ clean |
| 74 | `Card_Expiry_Date__c` | nvarchar | 143389 | 54.82% | 173 | 🔴 high |
| 75 | `SR_Units_Allocation__c` | nvarchar | 86667 | 33.13% | 29 | 🔴 high |
| 76 | `Total_Amount_Available_for_Instruction__c` | nvarchar | 87588 | 33.48% | 1 | 🔴 high |
| 77 | `Total_Amount_Instructed__c` | nvarchar | 260520 | 99.60% | 79 | 🔴 high |
| 78 | `Total_Amount_for_1_Unit_of_each_GAU__c` | nvarchar | 85217 | 32.58% | 119 | 🔴 high |
| 79 | `Allow_Instruction__c` | nvarchar | 0 | .00% | 2 | ✅ clean |
| 80 | `Amount_Available_for_SR_Instruction__c` | nvarchar | 0 | .00% | 344 | ✅ clean |
| 81 | `Enough_funds_to_instruct__c` | nvarchar | 0 | .00% | 2 | ✅ clean |
| 82 | `Casesafe_Recurring_Donation_Id__c` | nvarchar | 0 | .00% | 258465 | ✅ clean |
| 83 | `Payment_Schedule__c` | nvarchar | 83223 | 31.82% | 7 | 🔴 high |
| 84 | `Total_Paid_Amount_excl__c` | nvarchar | 3911 | 1.50% | 6123 | 🟡 low |
| 85 | `Last_Year_Value__c` | nvarchar | 47733 | 18.25% | 1018 | 🟠 medium |
| 86 | `Number_of_Unpaid_Installments__c` | nvarchar | 0 | .00% | 241 | ✅ clean |
| 87 | `Email_Acknowledgement__c` | nvarchar | 259484 | 99.20% | 1 | 🔴 high |
| 88 | `Email_Acknowledgement_Date__c` | nvarchar | 259483 | 99.20% | 2 | 🔴 high |
| 89 | `Number_of_Failed_Payments__c` | nvarchar | 165350 | 63.21% | 37 | 🔴 high |
| 90 | `Total_Number_of_Failed_Payments__c` | nvarchar | 131863 | 50.41% | 44 | 🔴 high |
| 91 | `_etl_loaded_at_utc` | datetime2 | 3209 | 1.23% | 1 | 🟡 low |
| 92 | `_etl_source` | nvarchar | 3209 | 1.23% | 1 | 🟡 low |
| 93 | `_etl_source_object` | nvarchar | 0 | .00% | 1 | ✅ clean |

## Column Inventory (90 Columns)

### System / Audit Fields (13)

| Column | Purpose |
|--------|---------|
| `Id` | Primary key — 18-char Salesforce ID |
| `IsDeleted` | Soft-delete flag |
| `Name` | Auto-generated name (e.g., "RD-000001") |
| `OwnerId` | Record owner |
| `CurrencyIsoCode` | Currency of the donation |
| `CreatedDate` | Record creation timestamp |
| `CreatedById` | Creator user |
| `LastModifiedDate` | Last edit |
| `LastModifiedById` | Editor user |
| `SystemModstamp` | System watermark |
| `LastActivityDate` | Last related activity date |
| `LastViewedDate` | Last viewed by a user (100% null) |
| `LastReferencedDate` | Last referenced by a user (100% null) |

### Core NPSP Fields (npe03__ prefix) (16)

| Column | Purpose |
|--------|---------|
| `npe03__Amount__c` | Recurring donation amount per installment |
| `npe03__Contact__c` | Donor Contact (FK) |
| `npe03__Date_Established__c` | When the recurring donation was set up |
| `npe03__Donor_Name__c` | Formula/text showing donor name |
| `npe03__Installment_Amount__c` | Amount per installment (may differ from Amount) |
| `npe03__Installment_Period__c` | Frequency: Monthly, Quarterly, Yearly, etc. |
| `npe03__Installments__c` | Number of planned installments (fixed-length) |
| `npe03__Last_Payment_Date__c` | Last successful payment date |
| `npe03__Next_Payment_Date__c` | Next expected payment date |
| `npe03__Open_Ended_Status__c` | Open/Closed/None (legacy field) |
| `npe03__Organization__c` | Org donor (FK to Account) |
| `npe03__Paid_Amount__c` | Total amount paid so far |
| `npe03__Recurring_Donation_Campaign__c` | Campaign FK |
| `npe03__Schedule_Type__c` | Schedule type |
| `npe03__Total_Paid_Installments__c` | Count of paid installments |
| `npe03__Total__c` | Total expected amount |

### NPSP Enhanced Fields (npsp__ prefix) (20)

| Column | Purpose |
|--------|---------|
| `npsp__Always_Use_Last_Day_Of_Month__c` | Force payment on last day |
| `npsp__Day_of_Month__c` | Day of month for payment (1-31) |
| `npsp__CurrentYearValue__c` | Rollup: current year amount |
| `npsp__NextYearValue__c` | Rollup: next year projected |
| `npsp__CommitmentId__c` | Elevate commitment reference |
| `npsp__EndDate__c` | Scheduled end date |
| `npsp__InstallmentFrequency__c` | Frequency multiplier |
| `npsp__PaymentMethod__c` | Credit Card, Direct Debit, etc. |
| `npsp__RecurringType__c` | Open or Fixed |
| `npsp__StartDate__c` | Effective start date |
| `npsp__Status__c` | Active, Lapsed, Closed, Paused |
| `npsp__ClosedReason__c` | Reason for closure |
| `npsp__DisableFirstInstallment__c` | Skip first installment flag |
| `npsp__CardExpirationMonth__c` | Payment card expiry month |
| `npsp__CardExpirationYear__c` | Payment card expiry year |
| `npsp__CardLast4__c` | Last 4 digits of card |
| `npsp__LastElevateEventPlayed__c` | Elevate integration event |
| `npsp__ACH_Last_4__c` | ACH account last 4 |
| `npsp__LastElevateVersionPlayed__c` | Elevate version |
| `npsp__ChangeType__c` | Type of last change |

### Payment Detail Fields (8)

| Column | Purpose |
|--------|---------|
| `Card_Payment_Detail__c` | Card payment reference |
| `Direct_Debit_Detail__c` | DD mandate reference |
| `Payment_Method_Id__c` | External payment ID |
| `Bank_Name__c` | Bank name for DD |
| `Routing_Number__c` | Bank routing number |
| `Card_Expiry_Date__c` | Formatted card expiry |
| `Payment_Schedule__c` | Payment schedule details |
| `DD_Hold_Reason__c` | Direct Debit hold reason |

### Classification / Source Fields (10)

| Column | Purpose |
|--------|---------|
| `Donation_Type__c` | Type of donation |
| `GAU_Allocation__c` | Linked GAU/Item |
| `Opportunity__c` | Related opportunity |
| `Source__c` | Acquisition source |
| `Medium__c` | Acquisition medium |
| `Department__c` | Department code |
| `Regional_Code__c` | Regional classification |
| `Regional_Office_Code__c` | Office code |
| `Website_Code__c` | Online channel code |
| `Campaign_Department__c` | Campaign department link |

### Financial Tracking Fields (11)

| Column | Purpose |
|--------|---------|
| `Total_Amount_Percentage_Paid__c` | % of total paid |
| `Total_Donation_Amount__c` | Lifetime donation total |
| `Total_Paid_Amount_excl__c` | Paid excl. certain items |
| `Last_Year_Value__c` | Previous year total |
| `Total_Amount_Available_for_Instruction__c` | Available for fund allocation |
| `Total_Amount_Instructed__c` | Already instructed/allocated |
| `Total_Amount_for_1_Unit_of_each_GAU__c` | Per-unit GAU amount |
| `Amount_Available_for_SR_Instruction__c` | Sponsorship allocation available |
| `Number_of_Unpaid_Installments__c` | Unpaid installment count |
| `Number_of_Failed_Payments__c` | Recent failed payments |
| `Total_Number_of_Failed_Payments__c` | Lifetime failed payments |

### Sponsorship & Instruction Fields (4)

| Column | Purpose |
|--------|---------|
| `SR_Units_Allocation__c` | Sponsorship unit allocations |
| `Allow_Instruction__c` | Whether fund instruction is allowed |
| `Enough_funds_to_instruct__c` | Has sufficient funds |
| `Basket__c` | Donation basket reference |

### Reference / ID Fields (4)

| Column | Purpose |
|--------|---------|
| `External_Id__c` | External system ID |
| `Source_Donation_Transaction_Id__c` | Source transaction reference |
| `Casesafe_Recurring_Donation_Id__c` | 18-char safe ID |
| `Account_mismatch_temp__c` | Temp field for account cleanup |

### Communication & Localization Fields (4)

| Column | Purpose |
|--------|---------|
| `Email_Acknowledgement__c` | Email ack status |
| `Email_Acknowledgement_Date__c` | When ack was sent |
| `Date_Established_Region_Format__c` | Localized date format |
| `Start_Date_Region_Format__c` | Localized start date |

---

## Key Observations

### Data Patterns

| Pattern | Detail |
|---------|--------|
| ID format | Standard 18-char Salesforce IDs |
| Currency | Expect mostly `GBP` (UK charity), possibly USD/EUR for intl offices |
| Date format | ISO 8601 (`2020-11-05T14:25:39.000Z`) |
| NULL representation | Empty strings in CSV → converted to NULL in SQL |
| Amount precision | Decimal values (e.g., `25.00`, `100.50`) |
| Status lifecycle | Active → Lapsed → Closed |
| Naming | NPSP-prefixed fields (`npe03__`, `npsp__`) vs custom fields (`__c`) |

### Expected Value Patterns

| Field | Expected Values |
|-------|-----------------|
| `npsp__Status__c` | Active, Lapsed, Closed, Paused |
| `npe03__Installment_Period__c` | Monthly, Quarterly, Yearly, Weekly, 1st and 15th |
| `npsp__RecurringType__c` | Open, Fixed |
| `npsp__PaymentMethod__c` | Credit Card, Direct Debit, Check, ACH |
| `npsp__Day_of_Month__c` | 1-31 or "Last_Day" |
| `CurrencyIsoCode` | GBP, USD, EUR, CAD |

---

## Relationship Map

```
Recurring Donation
    │
    ├── Contact (npe03__Contact__c) — the donor
    │
    ├── Account/Organization (npe03__Organization__c) — org donor
    │
    ├── Campaign (npe03__Recurring_Donation_Campaign__c) — source campaign
    │
    ├── Opportunity (child records — one per installment)
    │       └── Payment (child of each Opportunity)
    │
    ├── GAU/Item (GAU_Allocation__c) — fund designation
    │
    └── Sponsorship Unit (SR_Units_Allocation__c) — if sponsorship RD
```

---

## Initial Risk Areas

| Risk | Impact | Priority |
|------|--------|----------|
| **Status lifecycle integrity** | Active RDs with past end dates, or Closed with future payments | HIGH |
| **Amount = 0 on Active RDs** | Active donations with £0 amount — legitimate or error? | HIGH |
| **Orphan Contact references** | `npe03__Contact__c` pointing to non-existent Contacts | HIGH |
| **Payment method sensitivity** | `npsp__CardLast4__c`, `Routing_Number__c` — PII/PCI concern | CRITICAL |
| **Failed payment tracking** | High failure counts may indicate stale/expired cards | MEDIUM |
| **Day_of_Month validation** | Values > 28 cause issues in short months | MEDIUM |
| **Installment math** | `Amount × Installments` should ≈ `Total__c` for fixed RDs | MEDIUM |
| **Lapsed definition** | When does Active become Lapsed? Consistent threshold? | MEDIUM |
| **Currency mixing** | Multi-currency RDs complicate aggregation | LOW |
| **Legacy vs NPSP fields** | `npe03__Open_Ended_Status__c` (legacy) vs `npsp__Status__c` (current) — which is authoritative? | MEDIUM |

---

## Initial DQ Rule Candidates

| # | Rule | Type | Severity |
|---|------|------|----------|
| 1 | Every RD must have a non-NULL `Id` | Completeness | CRITICAL |
| 2 | `Id` must be unique | Uniqueness | CRITICAL |
| 3 | `npe03__Contact__c` OR `npe03__Organization__c` must be populated | Completeness | HIGH |
| 4 | `npe03__Amount__c` must be > 0 for Active recurring donations | Validity | HIGH |
| 5 | `npsp__Status__c` must be one of: Active, Lapsed, Closed, Paused | Validity | HIGH |
| 6 | `npsp__Day_of_Month__c` must be 1-31 or "Last_Day" | Validity | MEDIUM |
| 7 | `npsp__StartDate__c` should not be in the future for Active RDs | Timeliness | MEDIUM |
| 8 | `npsp__EndDate__c` should be after `npsp__StartDate__c` | Consistency | HIGH |
| 9 | Active RDs should have `npe03__Next_Payment_Date__c` within 45 days | Timeliness | MEDIUM |
| 10 | `npe03__Paid_Amount__c` should not exceed `npe03__Total__c` for Fixed RDs | Consistency | MEDIUM |
| 11 | `npsp__CardExpirationYear__c` + `npsp__CardExpirationMonth__c` should not be past for Active card RDs | Validity | MEDIUM |
| 12 | `Number_of_Failed_Payments__c` > 3 on Active RD = review needed | Business | LOW |
| 13 | `npe03__Contact__c` must exist in `raw.salesforce_contact` | Referential | HIGH |
| 14 | `npe03__Recurring_Donation_Campaign__c` must exist in `raw.salesforce_campaign` | Referential | MEDIUM |

---

## DQ Framework — All Rules (RD-001 to RD-017)

Framework object name: `Recurring_Donation`  
Staging source: `staging.recurring_donation_latest`  
Total framework rules: 17  
Main script: `recurring_donation_staging_dq_PROD_framework.sql`

### Rule Catalog

| Rule | Severity | Column | Description | Status | Open |
|------|----------|--------|-------------|--------|-----:|
| RD-001 | CRITICAL | `Id` | Id must not be null | ✅ PASS | 0 |
| RD-002 | CRITICAL | `Id` | Id must be 15 or 18 characters | ✅ PASS | 0 |
| RD-003 | HIGH | `npe03__Contact__c` / `npe03__Organization__c` | At least one donor FK must be populated | 🔴 FAIL | 57 |
| RD-004 | HIGH | `npe03__Amount__c` | Active RD must have amount > 0 | ✅ PASS | 0 |
| RD-005 | — | `npsp__Status__c` | Distinct values reported — no assumed list | 📋 REPORT-ONLY | — |
| RD-006 | MEDIUM | `npsp__Day_of_Month__c` | Day must be 1–31 or Last_Day when populated | ✅ PASS | 0 |
| RD-007 | HIGH | `npsp__StartDate__c` / `npsp__EndDate__c` | StartDate must not be after EndDate | 🔴 FAIL | 19,864 |
| RD-008 | HIGH | `npe03__Contact__c` | Contact must exist in raw.salesforce_contact ⚠️ table empty | ⚠️ FAIL (capped) | 100 |
| RD-009 | MEDIUM | `npe03__Recurring_Donation_Campaign__c` | Campaign must exist in raw.salesforce_campaign | ✅ PASS | 0 |
| RD-010 | — | `npe03__Installment_Period__c` | Distinct values reported — no assumed list | 📋 REPORT-ONLY | — |
| RD-011 | — | `npsp__RecurringType__c` | Distinct values reported — no assumed list | 📋 REPORT-ONLY | — |
| RD-012 | — | `npsp__PaymentMethod__c` | Distinct values reported — no assumed list | 📋 REPORT-ONLY | — |
| RD-013 | — | `Donation_Type__c` | Distinct values reported — no assumed list | 📋 REPORT-ONLY | — |
| RD-014 | — | `Regional_Office_Code__c` | Distinct values reported — no assumed list | 📋 REPORT-ONLY | — |
| RD-015 | MEDIUM | `npsp__ClosedReason__c` | Closed RD must have ClosedReason populated | 🔴 FAIL | 79,000 |
| RD-016 | HIGH | `npe03__Paid_Amount__c` | Must be numeric when populated | ✅ PASS | 0 |
| RD-017 | HIGH | `Total_Donation_Amount__c` | Must be numeric when populated | ✅ PASS | 0 |

_All 17 rules executed — 2026-07-30 18:27._

### Open Exceptions Summary

| Rule | Severity | Count | Interpretation |
|------|----------|---------:|----------------|
| RD-007 | HIGH | 19,864 | StartDate > EndDate — likely data migration artifact |
| RD-015 | MEDIUM | 79,000 | Closed RDs missing ClosedReason — 42% of all Closed |
| RD-008 | HIGH | 100 (capped) | Contact table empty — informational only, not real DQ |
| RD-003 | HIGH | 57 | No donor link (Contact + Org both null) |

> Controlled-list fields (Status, Installment Period, Recurring Type, Payment Method, Donation Type, Regional Office, Currency) are **report-only** — no assumed values; distinct values are listed in the analysis doc (§3b).

### Known Data Quality Issues Found in Pre-Analysis

| Finding | Count | Rule |
|---------|------:|------|
| StartDate > EndDate | 19,865 | RD-007 |
| Active RDs with amount = 0 | 0 | RD-004 |
| Active RDs missing next payment | ~90 | — |
| Active RD with past end date | 1 | — |
| Payment method variants (16 forms) | ~260K populated | RD-012 |
| raw.salesforce_contact empty | affects all | RD-008 (caveat) |

---

## Staging Coverage (30 Columns)

| Column | In Staging | Cycle | Purpose |
|--------|-----------|-------|---------|
| `row_number` | ✅ | 1 | Dedup rank |
| `Id` | ✅ | 1 | Primary key |
| `IsDeleted` | ✅ | 1 | Filter |
| `Name` | ✅ | 1 | Identity |
| `CurrencyIsoCode` | ✅ | 1 | Currency |
| `npe03__Contact__c` | ✅ | 1 | Donor FK |
| `npe03__Organization__c` | ✅ | 1 | Org FK |
| `npe03__Amount__c` | ✅ | 1 | Amount |
| `npe03__Installment_Amount__c` | ✅ | 2 | Per-installment |
| `npe03__Paid_Amount__c` | ✅ | 2 | Financial |
| `Total_Donation_Amount__c` | ✅ | 2 | Financial |
| `npsp__Status__c` | ✅ | 1 | Status lifecycle |
| `npsp__RecurringType__c` | ✅ | 2 | Open/Fixed |
| `npsp__StartDate__c` | ✅ | 1 | Date logic |
| `npsp__EndDate__c` | ✅ | 1 | Date logic |
| `npsp__ClosedReason__c` | ✅ | 2 | Closure reason |
| `npe03__Installment_Period__c` | ✅ | 2 | Schedule |
| `npsp__Day_of_Month__c` | ✅ | 1 | Schedule |
| `npe03__Next_Payment_Date__c` | ✅ | 1 | Timeliness |
| `Donation_Type__c` | ✅ | 2 | Classification |
| `npsp__PaymentMethod__c` | ✅ | 2 | Payment |
| `Regional_Office_Code__c` | ✅ | 2 | Office |
| `npe03__Recurring_Donation_Campaign__c` | ✅ | 1 | Campaign FK |
| `Number_of_Failed_Payments__c` | ✅ | 2 | Monitoring |
| `SystemModstamp` | ✅ | 1 | Dedup order |
| `_etl_source` | ✅ | 1 | Lineage |
| `_etl_source_object` | ✅ | 1 | Lineage |
| `_etl_loaded_at_utc` | ✅ | 1 | Load audit |
| `staging_is_duplicate` | ✅ | 1 | Dedup flag |
| `staging_duplicate_count` | ✅ | 1 | Dedup pressure |
| `staging_created_at` | ✅ | 1 | Timestamp |

---

## Batch Execution + Progress Monitoring

### Run command
```bash
sqlcmd -S localhost -E -d SalesforceDW -C -N -i "d:/career/github/VA Work/mohey_work/Tables/recurring_donation/recurring_donation_staging_dq_PROD_framework.sql"
```

### Progress check (run any time)
```sql
SELECT r.check_name, s.last_run_status,
       ISNULL(dr.check_status,'NOT RUN') AS last_status,
       ISNULL(dr.failed_count,0)         AS failed_count
FROM dq.dq_rule_catalog r
JOIN dq.rule_execution_state s ON s.rule_id=r.rule_id
LEFT JOIN (
    SELECT check_name, check_status, failed_count,
           ROW_NUMBER() OVER (PARTITION BY check_name ORDER BY checked_at DESC) AS rn
    FROM dq.dq_results WHERE object_name='Recurring_Donation'
) dr ON dr.check_name=r.check_name AND dr.rn=1
WHERE r.object_name='Recurring_Donation'
ORDER BY r.check_name;
```

### Emergency stop + deactivate
```sql
UPDATE s SET last_source_watermark_value=NULL, reprocess_review_pending=0
FROM dq.rule_execution_state s JOIN dq.dq_rule_catalog r ON r.rule_id=s.rule_id
WHERE r.object_name='Recurring_Donation' AND r.check_name='RD-008';

UPDATE dq.dq_rule_catalog SET is_active=0
WHERE object_name='Recurring_Donation' AND check_name='RD-008';
```

---

## DQ Framework Audit — Timing

The framework records timing at two levels — same as Item_GAU:

| Level | Table | What Is Stored |
|-------|-------|----------------|
| Per EXEC call | `dq.technical_run` | `started_at`, `completed_at`, `run_status` |
| Per rule | `dq.dq_results` | `checked_at` per rule execution |

```sql
SELECT object_name,
       COUNT(DISTINCT check_name) AS rules_run,
       MIN(checked_at) AS first_run,
       MAX(checked_at) AS last_run,
       DATEDIFF(SECOND, MIN(checked_at), MAX(checked_at)) AS span_sec
FROM dq.dq_results
WHERE object_name = 'Recurring_Donation'
GROUP BY object_name;
```

---

## Suggested Queries — Confirm Before Running

### SQ-01: RD-007 breakdown — StartDate > EndDate by year
```sql
SELECT YEAR(TRY_CONVERT(DATETIME2,[npsp__StartDate__c])) AS start_year, COUNT(*) AS cnt
FROM staging.recurring_donation_latest
WHERE TRY_CONVERT(DATETIME2,[npsp__StartDate__c]) > TRY_CONVERT(DATETIME2,[npsp__EndDate__c])
GROUP BY YEAR(TRY_CONVERT(DATETIME2,[npsp__StartDate__c]))
ORDER BY start_year;
```

### SQ-02: Active RDs with expired card
```sql
SELECT COUNT(*) AS active_expired_card
FROM staging.recurring_donation_latest
WHERE UPPER(LTRIM(RTRIM(COALESCE([npsp__Status__c],'')))) = 'ACTIVE'
  AND LOWER(LTRIM(RTRIM(COALESCE([npsp__PaymentMethod__c],'')))) LIKE '%card%'
  AND NULLIF(LTRIM(RTRIM(COALESCE([npsp__EndDate__c],''))),'')<>''
  AND TRY_CONVERT(DATETIME2,[npsp__EndDate__c]) < GETUTCDATE();
```

### SQ-03: Closed RDs without ClosedReason distribution
```sql
SELECT COALESCE([npsp__ClosedReason__c],'(NULL)') AS reason, COUNT(*) AS cnt
FROM staging.recurring_donation_latest
WHERE UPPER(LTRIM(RTRIM(COALESCE([npsp__Status__c],'')))) = 'CLOSED'
GROUP BY [npsp__ClosedReason__c] ORDER BY cnt DESC;
```

### SQ-04: Active RDs with ≥ 3 failed payments
```sql
SELECT [Id], [npe03__Amount__c], [Number_of_Failed_Payments__c]
FROM staging.recurring_donation_latest
WHERE UPPER(LTRIM(RTRIM(COALESCE([npsp__Status__c],'')))) = 'ACTIVE'
  AND TRY_CONVERT(INT,[Number_of_Failed_Payments__c]) >= 3
ORDER BY TRY_CONVERT(INT,[Number_of_Failed_Payments__c]) DESC;
```

### SQ-05: PaymentMethod full distribution for normalization
```sql
SELECT [npsp__PaymentMethod__c], COUNT(*) AS cnt
FROM staging.recurring_donation_latest
GROUP BY [npsp__PaymentMethod__c]
ORDER BY cnt DESC;
```

- Status distribution is the #1 analysis — how many Active vs Lapsed vs Closed?
- Amount distribution by status — are £0 amounts common?
- Payment method breakdown — Card vs DD vs other
- Contact linkage — how many orphan `npe03__Contact__c` values?
- Installment period — Monthly should dominate for charity subscriptions
- Failed payment concentration — are there donors with 10+ failures still Active?
- Card expiry analysis — Active RDs with expired cards
- PCI sensitivity — `npsp__CardLast4__c` and `Routing_Number__c` should be assessed for masking
