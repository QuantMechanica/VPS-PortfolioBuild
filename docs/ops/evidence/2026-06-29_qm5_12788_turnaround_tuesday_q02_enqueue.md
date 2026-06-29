# QM5_12788 Turnaround Tuesday Q02 Enqueue

Date: 2026-06-29

## Scope

- Mission: add a diverse, low-frequency FX calendar sleeve to the V5 funnel.
- Selected backlog card: `QM5_12788_turnaround-tuesday`, the approved top pick from the SM strategy-mining campaign.
- Diversity rationale: GBPUSD weekly calendar mean-reversion is outside the current index, metal, and energy survivor cluster.
- Lead symbol: `GBPUSD.DWX`.
- Optional FX-broad fanout from the card: `EURUSD.DWX`, `USDCAD.DWX`.

## Build Evidence

- EA: `framework/EAs/QM5_12788_turnaround-tuesday/QM5_12788_turnaround-tuesday.mq5`
- SPEC: `framework/EAs/QM5_12788_turnaround-tuesday/SPEC.md`
- Strategy card copy: `framework/EAs/QM5_12788_turnaround-tuesday/docs/strategy_card.md`
- Runtime card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_12788_turnaround-tuesday.md`
- Build result: `artifacts/qm5_12788_build_result.json`
- Runtime build result: `D:\QM\strategy_farm\artifacts\builds\ef8d5a9c-9807-464f-9df3-130315178d8a.json`
- Build task: `ef8d5a9c-9807-464f-9df3-130315178d8a`
- Magic rows: `127880000` GBPUSD, `127880001` EURUSD, `127880002` USDCAD.
- Risk mode: generated backtest setfiles use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- SPEC validation: PASS.
- Build check: PASS, failures `0`; warnings were existing shared-framework DWX advisories.
- Build-check report: `D:\QM\reports\framework\21\build_check_20260629_202044.json`
- Strict compile: PASS, errors `0`, warnings `0`.
- Compile log: `C:\QM\repo\framework\build\compile\20260629_202109\QM5_12788_turnaround-tuesday.compile.log`
- Smoke: PASS on `GBPUSD.DWX` H1, year 2024, terminal `T9`.
- Smoke summary: `D:\QM\reports\smoke\QM5_12788\20260629_202144\summary.json`

## Q02 Enqueue

`farmctl record-build` marked the build task `done` and inserted three Q02 work items:

| work_item_id | symbol | timeframe | status | setfile |
|---|---|---|---|---|
| `2260002d-1fa9-4106-9b57-3866aedbd1bc` | `GBPUSD.DWX` | `H1` | `pending` | `framework/EAs/QM5_12788_turnaround-tuesday/sets/QM5_12788_turnaround-tuesday_GBPUSD.DWX_H1_backtest.set` |
| `e92a70be-06a2-414c-a04e-b990c9758786` | `EURUSD.DWX` | `H1` | `pending` | `framework/EAs/QM5_12788_turnaround-tuesday/sets/QM5_12788_turnaround-tuesday_EURUSD.DWX_H1_backtest.set` |
| `690b52d3-fed0-493d-b71e-734d433539eb` | `USDCAD.DWX` | `H1` | `pending` | `framework/EAs/QM5_12788_turnaround-tuesday/sets/QM5_12788_turnaround-tuesday_USDCAD.DWX_H1_backtest.set` |

## Guardrails

- Structural only: fixed calendar, OHLC, and ATR rules; no ML, grid, martingale, or external data.
- Backtest setfiles are RISK_FIXED.
- No portfolio gate, Q11/Q12 artifacts, T_Live manifest, or AutoTrading state touched.
- Q02 execution is left to the paced factory workers.
