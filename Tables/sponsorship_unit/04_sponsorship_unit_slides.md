---
marp: true
theme: default
paginate: true
size: 16:9
title: Sponsorship Unit DQ Review
---

# Sponsorship Unit DQ Review

SalesforceDW | raw.salesforce_sponsorship_unit  
High-volume child-table quality controls

1,291,058 raw records  
1,291,058 distinct IDs  
9 initial DQ rules

Read-only analysis. No Salesforce write-back is performed.

---

# Meeting Objective

Show the Sponsorship Unit DQ scaffold and the safe first-run plan for a high-volume table.

Ready now:
- CSV EDA and SQL QA exist.
- Local PROD DQ scaffold exists.
- Framework wrapper is prepared for a 200K-row first pass.

Not claimed yet:
- Full rule counts are pending execution.

---

# Execution Model

1. Source: raw.salesforce_sponsorship_unit
2. Staging: staging.sponsorship_unit_latest
3. Local review: staging.sponsorship_unit_dq_exceptions_temp
4. Framework: dq.dq_rule_catalog and dq.rule_execution_state
5. Evidence: sponsorship_unit_staging_dq_ANALYSIS.md after run

---

# Raw Profile Snapshot

| Metric | Value |
|--------|------:|
| Raw rows | 1,291,058 |
| Distinct IDs | 1,291,058 |
| Raw columns | 25 |
| Clean columns | 19 |
| High-null columns | 5 |

High-null fields are mostly optional deferred amount/context fields plus fully blank activity/orphan account fields.

---

# Rule Overview

- SU-001 to SU-002: Id completeness and format
- SU-003 to SU-004: mandatory Sponsorship parent and parent existence
- SU-005 to SU-006: deferred amount and local currency consistency
- SU-007: donation date validity
- SU-008: GAU allocation reference integrity
- SU-009: unit linked to deleted sponsorship check

---

# Review Focus

First-run questions:

- Are all `Sponsorship__c` references present in parent Sponsorship?
- Is `GAU_Allocation__c` source loaded and reliable enough for SU-008?
- Are deferred GBP/LC blanks valid because most rows are not deferred?
- Should negative deferred GBP ever be allowed?
- Are deleted parent sponsorships expected to retain unit history?

---

# Run Recommendation

Run in this order:

1. Local PROD scaffold.
2. Review temp exceptions.
3. Framework wrapper with `@MaxRowsPerRule = 200000`.
4. Update final analysis with counts and top failing rules.

Full-population execution should wait until the 200K pass is reviewed.
