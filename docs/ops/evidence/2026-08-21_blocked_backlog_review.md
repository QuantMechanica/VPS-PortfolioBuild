# Review of the 148 BLOCKED agent tasks — is the blocker still real?

**Date:** 2026-08-21 · **Author:** Claude (Orchestrator) · **Programme:** drain
**Trigger:** the REVIEW queue reached 0, so the review duty moved to the next thing that is
silting by the OWNER's own definition — rows parked as BLOCKED that nobody re-tests.

## Result

| Decision | Rows | Meaning |
|---|---:|---|
| **SUPERSEDED — disposed** | **27** | the EA produced gate rows *after* the block; the row was bookkeeping |
| KEEP — live defect | 28 | unwired inputs, magic conflation, withdrawn approval: needs a rebuild, not an unblock |
| KEEP — blocker never re-tested | 62 | honest block, but untested since it was written (some since 2026-06) |
| KEEP — non-EA | 20 | ops/triage rows with no EA to test against |
| KEEP — in flight | 6 | the EA has open work items right now |
| KEEP — policy exclusion | 5 | `requeue_excluded_eas.txt`, `SELECTION_RELEASED` |

BLOCKED 148 → **121**.

## The test that separates stale from live

The naive test — *"the EA has gate history, so the block must be stale"* — flagged **70** rows.
The strict test — *"the EA produced completed gate rows with `updated_at` strictly AFTER the
block date"* — leaves **27**.

That gap is the whole point. 43 rows have gate history that predates their block; the history
is what got them blocked. Disposing them on the naive test would have quietly reopened EAs that
were stopped for cause. Same discipline as the RECYCLE wave, where 113 of 384 apparently
actionable rows turned out to be already done.

The largest genuinely superseded rows: QM5_10146 (222 completed gate rows after its 2026-06-02
block, 94 PASS), QM5_10070 (90 after, 19 PASS), QM5_20085 (32 after, 25 PASS). Most are the
2026-07-27 "preflight refusal accepted and correct" set plus CPU/capacity deferrals — the build
task was blocked while the EA reached the gates by another route.

Disposals are terminal bookkeeping, explicitly **not** a pass on merit: no verdict overwritten,
no gate result created, each row carries the count that justified it, all reversible via
`agent_task_transition_ledger`.

## Finding: defect-blocked EAs left evidence behind

15 EAs were blocked on **2026-08-16** for known correctness defects — host-slot magic
conflation (3), unwired strategy inputs (2), withdrawn mechanical approvals (10).

**The block held.** Across all 15, gate rows produced after the block date: **zero**. That is
worth stating plainly, because the opposite would have been an incident.

What remains is structural. Those EAs produced **44 PASS rows before** they were blocked —
36 at Q02, 8 at Q03, deepest phase reached Q04 with no Q04 PASS — and nothing distinguishes
those rows from clean evidence in any count. **None reached `portfolio_candidates`**, so there
is no book-selection exposure today; the exposure is that funnel counts, pass-rate statistics
and any future cohort selector read them as ordinary evidence.

Commissioned as `5343f90a`: a **derived, query-only** marker in the style of MNT-016
(`9d9259dec` derived 49,633 missing taxonomy fields without rewriting a single stored row).
Deleting or rewriting a verdict is ROT and is not on the table.

The 15: 10648, 10649, 10973, 11301, 11302, 11689, 11897, 11898, 12352, 20070, 20071, 20179,
2076, 9354, 9501.

## What stays open

`630535e0` covers the 62 blockers that were never re-tested, and carries the method: judge
against live state, never against the verdict text.

## Reproduction

Read-only against `farm_state.sqlite` and `framework/EAs`: take `agent_tasks` where
`state='BLOCKED'`, resolve each row's `ea_id` from its payload, then compare `work_items`
`updated_at` against the row's `updated_at`. Superseded ⇔ at least one `status='done'` row
strictly after the block.
