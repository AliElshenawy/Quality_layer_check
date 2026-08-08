# 04 — Contact Data Quality: Stakeholder Slides

> Human Appeal · Salesforce Data Quality · Object: **Contact (Donor Master)**
> Read-only assessment — **no changes are written back to Salesforce.**

---

## Slide 1 — Title
**Donor (Contact) Data Quality Review**
Human Appeal · Salesforce → SQL Server DQ Framework
Run date: 2026-08-05 · 1.9M donor records profiled · Read-only, no write-back.

---

## Slide 2 — Meeting Objective
- **What this proves:** we can measure donor-record completeness at full scale (1,901,026 donors) against
  the org's own validation rules.
- **Ready now:** the 3 client validation rules (address, Gift Aid, email) plus 6 engineering checks are live
  and produce reproducible counts.
- **Not claimed:** we are **not** auto-correcting anything — every finding awaits your decision.
- **Main question:** which gaps are real policy breaches vs. accepted legacy?

---

## Slide 3 — Execution Model
- **Source:** `raw.salesforce_contact` (1.9M rows, full Salesforce export).
- **Staging:** `staging.contact_latest` — deduped, deleted rows removed (1,901,026 donors).
- **Rules:** 9 checks in the DQ framework (`dq.dq_rule_catalog`).
- **Findings:** `dq.dq_exceptions` — 858,899 open, all read-only.

---

## Slide 4 — Rule Overview
| Category | Rules |
|----------|-------|
| Client validation rules | Address required, Gift Aid Yes/No, Email required |
| Integrity (clean) | Id present & valid, IsDeleted valid |
| Required field | LastName present |
| Matching | External Id present |
| Mechanical | Email format |

---

## Slide 5 — Headline Findings (the money slide)
- **554,496 donors (29%)** have at least one data-quality issue.
- Biggest gaps:
  - **352,836** donors have Gift Aid = *Unspecified* → **Gift Aid reclaim at risk**.
  - **251,271** donors have an **incomplete mailing address** → stewardship / mail undeliverable.
  - **161,517** donors have **no email** → cannot be contacted digitally; weaker duplicate matching.
  - **92,584** donors have **no External Id** → bypass duplicate prevention.
- Clean: every donor has a valid unique Id (no duplicates).

---

## Slide 6 — Two Big Policy Questions
1. **Mailing State:** the address rule lists State, but **88.6% of donors have no State**. Enforcing it
   literally would flag almost everyone. *Is State truly mandatory, or is the core address (Street/City/
   Postcode/Country) enough?*
2. **Gift Aid "Unspecified" (352,836):** your rule says Yes/No only. *Is legacy "Unspecified" acceptable,
   or must we remediate it?* This directly affects Gift Aid claim eligibility.

---

## Slide 7 — Decisions We Need
| # | Decision | Impact | Owner |
|---|----------|--------|-------|
| 1 | State mandatory? | Address rule scope | Data Governance |
| 2 | Gift Aid Unspecified accept/remediate | £ Gift Aid reclaim | Fundraising + Compliance |
| 3 | Backfill 161,517 missing emails? | Contactability + matching | Fundraising Ops |
| 4 | Regenerate 92,584 External Ids? | Duplicate prevention | Integration |
| 5 | Approve engineering fix: 183 blank surnames + 508 bad emails | Mechanical cleanup | Data Engineering |

---

## Slide 8 — What Happens Next
- **Engineering-safe fixes** (691 records) can proceed on approval — no business risk.
- **Policy decisions** (State, Gift Aid, email, External Id) are needed before any remediation or write-back.
- Rules now run **incrementally** — future donor loads are re-checked automatically.
- Technical evidence & reproducible queries: see [`03_contact_staging_dq_ANALYSIS.md`](03_contact_staging_dq_ANALYSIS.md).
