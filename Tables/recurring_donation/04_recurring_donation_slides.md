---
marp: true
theme: default
paginate: true
size: 16:9
title: Recurring Donation DQ Review
---

# Recurring Donation DQ Review

SalesforceDW | raw.salesforce_recurring_donation  
NPSP recurring giving quality checks

261,577 raw records  
258,465 staged latest records  
23 framework rules (16 pass / 7 fail)

Read-only analysis. No Salesforce write-back is performed.

---

# Meeting Objective

Show the current Recurring Donation staging and framework DQ status.

Ready now:
- Staging is built and deduplicated.
- RD-001 to RD-023 are registered and executed in the framework.
- 16 rules pass; 7 need review (1 is a false alarm).

Business question: Which failed rules are true donor/payment defects versus migration or governance cleanup?

---

# Execution Model

1. Source: raw.salesforce_recurring_donation
2. Staging: staging.recurring_donation_latest
3. Framework: dq.dq_rule_catalog and dq.rule_execution_state
4. Results: dq.dq_results and dq.dq_exceptions
5. Evidence: recurring_donation_staging_dq_ANALYSIS.md

Large-table note: exploratory profiling can use 200,000 rows before full-population approval.

---

# Baseline Metrics

| Metric | Value |
|--------|------:|
| Raw rows | 261,577 |
| Distinct raw IDs | 258,465 |
| Staging rows | 258,465 |
| Duplicate rows removed | 3,112 |
| Staging columns | 31 |
| Framework rules | 23 |
| Records with a failure | 54,795 |

---

# Rule Overview

- Identity and format: RD-001, RD-002
- Donor completeness: RD-003
- Amount and numeric checks: RD-004, RD-016, RD-017, RD-018, RD-019, RD-020
- Status and lifecycle: RD-005, RD-007, RD-011, RD-015, RD-023
- Schedule and payment: RD-006, RD-010, RD-012, RD-022
- Referential checks: RD-008, RD-009
- Classification: RD-013, RD-014, RD-021

RD-018 to RD-023 were added after data investigation (5 are clean guards; RD-023 found 90 real issues).

---

# Current Rule Findings

| Rule | Failures | Interpretation |
|------|---------:|----------------|
| RD-015 | 79,000 | Closed reason missing |
| RD-007 | 19,864 | Start date after end date |
| RD-012 | 129 | Payment method normalization (`SEPA`) |
| RD-008 | 100 capped | Contact table not loaded (false alarm) |
| RD-023 | 90 | Active donation with no next payment date |
| RD-003 | 57 | Missing donor contact/org |
| RD-005 | 1 | Status outside allowed list |

Worst records break 3 rules each (RD-007 + RD-008 + RD-015).

---

# Known Limitation

RD-008 depends on `raw.salesforce_contact`.

Current state:
- Contact table has 0 rows.
- RD-008 is capped at 100 exceptions.
- This is an upstream load readiness issue, not proof of bad recurring donation data.

Decision needed: rerun RD-008 at full scope only after Contact is loaded.

---

# Decisions Needed

- Is a **closed reason mandatory** for closed donations? (RD-015 — 79,000)
- Are **start/end date** failures migration artifacts or hard defects? (RD-007 — 19,864)
- Should **`SEPA`** be an approved payment method? (RD-012 — 129)
- Should an **active** donation always have a **next payment date**? (RD-023 — 90)
- The 57 donations with **no donor** — fix at source or exclude? (RD-003)
- When Contact is loaded, turn **RD-008** into a hard referential rule.

---

# Open Data Questions

- **`Total_Donation_Amount__c` meaning:** it is the recurring amount, not the lifetime total (Paid can far exceed it). Confirm before any "paid vs total" rule.
- **At-risk donors:** 3,286 active donations have 3+ failed payments — do you want an alert rule, and at what threshold?
- **Open vs Fixed lifecycle:** many Open have end dates and many Fixed have none — confirm the expected rule.

---

# Recommendation

Keep RD-001 to RD-023 active in the framework. Treat RD-008 as blocked by the Contact load, prioritize RD-015 and RD-007 for business review, add `SEPA` to the payment-method list (RD-012), and investigate the 90 active donations with no next payment date (RD-023).
