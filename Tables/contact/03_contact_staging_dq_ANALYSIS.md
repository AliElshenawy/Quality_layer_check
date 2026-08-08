# 03 — Contact Staging + DQ Analysis (run results)

> Run executed: **2026-08-05** via [`02_contact_staging_dq_PROD_framework.sql`](02_contact_staging_dq_PROD_framework.sql)
> Framework: `dq.dq_rule_catalog` + `dq.rule_execution_state` + `dq.run_incremental_catalog_rules`
> Exceptions written to the official layer `dq.dq_exceptions` (all `OPEN` — read-only, no write-back).

---

## 0. Validation-rule additions — 2026-08-07 (Salesforce active validation rules)

Source: `shared files/The Team/20260804 active validation rules.tsv` (live Salesforce org validation
rules). **Five** Contact rules were mapped into `dq.dq_rule_catalog` using the `-VR-` provenance namespace
and run incrementally full-population (no sample). To enable CON-VR-004/005, `staging.contact_latest` was
widened with the orphan/guardian columns. Contact rule count **9 → 14**.

| Rule | Source SF validation rule | Type | Severity | Open exceptions (full pop) |
|------|---------------------------|------|----------|---------------------------:|
| `CON-VR-001` | `Comma_Not_Allowed_Mobile` | CUSTOM_SQL | LOW | **7** |
| `CON-VR-002` | `Comma_Not_Allowed_MailingCity` | CUSTOM_SQL | LOW | **7,048** |
| `CON-VR-003` | `Comma_Not_Allowed_Guardian_Id` | CUSTOM_SQL | LOW | **0** (PASS — clean) |
| `CON-VR-004` | `If_Mother_Is_Guardian_is_False` | CUSTOM_SQL | MEDIUM | **4,259** |
| `CON-VR-005` | `IF_Mother_not_alive` | CUSTOM_SQL | MEDIUM | **693** |

Both are **engineering-safe format checks** (a comma is disallowed by Salesforce; use `;`). They are not a
business-policy decision — the fix is mechanical (replace `,` with `;`), so they route to a writeback
correction, not to stakeholders.

### CON-VR-001 — MobilePhone contains a comma (7)
```sql
SELECT TOP 10 [Id], [MobilePhone] FROM staging.contact_latest WHERE [MobilePhone] LIKE '%,%';
```
| Id | MobilePhone (sample) |
|----|----------------------|
| 0034J00000XtcGyQAJ | `,` (lone comma) |
| 003N200000jdUUAIA2 | `+2567811•••••, +2567636•••••` |
| 003N200000QdEBWIA3 | `+2349090••••• - WhatsApp, +4473660•••••` |

### CON-VR-002 — MailingCity contains a comma (7,048)
```sql
SELECT TOP 10 [Id], [MailingCity] FROM staging.contact_latest WHERE [MailingCity] LIKE '%,%';
```
| Id | MailingCity (sample) |
|----|----------------------|
| 0034J00000aF3DKQA0 | `Waltham Forest, London` |
| 0034J00000aFgIKQA0 | `Purley,Surrey` |
| 0034J00000aFR3GQAW | `Stockton on tees,` (trailing comma) |

**Business action:** none required — mechanical fix. Candidate for the writeback auto-fix queue: split on
`,` → `;`, preserve the pre-fix value in `dq.dq_exceptions`. Exceptions remain `OPEN` until the writeback
loop applies the correction.

### CON-VR-003 — Guardian Id contains a comma (0 — clean)
Full-population scan of 1,901,026 rows returned **0** — no `Guardian_ID__c` holds a comma. PASS.

