# FX cointegration QM5_12507 Q02 CPU-ceiling stop

Recorded: 2026-09-06T11:15:56.746Z (13:15 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `99d726752869f3f30992a503c3de246790621716`

## Outcome

The frozen sign-aware 66-pair FX scan has no unbuilt approved relationship.
Creating another scan-derived card or EA would duplicate governed coverage. The
preferred anchors also require no Q02 setup repair: `QM5_12532` has logical
basket Q02 PASS followed by Q05 FAIL, while `QM5_12533` has logical-basket Q02
PASS followed by Q04 FAIL.

The concrete existing fallback remains `QM5_12507_pair-coint-z`, the
EURUSD/GBPUSD H1 cointegration basket. Its canonical logical Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` is still pending, unclaimed, attempt
zero, and has no verdict. That row is already the unique current enqueue for
logical symbol `QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1`; no duplicate row was
appended.

## Capacity stop

The explicit backtest CPU ceiling bound. Five one-second whole-host samples
were 100%, 93%, 94%, 97%, and 94% (average 95.6%, maximum 100%) against the
97% hard ceiling rule, which stops on either average or any sample meeting the
ceiling. Free physical memory was 33.715 GiB of 63.120 GiB.

The canonical farm view showed four active work items: one Q08 and three
OPT_CENSUS jobs. The process census found factory terminals T3 and T9. `T_Live`
and an unrelated FTMO terminal were observed only and were not controlled.
No claim, dispatch tick, tester, compile, terminal, hold, priority, or queue
payload mutation was attempted.

## Preserved execution contract

| Field | Value |
| --- | --- |
| EA | `QM5_12507_pair-coint-z` |
| Pair | `EURUSD.DWX` / `GBPUSD.DWX` |
| Logical symbol | `QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1` |
| Work item | `547c4fd3-f3fd-4c59-b9dc-654e96521251` |
| State | pending, unclaimed, attempt 0, no verdict |
| Risk | `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` |
| Manifest | `framework/EAs/QM5_12507_pair-coint-z/basket_manifest.json` |
| Setfile | `framework/EAs/QM5_12507_pair-coint-z/sets/QM5_12507_pair-coint-z_QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1_H1_backtest.set` |

The current source, EX5, manifest, and setfile hashes match the prior sealed
Q02 handoff. No EA or execution artifact was changed.

## Safety boundary and continuation

No portfolio-admission, portfolio-KPI, Q08-contribution, portfolio-gate,
`T_Live` manifest, live/deploy, or AutoTrading surface was touched.

On the next paced wake, re-read the exact Q02 row and re-sample capacity. If it
remains uniquely pending, unheld, and unclaimed and every CPU sample stays
below 97%, leave it to the governed terminal-worker claim order. Never append
a duplicate logical Q02 row.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12507_q02_cpu_ceiling_stop_20260906T111556Z_board_advisor.json`.
