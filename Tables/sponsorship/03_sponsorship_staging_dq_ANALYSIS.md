# Sponsorship — DQ Analysis (Final)

Object: `Sponsorship` · Source: `raw.salesforce_sponsorship` · Staging: `staging.sponsorship_latest`
Framework run: **2026-08-01**.
Status: **Final.**

## 1. Executive Summary

| Metric | Value |
|---|---|
| Run date | 2026-08-01 |
| Raw rows (non-deleted) | 228,228 |
| Staging rows (latest per Id) | 227,244 |
| Rows collapsed by dedup | 984 |
| Rules in framework | 8 (SP-001..008) |
| PASS / FAIL | 4 PASS / 4 FAIL |
| Open exceptions | 62,414 |
| Distinct affected records | 61,978 (some fail >1 rule) |

### Severity split (open exceptions)
| Severity | Count |
|---|---:|
| CRITICAL | 0 |
| HIGH | 4,406 |
| MEDIUM | 58,008 |
| **Total** | **62,414** |

## 2. Table creation, dedup & staged-row evidence

`staging.sponsorship_latest` is rebuilt from `raw.salesforce_sponsorship`, deduped by `Id` (latest
`SystemModstamp`), excluding soft-deleted rows → **227,244 rows, 23 columns** (984 collapsed from 228,228
non-deleted raw).

**Dedup logic:**
```sql
WITH dedup AS (
  SELECT [Id],[IsDeleted],[SystemModstamp],
    ROW_NUMBER() OVER (
      PARTITION BY CONVERT(VARCHAR(18),[Id])
      ORDER BY COALESCE(TRY_CONVERT(DATETIME2(7),[SystemModstamp],127),
                        TRY_CONVERT(DATETIME2(7),[SystemModstamp])) DESC) AS rn
  FROM [raw].[salesforce_sponsorship]
  WHERE [Id] IS NOT NULL
)
SELECT * FROM dedup
WHERE rn=1
  AND COALESCE(LOWER(LTRIM(RTRIM(CONVERT(NVARCHAR(20),[IsDeleted])))),N'false')
      NOT IN (N'true',N'1',N'yes',N'y');
```

**Staging columns (23):**

| # | Column | # | Column |
|---|--------|---|--------|
| 1 | `row_number` | 13 | `End_Date_Time__c` |
| 2 | `Id` | 14 | `Sponsorship_Deactivation_Reason__c` |
| 3 | `IsDeleted` | 15 | `Campaign_Source__c` |
| 4 | `Name` | 16 | `Orphan_Country__c` |
| 5 | `CurrencyIsoCode` | 17 | `SystemModstamp` |
| 6 | `Status__c` | 18 | `_etl_source` |
| 7 | `IsActive__c` | 19 | `_etl_source_object` |
| 8 | `Donor__c` | 20 | `_etl_loaded_at_utc` |
| 9 | `Orphan__c` | 21 | `staging_is_duplicate` |
| 10 | `Recurring_Donation__c` | 22 | `staging_duplicate_count` |
| 11 | `Recurring_Donation_Status__c` | 23 | `staging_created_at` |
| 12 | `Start_Date_Time__c` | | |

**Staged-row evidence (SSMS-ready):**
```sql
SELECT TOP (2) [Id],[Status__c],[IsActive__c],[Donor__c],[Start_Date_Time__c],[End_Date_Time__c]
FROM staging.sponsorship_latest ORDER BY staging_created_at DESC;
```

| Id | Status | IsActive | Donor__c | Start | End |
|----|--------|----------|----------|-------|-----|
| a2C4J0000003nQZUAY | Sponsored | false | 0034J00000Tx7fwQAB | 2010-02-03 | 2014-07-31 |
| a2C4J0000003odsUAA | Sponsored | false | 0034J00000Kg8psQAB | 2015-07-16 | 2016-06-08 |

## 3. Rule Catalog Executed

| Rule | Severity | Check | Status | Open exc |
|---|---|---|:---:|---:|
| SP-001 | CRITICAL | Id not null/blank | PASS | 0 |
| SP-002 | CRITICAL | Id 15/18 chars | PASS | 0 |
| **SP-003** | **HIGH** | Active sponsorship must have `Donor__c` | **FAIL** | **399** |
| SP-004 | HIGH | Active sponsorship must have `Orphan__c` | PASS | 0 |
| SP-005 | HIGH | `Status__c` / `IsActive__c` consistent | PASS | 0 |
| **SP-006** | **MEDIUM** | Active should have `Recurring_Donation__c` | **FAIL** | **2,510** |
| **SP-007** | **HIGH** | Start date ≤ End date | **FAIL** | **4,007** |
| **SP-008** | **MEDIUM** | Terminated/Inactive needs deactivation reason | **FAIL** | **55,498** |

## 4. Zero-Finding Checks

4 of the 8 rules are clean: SP-001, SP-002, SP-004 (active items have Orphan), SP-005 (status/active
consistent). Identity and format are solid; the orphan linkage that matters most for this charity object
is fully populated on active records.

## 5. Rule Matches Requiring Review

