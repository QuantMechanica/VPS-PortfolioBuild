# intake-first-q02 --supersede-pending-canary --apply

Task: `7b2c1bc7-8320-4eae-b768-01585a4d8bbf` (routed to claude, source
`fable-orchestrator-2026-09-18`, quota_gate class `ops_review`).

## What was built

`tools/strategy_farm/farmctl.py`: new function
`intake_first_q02_supersede_pending_canary()` plus CLI wiring
`intake-first-q02 --supersede-pending-canary [--apply]`.

Handles exactly one `intake-first-q02` blocker: `existing_q02_row` firing
because every existing pending Q02 row for the EA is stuck in the RAM
"exclusive" class (currently the 44GB `single_index_tick` fail-safe read
live from `terminal_worker.SINGLE_INDEX_TICK_COMMIT_RESERVATION_GB`, never
hand-duplicated). Eligibility is per-row and strict: pending, unclaimed,
no verdict, RAM reservation at/above the threshold. Any row with a verdict
or an active claim is out of scope — this tool never touches evidence.

Apply path (governed, under `FactoryMutationLock` + `_governed_state_backup`,
same pattern as `intake_first_q02`/`rebind_q02_stale_ex5`):

1. Re-checks predecessor eligibility under `BEGIN IMMEDIATE` (race guard).
2. Re-plans a Q02 canary from the same target-symbol universe, excluding the
   predecessor row ids, using the existing live RAM-ranked selection
   (`_q02_canary_symbol_rank` / `_stage_q02_setfiles` — unchanged).
3. **Refuses to apply if the replanned canary is ALSO at/above the exclusive
   threshold** (`replan_canary_also_exclusive_class`) — added safety gate not
   explicit in the ticket text, but necessary: without it the tool would
   park a 44GB row only to append another 44GB row, pure churn with zero
   benefit.
4. Parks each eligible predecessor with a durable `work_item_holds` row
   (`hold_code=SUPERSEDED_CANARY_RAM_CLASS`) and a `work_item_supersedes`
   edge (predecessor → successor).
5. Appends exactly one new pending Q02 row for the replanned symbol.
6. Writes a receipt (`qm.first-q02-intake-supersede-receipt/v1`) under
   `artifacts/receipts/first_q02_intake_supersede/`.

Append-only throughout: predecessor `work_items` rows and any verdict are
never updated in place, only a hold + a supersedes edge are added.

`_plan_first_q02_intake()` gained an `exclude_work_item_ids` parameter (default
empty, so `intake_first_q02()`'s existing behaviour and its full test suite
are unchanged) and its `existing` query now also returns `symbol`/`claimed_by`
so the eligibility check has what it needs.

## Tests

`tools/strategy_farm/tests/test_first_q02_intake.py`: 7 new tests (dry-run
eligible with cheaper replan, apply parks predecessor + appends successor +
writes hold/supersedes/receipt, refuse when replan is also exclusive class,
refuse when predecessor is claimed or verdict-bearing, refuse when predecessor
is below threshold, pass-through when nothing to supersede, pass-through for
an unrelated refusal reason). Full file: **29/29 pass**
(`python -m pytest tools/strategy_farm/tests/test_first_q02_intake.py -q`).

Built and tested in a dedicated worktree branched off `agents/board-advisor`
(where this Q02 infra lives): `C:/QM/worktrees/claude-q02-supersede-20260918`,
branch `agents/claude-q02-supersede-20260918`, commit `2888287760`. Not
merged — left for review per standing instruction (leave the board-advisor
artifact in REVIEW; no self-approval).

## Live result for the two rows named in the ticket — and why they don't unblock

The ticket asked to run this for `QM5_41475`/`feac1f1f-f939-4857-ac59-d7cf30a443b0`
and `QM5_41476`/`96e5f16f-8d18-4ace-8318-a0c26ea6b9cf` (both pending, unclaimed,
verdict-free, `SP500.DWX`, confirmed against the live DB) so H-CW/H-MR would
"get NDX (12 GB) canaries today". Read-only dry-runs against the live
`D:/QM/strategy_farm` state (no `--apply`, no mutation):

```
$ python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm intake-first-q02 \
    --compile-work-item-id 57ef721a-d4ce-4e2d-9030-5d17b5d8d7a9 --supersede-pending-canary
{ "reason": "replan_canary_also_exclusive_class", "eligible": false,
  "replan_symbol": "GDAXI.DWX", "replan_ram_reservation_gb": 44.0, ... }

$ python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm intake-first-q02 \
    --compile-work-item-id 07087e86-8a5a-4638-b3aa-3d56edc55780 --supersede-pending-canary
{ "reason": "replan_canary_also_exclusive_class", "eligible": false,
  "replan_symbol": "GDAXI.DWX", "replan_ram_reservation_gb": 44.0, ... }
```

Both refuse correctly, not from a bug: **the "NDX (12 GB)" premise in the
ticket is stale.** Both EAs only ship setfiles for GDAXI/NDX/SP500
(`framework/EAs/QM5_41475_.../sets/`, `QM5_41476_.../sets/`), and
`INDEX_TICK_RESERVATION_GB_BY_BASE` in `terminal_worker.py` moved NDX and
GDAXI back to the 44GB fail-safe on 2026-09-16 (ticket 6cdc6811 class
calibration — Q05 D1 full-window runs measured 39.2–39.5 GB, falsifying the
12GB provisional value that stood from 2026-09-14 to 2026-09-16). Confirmed
directly:

```
>>> farmctl._q02_canary_ram_reservation_gb('GDAXI.DWX', 'QM5_41475') -> 44.0
>>> farmctl._q02_canary_ram_reservation_gb('NDX.DWX',   'QM5_41475') -> 44.0
>>> farmctl._q02_canary_ram_reservation_gb('SP500.DWX', 'QM5_41475') -> 44.0
```

So as of today every symbol either EA can run at all is in the exclusive
class — there is no cheaper canary in their universe to escape to, with or
without this tool. This matches the ticket's own note that "universe
expansion refuses native_q02_pass_parent_invalid" (someone already tried the
other escape route and it was also refused). Both source rows are untouched
(no hold, no supersede, no mutation) — dry-run only, `--apply` was never
invoked, because applying would have been confirmed churn.

## What would actually unblock H-CW/H-MR

Not a code lever: either (a) fleet RAM capacity frees up enough for a 44GB
`single_index_tick` row to run (needs an empty-fleet window per the existing
admission model), or (b) the EAs' target-symbol universe is widened beyond
GDAXI/NDX/SP500 (blocked today by `native_q02_pass_parent_invalid` on the
existing universe-expansion path — a separate, unexamined refusal). Neither
is in scope for this ticket.

## Risks / blockers

None from this change — dry-run only against production, no rows mutated,
no verdicts touched, no factory-off/on, no T_Live contact. The new code path
is committed on an unmerged review branch, not on `main`/`agents/board-advisor`.

## Recommended next step

Router: move `7b2c1bc7-8320-4eae-b768-01585a4d8bbf` to REVIEW with this
evidence + the `agents/claude-q02-supersede-20260918` branch as artifact.
Separately (new ticket, not this one): investigate why universe expansion
refuses `native_q02_pass_parent_invalid` for QM5_41475/QM5_41476 — that is
the actual remaining path to a winnable Q02 canary for these two EAs.
