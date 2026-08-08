# 01 — EDA: Contact (`raw.salesforce_contact`)

> Evidence input: [`00_null_analysis_salesforce_contact.csv`](00_null_analysis_salesforce_contact.csv)
> Business input: `Quality_layer_check/DOCS/Donor Creation and Matching Process Assessment.docx`
> Client validation rules: provided by Human Appeal (see §6).

---

## 1. Object Overview

| Item | Value |
|------|-------|
| Salesforce API name | `Contact` |
| Raw SQL table | `raw.salesforce_contact` |
| CSV/export file | `exports/salesforce_contact_20260727_141604.csv` (7.3 GB) |
| Row count | **1,901,058** (loaded 2026-08-05, run 698s, verified: no NULL Id, no duplicate Id) |
| Distinct Id | 1,901,058 (0 duplicate Ids in raw) |
| Column count | **526** (Salesforce/NPSP field sprawl) |
| Deleted rows (`IsDeleted='true'`) | 32 |

**Purpose:** The Contact object is the **donor master** for Human Appeal. Every donation, payment,
recurring donation and sponsorship ultimately attributes to a Contact. Donors enter through several
channels (Salesforce CRM, website checkout, crowdfunding, bulk upload), each with different mandatory
fields and matching logic, so data completeness varies by channel.

## 2. Sampling Note

Total raw rows (1,901,058) exceed the 200,000 EDA threshold, so full-column profiling of all 526 columns
was **not** run (COUNT(DISTINCT) over 526 × 1.9M is prohibitively heavy). Instead, the null/blank and
distinct profile in `00_...csv` is a **full-population single-pass scan of the DQ-relevant column subset**
(keys, required fields, address, email, matching keys, Gift Aid). These counts are full-population, not
sampled. Broader descriptive profiling of the remaining ~500 low-value columns is deferred.

## 3. Column Inventory (DQ-relevant subset)

Candidate staging columns marked 🟢.

| Group | Column | Purpose (one line) | Stage? |
|-------|--------|--------------------|:------:|
| Identity | `Id` | Salesforce 18-char record id (PK). | 🟢 |
| Identity | `Name` | Derived full name (FirstName + LastName). | 🟢 |
| Identity | `FirstName` | Given name; required on web/crowdfunding. | 🟢 |
| Identity | `LastName` | Surname; required on **all** channels. | 🟢 |
| Identity | `RecordTypeId` | Record type; required for bulk upload. | 🟢 |
| System | `IsDeleted` | Soft-delete flag; excluded from staging. | 🟢 |
| System | `SystemModstamp` | Last system change; dedup/watermark order. | 🟢 |
| System | `CreatedDate` / `LastModifiedDate` | Audit dates. | 🟢 |
| Contact | `Email` | Primary email; required + **primary match key**. | 🟢 |
| Contact | `Phone` | Landline; required on web/crowdfunding. | 🟢 |
| Contact | `MobilePhone` | Mobile; My Jannah account requirement. | 🟢 |
| Address | `MailingStreet` | Street; part of address-required rule. | 🟢 |
| Address | `MailingCity` | City; part of address-required rule. | 🟢 |
| Address | `MailingState` | State/region; listed in client rule (88.6% empty). | 🟢 |
| Address | `MailingPostalCode` | Postcode; part of address-required rule. | 🟢 |
| Address | `MailingCountry` | Country; part of address-required rule. | 🟢 |
| Matching | `External_Id__c` | Integration dedup key (`Email_RegionalOffice`). | 🟢 |
| Matching | `Regional_Office_Code__c` | Regional office; component of External Id. | 🟢 |
| Gift Aid | `Gift_Aid_Status__c` | Gift Aid declaration status (client: Yes/No only). | 🟢 |
| Classification | `Is_Donor__c` | Donor flag. | 🟢 |
| ETL meta | `_etl_source`, `_etl_source_object`, `_etl_loaded_at_utc` | Lineage from CSV load. | 🟢 |

Not staged (examples): the ~500 remaining NPSP rollup / geocode / photo /社 legacy columns
(`npo02__*`, `MailingLatitude`, `PhotoUrl`, `Jigsaw*`, deprecated `Gift_Aid_Delcared__c` typo field).
Not needed for the current DQ rules; can be added later if a rule requires them.

