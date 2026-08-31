# ac5a29c9 recycle 1 — authenticated frontier refill repair

- Date: 2026-08-31
- Branch: `agents/board-advisor`
- Router task: `ac5a29c9-57b2-4153-889b-ae96258179dd`
- Code commits: `e575277c4dfe50b431387fdd9c30120f67b527d1`,
  `844a2ff05f`
Verdict: **PASS — 80 RESOLVED CELLS/H, ZERO DECLINE-LOOP RECURRENCE**

## Outcome

The first repair removed the global
`opt_census_lane_preflight_required` decline loop, but its live rollout exposed
the inverse failure: normal single-symbol census cells could bypass the cold
lane preflight, and the priority frontier could drain between matrix-service
runs.  Both defects are fixed without changing the default `K=6`, `L=1`,
`G=6` topology or weakening the authenticated arm-frontier check.

The final fixed 60-minute live window is preregistered as
`2026-08-31T12:36:50.174228Z <= t < 2026-08-31T13:36:50.174228Z`.
It closed with 80 resolved census cells, against the `>=60/h` target, and zero
`opt_census_lane_preflight_required` declines.

## Root cause

There were four coupled defects.

1. The first fix correctly moved cold lane authentication behind capacity,
   duplicate, and resource rejection gates, but the new block was accidentally
   indented inside `if item_is_multisym`.  Governed DL-089 census cells are
   normally single-symbol, so an otherwise eligible row reached the claim CAS
   without a token and was silently skipped.  The allow-listed unit test mocked
   `_opt_census_token_matches()` as true and asserted only the final claim, so it
   did not exercise the real normal-cell completion path.
2. `opt_census.boost()` incorrectly used the execution lane limit `L` to size
   the pending priority frontier.  With default `L=1`, each program had only one
   executable head; consuming it left no replacement until another matrix
   service pass.  `dl089_matrix_service` compounded that error by passing only
   residual global capacity (`G - other_active`) as the program refill limit,
   which deboosted refill rows exactly when the fleet was saturated.  `L` must
   bound active execution, while the pending buffer is independently bounded by
   `min(priority_window, G)`.
3. Two programs carried hundreds of OWNER-authored `priority_track=true` rows.
   Those durable OWNER flags must not be rewritten, but the old priority sort
   could not distinguish the current authenticated frontier from stale broad
   priority rows.  A separate `opt_census_frontier_priority` marker and a
   same-rank tie-break now select the current frontier without changing OWNER
   authority, reason, or priority metadata.
4. The comprehensive matrix service lived after build, review, and promotion
   work in the 270-second pump budget.  The 12:18Z scheduled cycle exhausted
   that budget before reaching the service, and the overlapping 12:23Z cycle
   skipped behind the still-running pump.  A six-head buffer removes the
   single-cell cadence cliff, but cannot guarantee an hour if every late
   service is starved.  Existing owners therefore need a small early refill
   path that does not repeat sibling discovery, Q02 seeding, receipt writing,
   selector advancement, or materialization.

The missing acceptance coverage mirrored those defects: there was no
single-symbol eligible governed tail behind more than eight serialized rows,
the replay encoded the erroneous `L`-sized refill as expected behavior, and no
ordering test combined a current frontier marker with an existing OWNER
priority row.

## Repair

- `terminal_worker.py`: run governed lane preflight for every admitted census
  candidate, outside the multisymbol-only branch and after all cheap rejection
  gates.  Claimed-event telemetry now records preflight status, program, and
  arm separately from pruning telemetry.
- `opt_census.py`: maintain up to `min(priority_window, G)` pending frontier
  heads while `L` continues to bound active lanes.  Preserve external OWNER
  priority fields and manage only the independent frontier marker.
- `dl089_matrix_service.py`: pass effective `G`, not residual capacity, to the
  refill operation.
- `farmctl.py`: prefer the current frontier marker among otherwise equal
  priority rows without overtaking a higher Q-series rank.
- `dl089_matrix_service.py` + `farmctl.py`: add a refill-only service for
  already-materialized owners and run it immediately after dispatch, before
  budget-heavy pump stages.  The full late service remains authoritative for
  discovery, prerequisites, materialization, receipts, and advancement.
- Regression tests cover the deep serialized queue plus eligible governed
  tail, external OWNER-priority preservation, frontier ordering, and `G`-sized
  refill under `L=1`.

## Focused verification

The two new tests first failed against the recycled implementation:

- the eligible single-symbol tail performed zero lane preflights;
- an `L=1` replay produced only two refill heads instead of the five fixture
  arms available under `G=6`.

After the repair:

- the four directly affected regressions passed;
- the nine-module DL-089/atomic-claim pack produced 194 passes and one
  unrelated concurrency-sensitive failure
  (`test_frozen_commit_probe_caps_parallel_ordinary_claims` observed
  `factory_admission_interlock_error` rather than `commit_headroom_low`); its
  isolated rerun passed in 78.01 seconds;
- `python -m py_compile` passed for all eight changed runtime/test modules;
- `git diff --check` passed (line-ending warnings only).
- the final refill-only and pump-order suite passed `12 passed`; a live
  read-only probe selected the same six owners in 0.515 seconds with zero
  deferred programs, and the first applied refill completed in 1.203 seconds.
