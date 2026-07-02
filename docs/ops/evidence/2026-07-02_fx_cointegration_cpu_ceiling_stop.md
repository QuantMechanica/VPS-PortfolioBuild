# FX Cointegration CPU-Ceiling Stop - 2026-07-02

Branch: `agents/board-advisor`

## Scope

Mission: grow the certified V5 portfolio book with forex market-neutral
cointegration baskets, preferring a Q02 unblock for `QM5_12532` or
`QM5_12533` if either strict survivor was still blocked.

## Research and Build State

The controlling source remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`.

Rerunning the local scan logic over the exported Darwinex D1 CSVs showed only
two strict 66-pair FX cointegration survivors:

| Pair | DEV Sharpe | OOS net Sharpe | OOS return | OOS trades | State |
|---|---:|---:|---:|---:|---|
| `EURJPY~GBPJPY` | 0.59 | 1.53 | 5.98% | 24 | built as `QM5_12533` |
| `AUDUSD~NZDUSD` | 0.13 | 1.29 | 5.68% | 14 | built as `QM5_12532` |

The same read-only rerun found 29 positive-hedge ranked rows. All locally
registered EdgeLab FX cointegration baskets from that ranked set are already
built:
`QM5_12532`, `QM5_12533`, `QM5_12624`, `QM5_12712`, `QM5_12723`,
`QM5_12728`, `QM5_12731`, `QM5_12732`, `QM5_12735`, `QM5_12739`,
`QM5_12747`, `QM5_12749`, `QM5_12751`, `QM5_12756`, `QM5_12758`,
`QM5_12760`, `QM5_12762`, `QM5_12764`, `QM5_12765`, `QM5_12766`,
`QM5_12768`, `QM5_12770`, `QM5_12772`, `QM5_12776`, `QM5_12778`,
`QM5_12781`, `QM5_12783`, `QM5_12786`, and `QM5_12803`.

## Current Funnel State

`QM5_12532_AUDNZD_COINTEGRATION_D1` is not Q02-blocked. It has Q02 `PASS`,
Q04 `PASS`, and the latest Q05 retry completed `INFRA_FAIL` at
`2026-07-02T10:23:08+00:00` after the existing timeout and CPU-trim repairs.
The current aggregate is:
`D:/QM/reports/work_items/82cab3d1-bf05-4aa4-8278-86c8064b16e7/QM5_12532/Q05/QM5_12532_AUDNZD_COINTEGRATION_D1/aggregate.json`.
Reason: `summary_missing` with exit code `3221225794` and runner timeout
`5520` seconds.

`QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` is not Q02-blocked. It has Q02
`PASS` and a later completed Q04 `FAIL`.

`QM5_12728_NZDUSD_GBPJPY_COINTEGRATION_D1` is already pending at Q04 after
the earlier no-history infra requeue, so no duplicate queue mutation was made.

`QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1` is the cleanest higher-progress
fallback candidate by phase state: Q02 `PASS`, Q03 `PASS`, Q04 `PASS`, and a
Q05 retry is already pending as work item
`1c0405e7-16d3-40e6-b884-6be1b504dc4c`. Its prior Q05 evidence is not a
strategy fail, but it is also not a cheap setup fix:

- Work item: `1c0405e7-16d3-40e6-b884-6be1b504dc4c`
- Evidence:
  `D:/QM/reports/work_items/1c0405e7-16d3-40e6-b884-6be1b504dc4c/QM5_12778/Q05/QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1/aggregate.json`
- Reason:
  `invalid_summary:BARS_ZERO,EMPTY_EXPERT,EMPTY_SYMBOL,HISTORY_CONTEXT_INVALID,INCOMPLETE_RUNS,M0_1970_PERIOD,NO_HISTORY,REPORT_MISSING,RUN_STATUS_INVALID`
- Runner timeout: 3420 seconds
- Attempt detail: two no-history empty report shells plus one trade-producing
  run that later ended as `REPORT_MISSING` / `METATESTER_HUNG`.

## CPU-Ceiling Stop

Factory slot scan at the stop point showed all T1-T5 terminals occupied:

| Terminal | Active work item |
|---|---|
| T1 | `QM5_10375` Q05 `NDX.DWX` |
| T2 | `QM5_9936` Q05 `USDJPY.DWX` |
| T3 | `QM5_10813` Q05 `GDAXI.DWX` |
| T4 | `QM5_1238` Q03 `XAUUSD.DWX` |
| T5 | `QM5_12821` Q02 `FX8_TWIN_CSM_BASKET_H1` |

Per mission constraint, I stopped at the backtest CPU ceiling instead of
requeueing another full-history FX basket run. `QM5_12532` has now consumed
multiple Q05 retries: the earlier retry failed inside the 3420-second runner
envelope, and the post-worker recheck below shows the later row also completed
`INFRA_FAIL` under a 5520-second wrapper. Another enqueue would be duplicate
CPU work without a new execution mode or budget decision. No manual MT5 tester
run was launched.

## Post-Worker Recheck

Rechecked the farm DB at `2026-07-02T11:04Z` before closing this pass. No
EdgeLab FX cointegration basket had an active or pending logical Q02/Q05/Q07
row. The relevant later-phase baskets had all completed as infra failures:

| EA | Phase | Symbol | Current verdict | Current reason |
|---|---|---|---|---|
| `QM5_12532` | Q05 | `QM5_12532_AUDNZD_COINTEGRATION_D1` | `INFRA_FAIL` | `summary_missing`, exit code `3221225794`, runner timeout `5520` |
| `QM5_12712` | Q05 | `QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1` | `INFRA_FAIL` | `invalid_summary:INCOMPLETE_RUNS,TIMEOUT`, exit code `3221225794`, runner timeout `5520` |
| `QM5_12772` | Q05 | `QM5_12772_GBPJPY_AUDJPY_COINTEGRATION_D1` | `INFRA_FAIL` | `summary_missing`, exit code `3221225794`, runner timeout `5520` |
| `QM5_12778` | Q05 | `QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1` | `INFRA_FAIL` | no-history/report-missing invalid summary, exit code `3221225794`, runner timeout `5520` |
| `QM5_12781` | Q07 | `QM5_12781_USDJPY_AUDJPY_COINTEGRATION_D1` | `INFRA_FAIL` | all five seeds invalid with exit code `3221225794`, runner timeout `2520` |

I did not requeue any of these rows. The next non-duplicate action needs a new
runner mode, a narrower validated stress window, or an owner-approved timeout
budget; replaying the same worker-owned path would only consume terminal time.

## Safety

No `T_Live`, AutoTrading, portfolio admission, portfolio KPI, Q08
contribution, portfolio gate, or deploy manifest files were touched.