## 4. Ordered Null and Data Presence Review

Full-population counts (n = 1,901,058). Ordered by DQ priority.

| Column | Null/blank | Null % | Distinct | Stage? | Why |
|--------|-----------:|-------:|---------:|:------:|-----|
| `Id` | 0 | .00% | 1,901,058 | ✅ | PK — clean, no dups. |
| `IsDeleted` | 0 | .00% | 2 | ✅ | 32 rows `true` → excluded from staging. |
| `SystemModstamp` | 0 | .00% | 1,901,058 | ✅ | Watermark/dedup order. |
| `LastName` | 183 | .01% | 363,619 | ✅ | Required all channels — 183 blanks = real defect. |
| `RecordTypeId` | 16 | .00% | 5 | ✅ | Required for bulk upload. |
| `Email` | 161,517 | 8.50% | 1,551,956 | ✅ | Required (client) + primary match key. |
| `MailingStreet` | 67,605 | 3.56% | 1,209,930 | ✅ | Address-required rule. |
| `MailingCity` | 143,107 | 7.53% | 75,189 | ✅ | Address-required rule. |
| `MailingPostalCode` | 117,499 | 6.18% | 356,062 | ✅ | Address-required rule. |
| `MailingCountry` | 49,163 | 2.59% | 213 | ✅ | Address-required rule. |
| `MailingState` | 1,683,298 | 88.55% | 332 | ✅ | Listed in client rule but 88.6% empty — see callout. |
| `External_Id__c` | 92,584 | 4.87% | 1,808,466 | ✅ | Matching key; 8 dup groups (16 rows). |
| `Regional_Office_Code__c` | 73 | .00% | 11 | ✅ | Matching key component. |
| `Gift_Aid_Status__c` | 198,606 | 10.45% | 3 | ✅ | Client Yes/No rule; `Unspecified`=352,838. |
| `FirstName` | 10,435 | .55% | 223,601 | ✅ | Required web/crowdfunding. |
| `Phone` | 535,235 | 28.15% | 1,182,265 | ✅ | Required web/crowdfunding. |
| `MobilePhone` | 1,567,839 | 82.47% | 273,828 | ✅ | My Jannah requirement. |
| `Is_Donor__c` | 0 | .00% | 2 | ✅ | Donor flag. |

### Top Null Columns (RAW) — highest first

| Rank | Column | Null % | Non-empty | Example | Why we care |
|-----:|--------|-------:|----------:|---------|-------------|
| 1 | `MailingState` | 88.55% | 217,760 | `Greater Manchester` | Listed in the client address rule, but almost never populated — **concerning if enforced literally** (see callout). |
| 2 | `MobilePhone` | 82.47% | 333,219 | `07795802467` | Blocks SMS channel + My Jannah account creation. **Expected-ish** (many CRM/bulk donors have no mobile). |
| 3 | `Phone` | 28.15% | 1,365,823 | `07795802467` | Web/crowdfunding require a phone; missing weakens contactability. **Concerning** for those channels. |
| 4 | `Gift_Aid_Status__c` | 10.45% | 1,702,452 | `No` | Missing blocks Gift Aid reclaim eligibility. **Concerning** (financial). |
| 5 | `Email` | 8.50% | 1,739,541 | `acegill2013@…` | Required by client + **primary matching key** — missing email forces the weaker `LastName_RegionalOffice` match. **Concerning**. |
| 6 | `MailingCity` | 7.53% | 1,757,951 | `CHEADLE` | Address completeness. **Concerning**. |
| 7 | `MailingPostalCode` | 6.18% | 1,783,559 | `SK8 3JR` | Address completeness + geographic reporting. **Concerning**. |
| 8 | `External_Id__c` | 4.87% | 1,808,474 | `acegill2013@…_UK` | 4.87% have no integration dedup key → duplicate risk. **Concerning**. |
| 9 | `MailingStreet` | 3.56% | 1,833,453 | `60 Roundhey` | Address completeness. **Concerning**. |
| 10 | `MailingCountry` | 2.59% | 1,851,895 | `United Kingdom` | Address completeness. **Concerning**. |
| 11 | `FirstName` | .55% | 1,890,623 | `Ace` | Web/crowdfunding required. **Mostly expected** (orgs/anon). |

