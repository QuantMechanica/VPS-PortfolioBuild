# FX cointegration fallback — Q02 CPU-ceiling stop

- Observed UTC: `2026-07-26T09:16:33Z`
- Branch: `agents/board-advisor`
- Fallback candidate: `QM5_20062_kats-eu-macisar`
- Instrument / timeframe: `EURUSD.DWX / D1`
- Farm build task: `ee2fe37e-5509-4371-8979-c58db2966313`

## Non-duplicate decision

The governed FX cointegration frontier remains exhausted. Repository evidence
in `docs/research/FX_COINTEGRATION_FRONTIER_DUPLICATE_GUARD_2026-07-24.md`
shows that both anchor baskets are already beyond Q02:

- `QM5_12532` AUDUSD/NZDUSD has logical-basket Q02 PASS and later Q05 FAIL.
- `QM5_12533` EURJPY/GBPJPY has logical-basket Q02 PASS and later Q04 FAIL.

All seven governed scan qualifiers have builds and terminal Q02 evidence.
Creating another card from that scan, repairing either anchor at Q02, or
re-enqueueing one of those completed Q02 rows would duplicate existing work.

The mission fallback is therefore the existing approved, built forex card
`QM5_20062_kats-eu-macisar`. It is a low-frequency EURUSD D1 sleeve with an
active EA registry row, active magic row `200620000`, a compiled EX5, and a
canonical backtest setfile. The card is OWNER-approved at G0 and the setfile
uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

No strategy, card, registry, EA, binary, setfile, or basket manifest was
changed during this wake.

## Binding paced-fleet ceiling

`python tools/strategy_farm/farmctl.py mt5-slots` reported exactly seven
running factory terminals, equal to the documented paced-fleet ceiling:

| Terminal | EA | Phase | Symbol |
|---|---|---|---|
| T2 | `QM5_11912` | Q02 | `AUDJPY.DWX` |
| T3 | `QM5_20007` | Q02 | `SP500.DWX` |
| T4 | `QM5_12365` | Q07 | `XAUUSD.DWX` |
| T6 | `QM5_20161` | Q02 | `QM5_20161_XAUUSD_XAGUSD_OLS_D1` |
| T7 | `QM5_1567` | Q07 | `GBPJPY.DWX` |
| T8 | `QM5_11912` | Q02 | `EURJPY.DWX` |
| T10 | `QM5_13036` | Q07 | `GDAXI.DWX` |

The separately observed `T_Live` and FTMO terminal processes were excluded
from the factory count and were not controlled. All nine configured
terminal-worker daemons were present.

Per the mission's explicit CPU-ceiling rule, execution stopped before claiming
the build task, submitting the required smoke, recording a build result,
enqueueing Q02, dispatching work, or launching MT5.

## Handoff and safety

When the factory count is below seven, recheck that `QM5_20062` has no pending
or active Q02 work item, then use the supported farm build-result path to
enqueue exactly one `EURUSD.DWX` D1 Q02 item. Do not bypass the one-pass smoke
or capacity resolver.

No portfolio-admission, portfolio KPI, Q08 contribution, deploy manifest,
`T_Live` manifest, live setfile, AutoTrading state, terminal process, or live
artifact was changed.
