# FX Cointegration Frontier / QM5_12507 Q04 CPU-Ceiling Stop - 2026-07-09

Mission scope: grow the V5 portfolio book with forex sleeves, preferably market-neutral FX cointegration baskets.

## Decision

No new unbuilt FX cointegration pair was selected. The documented strict 66-pair scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` produced only two strict survivors:

- `QM5_12533` EURJPY/GBPJPY: already built, Q02 PASS, later Q04 strategy FAIL.
- `QM5_12532` AUDUSD/NZDUSD: already built, Q02 PASS, later downstream Q05 history/CPU evidence.

The local approved FX cointegration/coint card audit found 20 approved cards, all with EA folders and Q02 work already present. The fallback existing forex lane is `QM5_12507_pair-coint-z` on EURUSD/GBPUSD:

- EURUSD Q02: PASS.
- GBPUSD Q02: PASS.
- EURUSD Q04: FAIL.
- GBPUSD Q04: pending.

No duplicate Q02/Q04 work item was inserted.

## CPU Ceiling

Current farm snapshot showed 7 active work items across 7 enabled terminal workers:

- Q02 active: 5.
- Q04 active: 1.
- Q06 active: 1.

`terminal64.exe` was also running for `T_Live` and FTMO outside the pipeline. No T_Live files, manifest, AutoTrading, or portfolio gate files were touched. No manual MT5 backtest was launched.

Evidence JSON: `artifacts/fx_cointegration_qm5_12507_q04_cpu_ceiling_20260709T0055Z.json`.
