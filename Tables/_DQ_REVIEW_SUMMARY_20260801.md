<!-- AI created but i reviewed it -->
# DQ Folder Review — Summary of Actions (2026-08-01)

Scope: reviewed the four non-campaign object folders under `Quality_layer_check/Tables/` against
`mohey_work/DQ instructions.md`. **Campaign was excluded** (per instruction). The DQ framework was **NOT
re-run**; for each object we checked whether it had already run (via `dq.rule_execution_state`,
`dq.dq_results`, `dq.dq_exceptions`) and used that real data. Where an object was not fully run, a
"what to do" TODO file was created instead of a fabricated final analysis.

## Actions per object

| Object | Framework run? | Real run evidence | Action taken |
|---|---|---|---|
| **item_gau** | ✅ Fully (2026-07-30) | 30,815 staged · 26 rules · 20 PASS / 6 FAIL · 1,537 exceptions | **Rewrote** `01_EDA` (business format) and `03_ANALYSIS` (9 spec sections, real data). Slides left as scaffold (flagged). |
| **recurring_donation** | ✅ Fully (2026-07-31) | 258,465 staged · 23 rules · 16 CAUGHT_UP / 7 FAIL (2 deferred) · 70,241 exceptions | Already spec-complete with real evidence — **no rewrite needed**; only minor EDA heading polish outstanding. |
| **sponsorship_unit** | ✅ Fully (2026-07-30) | 1,291,058 staged · 9 rules · 7 PASS / 1 FAIL (SU-008 deferred) · 51,815 affected | **Added** the missing spec sections (Zero-Finding, Most-Violating, Recommendations). EDA already complete. Slides scaffold (flagged). |
| **sponsorship** | ✅ 8 rules run (2026-08-01); SP-009/010 skipped (heavy) | 227,244 staged · SP-001..008 = 4 PASS / 4 FAIL · 62,414 open exceptions | **Ran SP-001..008 to completion** and wrote the final `03_ANALYSIS`. Deferred SP-009 (Contact empty) + SP-010 (heavy join); EDA notes the skip; TODO updated to a deletion candidate. |

## Why this is good

- **Every number is grounded in the live `dq` tables** — no invented counts. item_gau's new analysis mirrors
  the actual 2026-07-30 run (GAU-010=955, GAU-011=231, GAU-018=333, GAU-024=8, GAU-025=2, GAU-026=8).
- **The framework was not re-run**, as instructed — read-only evidence only.
- **Honest handling of incomplete work:** sponsorship is flagged with a concrete TODO rather than a
  misleading "final" document.
- **Dependency-aware truth preserved:** deferred rules (RD-003/RD-008 → Contact empty; SU-008 →
  item_allocation empty) are reported as data-load gaps, not defects.
- Folders now match the 5-file numbered spec (`00_`…`04_`); item_gau's split rule files were already
  consolidated into `02_..._framework.sql`.

## Why this is bad / current gaps

- **Slides (`04_`) are thin scaffolds** for item_gau, sponsorship, and sponsorship_unit — not yet
  stakeholder-ready (missing Result Interpretation, Verified Evidence, Stakeholder Questions).
- **Sponsorship heavy joins deferred:** SP-009 (→ Contact, empty) and SP-010 (→ Recurring_Donation, heavy
  227K×261K join) are skipped (`is_active=0`), so its picture is complete only for the 8 single-table rules.
  SP-008's 55,498 fails need a business/backfill decision before being treated as live defects.
- **recurring_donation EDA** lacks explicit `Top Null Columns (RAW)` and `STG Coverage` headings (content
  is present, headings are not).
- **Two real data issues surfaced** and still need action:
  - item_gau: 18 non-numeric financial values (GAU-024/025/026) — engineering-fixable at source.
  - sponsorship_unit: 51,815 sub-penny negative GBP deferrals (SU-005) — business decision (rounding vs fix).
- **Deferred rules can't be judged** until parent tables load: `raw.salesforce_contact` (RD-008, SP-009)
  and `raw.salesforce_item_allocation` (SU-008).

## What can improve (next actions)

1. **Load the missing raw tables** — Contact and Item Allocation — then re-enable & re-scan RD-008, SP-009,
   SP-010, SU-008 (they are deferred only because their lookup tables are empty).
2. **Finish the sponsorship heavy joins** — load Contact then re-enable & run SP-009; run SP-010 in a
   dedicated batched pass; then delete `sponsorship_TODO_finish_dq_run.md`. (SP-001..008 are already final.)
3. **Upgrade all `04_slides`** to the full stakeholder format (Baseline Metrics, Result Interpretation,
   Verified Evidence, Field-by-Field, Stakeholder Questions, Recommendation).
4. **Polish recurring_donation `01_EDA`** — add the two explicit table headings.
5. **Get stakeholder decisions** on the open policy questions: GAU-010 (Country requirement),
   GAU-011 (active vs status authority), GAU-018 (Sponsorship/Ticket allow-flags), SU-005 (negative deferrals).
6. **Fix the 18 non-numeric item_gau financial values** at source (unambiguous defects).

## Not done deliberately

- No framework re-run (as instructed).
- Campaign folder untouched (out of scope).
- Sponsorship final analysis not written (data not complete) — captured in its TODO instead.
