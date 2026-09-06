# FX cointegration QM5_12507 Q02 hard-CPU stop

Recorded: 2026-09-06T12:16:23.064Z (14:16 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `db3876b17479e775120b717ce046fa6d6354f92d`

## Outcome

The frozen sign-aware 66-pair FX scan still has no unbuilt approved
relationship. Creating another scan-derived card or EA would duplicate governed
coverage. The preferred anchors also require no Q02 setup repair:
`QM5_12532` has logical-basket Q02 PASS followed by Q05 FAIL, and
`QM5_12533` has logical-basket Q02 PASS followed by Q04 FAIL.

The concrete existing fallback remains `QM5_12507_pair-coint-z`, the
EURUSD/GBPUSD H1 cointegration basket. Its canonical logical Q02 item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` remains the sole open row for
`QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1`: pending, unclaimed, unheld,
attempt zero, and without a verdict. It already carries `priority_track=true`,
so no duplicate enqueue or payload mutation was made.

## Capacity stop

Five one-second whole-host CPU samples were 99%, 94%, 99%, 97%, and 99%.
The average was 97.6% and the maximum was 99%, so both measures bind the
explicit 97% hard ceiling.

The read-only process census found factory terminals T3, T5, T8, and T9.
The canonical farm database recorded three active work items on T3, T5, and
T8; T9 was running a separate pipeline report. `T_Live` and an unrelated FTMO
terminal were observed only so they could be excluded. Neither was controlled.
Free physical memory was 27.799 GiB of 63.120 GiB and was not the binding gate.

Per the mission stop rule, no queue append, claim, dispatch tick, tester,
compile, terminal, hold, priority, or queue-payload mutation was attempted.

## Preserved execution contract

| Field | Value |
| --- | --- |
| EA | `QM5_12507_pair-coint-z` |
| Pair | `EURUSD.DWX` / `GBPUSD.DWX` |
| Logical symbol | `QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1` |
| Work item | `547c4fd3-f3fd-4c59-b9dc-654e96521251` |
| State | pending, unclaimed, unheld, attempt 0, no verdict |
| Predecessor | Q01 PASS (`7d1a179d-4d25-5d37-a69a-3a52fd78ae63`) |
| Risk | `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` |
| Manifest | `framework/EAs/QM5_12507_pair-coint-z/basket_manifest.json` |
| Setfile | `framework/EAs/QM5_12507_pair-coint-z/sets/QM5_12507_pair-coint-z_QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1_H1_backtest.set` |

The source, EX5, manifest, and logical backtest setfile remain byte-identical
to the prior sealed handoff.

## Safety and continuation

No portfolio-admission, portfolio-KPI, Q08-contribution, portfolio-gate,
`T_Live` manifest, live/deploy, or AutoTrading surface was touched.

On the next paced wake, re-read the exact Q02 row and take a fresh CPU sample.
If it remains unique, pending, unheld, and unclaimed and every CPU sample stays
below 97%, leave it to the governed terminal-worker claim order. Never append
a duplicate logical Q02 row.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12507_q02_hard_cpu_stop_20260906T121623Z_board_advisor.json`.
