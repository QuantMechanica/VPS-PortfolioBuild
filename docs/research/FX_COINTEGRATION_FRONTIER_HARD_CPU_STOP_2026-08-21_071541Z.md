# FX cointegration frontier hard CPU stop

Date: 2026-08-21 UTC

Branch: `agents/board-advisor`

Status: stopped at the explicit backtest CPU ceiling before any card, build,
queue, dispatch, or execution mutation

## Outcome

No new FX Strategy Card or EA was created. The latest committed governed
relationship reconciliation (`1ac37f468`) accounts for all 66 relationships in
the frozen sign-aware scan, so another Card, registry allocation, basket
manifest, or EA would duplicate existing work.

The same committed evidence records both preferred anchors beyond Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

Neither anchor has an ONINIT or NO_HISTORY Q02 blocker. The selected
non-duplicate continuation remains rank-21
`QM5_20203_EURUSD_AUDJPY_COINTEGRATION_D1`, whose Q02 verdict is PASS and whose
Q04 successor was already pending exactly once. This run does not present that
selected-pair state as freshly queried: the CPU stop bound before any queue or
execution action, so the last committed reconciliation remains the explicit
reference.

## Binding capacity stop

Five fresh whole-host CPU readings at two-second intervals were 97.95%, 98.26%,
93.95%, 92.92%, and 98.60%. Average CPU was 96.34% and maximum CPU was 98.60%.
The repository's governed stop rule is average-or-maximum at or above 97%; the
maximum therefore crossed the hard ceiling.

A concurrent read-only `farmctl mt5-slots` census found five governed tester
processes on T2, T4, T8, T9, and T10, with one Q03 and four Q07 process
bindings and no orphaned governed process. No reservation, process control, or
terminal action followed.

## Non-duplicate delta

This sample completed 58.96 minutes after the preceding FX frontier sample.
Average CPU moved from 97.00% to 96.34%, while maximum CPU moved from 100.00%
to 98.60%; capacity changed but the hard ceiling remained binding. The
observation base advanced from `060bdc931` to `b855323a8`.

No Q02 or Q04 enqueue, requeue, priority change, dispatcher tick, smoke,
backtest, tester launch, terminal reservation, terminal reconciliation, or
terminal control was performed. Machine-readable evidence is
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260821T071541Z_board_advisor.json`.

## Safety

No portfolio-admission path, portfolio KPI, Q08 contribution, T_Live manifest,
T_Live terminal, AutoTrading state, Card, EA, EX5, setfile, basket manifest,
registry row, magic row, queue row, history archive, or containment state was
changed. Concurrent unrelated worktree changes were left unstaged and
untouched.