### SP-008 — Terminated/Inactive without deactivation reason (MEDIUM, 55,498)
By far the largest signal — inactive sponsorships (`IsActive__c = false`) with no
`Sponsorship_Deactivation_Reason__c`. **Confirm the business rule first:** is a deactivation reason
mandatory for historical/legacy records, or only going forward? If legacy records were migrated without
it, this is a backfill, not a live defect.

```sql
SELECT TOP 10 [Id],[Status__c],[IsActive__c],[Sponsorship_Deactivation_Reason__c]
FROM staging.sponsorship_latest
WHERE LOWER(LTRIM(RTRIM(COALESCE([IsActive__c],'false'))))='false'
  AND NULLIF(LTRIM(RTRIM(COALESCE([Sponsorship_Deactivation_Reason__c],''))),'') IS NULL
ORDER BY [Id];
```

**Sample rule matches (actual output — top 6):**

| Id | Status__c | IsActive__c | Deactivation Reason |
|----|-----------|-------------|---------------------|
| a2C4J0000003mvhUAA | Sponsored | false | NULL |
| a2C4J0000003mviUAA | Sponsored | false | NULL |
| a2C4J0000003mvjUAA | Sponsored | false | NULL |
| a2C4J0000003mwaUAA | Sponsored | false | NULL |
| a2C4J0000003mwbUAA | Sponsored | false | NULL |
| a2C4J0000003mwcUAA | Sponsored | false | NULL |

**Stakeholder question:** Is a deactivation reason mandatory for legacy/terminated records, or only going forward?

### SP-007 — Start date after End date (HIGH, 4,007)
Date inversions where `Start_Date_Time__c` > `End_Date_Time__c`. Engineering-checkable; likely data-entry
or migration artifacts (several are same-day time inversions).

```sql
SELECT TOP 10 [Id],[Start_Date_Time__c],[End_Date_Time__c]
FROM staging.sponsorship_latest
WHERE TRY_CONVERT(datetime2,[Start_Date_Time__c]) > TRY_CONVERT(datetime2,[End_Date_Time__c])
ORDER BY [Id];
```

**Sample rule matches (actual output — top 6):**

| Id | Start_Date_Time__c | End_Date_Time__c |
|----|--------------------|------------------|
| a2C4J0000003t1ZUAQ | 2017-06-09T22:04 | 2017-06-09T11:00 |
| a2C4J000001McYeUAK | 2021-09-01T00:00 | 2021-02-01T12:00 |
| a2C8e0000008gdREAQ | 2023-04-03T16:11 | 2023-03-01T07:19 |
| a2C8e0000008gVpEAI | 2023-04-03T12:27 | 2022-09-30T01:00 |
| a2C8e0000008hUqEAI | 2023-05-01T00:00 | 2023-04-18T08:42 |
| a2C8e000000TecYEAS | 2022-08-14T00:00 | 2022-08-01T20:26 |

### SP-006 — Active sponsorship without recurring-donation link (MEDIUM, 2,510)
Active sponsorships not linked to a recurring donation.

```sql
SELECT TOP 10 [Id],[Status__c],[IsActive__c],[Recurring_Donation__c]
FROM staging.sponsorship_latest
WHERE LOWER(LTRIM(RTRIM(COALESCE([IsActive__c],'false'))))='true'
  AND NULLIF(LTRIM(RTRIM(COALESCE([Recurring_Donation__c],''))),'') IS NULL
ORDER BY [Id];
```

**Sample rule matches (actual output — top 6):**

| Id | Status__c | IsActive__c | Recurring_Donation__c |
|----|-----------|-------------|-----------------------|
| a2C8e000001YhJMEA0 | Sponsored | true | NULL |
| a2CN2000000FJyPMAW | Sponsored | true | NULL |
| a2CN2000000Hv57MAC | Sponsored | true | NULL |
| a2CN2000000k0eXMAQ | Sponsored | true | NULL |
| a2CN2000000KwuIMAS | Sponsored | true | NULL |
| a2CN2000000lESYMA2 | Sponsored | true | NULL |

**Stakeholder question:** Can an active sponsorship be funded another way (one-off, offline), or must every active one have an RD link?

### SP-003 — Active sponsorship without Donor (HIGH, 399)
399 active sponsorships with no `Donor__c`. High priority — an active sponsorship should have a donor.

```sql
SELECT TOP 10 [Id],[Status__c],[IsActive__c],[Donor__c]
FROM staging.sponsorship_latest
WHERE LOWER(LTRIM(RTRIM(COALESCE([IsActive__c],'false'))))='true'
  AND NULLIF(LTRIM(RTRIM(COALESCE([Donor__c],''))),'') IS NULL
ORDER BY [Id];
```

**Sample rule matches (actual output — top 6):**

| Id | Status__c | IsActive__c | Donor__c |
|----|-----------|-------------|----------|
| a2CN20000028XxKMAU | Sponsored By HA | true | NULL |
| a2CN20000028XxVMAU | Sponsored By HA | true | NULL |
| a2CN20000028XxZMAU | Sponsored By HA | true | NULL |
| a2CN2000002a2TZMAY | Sponsored By HA | true | NULL |
| a2CN2000002a8NhMAI | Sponsored By HA | true | NULL |
| a2CN2000002a8NiMAI | Sponsored By HA | true | NULL |