### CON-VR-004 — Mother not guardian but guardian details incomplete (4,259)
Fires only where `Orphan_Mother_Is_Guardian__c = 'no'` (7,607 records); 4,259 are missing at least one of
Guardian First/Last Name, Relationship, or Mother-Not-Guardian Reason. **Business/completeness review.**
```sql
SELECT TOP 10 [Id], [Orphan_Guardian_First_Name__c], [Oprhan_Guardian_Last_Name__c],
       [Orphan_Guardian_Relationship__c], [Orphan_Mother_Not_Guardian_Reason__c]
FROM   staging.contact_latest
WHERE  LOWER(LTRIM(RTRIM([Orphan_Mother_Is_Guardian__c]))) = 'no'
  AND (NULLIF(LTRIM(RTRIM(COALESCE([Orphan_Guardian_First_Name__c],''))),'') IS NULL
    OR NULLIF(LTRIM(RTRIM(COALESCE([Oprhan_Guardian_Last_Name__c],''))),'') IS NULL
    OR NULLIF(LTRIM(RTRIM(COALESCE([Orphan_Guardian_Relationship__c],''))),'') IS NULL
    OR NULLIF(LTRIM(RTRIM(COALESCE([Orphan_Mother_Not_Guardian_Reason__c],''))),'') IS NULL);
```
| Id | exception_value (sample) |
|----|--------------------------|
| 0034J00000aFQ37QAG | `GFirst=Ezat;GLast=Mohammed Kamal Alnono;Rel=Brother;Reason=(null)` |
| 0034J00000aFQ3TQAW | `GFirst=Sobia;GLast=Khatoon;Rel=Sister;Reason=(null)` |

### CON-VR-005 — Mother not alive but death details incomplete (693)
Fires only where `Orphan_Is_Mother_Alive__c = 'no'` (2,231 records); 693 miss cause/date-of-death or
verification method. **Business/completeness review.**
| Id | exception_value (sample) |
|----|--------------------------|
| 0034J00000fFZvVQAW | `Cause=(null);DoD=(null);Method=(null)` |
| 0034J00000Xta4NQAR | `Cause=(null);DoD=(null);Method=(null)` |

### Salesforce validation rules NOT implemented (and why)

Other Contact validation rules from the TSV were **not** turned into DQ rules. Reasons fall into three
classes: **(A) ambiguous trigger** — the *when* is a business condition not defined in staged data, so
gating would mean inventing policy (the DQ instruction forbids this); **(P) permission/authorization guard**
(depends on the acting user, not stored data); **(T) state-transition guard** (needs before/after state).

| SF validation rule | Class | Why we can't run it | Path to enable |
|--------------------|:-----:|---------------------|----------------|
| `CHY3_Received_Date_Required` | A | the CHY3 date columns are staged, but *when* CHY3 dates are required (which donors) is undefined | confirm the trigger (e.g. Gift-Aid-qualified) with stakeholders, then gate |
| `CHY3_Send_Date_Required` | A | same — the send-date requirement condition is undefined | confirm trigger, then gate |
| `Mandatory_University_Related_Feild` | A | Major/Year columns are staged, but “education level = University” is not identifiable in staging | stage an education-level field / confirm trigger |
| `Orphan_Mailing_Address_Required` | A | address is staged, but the orphan RecordType is not identified in staging | confirm orphan `RecordTypeId`, then gate |
| `Field_Officers_Should_Not_Inactive_Orpha` | P | enforces *who* may deactivate an orphan — a permission, not a data value | not warehouse-checkable (Salesforce-only) |
| `Cannot_Re_Activate_Oprhan_Directly` | T/P | blocks a reactivation *action*; needs before/after + the approval flow | not warehouse-checkable |

> **Now implemented** (were Class C, enabled by widening staging): `Comma_Not_Allowed_Guardian_Id`
> → CON-VR-003, `If_Mother_Is_Guardian_is_False` → CON-VR-004, `IF_Mother_not_alive` → CON-VR-005.
>
> **No join rules here.** None of the remaining Contact rules require a join, so the “complicated-join /
> empty-table” skip rule doesn't apply to Contact. That skip class applies to cross-object rules on other
> objects — e.g. Sponsorship_Unit `Validate_Allocation_Sponsorship` joins the **empty** `Item Allocation`
> table, so it stays deferred (`is_active = 0`) until that table is loaded.

---

## 1. Executive Summary

