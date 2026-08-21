# Pipeline-entry blockers behind the APPROVED limbo — diagnosis and repair

**Date:** 2026-08-21 · **Author:** Claude (orchestrator) · **Branch:** `agents/board-advisor`
**Follows:** `2026-08-21_review_backlog_closeout.md`, `2026-08-21_approved_limbo_reconcile.md`

## 1 · What triggered this

`reconcile-exits --state APPROVED --apply` relabelled 60 `build_ea` tasks as
`APPROVED → PIPELINE` ("approved build handed to pipeline"). Six of those EAs have **zero
`work_items`** — they were never handed to anything. The label was therefore untrue for
those six. This document closes that gap instead of leaving the books prettier than reality.

## 2 · Why the six never entered the pipeline

Fresh Q02 seeding for a never-tested EA happens only through the canonical sweeper
`tools/strategy_farm/sweep_enqueue_built_eas.py`. It applies two independent filters, and the
six failed **different** ones:

| EA | built? | magic rows | registry status | review gate | actual blocker |
|---|---|---|---|---|---|
| QM5_11533 | mq5 + ex5, 1 set | 1 (active) | was `pending` → **activated** | **no `review_ea` row at all** | review gate |
| QM5_11537 | mq5 + ex5, 2 sets | 2 (active) | was `pending` → **activated** | no `review_ea` row | review gate |
| QM5_11539 | mq5 + ex5, 2 sets | 2 (active) | was `pending` → **activated** | no `review_ea` row | review gate |
| QM5_11563 | mq5 + ex5, 3 sets | 3 (active) | was `pending` → **activated** | no `review_ea` row | review gate |
| QM5_1354 | built | active | **no registry row at all** | `review_ea` = PASSED ✔ | missing registry row |
| QM5_30001 | no ex5 **by design** | — | `active` | review PASS **on a refusal** | not a build at all |

### 2.1 The review-entry gate, exactly

`tools/strategy_farm/review_entry_gate.py`:

- `ACCEPTED_STATES = {APPROVED, PASSED}` (line 42), **but acceptance is only counted for
  `task_type == "review_ea"`** (lines 109–111).
- `PIPELINE` is in none of `BLOCKING_STATES`, `ACCEPTED_STATES` or `OPEN_STATES`, so a task in
  `PIPELINE` falls through to `review_not_completed` (lines 115–123).

Consequence for the four `115xx` EAs: they carry a `CODEX_APPROVED` / `CODEX_APPROVED_WITH_INFO`
verdict **on their build task**, and no `review_ea` row exists. The gate has therefore blocked
them since **2026-05-23** — three months — and no amount of registry activation changes that.
The gate is behaving as designed; the EAs simply never got a review ticket.

## 3 · What was changed

**Registry activation (4 rows).** `framework/registry/ea_id_registry.csv`: `11533`, `11537`,
`11539`, `11563` flipped `pending → active`. Verified before flipping: each has `.mq5`, `.ex5`,
and a set-file count equal to its active magic-row count. Diff is exactly 4 lines, status field
only (backup taken). This removes the *first* of the two blockers; the review gate remains.

**Reviews dispatched (6 `review_ea` tasks).** For the four `115xx` EAs (prio 78) and for the two
builds left stranded in `REVIEW` by the backlog close-out: `QM5_1673` (its only review is a stale
2026-07-19 RECYCLE predating the 2026-08-17 rebuild — it describes a different artifact) and
`QM5_41002` (no review at all; blocked behind a `dirty_registry_abort` preflight), both prio 76.
The four briefs explicitly forbid rubber-stamping the existing build verdict and require
independent re-verification of card fidelity, input wiring, magic binding, `RISK_FIXED`, the
card's loss limits versus the framework default (`QM_Common.mqh:298` = 3.0/0.0), broker-time
handling and a strict `build_check` PASS.

**Registry-integrity task (`ops_issue`, prio 74).** `QM5_1354` and `QM5_1355` are built and carry
**active magic rows but have no `ea_id_registry` row**. A magic allocation without a registry row
is an integrity hole: the registry is the authority for the `ea_id`/slug binding on which
`ea_id*10000+slot` depends. The task asks for the root cause first (never written, or removed
later — the CSV's git history answers it), then the repair, with no new ID reservation.

**QM5_30001 closed honestly.** Moved `PIPELINE → PASSED`, not `BLOCKED`: it is an **accepted
refusal**, not a failed build. It is a Bollinger grid/martingale strategy that was correctly
refused on charter grounds; there is no `.ex5` by design and there never will be `work_items`.
Residual noted for the registry task: its registry row still says `status=active` and should be
`retired`.

## 4 · Residual, stated plainly

Five rows relabelled to `PIPELINE` still carry no `work_items` (the four `115xx` plus `QM5_1354`).
Their label becomes truthful only when the dispatched reviews complete (four) and the registry
row is repaired (one). This is recorded rather than hidden; the reconcile's blanket relabel is
the reason, and the fix is in flight rather than pending a decision.

## 5 · Verification

```
sweep_enqueue_built_eas.py (dry-run, APPLY=False, after activation)
  part1 never_tested: enqueued=0 skipped=771
  the four 115xx now skip with reason "review_entry_gate" / "review_not_completed"
  (previously "registry_status=pending") -- i.e. blocker one is gone, blocker two remains
```

Backup of the pre-change registry: session scratchpad `ea_id_registry.backup.csv`.
