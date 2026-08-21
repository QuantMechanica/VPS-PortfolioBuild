# MNT-039 (partial): PIPELINE-orphan disposition + idempotency proof

Date: 2026-08-21. Author: Claude (orchestrator, headless cycle). Branch: agents/board-advisor.

## Scope of this pass

MNT-039 asks for three things: (1) a canonical work-identity object (parent/child/retry),
(2) a per-class idempotent sweeper, (3) an aging SLO alarm. This pass delivers a scoped,
tested slice of (2): the **PIPELINE** class only. The **RECYCLE** class stays frozen per
the ticket's own note (depends on the build-gate work in commit 57faa292, in progress by
Codex). The canonical-identity object and the aging alarm are NOT done in this pass —
listed as follow-up below.

## Defect found

`agent_router.py::_compute_task_exit`, PIPELINE branch, previously had exactly one exit:
resolve to PASSED/FAILED once `work_items` records a Q10/P8 closing verdict, otherwise
leave the row in place forever ("in flight"). Two sub-populations of the 163 PIPELINE
rows can **never** reach a closing verdict under this rule and were stuck permanently:

- 9 rows with no resolvable `ea_id`/`card_id` in payload at all — `_ea_pipeline_verdict`
  has nothing to query.
- 4 rows with a resolvable `ea_id` but **zero** `work_items` rows ever created for it —
  nothing is running that could ever produce a verdict.

Measured directly against `D:/QM/strategy_farm/state/farm_state.sqlite` before the fix:
150 rows had `work_items` and were legitimately in flight; 13 had no path to resolution.

## Fix

`tools/strategy_farm/agent_router.py`:
- Added `_ea_has_work_items(conn, ea_id)` — distinguishes "no rows yet" (structurally
  orphaned) from "rows exist but none closing" (legitimately in flight).
- PIPELINE branch of `_compute_task_exit` now returns:
  - `BLOCKED / pipeline_no_ea_binding` when no ea_id resolves at all,
  - `BLOCKED / pipeline_no_work_items` when the ea_id resolves but has zero work_items,
  - unchanged behaviour (PASSED/FAILED/left-in-place) otherwise.

No verdict is fabricated: BLOCKED is a routing disposition, not a pipeline verdict — Hard
Rule "pipeline verdicts come only from pipeline evidence" is unaffected since these rows
never had pipeline evidence to begin with.

## Tests (failed before, pass after)

`tools/strategy_farm/tests/test_agent_router_state_exits.py`:
- `test_pipeline_with_no_ea_binding_resolves_to_blocked`
- `test_pipeline_with_zero_work_items_resolves_to_blocked`
- `test_pipeline_orphan_dispositions_are_idempotent` — proves a second `apply=True` run
  over an unchanged snapshot moves nothing (`moved_count == 0`, `would_move == {}`),
  satisfying the ticket's idempotency acceptance criterion for this class.

All three failed against the pre-fix code (rows stayed in PIPELINE / KeyError on the new
reason strings) and pass after. Full suite: `pytest tools/strategy_farm/tests/ -k
"agent_router or reconcile"` — 107 passed (was 104; +3 new), 0 failed.

## Applied to the live DB (bounded, blast radius named)

Dry-run confirmed the predicted split, then applied scoped to `states=['PIPELINE']` only
(RECYCLE untouched — still frozen):

```
python -c "from tools.strategy_farm import agent_router; \
  print(agent_router.reconcile_task_exits(apply=True, states=['PIPELINE']))"
```

Result: 14 rows moved — 13 to BLOCKED (9 `pipeline_no_ea_binding`, 4
`pipeline_no_work_items`), 1 to PASSED (`pipeline_closing_verdict_pass`, a genuine Q10
PASS that had simply never been reconciled). 149 rows correctly left in place
(`pipeline_in_flight_no_closing_verdict`). This is a GRÜN-scope action: existing tool,
unchanged criteria for the rows it already handled, a small tested code delta for the
rows it didn't, blast radius = 14 rows, each with a per-row `exit_reconciliations`
history entry for rollback/audit. `agent_task_state_stranded` PIPELINE count should read
149 (was 163) on the next health run.

## Rollback

Revert the two edits in `agent_router.py` (helper + PIPELINE branch) and the test
additions. The 14 moved rows are not restorable to PIPELINE automatically (state is a
one-way transition by design, same as every other reconciler exit) — restoring would
require a manual UPDATE keyed off `exit_reconciliations` timestamps if ever needed.

## Not done in this pass (follow-up)

- **Canonical work-identity object** (parent/child/retry unified across `agent_tasks` and
  `work_items`): `agent_tasks.parent_id` exists but is unused; `work_items.parent_task_id`
  and the `append_only_rerun_of_work_item` payload convention are the closest existing
  primitives. No unification attempted here — this is a design task, not a bug fix, and
  deserves its own scoped pass.
- **RECYCLE class sweeper**: intentionally left untouched. The existing
  `_compute_task_exit` RECYCLE branch is not exercised further here; MNT-039's own note
  says it stays frozen until Codex's build-gate change (commit 57faa292) lands, since
  RECYCLE->TODO re-queues into the build lane (a capacity decision, and today
  `codex_auth_broken` means nothing would consume it anyway).
- **Aging SLO alarm**: `health.py::chk_agent_task_state_stranded` still reports one
  aggregate age bucket, not a per-class threshold. Deferred to a follow-up ticket.

## Verification commands

```
python -m pytest tools/strategy_farm/tests/test_agent_router_state_exits.py -q   # 24 passed
python -m pytest tools/strategy_farm/tests/ -k "agent_router or reconcile" -q     # 107 passed
python tools/strategy_farm/farmctl.py health   # agent_task_state_stranded PIPELINE: 163 -> 149
```