| Item | Value |
|------|-------|
| Run date | 2026-08-05 |
| Database | SalesforceDW |
| Object | Contact |
| Status | Completed — 9 rules run (3 PASS, 6 FAIL, 0 error) |
| Staging records | **1,901,026** |
| Raw records | 1,901,058 |
| Deleted removed | 32 |
| Duplicate Ids removed | 0 (raw already had 0 duplicate Ids) |
| Total open exceptions | **858,899** |
| Distinct affected records | **554,496** (29.2% of staged donors) |
| CRITICAL / HIGH / MEDIUM / LOW | 0 / 412,971 / 445,928 / 0 |

## 2. Null Analysis (RAW vs Staging)

Highest-null DQ-relevant columns (full population, n = 1,901,058). All are carried into staging.

| Column | Null % (raw) | In staging? | Verdict |
|--------|-------------:|:-----------:|---------|
| `MailingState` | 88.55% | ✅ | **Report-only** — not enforced by CON-004 (would flag 88%). |
| `MobilePhone` | 82.47% | ✅ | Expected (channel-dependent). |
| `Phone` | 28.15% | ✅ | Concerning for web/crowdfunding donors. |
| `Gift_Aid_Status__c` | 10.45% (NULL) | ✅ | NULL not gated; `Unspecified`(352,836) gated by CON-007. |
| `Email` | 8.50% | ✅ | Real DQ concern — CON-005 (161,517). |
| `MailingCity` | 7.53% | ✅ | Feeds CON-004. |
| `MailingPostalCode` | 6.18% | ✅ | Feeds CON-004. |
| `External_Id__c` | 4.87% | ✅ | CON-008 (92,584). |
| `MailingStreet` | 3.56% | ✅ | Feeds CON-004. |
| `MailingCountry` | 2.59% | ✅ | Feeds CON-004. |

## 3. Evidence Snapshot

**Table check — sample staged rows** (`staging.contact_latest`):

```sql
SELECT TOP (2) [Id],[LastName],[FirstName],[Email],[MailingCity],[MailingCountry],[Gift_Aid_Status__c],[External_Id__c]
FROM   staging.contact_latest
ORDER  BY staging_created_at DESC;
```

| Id | LastName | FirstName | Email | MailingCity | MailingCountry | Gift_Aid_Status__c | External_Id__c |
|----|----------|-----------|-------|-------------|----------------|--------------------|----------------|
| 003N2000003OU9mIAG | Jamieson | Abbie | abbiejamieson15@…​ | bourne | United Kingdom | Unspecified | abbiejamieson15@…_uk |
| 003N200000BhWsqIAF | Manning | Clive | ccmanning113@…​ | Sudbury | United Kingdom | Yes | ccmanning113@…_uk |

**Rule run output (actual):**

| rule | severity | rows_checked | failed | status |
|------|----------|-------------:|-------:|--------|
| CON-001 Id NOT_NULL | CRITICAL | 1,901,026 | 0 | PASS |
| CON-002 Id VALID_SALESFORCE_ID | CRITICAL | 1,901,026 | 0 | PASS |
| CON-003 LastName NOT_NULL | HIGH | 1,901,026 | 183 | FAIL |
| CON-004 Mailing address (core four) | HIGH | 1,901,026 | 251,271 | FAIL |
| CON-005 Email required | HIGH | 1,901,026 | 161,517 | FAIL |
| CON-006 Email format | MEDIUM | 1,901,026 | 508 | FAIL |
| CON-007 Gift Aid ≠ Yes/No (present) | MEDIUM | 1,901,026 | 352,836 | FAIL |
| CON-008 External_Id missing | MEDIUM | 1,901,026 | 92,584 | FAIL |
| CON-009 IsDeleted VALID_BOOLEAN | HIGH | 1,901,026 | 0 | PASS |

## 4. Table Creation and Population

Staging built by dedup on `Id`, keeping the latest `SystemModstamp`, excluding deleted rows:

