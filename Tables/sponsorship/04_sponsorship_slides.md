---
marp: true
theme: default
paginate: true
size: 16:9
title: Sponsorship DQ Review
---

# Sponsorship DQ Review

SalesforceDW | raw.salesforce_sponsorship  
Donor-to-orphan sponsorship quality controls

228,229 raw records  
227,245 distinct IDs  
10 initial DQ rules

Read-only analysis. No Salesforce write-back is performed.

---

# Meeting Objective

Show the Sponsorship DQ scaffold and the rule areas that need first-run validation.

Ready now:
- Raw EDA exists.
- Staging/DQ PROD scaffold exists.
- Framework wrapper is prepared for controlled 200K-row first pass.

Not claimed yet:
- Full post-run exception counts are not final until execution.

---

# Execution Model

1. Source: raw.salesforce_sponsorship
2. Staging: staging.sponsorship_latest
3. Local review: staging.sponsorship_dq_exceptions_temp
4. Framework path: dq.dq_rule_catalog / dq.rule_execution_state
5. Evidence: sponsorship_staging_dq_ANALYSIS.md after run

---

# Raw Profile Snapshot

| Metric | Value |
|--------|------:|
| Raw rows | 228,229 |
| Distinct IDs | 227,245 |
| Raw columns | 99 |
| Clean columns | 56 |
| High-null columns | 31 |

Sensitive fields:
- Donor__c: 30.03% null/empty
- Recurring_Donation__c: 49.84% null/empty
- Sponsorship_Deactivation_Reason__c: 83.97% null/empty

---

# Rule Overview

- SP-001 to SP-002: Id completeness and format
- SP-003 to SP-004: active donor/orphan completeness
- SP-005: status and active-flag consistency
- SP-006: active recurring donation linkage
- SP-007: start/end date order
- SP-008: inactive termination reason
- SP-009 to SP-010: donor and recurring donation referential checks

---

# Review Focus

High-value first-run questions:

- Are active records ever valid without Donor__c?
- Are active records ever valid without Orphan__c?
- Is `Recurring_Donation__c` mandatory for every active sponsorship?
- Which inactive/terminated states require a deactivation reason?
- Is Contact loaded before enforcing donor reference checks?

---

# Run Recommendation

Run in this order:

1. Local PROD scaffold.
2. Review temp exceptions.
3. Framework wrapper with `@MaxRowsPerRule = 200000`.
4. Update the final analysis with actual counts.

Use full-population framework execution only after the first pass is reviewed.
