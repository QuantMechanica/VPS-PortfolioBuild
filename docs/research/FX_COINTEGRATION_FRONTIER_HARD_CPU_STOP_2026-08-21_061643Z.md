# FX cointegration frontier hard CPU stop

Date: 2026-08-21 UTC

Branch: `agents/board-advisor`

Status: stopped at the explicit backtest CPU ceiling before any queue or
execution mutation

## Outcome

No new FX Strategy Card or EA was created. The latest committed governed
reconciliation (`1ac37f468`) accounts for all 66 relationships in the frozen
sign-aware scan, so another Card, registry allocation, basket manifest, or EA
would duplicate existing work.

That same committed evidence records both preferred anchors beyond Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

Neither had an ONINIT or NO_HISTORY Q02 blocker. The selected non-duplicate
continuation remained rank-21 `QM5_20203_EURUSD_AUDJPY_COINTEGRATION_D1`,
whose Q02 verdict is PASS and whose Q04 successor was already pending exactly
once. This run does not represent those database facts as freshly queried:
the CPU stop bound first, so the last committed reconciliation remains the
explicit reference.

## Binding capacity stop

Five fresh whole-host CPU readings were 85%, 100%, 100%, 100%, and 100%.
Their average was exactly 97% and their maximum was 100%. The mission's 97%
hard ceiling therefore bound under both the average and maximum tests.

No Q02 or Q04 dispatch, enqueue, requeue, priority change, tester launch,
terminal reservation, terminal reconciliation, or terminal control followed.

## Non-duplicate delta

The sample completed approximately 60.36 minutes after the preceding CPU
sample. Average CPU moved from 100% to 97%, while maximum CPU remained 100%;
capacity therefore changed but did not clear the hard stop. The observation
base advanced from `ebed8e292` to `060bdc931` during that interval.

Machine-readable evidence is
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260821T061643Z_board_advisor.json`.

## Safety

No portfolio-admission path, portfolio KPI, Q08 contribution, T_Live
manifest, T_Live terminal, AutoTrading state, Card, EA, EX5, setfile, basket
manifest, registry row, magic row, queue row, history archive, or containment
state was changed. Concurrent unrelated worktree changes were left unstaged
and untouched.