```sql
WITH dedup AS (
  SELECT ...,
    ROW_NUMBER() OVER (PARTITION BY CONVERT(VARCHAR(18),[Id])
                       ORDER BY COALESCE(TRY_CONVERT(DATETIME2(7),[SystemModstamp],127),
                                         TRY_CONVERT(DATETIME2(7),[SystemModstamp])) DESC) AS rn,
    COUNT(*) OVER (PARTITION BY [Id]) AS dup_cnt
  FROM [raw].[salesforce_contact] WHERE [Id] IS NOT NULL)
INSERT INTO staging.contact_latest (...)
SELECT ... FROM dedup
WHERE rn = 1
  AND COALESCE(LOWER(LTRIM(RTRIM(CONVERT(NVARCHAR(20),[IsDeleted])))),'false')
      NOT IN ('true','1','yes','y');
```

Result: 1,901,058 raw − 32 deleted = **1,901,026** staged (0 duplicate Ids).

### Final staging columns (25)

| # | Column | # | Column | # | Column |
|--:|--------|--:|--------|--:|--------|
| 1 | row_number | 10 | MobilePhone | 19 | Is_Donor__c |
| 2 | Id | 11 | MailingStreet | 20 | SystemModstamp |
| 3 | Name | 12 | MailingCity | 21 | _etl_source |
| 4 | FirstName | 13 | MailingState | 22 | _etl_source_object |
| 5 | LastName | 14 | MailingPostalCode | 23 | _etl_loaded_at_utc |
| 6 | RecordTypeId | 15 | MailingCountry | 24 | staging_is_duplicate |
| 7 | IsDeleted | 16 | External_Id__c | 25 | staging_duplicate_count |
| 8 | Email | 17 | Regional_Office_Code__c | | staging_created_at |
| 9 | Phone | 18 | Gift_Aid_Status__c | | |

## 5. Rule Catalog Executed

| Rule | Description | Severity | Category | Result |
|------|-------------|----------|----------|-------:|
| CON-001 | Id not null | CRITICAL | Integrity | 0 |
| CON-002 | Id valid Salesforce Id | CRITICAL | Integrity | 0 |
| CON-003 | LastName not null | HIGH | Required field | 183 |
| CON-004 | Mailing address core-four complete | HIGH | Client rule | 251,271 |
| CON-005 | Email required | HIGH | Client rule | 161,517 |
| CON-006 | Email format valid | MEDIUM | Mechanical | 508 |
| CON-007 | Gift Aid Status Yes/No only | MEDIUM | Client rule | 352,836 |
| CON-008 | External_Id present | MEDIUM | Matching | 92,584 |
| CON-009 | IsDeleted valid boolean | HIGH | Integrity | 0 |

## 6. Zero-Finding Checks

- **CON-001 / CON-002 (Id):** every staged row has a valid 18-char Salesforce Id — clean PK, safe to join on.
- **CON-009 (IsDeleted):** staging already excludes deleted rows and all remaining tokens are `false` — 0, as expected.

## 7. Rule Matches Requiring Review

### CON-004 — Mailing address incomplete (core four) · 251,271 · HIGH
Missing at least one of Street / City / PostalCode / Country. Client rule `Donor_Mailing_Address_Required`.
```sql
SELECT TOP 10 [Id],[MailingStreet],[MailingCity],[MailingPostalCode],[MailingCountry]
FROM staging.contact_latest
WHERE NULLIF(LTRIM(RTRIM(COALESCE([MailingStreet],''))),'') IS NULL
   OR NULLIF(LTRIM(RTRIM(COALESCE([MailingCity],''))),'') IS NULL
   OR NULLIF(LTRIM(RTRIM(COALESCE([MailingPostalCode],''))),'') IS NULL
   OR NULLIF(LTRIM(RTRIM(COALESCE([MailingCountry],''))),'') IS NULL;
```
> ⚠️ **State callout:** the literal client rule also lists **State**, which is 88.55% empty. CON-004 deliberately
> excludes State to avoid flagging ~1.68M donors. **Stakeholder question:** is State genuinely mandatory?

