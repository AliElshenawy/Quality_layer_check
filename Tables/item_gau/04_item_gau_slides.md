---
marp: true
theme: default
paginate: true
size: 16:9
title: Item_GAU DQ Framework Review
---

# Item_GAU DQ Framework Review

SalesforceDW | raw.salesforce_item  
Data Quality Rules and Field-by-Field Analysis

31,391 raw records  
30,815 staged latest records  
26 framework rules

Read-only analysis. No Salesforce write-back is performed.

---

# Meeting Objective

Show how Item_GAU moved from raw profiling to framework-backed DQ rules.

Ready now:
- Staging is built and deduplicated.
- Core and expanded DQ rules are registered.
- Current failures are isolated to six review areas.

Business question: Which remaining failures are source defects, and which are valid operating patterns?

---

# Execution Model

1. Source: raw.salesforce_item
2. Staging: staging.item_gau_latest
3. Rules: GAU-001 to GAU-026
4. Framework: dq.dq_rule_catalog and dq.rule_execution_state
5. Evidence: item_gau_staging_dq_ANALYSIS.md and null-profile CSVs

---

# Baseline Metrics

- Raw rows: 31,391
- Raw non-deleted rows: 31,390
- Staging rows: 30,815
- Duplicate rows removed: 574
- Raw columns profiled: 133

Null-profile summary:
- Clean columns: 64
- Low-null columns: 13
- Medium-null columns: 10
- High-null columns: 46

---

# Staging Coverage

Staging expanded in controlled cycles.

Included groups:
- Identity and dedup fields
- Active/currency fields
- Product and programme classification
- Country, campaign, regional office
- Donation control flags
- Financial check columns
- ETL lineage and staging audit fields

Rule-driven staging avoids moving all 133 raw columns into operational DQ.

---

# Rule Overview

- GAU-001 to GAU-006: baseline structure and controlled values
- GAU-007 to GAU-012: business classification and relationship checks
- GAU-013 to GAU-019: uniqueness, office/frequency, and allocation controls
- GAU-020 to GAU-026: financial null and numeric controls

---

# Current Results

Open review items:

| Rule | Count | Review topic |
|------|------:|--------------|
| GAU-010 | 955 | Active Fund/Project items without Country |
| GAU-011 | 231 | Inactive status with active flag true |
| GAU-018 | 333 | Sponsorship/Ticket allow flags |
| GAU-024 | 8 | Non-numeric non-zakat credit |
| GAU-025 | 2 | Non-numeric zakat credit |
| GAU-026 | 8 | Non-numeric allocation total |
| GAU-VR-001 | 448 | Inactive items still holding unspent Zakat/Non-Zakat funds |

---

# Decision Points

- Confirm Country requirement for active Fund and Project items.
- Decide whether inactive status plus active flag is transitional or a hard error.
- Confirm allow-flag expectations for Sponsorship and Ticket items.
- Fix non-numeric financial values at source or approve a cleansing rule.
- Review 448 inactive items that still hold unspent funds (Salesforce blocks deactivation until funds are spent) — who reallocates, and by when?

---

# Recommendation

Approve the framework structure and focus the next cycle on the six remaining exceptions. The financial non-numeric issues are small and likely source-fix candidates; the active/country and allow-flag rules need business policy confirmation.
