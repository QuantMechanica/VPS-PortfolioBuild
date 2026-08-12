# QM5_20183 GBPUSD/USDCHF Q02 Terminal Retirement

Date: 2026-07-31 (Europe/Berlin)

Branch: `agents/board-advisor`

EA: `QM5_20183_gbpusd-chf-coint`

## Outcome

The existing GBPUSD/USDCHF D1 cointegration basket completed its single
logical Q02 work item with a terminal `FAIL`. This is the non-duplicate
existing-forex fallback after confirming that `QM5_12532` and `QM5_12533` are
already past Q02 and that every strict qualifier from the governed 66-pair
scan already has a dedicated build and terminal Q02 evidence.

No new below-screen tail pair was carded. The fixed scan's reputable-source
screen requires positive DEV net Sharpe, OOS net Sharpe above 0.8, and at least
four OOS state changes; weakening that screen after observing the existing
frontier would be post-selection overfit.

## Terminal Q02 Evidence

- Work item: `564a8012-bb2b-4edf-a9f1-acd04b177d64`
- Logical symbol: `QM5_20183_GBPUSD_USDCHF_COINTEGRATION_D1`
- Host/companion: `GBPUSD.DWX` / `USDCHF.DWX`
- Status/verdict: `done` / `FAIL`
- Reason class: `MIN_TRADES_NOT_MET`
- Test window: 2018-07-02 through 2022-12-31, D1, model 4
- Trades: 8 against the binding minimum of 25
- Profit factor: 0.82
- Net profit: -243.26
- Drawdown: 792.18 (0.79%)
- `oninit_failure_detected`: `false`
- Evidence:
  `D:/QM/reports/work_items/564a8012-bb2b-4edf-a9f1-acd04b177d64/QM5_20183/20260731_155342/summary.json`

The run used the canonical logical-basket setfile, and the evidence records
matching source/deployed hashes for both the EA binary and setfile. The tester
completed normally with exit code 0. There is no `ONINIT`, `NO_HISTORY`, stale
binary, wrong-setfile, or physical-host dispatch defect to repair.

## Retirement Decision

The approved card predeclares retirement at Q02 when realized cadence is below
the binding floor and retirement on a terminal economic Q02 failure. It also
forbids a post-failure regime, carry, trend-filter, beta-refit, or parameter
sweep rescue because DEV net Sharpe was already negative.

The observed result triggers both the cadence and economic cautions. The Q02
row was not reset, duplicated, reprioritized, or re-enqueued, and the strategy
logic and parameters were not changed.

## CPU Ceiling

The final read-only slot scan at `2026-07-31T22:04:05Z` found seven factory
backtests running on `T1`, `T5`, `T6`, `T7`, `T8`, `T9`, and `T10`, exactly at
the documented ceiling. The separate pre-existing `T_Live` process was
observed only to exclude it and was not controlled.

Per the paced-fleet boundary, no new Q02 work item, dispatch, tester launch,
backtest, wait loop, or downstream phase action followed.

## Safety

- No portfolio admission, portfolio KPI, or Q08 contribution artifact changed.
- No `T_Live` file, manifest, terminal, or AutoTrading state changed.
- No live setfile, deploy artifact, registry row, magic row, EA source, binary,
  setfile, or basket manifest changed.