### CON-005 — Email missing · 161,517 · HIGH
Client rule `Email_Field_is_Significant`; email is also the primary matching key, so a missing email forces
the weaker `LastName_RegionalOffice` match and raises duplicate risk.
```sql
SELECT TOP 10 [Id],[LastName],[External_Id__c]
FROM staging.contact_latest
WHERE NULLIF(LTRIM(RTRIM(COALESCE([Email],''))),'') IS NULL;
```

### CON-006 — Email present but malformed · 508 · MEDIUM (engineering-safe)
Sample actual output (top 5):

| Id | Email |
|----|-------|
| 0034J00000bquVSQAY | sihem_305@yahoo.r |
| 0034J00000bqzEYQAY | a@a.a |
| 0038e000003MR3ZAAW | ali1994.as@mail.r |
| 0038e000005tu8lAAA | zakiyyahbibi25@gmail.c |
| 0038e000007QEC2AAO | maymun@live.o |

> **Root-cause / mechanical:** these are truncated top-level domains (`.r`, `.c`, `.o`) or placeholder
> `a@a.a`. Not a business decision — fix at source or via a validated re-capture. Engineering-safe.

### CON-007 — Gift Aid Status not Yes/No · 352,836 · MEDIUM (client-approved list, review the population)
All 352,836 are the single value **`Unspecified`**. NULL/blank (198,606) is **not** gated (report-only).
```sql
SELECT [Gift_Aid_Status__c], COUNT(*) AS cnt
FROM staging.contact_latest
GROUP BY [Gift_Aid_Status__c] ORDER BY cnt DESC;
```
Distinct values observed: `No` (1,087,070) · `Unspecified` (352,836) · `Yes` (262,543) · NULL (198,580).
> **Stakeholder question:** the client rule says Yes/No only. Is legacy `Unspecified` acceptable, or must it
> be remediated to Yes/No? This is a large population (18.6% of donors) — confirm before any write-back.

### CON-008 — External_Id missing · 92,584 · MEDIUM
Matching/dedup key blank → these donors bypass integration duplicate prevention.
```sql
SELECT TOP 10 [Id],[Email],[Regional_Office_Code__c]
FROM staging.contact_latest
WHERE NULLIF(LTRIM(RTRIM(COALESCE([External_Id__c],''))),'') IS NULL;
```

### CON-003 — LastName missing · 183 · HIGH
LastName is the one field required on every channel; 183 blanks are true defects to correct at source.

## 8. Rule Match Summary (ranked)

**By severity:**

| Severity | Count | % of total |
|----------|------:|-----------:|
| CRITICAL | 0 | 0.0% |
| HIGH | 412,971 | 48.1% |
| MEDIUM | 445,928 | 51.9% |
| LOW | 0 | 0.0% |
| **Total** | **858,899** | 100% |

**By rule (ranked):**

| Rank | Rule | Description | Matches | Severity |
|-----:|------|-------------|--------:|----------|
| 1 | CON-007 | Gift Aid ≠ Yes/No (Unspecified) | 352,836 | MEDIUM |
| 2 | CON-004 | Mailing address incomplete | 251,271 | HIGH |
| 3 | CON-005 | Email missing | 161,517 | HIGH |
| 4 | CON-008 | External_Id missing | 92,584 | MEDIUM |
| 5 | CON-006 | Email malformed | 508 | MEDIUM |
| 6 | CON-003 | LastName missing | 183 | HIGH |
| | | **Total** | **858,899** | |

Total open exceptions **858,899** across **554,496 distinct donors** (one donor can fail several rules).

## 9. Business Actions Required