**Expected empty:** `MobilePhone` (channel-dependent), most `npo02__*` rollups, `MailingLatitude/Longitude`.
**Concerning empty:** `Email`, `MailingCity/PostalCode/Street/Country`, `External_Id__c`, `Gift_Aid_Status__c`.

### ⚠️ Root-cause callout — `MailingState` in the client address rule
The client rule `Donor_Mailing_Address_Required` lists **Street, City, State, Country, Postal Code**.
`MailingState` is **88.55% empty** (1.68M of 1.9M). Enforcing State literally would flag ~88% of all
donors, which is clearly not how the org has operated. **Engineering decision:** `CON-004` enforces the
**core four** (Street, City, PostalCode, Country) and treats `MailingState` as **report-only** pending
stakeholder confirmation of whether State is genuinely mandatory. This is a policy question, not a defect.

## 5. STG Contact Coverage

| Staging column | Reason |
|----------------|--------|
| `Id` | PK, dedup, exception join. |
| `Name`, `FirstName`, `LastName` | Required-field rules + review readability. |
| `RecordTypeId` | Bulk-upload required check. |
| `Email` | Required rule + email-format rule + matching key. |
| `Phone`, `MobilePhone` | Channel completeness reporting. |
| `MailingStreet`, `MailingCity`, `MailingState`, `MailingPostalCode`, `MailingCountry` | Address-required rule. |
| `External_Id__c`, `Regional_Office_Code__c` | Matching integrity checks. |
| `Gift_Aid_Status__c` | Gift Aid controlled-value rule. |
| `Is_Donor__c` | Donor scoping. |
| `IsDeleted` | Dedup filter + `VALID_BOOLEAN` check. |
| `SystemModstamp` | Dedup order + watermark. |
| `_etl_source`, `_etl_source_object`, `_etl_loaded_at_utc` | Lineage/audit. |
| `staging_is_duplicate`, `staging_duplicate_count`, `staging_created_at`, `row_number` | Dedup pressure + framework compatibility. |

**Important raw columns not staged (yet):** `Has_Opted_Out_Of_SMS__c`, `HasOptedOutOfEmail`,
`Email_Single_Opt_In__c`, `SMS_Single_Opt_In__c` (GDPR consent — no rule approved yet); the ~500
NPSP rollup/geocode columns (not rule inputs).

## 6. Candidate Rule Ideas

### Client-provided validation rules (Human Appeal, their side)
| Client rule | Interpretation | DQ rule |
|-------------|----------------|---------|
| `Donor_Mailing_Address_Required` | Address (Street, City, State, Country, Postal Code) required | **CON-004** (core four; State report-only) |
| `Check_if_Gift_Aid_Validation_is_correct` | Gift Aid Status may only be `Yes` or `No` | **CON-007** (flags present-but-not-Yes/No, e.g. `Unspecified`) |
| `Email_Field_is_Significant` | Email required | **CON-005** |

### Engineering-safe (no business assumption)
- **CON-001** `Id` NOT_NULL · **CON-002** `Id` valid Salesforce Id · **CON-009** `IsDeleted` valid boolean.
- **CON-003** `LastName` NOT_NULL (min-info across all channels; 183 blanks).
- **CON-006** `Email` format invalid when present (508 rows fail a basic `x@y.z` shape) — mechanical.
- **CON-008** `External_Id__c` missing (92,584 blanks / 4.87%) — matching-key completeness.

### Report-only / stakeholder confirmation (no gate)
- **`Gift_Aid_Status__c` `Unspecified` (352,838) and NULL (198,606):** the client rule says Yes/No only.
  `Unspecified` is a large legacy population — **confirm** whether it must be remediated or accepted.
  NULL/blank is **not** gated (report-only) per DQ policy.
- **`MailingState` (88.55% empty):** confirm whether State is truly mandatory before gating.
- **`External_Id__c` duplicates (8 groups / 16 rows):** matching should keep External Id unique — report
  the 16 rows for review (kept out of the framework as a report-only finding to avoid a 1.9M self-join).
- **GDPR opt-in/opt-out consistency:** no rule until consent-field semantics are confirmed.
