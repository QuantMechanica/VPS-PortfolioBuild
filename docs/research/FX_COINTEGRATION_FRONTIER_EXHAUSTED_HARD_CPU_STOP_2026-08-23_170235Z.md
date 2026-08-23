# FX cointegration frontier: exhausted scan / hard CPU stop

**Date:** 2026-08-23 UTC (`2026-08-23T17:03:28Z`), Europe/Berlin

**Branch:** `agents/board-advisor`

**Status:** frozen 66-pair frontier remains fully mechanized; the latest
existing-pair fallback is terminal; stopped at the explicit backtest CPU
ceiling

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

Neither anchor has a current Q02 ONINIT or NO_HISTORY blocker.

## Existing-pair fallback reconciliation

The most recent selected structural D1 basket,
`QM5_20208_nzdusd-euraud` (`NZDUSD.DWX` / `EURAUD.DWX`, frozen-scan rank 27),
has terminal lineage Q02 PASS, Q04 PASS_LOWFREQ, Q05 PASS, and Q06 FAIL. Its
sole Q06 row, `776e6310-7ad6-41ba-8a08-4d63e045d4e5`, is already done. The
durable terminal evidence is
`artifacts/fx_cointegration_qm5_20208_q06_fail_cpu_stop_20260823T113134Z_board_advisor.json`.

Re-enqueueing that row or advancing through its terminal hard failure would be
invalid duplicate work. Its canonical contract remains structural,
fixed-beta, low-frequency, and `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1`; no mechanic, parameter, source claim, indicator, ML
component, or risk setting changed.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-23T17:02:09Z`
observed six governed factory terminals actively testing: T1, T3, T4, T6, T7,
and T10. The paced launch gate in
`D:/QM/strategy_farm/state/launch_gate_max.txt` is `1`, so the factory count
was already six times the permitted launch capacity.

Five current whole-host CPU readings were `92.79%`, `100.00%`, `94.26%`,
`100.00%`, and `96.29%`. Their average was `96.668%` and their maximum was
`100.00%`. The explicit ceiling binds when either the average or maximum is at
least `97%`; the maximum therefore triggered the stop. `T_Live` and the
unrelated FTMO terminal were observed only to exclude them from the factory
count; neither was controlled.

Per the mission stop condition, no further candidate search, card or EA
creation, queue mutation, dispatch tick, tester launch, terminal reservation,
terminal control, compile, or backtest followed. Machine-readable evidence is
in
`artifacts/fx_cointegration_frontier_exhausted_cpu_stop_20260823T170235Z_board_advisor.json`.

## Safety

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, setfile, basket manifest, registry row, or magic row
  changed.
- Concurrent unrelated worktree changes were left unstaged and untouched.
