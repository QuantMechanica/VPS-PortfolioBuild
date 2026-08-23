# FX cointegration fleet: exhausted frontier / hard CPU stop

**Date:** 2026-08-23 UTC (`2026-08-23T10:00:39Z`), Europe/Berlin

**Branch:** `agents/board-advisor`

**Status:** frozen 66-pair frontier fully mechanized; existing structural FX
basket retained as the fallback; stopped at the explicit backtest CPU ceiling

## Outcome

No new Strategy Card or EA was created. The durable sign-aware relationship
audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships produced by
`analyze_cross_asset_v3.py --include-negative-hedges`: 66 covered and zero
uncovered. A new scan-derived identity would duplicate governed work.

The preferred anchors do not need Q02 infrastructure repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 PASS and Q04 PASS, followed by
  Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 PASS, followed by Q04
  FAIL.

Neither anchor has a current Q02 ONINIT or NO_HISTORY blocker in the latest
durable reconciliation.

## Existing-pair fallback

The most recent same-day governed handoff selects the structural D1
`NZDUSD.DWX` / `EURAUD.DWX` basket `QM5_20208_nzdusd-euraud`, rank 27 in the
frozen scan. Its exact lineage is Q02 PASS, Q04 PASS_LOWFREQ, Q05 PASS, and one
Q06 retry row (`776e6310-7ad6-41ba-8a08-4d63e045d4e5`) last observed pending,
unclaimed, at attempt one. That row is already the unique non-duplicate next
step, so no enqueue, requeue, priority restamp, or second work item is valid.

The basket remains fixed-beta, structural, low-frequency, and bound to the
canonical harsh-stress setfile with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No strategy mechanic, source claim, indicator, ML
component, parameter, or risk setting changed.

## Binding capacity stop

The supported `farmctl mt5-slots` sample observed six governed factory
terminals actively testing: T1, T3, T4, T5, T8, and T9. The paced launch gate
in `D:/QM/strategy_farm/state/launch_gate_max.txt` is `1`, so the running
factory count was already six times the allowed launch capacity.

Five whole-host CPU readings were 100%, 100%, 100%, 100%, and 100%. Both the
100% average and 100% maximum exceed the explicit 97% hard ceiling. `T_Live`
and the unrelated FTMO terminal were observed only to exclude them from the
factory count; neither was controlled.

Per the mission stop condition, no further candidate query, queue mutation,
dispatch tick, tester launch, terminal reservation, terminal control, compile,
or backtest followed. Machine-readable evidence is in
`artifacts/fx_cointegration_fleet_cpu_stop_20260823T100039Z_board_advisor.json`.

## Safety

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, setfile, basket manifest, registry row, or magic row
  changed.
- Concurrent unrelated worktree changes were left unstaged and untouched.
