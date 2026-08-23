# FX cointegration frontier: QM5_20208 Q06 terminal / hard CPU stop

**Date:** 2026-08-23 UTC (`2026-08-23T11:31:34Z`), Europe/Berlin

**Branch:** `agents/board-advisor`

**Status:** frozen 66-pair frontier remains fully mechanized; selected existing
FX basket reached terminal Q06 FAIL; stopped at the explicit backtest CPU
ceiling

## Outcome

No new Strategy Card or EA was created. The durable sign-aware relationship
audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships produced by
`analyze_cross_asset_v3.py --include-negative-hedges`: 66 covered and zero
uncovered. A further scan-derived identity would duplicate governed work.

Fresh supported `farmctl work-items` reads reconfirmed that the preferred
anchors do not need Q02 infrastructure repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has terminal Q02 PASS
  (`e4890d77-b865-4a48-b946-315faefca920`), followed by Q04 PASS and Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has terminal Q02 PASS
  (`76cb11ee-7e9d-4d75-be9d-626c205bca62`), followed by Q04 FAIL.

Neither anchor has a current Q02 ONINIT or NO_HISTORY blocker.

## Existing-pair fallback reached a terminal verdict

The selected structural D1 `NZDUSD.DWX` / `EURAUD.DWX` basket
`QM5_20208_nzdusd-euraud`, rank 27 in the frozen scan, now has this exact
lineage:

- Q02 `1935fc01-6eaa-4db1-8397-660d22ebdfbb`: PASS.
- Q04 `3703d3fd-6e3a-4fc2-bc4a-20b2984479b2`: PASS_LOWFREQ.
- Q05 `1a53b4bd-abbd-4c6e-a13a-5f1a1542bf8d`: PASS.
- Q06 `776e6310-7ad6-41ba-8a08-4d63e045d4e5`: done, attempt one, FAIL at
  `2026-08-23T09:41:02Z`.

This is a new terminal state relative to the previous receipt at
`artifacts/fx_cointegration_fleet_cpu_stop_20260823T100039Z_board_advisor.json`,
which last recorded that sole Q06 row as pending and unclaimed. No duplicate
enqueue, requeue, priority restamp, or replacement work item was created.

The basket's canonical backtest contract remains structural, fixed-beta,
low-frequency, and `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1`. No strategy mechanic, source claim, indicator, ML
component, parameter, or risk setting changed.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-23T11:31:19Z` observed
five governed factory terminals actively testing: T2, T3, T4, T7, and T8. The
paced launch gate in `D:/QM/strategy_farm/state/launch_gate_max.txt` is `1`, so
the running factory count was already five times the permitted launch
capacity.

Five whole-host CPU readings were 100%, 100%, 100%, 100%, and 100%. Both the
100% average and 100% maximum exceed the explicit 97% hard ceiling. `T_Live`
and the unrelated FTMO terminal were observed only to exclude them from the
factory count; neither was controlled.

Per the mission stop condition, the Q06 terminal result was not followed by
another candidate selection, queue mutation, dispatch tick, tester launch,
terminal reservation, terminal control, compile, or backtest. Machine-readable
evidence is in
`artifacts/fx_cointegration_qm5_20208_q06_fail_cpu_stop_20260823T113134Z_board_advisor.json`.

## Safety

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, setfile, basket manifest, registry row, or magic row
  changed.
- Concurrent unrelated staged and unstaged worktree changes were left
  untouched.
