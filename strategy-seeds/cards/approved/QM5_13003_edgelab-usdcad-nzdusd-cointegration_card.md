---
ea_id: QM5_13003
slug: edgelab-usdcad-nzdusd-cointegration
type: strategy
source_id: claude_cross_asset_discovery_2026-06-09
source_citation: "Chan, Ernest P. (2009). Quantitative Trading. Wiley, Chapter 7 stationarity and cointegration; plus QuantMechanica in-house 66-pair FX cointegration scan rerun on Darwinex .DWX D1 data."
sources:
  - "strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md"
  - "docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md"
  - "framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py"
concepts:
  - cointegration-pair-trade
  - zscore-band-reversion
  - market-neutral-fx-basket
indicators:
  - rolling-zscore
  - atr-stop
target_symbols: [USDCAD.DWX, NZDUSD.DWX]
logical_symbol: QM5_13003_USDCAD_NZDUSD_COINTEGRATION_D1
period: D1
expected_trade_frequency: "D1 two-leg basket, approximately 6-10 logical spread packages/year."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-03
g0_approval_reasoning: "R1 PASS Chan cointegration method plus OWNER-requested in-house 66-pair FX scan; R2 PASS deterministic fixed-pair z-score basket; R3 PASS USDCAD.DWX and NZDUSD.DWX data exist in scan universe; R4 PASS no ML/grid/martingale."
expected_pf: 1.10
expected_dd_pct: 25.0
portfolio_scope: basket
---

# Edge Lab USDCAD/NZDUSD Cointegration Basket

## Source

This card uses Chan's cointegration pair-trading structure from
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`: form a
stationary two-asset spread, compute a z-score, enter against extreme deviations,
and exit near the mean. The pair was selected from a full QuantMechanica 66-pair
FX scan rerun on Darwinex `.DWX` D1 data, using the same exported data and cost
model as `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`.

source_citation: Chan, Ernest P. (2009). Quantitative Trading. Wiley, Chapter 7;
QuantMechanica 2026 in-house 66-pair FX scan rerun on Darwinex `.DWX` D1 data.

The published positive-hedge scan hard-certified only `QM5_12533` and
`QM5_12532`. A full rerun that includes negative hedge ratios found
USDCAD/NZDUSD as the next unbuilt strict row: DEV Sharpe 0.4613, OOS net Sharpe
1.1259, OOS return 4.6620%, 21 OOS state changes, hedge -0.423071, and
54.67-day half-life.

## Concept

USDCAD and NZDUSD are both USD-linked majors, but their quote orientation is
opposite. A negative hedge ratio captures a spread where USD exposure is
partly offset by holding both legs in the same direction when the spread is
long, or shorting both legs when the spread is short.

## Hypothesis

Temporary dislocations in `ln(USDCAD) - beta * ln(NZDUSD)` can mean-revert
because CAD and NZD both respond to commodity, China/risk, and USD-liquidity cycles while retaining separate local-rate residuals. The scan result is in-house and low-sample, so
the pipeline is the judge.

## Markets And Timeframe

- Host symbol: USDCAD.DWX.
- Basket legs: USDCAD.DWX and NZDUSD.DWX.
- Logical symbol: QM5_13003_USDCAD_NZDUSD_COINTEGRATION_D1.
- Period: D1.
- Backtest risk mode: RISK_FIXED.

## Rules

- Entry, exit, and broken-package handling are deterministic.
- The EA trades only the fixed USDCAD/NZDUSD basket; it does not reselect pairs
  or refit beta in-test.
- No averaging, grid, martingale, pyramiding, trailing stop, or ML component is
  allowed.

## Entry Rules

- Evaluate only after a new closed D1 bar.
- Compute `spread = ln(USDCAD) - (-0.423070732289) * ln(NZDUSD)`.
- Compute a 60-bar rolling z-score of the spread.
- If no pair package is open and z > +2.0, open a short-spread package: short USDCAD and short NZDUSD.
- If no pair package is open and z < -2.0, open a long-spread package: long USDCAD and long NZDUSD.
- Size each leg from V5 fixed risk, split by absolute hedge weights.

## Exit Rules

- Close both legs when `abs(z) < 0.5`.
- Each leg receives a hard ATR(20) * 2.0 protective stop.
- If only one leg remains open, close it immediately as a broken package.
- Framework Friday close remains enabled.

## Filters

- Host chart must be USDCAD.DWX or NZDUSD.DWX on D1/H1, with slot 0 used for the logical host.
- No pyramiding, averaging, grid, martingale, partial close, or trailing stop.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Parameters To Test

- name: strategy_z_lookback_d1
  default: 60
  sweep_range: [40, 60, 90]
- name: strategy_beta
  default: -0.423070732289
  sweep_range: [-0.55, -0.423070732289, -0.30]
- name: strategy_entry_z
  default: 2.0
  sweep_range: [1.75, 2.0, 2.25]
- name: strategy_exit_z
  default: 0.5
  sweep_range: [0.25, 0.5, 0.75]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.0
  sweep_range: [1.5, 2.0, 2.5]

## Author Claims

No external performance claim is taken from Chan for USDCAD/NZDUSD specifically.
The in-house full-scan rerun found DEV Sharpe 0.4613 and OOS net Sharpe 1.1259
after the scan cost model. Pipeline gates are the judge.

## Initial Risk Profile

- expected_pf: 1.10.
- expected_dd_pct: 25.
- expected_trade_frequency: approximately 6-10 basket packages/year.
- risk_class: high because this is an in-house full-scan extension with a negative hedge ratio.
- gridding: false.
- scalping: false.
- ml_required: false.

## Risk

Backtests use V5 `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No live risk is authorized by this card; any future live
burn-in would be assigned only by the standard portfolio pipeline after all
gates.

## Strategy Allowability Check

- [x] R1 reputable source: Chan cointegration method plus OWNER-requested in-house 66-pair scan.
- [x] R2 mechanical: fixed beta, z-score entry/exit, ATR stop, broken-package close.
- [x] R3 testable: USDCAD.DWX and NZDUSD.DWX are Darwinex-native `.DWX` symbols in the exported scan data.
- [x] R4 compliant: no ML, no grid, no martingale, low-frequency D1.

## Framework Alignment

- no_trade: fixed host/symbol guard plus framework news/Friday/kill-switch.
- trade_entry: D1 cointegration spread z-score threshold with negative-beta leg direction.
- trade_management: broken-package cleanup only.
- trade_close: mean-reversion exit and framework Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-03 | initial full-scan next-unbuilt FX cointegration basket card | G0 | APPROVED |
| v2 | 2026-07-03 | compiled basket EA and logical basket Q02 enqueued as work item 48141c69-b04f-4ebc-a6fe-fd15bc30317e | Q02 | PENDING |