| Rule | Count | Stakeholder question | Decision options | Owner | Deadline |
|------|------:|----------------------|------------------|-------|----------|
| CON-007 | 352,836 | Is legacy Gift Aid `Unspecified` acceptable? | Accept legacy / remediate to Yes/No / backfill | Fundraising + Compliance | TBD |
| CON-004 + State | 251,271 | Is `MailingState` genuinely mandatory (88.6% empty)? | Enforce core four only / add State / relax | Data Governance | TBD |
| CON-005 | 161,517 | Backfill / accept email-less donors? | Backfill / accept (CRM & bulk) | Fundraising Ops | TBD |
| CON-008 | 92,584 | Regenerate missing External Ids? | Regenerate from Email+RegOffice / accept | Integration | TBD |
| CON-003 / CON-006 (mechanical) | 691 | — (engineering fix at source) | Correct 183 blank surnames + 508 malformed emails | Data Engineering | TBD |

## 10. Most-Violating Records

```sql
SELECT TOP (6) e.record_id, COUNT(DISTINCT r.check_name) AS rules_failed,
   STRING_AGG(r.check_name, ', ') WITHIN GROUP (ORDER BY r.check_name) AS failed_rules
FROM dq.dq_exceptions e JOIN dq.dq_rule_catalog r ON r.rule_id=e.rule_id
WHERE r.object_name='Contact' AND e.resolution_status='OPEN'
GROUP BY e.record_id ORDER BY rules_failed DESC;
```

| record_id | rules_failed | failed_rules |
|-----------|:-----------:|--------------|
| 0034J00000aFMK6QAO | 4 | CON-004, CON-005, CON-007, CON-008 |
| 0034J00000aGl3lQAC | 4 | CON-004, CON-005, CON-007, CON-008 |
| 0034J00000aGl5nQAC | 4 | CON-004, CON-005, CON-007, CON-008 |
| 0034J00000aGl5qQAC | 4 | CON-004, CON-005, CON-007, CON-008 |
| 0034J00000aGl5rQAC | 4 | CON-004, CON-005, CON-007, CON-008 |
| 0034J00000aGl5sQAC | 4 | CON-004, CON-005, CON-007, CON-008 |

The worst records fail **4 rules at once**: no complete mailing address, no email, Gift Aid `Unspecified`,
and no External Id — i.e. donors with almost no usable contact/matching data. No record fails more than 4.

## 11. What's Stored Where + Framework Status

| Store | Contents |
|-------|----------|
| `staging.contact_latest` | 1,901,026 deduped, non-deleted donors (25 cols) |
| `dq.dq_rule_catalog` | 9 CON rules (all `is_active=1`), run 2026-08-05 |
| `dq.dq_exceptions` | 858,899 OPEN Contact exceptions |
| `dq.rule_execution_state` | 9 CON rows, watermark = 2026-07-27 11:14:20 |

Exceptions remain `OPEN` until reviewed. **Write-back is not enabled** (read-only DQ).

## 12. Sign-off & Next Meeting

**What we accomplished**
- Loaded Contact (1.9M rows) and built a deduped staging donor table.
- Encoded the 3 client validation rules into the DQ framework + 6 engineering-safe checks.
- Produced full-population evidence: 858,899 exceptions across 554,496 donors.

**Decisions needed** (tick when agreed)
- [ ] Is `MailingState` mandatory? (CON-004 scope)
- [ ] Accept or remediate Gift Aid `Unspecified` (352,836)? (CON-007)
- [ ] Backfill missing emails (161,517)? (CON-005)
- [ ] Regenerate missing External Ids (92,584)? (CON-008)
- [ ] Approve engineering fix for 183 blank surnames + 508 malformed emails?

Date: ____________  Attendees: ____________

## 13. Recommendations

- **Engineering-safe now:** correct the 183 blank `LastName` and 508 malformed emails at source; regenerate
  External Ids where `Email` + `Regional_Office_Code__c` both exist.
- **Stakeholder policy:** confirm State mandatory-ness and the Gift Aid `Unspecified` treatment before any
  remediation or write-back.
- **Framework:** the 9 CON rules are promoted and running incrementally; future loads re-check only rows with
  a newer `SystemModstamp`.
- **Report-only (no gate):** Gift Aid NULL/blank, `MailingState`, and External_Id duplicates (8 groups/16 rows)
  remain review-only findings.
