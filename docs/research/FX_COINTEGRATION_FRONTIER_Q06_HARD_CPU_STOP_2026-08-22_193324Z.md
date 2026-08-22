# FX cointegration frontier: Q06 hard-CPU stop

**Date:** 2026-08-22 UTC (`2026-08-22T19:33:24Z`)

**Branch:** `agents/board-advisor`

**Status:** existing rank-27 FX basket remains Q06-eligible; no queue mutation
because the explicit backtest CPU ceiling is binding

## Outcome

No new Strategy Card or EA was created. The durable sign-aware reconciliation
in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships from `analyze_cross_asset_v3.py
--include-negative-hedges`: 66 covered and zero uncovered. Another
scan-derived identity would therefore duplicate governed work.

The preferred anchors do not need Q02 repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 PASS and Q04 PASS, followed by
  Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 PASS, followed by Q04
  FAIL.

## Existing-pair fallback

The rank-27 `NZDUSD.DWX` / `EURAUD.DWX` logical basket
`QM5_20208_nzdusd-euraud` remains the strongest non-duplicate successor. A
fresh canonical `farmctl work-items --ea QM5_20208` query returned exactly
three terminal rows:

- Q02 `1935fc01-6eaa-4db1-8397-660d22ebdfbb`: PASS.
- Q04 `3703d3fd-6e3a-4fc2-bc4a-20b2984479b2`: PASS_LOWFREQ.
- Q05 `1a53b4bd-abbd-4c6e-a13a-5f1a1542bf8d`: PASS.

No Q06 work item was present. The Q05 aggregate remains authenticated to EX5
SHA-256 `31d4460df6cd3e9ef579d8ed4e3849e62b3423ef0e942f6703122e2245988bc4`
and reports PF 1.17, 108 trades, 2.57823% drawdown, and full history from
2018-07-02 through 2025-12-31. Its generated setfile preserves the required
backtest risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

The exact append-only successor remains:

```powershell
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_20208 --phase Q06 --from-work-item-id 1a53b4bd-abbd-4c6e-a13a-5f1a1542bf8d
```

That command was recorded only and was not executed.

## Binding CPU stop

The required five-sample whole-host preflight returned 96%, 100%, 87%, 100%,
and 93%. The average was 95.2%, but the maximum reached 100%. The governed
rule binds when either the average or maximum is at or above 97%, so the
mission stopped before any queue mutation.

The path-aware slot scan at `2026-08-22T19:32:32Z` observed only two factory
terminals (`T3` and `T5`), down from eight in the preceding stop record, while
all ten enabled terminal-worker daemons remained alive. The peak CPU ceiling
therefore remained binding despite the materially lower instantaneous MT5
process count. `T_Live` and the unrelated FTMO terminal were observed only to
exclude them; neither was controlled. Disk capacity was not limiting at
119.8 GiB free on `D:`.

Per the explicit stop condition, no Q06 enqueue, dispatch, tester launch,
reservation, repair, requeue, terminal control, or other queue mutation
followed. Machine-readable evidence is
`artifacts/fx_cointegration_frontier_q06_cpu_stop_20260822T193324Z_board_advisor.json`.

## Worktree and safety

- The factory-generated Q05 stress setfile was already untracked and remains
  unstaged and uncommitted with the concurrent worktree changes.
- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, basket manifest, registry row, magic row, or setfile was
  changed.
