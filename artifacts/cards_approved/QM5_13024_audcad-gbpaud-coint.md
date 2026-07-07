---
ea_id: QM5_13024
slug: audcad-gbpaud-coint
type: strategy
source_id: QM-COINT-SCREEN-EXT-2026-07-06_AUDCAD-GBPAUD
source_citation: "Chan, Ernest P. (2009). Quantitative Trading. Wiley, Chapter 7 stationarity and cointegration; plus QuantMechanica extended FX cointegration screen on Darwinex .DWX D1 data, 2017-10-02 to 2025-12-31."
sources:
  - "strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md"
  - "docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md"
  - "D:/QM/strategy_farm/artifacts/research/coint_screen_ext_20260706/results_full.csv"
  - "D:/QM/strategy_farm/artifacts/research/coint_screen_ext_20260706/survivors.json"
concepts:
  - cointegration-pair-trade
  - zscore-band-reversion
  - market-neutral-fx-basket
indicators:
  - rolling-zscore
  - atr-stop
target_symbols: [AUDCAD.DWX, GBPAUD.DWX]
logical_symbol: QM5_13024_AUDCAD_GBPAUD_COINTEGRATION_D1
period: D1
expected_trade_frequency: "D1 two-leg basket, approximately 4-8 logical spread packages/year."
expected_trades_per_year_per_symbol: 5
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-07
g0_approval_reasoning: "R1 PASS Chan cointegration method plus OWNER-directed in-house FX cointegration scan; R2 PASS deterministic fixed-pair z-score basket; R3 PASS AUDCAD.DWX and GBPAUD.DWX data exist in the extended Darwinex scan; R4 PASS no ML/grid/martingale."
expected_pf: 1.10
expected_dd_pct: 25.0
portfolio_scope: basket
---

# AUDCAD/GBPAUD Cointegration Basket

## Source

This card uses Chan's cointegration pair-trading structure from
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`: form a
two-asset spread, compute a z-score, enter against extreme deviations, and exit
near the mean. The pair was selected from the QuantMechanica extended FX
cointegration screen on Darwinex `.DWX` D1 data after the original positive
hedge scan certified only `QM5_12533` and `QM5_12532`.

source_citation: Chan, Ernest P. (2009). Quantitative Trading. Wiley, Chapter 7;
QuantMechanica 2026 extended FX cointegration screen on Darwinex `.DWX` D1 data.

The extended screen flags `AUDCAD~GBPAUD` as the best card-worthy sibling
candidate: both half-sample ADF tests pass (`t=-3.685`, `p=0.0197` and
`t=-3.639`, `p=0.0225`), hedge sign is stable, and the 60-bar rolling z-score
has 44 `|z| >= 2` excursions across 2,121 observations. It is not a formal
all-gates survivor because the estimated half-life is 81.2 days versus the
original strict 60-day filter. That caveat is anchor-like rather than disqualifying
for this research card because `QM5_12532` already carried a 65-day half-life,
and the trade-check output labels this row card-worthy with OOS net Sharpe 1.16,
OOS return 11.2%, 34 OOS state changes, and DEV hedge `-0.4667`.

## Concept

AUDCAD and GBPAUD share AUD exposure but express it through different commodity,
rates, and GBP/CAD residual channels. The negative hedge ratio creates a
same-direction package: long spread means long AUDCAD and long GBPAUD; short
spread means short both legs. The basket is meant to be market-neutral at the
spread level, not a directional AUD forecast.

## Hypothesis

Temporary dislocations in `ln(AUDCAD) - beta * ln(GBPAUD)` can mean-revert
because both legs contain AUD while their non-AUD legs, CAD and GBP, carry
distinct local-rate and commodity/risk premia. The scan result is in-house and
the half-life is slow, so the pipeline gates remain the judge.

## Markets And Timeframe

- Host symbol: AUDCAD.DWX.
- Basket legs: AUDCAD.DWX and GBPAUD.DWX.
- Conversion/history dependencies for USD tester accounting: USDCAD.DWX and AUDUSD.DWX.
- Logical symbol: QM5_13024_AUDCAD_GBPAUD_COINTEGRATION_D1.
- Period: D1.
- Backtest risk mode: RISK_FIXED.

## Rules

- Entry, exit, and broken-package handling are deterministic.
- The EA trades only the fixed AUDCAD/GBPAUD basket; it does not reselect pairs
  or refit beta in-test.
- No averaging, grid, martingale, pyramiding, trailing stop, or ML component is
  allowed.

## Entry Rules

- Evaluate only after a new closed D1 bar.
- Compute `spread = ln(AUDCAD) - (-0.4667) * ln(GBPAUD)`.
- Compute a 60-bar rolling z-score of the spread.
- If no pair package is open and z > +2.0, open a short-spread package: short AUDCAD and short GBPAUD.
- If no pair package is open and z < -2.0, open a long-spread package: long AUDCAD and long GBPAUD.
- Size each leg from V5 fixed risk, split by absolute hedge weights.

## Exit Rules

- Close both legs when `abs(z) < 0.5`.
- Each leg receives a hard ATR(20) * 2.0 protective stop.
- If only one leg remains open, close it immediately as a broken package.
- Framework Friday close remains enabled.

## Filters

- Host chart must be AUDCAD.DWX or GBPAUD.DWX on D1/H1, with slot 0 used for
  the logical host.
- No pyramiding, averaging, grid, martingale, partial close, or trailing stop.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Parameters To Test

- name: strategy_z_lookback_d1
  default: 60
  sweep_range: [40, 60, 90]
- name: strategy_beta
  default: -0.4667
  sweep_range: [-0.60, -0.4667, -0.30]
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

No external performance claim is taken from Chan for AUDCAD/GBPAUD specifically.
The in-house extended scan found this as a card-worthy sibling candidate after
the certified AUDUSD/NZDUSD and EURJPY/GBPJPY anchors. Pipeline gates are the
judge.

## Initial Risk Profile

- expected_pf: 1.10.
- expected_dd_pct: 25.
- expected_trade_frequency: approximately 4-8 basket packages/year.
- risk_class: high because this is an in-house extended-screen sibling with a slow half-life.
- gridding: false.
- scalping: false.
- ml_required: false.

## Risk

Backtests use V5 `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No live risk is authorized by this card; any future live
burn-in would be assigned only by the standard portfolio pipeline after all
gates.

## Strategy Allowability Check

- [x] R1 reputable source: Chan cointegration method plus OWNER-directed in-house FX cointegration screen.
- [x] R2 mechanical: fixed beta, z-score entry/exit, ATR stop, broken-package close.
- [x] R3 testable: AUDCAD.DWX and GBPAUD.DWX are Darwinex-native `.DWX` symbols in the exported scan data.
- [x] R4 compliant: no ML, no grid, no martingale, low-frequency D1.

## Framework Alignment

- no_trade: fixed host/symbol guard plus framework news/Friday/kill-switch.
- trade_entry: D1 cointegration spread z-score threshold with negative-beta leg direction.
- trade_management: broken-package cleanup only.
- trade_close: mean-reversion exit and framework Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-07 | initial extended-screen FX cointegration sibling card | G0 | APPROVED |
| v2 | 2026-07-07 | compiled basket EA and logical basket Q02 enqueued as work item f165f53e | Q02 | PENDING |
