# AIHI
## AI FOR HUMANITARIAN IMPACT

Campaign Object  
Data Quality Rules and Field-by-Field Analysis  
Human Appeal - Salesforce Campaign to SQL Server / Azure SQL

40,775  
latest deduplicated campaign records

18  
executed campaign rules

29  
selected staging fields

Read-only analysis. No Salesforce write-back or merge is performed.

---

# Meeting Objective
## What this campaign analysis proves

- Clear separation between technical rule execution, governed rule design, and business policy decisions.
- Evidence is reproducible from staging and raw SQL queries.
- Failures are review signals, not automatic proof of source-system defects.

### Ready now
- Campaign latest table built and deduplicated.
- 18 campaign rules defined and executed.
- Rule-level counts and record-level examples collected.

### Not claimed yet
- No automatic remediation in Salesforce.
- No production enforcement decision without business approval.
- Controlled-list governance still pending for Region rule behavior.

Business question: Can we approve engineering evidence first, then decide business policy per rule?

---

# Execution Model
## How campaign rules were executed

1. Source: staging.campaign_latest (latest-state campaigns)
2. Baseline: raw.salesforce_campaign (for dedup and lineage checks)
3. Rules: campaign_staging_dq_PROD.sql (18 campaign rules)
4. Results: staging.campaign_dq_exceptions_temp
5. Evidence: drill-down SQL queries for each high-impact rule

Business question: Should future production execution stay sample-based or move rule-by-rule full-population checks?

---

# Rule Overview
## Campaign catalogue at a glance

- 3 identity and completeness rules (CAM-001 to CAM-003)
- 3 controlled-value rules (CAM-004, CAM-006, CAM-016)
- 4 financial and reasonableness rules (CAM-007, CAM-008, CAM-012, CAM-013)
- 3 lifecycle and date logic rules (CAM-005, CAM-009, CAM-011)
- 2 referential and consistency rules (CAM-010, CAM-014)
- 2 validity rules (CAM-015, CAM-017)
- 1 digital format rule (CAM-URL-001)

Governance note: CAM-016 depends on approved region values table.

---

# Result Interpretation
## How to read PASS, FAIL, SKIPPED

PASS: no rows matched the current failure condition.

FAIL: one or more rows matched and need review.

SKIPPED: rule logic exists but required governance input was not loaded.

Meeting phrase: A failed rule is a review signal. We confirm business semantics before classifying a true defect.

---

# Field-by-Field
## Identity and record-state controls

### Id (CAM-001, CAM-002)
- Completeness and Salesforce ID format checks.
- Result: 0 failures. 

### Name (CAM-003)
- Mandatory campaign name.
- Result: 0 failures.

### IsDeleted (CAM-017, raw layer)
- Valid token check for true or false states.
- Result: 0 failures.

Business question: Should deleted campaigns be excluded from all business KPIs or scored in a separate historical quality track?

---

# Field-by-Field
## Status and lifecycle controls

### CAM-004 Status controlled list plus non-blank
- Failures: 9
- Current flagged values are null or blank statuses.

### CAM-009 Completed or Aborted with active flag
- Failures: 2,097

### CAM-011 Past EndDate with active flag
- Failures: 13,318

Business question: Are these lifecycle states true defects, or accepted operational behavior pending process automation?

---

# Field-by-Field
## Date and chronology controls

### CAM-005 StartDate less than or equal to EndDate
- Failures: 0

### CAM-011 historical state behavior
- Ended campaigns still marked active.

Interpretation: chronology is technically valid, but lifecycle semantics require policy.

Business question: Should ended campaigns auto-transition to inactive, or remain active until manual closure?

---

# Field-by-Field
## Currency and region governance

### CAM-006 Currency controlled list
- Allowed set: GBP, USD, EUR, CAD, AUD, SAR
- Failures: 0

### CAM-016 Region controlled list
- Status: skipped when approved region list is not loaded.

Business question: Do we lock currencies and regions through centrally approved lists in DQ governance?

---

# Field-by-Field
## Financial consistency and reasonableness

### CAM-007 BudgetedCost non-negative
- Failures: 0

