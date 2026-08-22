# FX cointegration frontier: Q05 PASS / Q06 hard-CPU stop

**Date:** 2026-08-22 UTC (`2026-08-22T18:35:30Z`)

**Branch:** `agents/board-advisor`

**Status:** existing rank-27 FX basket reached Q05 PASS; Q06 is eligible but
was not enqueued because the explicit backtest CPU ceiling is binding

## Outcome

No new Strategy Card or EA was created. The durable sign-aware reconciliation
in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
still accounts for all 66 relationships from `analyze_cross_asset_v3.py
--include-negative-hedges`: 66 covered, zero uncovered. A new scan-derived
identity would therefore duplicate governed work.

The preferred anchors do not need Q02 repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 PASS and Q04 PASS, followed by
  Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 PASS, followed by Q04
  FAIL.

## Existing-pair advancement

The rank-27 `NZDUSD.DWX` / `EURAUD.DWX` basket
`QM5_20208_nzdusd-euraud` is the strongest non-duplicate fallback already
moving through the funnel. Its state changed materially since the preceding
16:32:58Z stop record:

- Q02 `1935fc01-6eaa-4db1-8397-660d22ebdfbb`: PASS.
- Q04 `3703d3fd-6e3a-4fc2-bc4a-20b2984479b2`: PASS_LOWFREQ.
- Q05 `1a53b4bd-abbd-4c6e-a13a-5f1a1542bf8d`: PASS, terminal at
  `2026-08-22T17:50:57Z`.

The Q05 aggregate reports PF 1.17, 108 trades, 2.57823% drawdown, and full
history from 2018-07-02 through 2025-12-31. Its EX5 binding is
`31d4460df6cd3e9ef579d8ed4e3849e62b3423ef0e942f6703122e2245988bc4`.
The generated stress setfile is fixed-risk (`RISK_FIXED=1000`,
`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`), and its hash matches the Q05
aggregate.

No Q06 work item existed at the final `farmctl work-items --ea QM5_20208`
check. Q05 PASS makes this exact append-only successor eligible once capacity
is below the ceiling:

```powershell
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_20208 --phase Q06 --from-work-item-id 1a53b4bd-abbd-4c6e-a13a-5f1a1542bf8d
```

That command was recorded for handoff only; it was not executed.

## Binding CPU stop

The required five-sample total-processor preflight returned 100%, 100%, 100%,
100%, and 100%. Both the maximum and average were 100%, above the explicit 97%
hard ceiling.

The path-aware slot view observed eight factory terminals (`T1`, `T10`, `T3`,
`T4`, `T5`, `T6`, `T8`, and `T9`). `T_Live` and the unrelated FTMO terminal
were observed only to exclude them; neither was controlled.

Per the mission stop condition, no Q06 enqueue, dispatch, tester launch,
reservation, repair, requeue, terminal control, or other queue mutation
followed. Machine-readable evidence is
`artifacts/fx_cointegration_frontier_q05_pass_q06_cpu_stop_20260822T183530Z_board_advisor.json`.

## Worktree and safety

- The factory-generated Q05 stress setfile was already untracked and was left
  unstaged and uncommitted with all other concurrent worktree changes.
- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, basket manifest, registry row, or magic row changed.