**Stakeholder question:** Should every active sponsorship have a Donor, or are some funded/managed centrally without one?

## 6. Rule Match Summary (ranked)

**Totals:** 62,414 open exceptions across **61,978 distinct affected sponsorships** (some fail more than
one rule). Only the 4 failing rules below produced matches; the other 4 rules PASS with 0.

### By severity
| Severity | Count | % of Total |
|----------|------:|-----------:|
| CRITICAL | 0 | 0.0% |
| HIGH | 4,406 | 7.1% |
| MEDIUM | 58,008 | 92.9% |
| **Total** | **62,414** | **100.0%** |

### By rule (ranked)
| Rank | Rule | Description | Matches | Severity |
|------|------|-------------|--------:|----------|
| 1 | SP-008 | Inactive without deactivation reason | 55,498 | MEDIUM |
| 2 | SP-007 | Start date after End date | 4,007 | HIGH |
| 3 | SP-006 | Active without recurring-donation link | 2,510 | MEDIUM |
| 4 | SP-003 | Active without Donor | 399 | HIGH |
| **Total** | | | **62,414** | |

## 7. Business Actions Required

| Rule | Count | Stakeholder question | Decision options | Owner | Deadline |
|------|------:|----------------------|------------------|-------|----------|
| SP-008 | 55,498 | Is a deactivation reason mandatory for legacy/terminated records? | Backfill history; enforce going forward only; drop rule | Sponsorship Business Owner | This week |
| SP-007 | 4,007 | Are Start > End dates migration artifacts or real errors? | Fix at source; accept legacy; exclude from date logic | Sponsorship + Data Eng | This week |
| SP-006 | 2,510 | Must every active sponsorship have an RD link? | Require RD; allow offline/one-off; monitor only | Fundraising Owner | Next week |
| SP-003 | 399 | Should every active sponsorship have a Donor? | Require donor; remediate at source | Sponsorship Business Owner | This week |

## 8. Most-Violating Records

```sql
SELECT TOP 5 e.record_id, COUNT(DISTINCT r.check_name) AS rules_failed,
       STRING_AGG(r.check_name, ', ') WITHIN GROUP (ORDER BY r.check_name) AS failed_rules
FROM dq.dq_exceptions e JOIN dq.dq_rule_catalog r ON r.rule_id=e.rule_id
WHERE r.object_name='Sponsorship' AND e.resolution_status='OPEN'
GROUP BY e.record_id ORDER BY rules_failed DESC;
```

**Actual output (top 5):**

| record_id | rules_failed | failed_rules |
|-----------|-------------:|--------------|
| a2C4J0000003t1ZUAQ | 2 | SP-007, SP-008 |
| a2CN2000000g2ILMAY | 2 | SP-007, SP-008 |
| a2CN2000000oZAfMAM | 2 | SP-007, SP-008 |
| a2CN2000000pv7VMAQ | 2 | SP-007, SP-008 |
| a2CN2000000VRdRMAW | 2 | SP-007, SP-008 |

Worst case = an inactive sponsorship that also inverts its dates (SP-008 + SP-007).

## 9. What's Stored Where + Framework Status

- ✅ Registered in `dq.dq_rule_catalog` — 8 Sponsorship rules. Framework run **2026-08-01**.
- ✅ 8 gated rules; 4 PASS / 4 FAIL; 0 CRITICAL.
- ⚠️ **`dq.dq_exceptions` holds 62,414 OPEN rows** across 61,978 sponsorships (SP-008 dominates at 55,498).
- ⚠️ Business review pending — exceptions stay `OPEN` until reviewed.
- ❌ No writeback to Salesforce (not enabled).

| Table | Rows | Status |
|-------|-----:|--------|
| `staging.sponsorship_latest` | 227,244 | latest-per-Id, 23 columns |
| `dq.dq_exceptions` (Sponsorship, OPEN) | 62,414 | official DQ layer — awaiting review |
| `dq.dq_rule_catalog` (Sponsorship) | 8 | all gated |

## 10. Sign-off & Next Meeting

**What we accomplished**
- Staged 227,244 sponsorships (984 duplicates collapsed).
- Ran 8 rules; 4 failing, 0 CRITICAL.
- 62,414 matches across 61,978 records; identified 4 business decisions.

**Decisions needed**
- [ ] SP-008 deactivation reason mandatory (legacy vs going-forward)? _______________
- [ ] SP-007 Start>End fix-at-source vs accept? _______________
- [ ] SP-006 must active have an RD link? _______________
- [ ] SP-003 require Donor on active? _______________

**Date:** _______________  **Attendees:** _______________

## 11. Recommendations

- **Confirm SP-008 policy** before treating 55,498 as defects — likely a migration backfill question.
- **Engineering-safe:** investigate the 4,007 SP-007 date inversions and the 399 SP-003 missing donors.
- **Promotion:** SP-001, SP-002, SP-004, SP-005 are clean and safe as production gates.