### CAM-008 AmountWon less than or equal to AmountAll
- Failures: 23

### CAM-012 ActualCost less than or equal to 200 percent of BudgetedCost
- Failures: 0

### CAM-013 Opportunity hierarchy consistency
- Failures: 0

Business question: Do we enforce strict financial checks or apply approved tolerance thresholds?

---

# Field-by-Field
## Relationship and reference integrity

### CAM-010 ParentId reference exists in campaign set
- Failures: 0

### CAM-014 Casesafe campaign ID matches Id
- Failures: 0

### CAM-015 Year validity range
- Failures: 0

Business question: Should referential checks remain staging-only controls or become hard production gates?

---

# Field-by-Field
## URL behavior and digital-field semantics

### CAM-URL-001 Fundraising URL pattern
- Rule: blank or starts with https, http, or www
- Failures: 2,252

Observation: many values look like campaign codes or labels, not malformed URLs.

Business question: Is this field a true URL field, or a mixed-purpose campaign reference field?

---

# Verified Evidence
## Campaign baseline and dedup metrics

- Raw non-deleted campaigns: 41,304
- Distinct campaign IDs: 40,775
- Duplicate rows removed by dedup: 529
- Final staged latest campaigns: 40,775

Technical conclusion: dedup logic is working as expected.

---

# Verified Evidence
## Rule match totals

- Total rule matches: 18,228
- Unique affected campaigns: 16,078
- Share of affected campaigns: 39.4 percent

Severity split:
- High: 9
- Medium: 4,901
- Low: 13,318
- Critical: 0

Business question: Should we prioritize volume-based remediation or severity-based remediation first?

---

# Cross-Field Behavior
## Top rules driving volume

1. CAM-011 Past campaigns still active: 13,318
2. CAM-URL-001 URL pattern mismatches: 2,252
3. CAM-009 Completed or Aborted still active: 2,097
4. CAM-008 Amount reconciliation: 23
5. CAM-004 Status controlled-list and non-blank: 9

Interpretation: lifecycle semantics dominate current DQ volume.

---

# Multi-Rule Concentration
## Campaigns with multiple rule matches

Some campaigns trigger 2 to 3 rules together, mostly from lifecycle plus URL plus amount/status combinations.

Implication:
- Prioritizing rules in isolation may miss root-cause process issues.
- Bundle remediation by business workflow, not only by column.

Business question: Should remediation ownership be assigned by campaign process owners rather than by individual data fields?

---

# Governance Decisions
## Rules needing business policy confirmation

- CAM-004: null or blank status handling.
- CAM-009: completed or aborted campaigns with active flag.
- CAM-011: past end-date campaigns with active flag.
- CAM-URL-001: accepted pattern and field semantics.
- CAM-008: tolerance for amount reconciliation.
- CAM-016: approved region list ownership and refresh.

Engineering principle: do not auto-correct business semantics without policy approval.

---

# Business Sign-Off
## Mandatory questions to close campaign DQ

- Which campaign statuses are mandatory and approved?
- What lifecycle rule should govern IsActive transitions?
- Is Fundraising_page_url__c URL-only or multi-purpose?
- Are amount reconciliation tolerances allowed?
- Who owns region and currency approved lists?
- Which rules are hard-blocking vs review-only?

---

# Recommended Next Step
## Decision and rollout path

1. Approve policy definitions for CAM-004, CAM-009, CAM-011, CAM-URL-001, CAM-008, CAM-016.
2. Keep evidence read-only and rank findings by business impact.
3. Move approved rules into governed incremental framework execution.
4. Run 100k controlled sample checks by object during rollout windows.
5. Promote approved checks to recurring production schedule.

Final message: Campaign DQ execution is technically ready; policy approval and ownership are the remaining gate for enforcement.

---

# Appendix
## Campaign key metrics snapshot

- Total staging campaigns: 40,775
- Total rule matches: 18,228
- Unique affected campaigns: 16,078
- Highest-volume rule: CAM-011 (13,318)
- Rule with governance dependency: CAM-016 (region approved list)

Status: Ready for business review and sign-off.