- the closing-cycle independent rerun of the six directly affected claim,
  frontier, priority, refill, and pump-order regressions passed in 22.30
  seconds.  `python -m py_compile` passed for the four changed runtime modules,
  and the scoped `git diff --check` was clean.

## Safe live rollout

All terminals were reserved only at their next claim boundary.  Active T1-T10
items were allowed to finish.  No `terminal64.exe` process was stopped or
started manually, and no T_Live, AutoTrading, active backtest, or live-trading
setting was touched.

Seven idle worker daemons were replaced through
`QM_StrategyFarm_WorkerDedupe` after an exact process-identity, child-process,
terminal-process, and active-item check.  Durable pre-action receipts are in
`D:/QM/reports/state/manual_process_kills.jsonl`:

| Terminal | Old PID | Initial new PID | Pre-action event ID |
|---|---:|---:|---|
| T1 | 14096 | 6148 | `07ba09f6-1c82-4911-b0de-56a91bc5dbc0` |
| T2 | 19368 | 24808 | `f971ac9a-0122-43b7-8b89-c0d81ea668a5` |
| T3 | 21288 | 17776 | `bb1a0a16-cb43-4e2b-a4b9-88f50e9eb7f4` |
| T6 | 31220 | 28440 | `2e7cc9e2-3106-4725-abda-abf601a04555` |
| T7 | 13456 | 7600 | `e81d2541-9f41-4b1d-8e2b-faeecc01ce5a` |
| T8 | 3296 | 4640 | `b5574041-7b3d-408f-8aa2-a6a111627cf0` |
| T10 | 4956 | 36192 | `2c9d182c-a2de-4a23-adaf-e0a1f940f575` |

The canonical matrix service first materialized six pending heads for each of
the six occupied program slots under default `K=6`, `L=1`, `G=6`.  That first
window exposed the late-pump budget starvation at 12:18Z and was discarded
before its result was used.  After commit `844a2ff05f`, the bounded early path
refilled the same six owners with zero deferred programs at 12:36:50Z.  All six
programs then held one active cell.  Fixed-generation claimed events carried
`dl089_lane_preflight_status=checked` plus the exact program and arm.

The first scheduled pump from the committed generation is durable at
`D:/QM/strategy_farm/logs/pump_task_20260831T124302Z.log`.  It applied the
early refill to six owners with zero deferred programs in 1.047 seconds.  The
same cycle later recorded `pre_promotion_stage: cycle_budget_exhausted`, which
is the decisive ordering regression: refill completed even though the old late
matrix-service position was not reached.

## One-hour acceptance and metric boundary

The ticket calls the original 88/h figure a "cell rate", while the canonical
read-only concurrency harness reports only terminal `MEASURED` executions.
Pruning can resolve several `SKIPPED_EXCLUDED` cells from one measured trigger,
so these are different numerators.  To avoid changing the metric after seeing
the result, this receipt reports both over the exact same one-hour window:

| Metric | Before repair | Post-fix one-hour | Acceptance |
|---|---:|---:|---|
| Terminal executions (`MEASURED`) | 14/h | 38/h | reported, not substituted |
| Resolved census cells (`MEASURED` + `SKIPPED_EXCLUDED`) | 14/h | **80/h** (38 + 42) | **PASS**, target `>=60/h` |
| `opt_census_lane_preflight_required` declines | 0 in prior four-hour review window | **0** | **PASS**, must remain zero |
| Governed claims with authenticated preflight telemetry | unavailable before telemetry change | **31** across 5 programs and 7 terminals | **PASS**, must be non-zero |

The half-open before and post-fix counts came from a read-only SQLite URI over
`work_items`: `phase=OPT_CENSUS`, `status=done`, verdict in `MEASURED` /
`SKIPPED_EXCLUDED`, and `julianday(updated_at)` inside each exact boundary.
The before window was
`2026-08-31T10:23:48.971810Z <= t < 2026-08-31T11:23:48.971810Z`.
The post-fix measured rows span 12:37:57Z–13:35:45Z; authenticated pruning
resolutions span 12:38:01Z–13:34:13Z.  An independent canonical concurrency
harness snapshot reported `measured_cells_per_hour=38.0`, complete log
coverage, 76.26% slot utilization, and zero CPU-high pauses.

The append-only `terminal_worker_T1`–`T10` logs were parsed as timestamped JSON
over the same exact post-fix boundary.  The first authenticated governed claim
was 12:37:44Z, the last was 13:36:33Z, and no matching decline event occurred.

The pre-fix diagnostic harness artifacts created during the investigation are:

- `D:/QM/reports/ops/ac5a29c9_throughput/recycle1_pre_fix.md`
- `D:/QM/reports/ops/ac5a29c9_throughput/recycle1_pre_fix.csv`

The canonical post-fix evidence and exact counts are contained in this receipt.

## Review boundary

This is a board-advisor repair artifact.  It does not self-approve the change,
advance it to any pipeline phase, authorize live use, or alter a pipeline
verdict.  The router task remains for independent REVIEW after the fixed
one-hour evidence is complete.
