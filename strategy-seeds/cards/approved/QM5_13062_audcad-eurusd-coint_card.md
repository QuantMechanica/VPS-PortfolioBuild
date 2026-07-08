---
ea_id: QM5_13062
slug: audcad-eurusd-coint
type: strategy
source_id: QM-COINT-SCREEN-EXT-2026-07-06_AUDCAD-EURUSD
source_citation: "Chan, Ernest P. (2009). Quantitative Trading. Wiley, Chapter 7 stationarity and cointegration; plus QuantMechanica extended FX cointegration screen on Darwinex .DWX D1 data, 2017-10-02 to 2025-12-31."
sources:
  - "strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md"
  - "docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md"
  - "D:/QM/strategy_farm/artifacts/research/coint_screen_ext_20260706/results_full.csv"
  - "D:/QM/strategy_farm/artifacts/research/coint_screen_ext_20260706/survivors.json"
  - "D:/QM/strategy_farm/artifacts/research/coint_screen_ext_20260706/trade_check.json"
concepts:
  - cointegration-pair-trade
  - zscore-band-reversion
  - market-neutral-fx-basket
strategy_type_flags:
  - symmetric-long-short
  - atr-hard-stop
  - signal-reversal-exit
  - friday-close-flatten
indicators:
  - rolling-zscore
  - atr-stop
target_symbols: [AUDCAD.DWX, EURUSD.DWX]
logical_symbol: QM5_13062_AUDCAD_EURUSD_COINTEGRATION_D1
period: D1
expected_trade_frequency: "D1 two-leg basket, approximately 4-8 logical spread packages/year."
expected_trades_per_year_per_symbol: 5
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-08
g0_approval_reasoning: "R1 PASS Chan cointegration method plus OWNER-directed in-house FX cointegration scan; R2 PASS deterministic fixed-pair z-score basket; R3 PASS AUDCAD.DWX and EURUSD.DWX data exist in the extended Darwinex scan; R4 PASS no ML/grid/martingale. This is the only unbuilt formal survivor in the extended scan, but its v3 fixed-hedge trade check is OOS-negative, so Q02 is evidence gathering rather than a clean performance claim."
expected_pf: 0.95
expected_dd_pct: 30.0
portfolio_scope: basket
---

# AUDCAD/EURUSD Cointegration Basket

## Source

This card uses Chan's cointegration pair-trading structure from
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`: form a
two-asset spread, compute a z-score, enter against extreme deviations, and exit
near the mean. The pair was selected from the QuantMechanica extended FX
cointegration screen on Darwinex `.DWX` D1 data after the original positive
hedge scan certified only `QM5_12533` and `QM5_12532`.

source_citation: Chan, Ernest P. (2009). Quantitative Trading. Wiley, Chapter 7;
QuantMechanica 2026 extended FX cointegration screen on Darwinex `.DWX` D1 data.

The extended screen flags `AUDCAD~EURUSD` as the only unbuilt formal survivor in
the 2026-07-06 run. It passed both half-sample ADF tests (`t=-3.337`, `p=0.0508`
and `t=-3.683`, `p=0.0199`), kept hedge sign stable, had a 51.4 day half-life,
and the 60-bar rolling z-score had 43 `|z| >= 2` excursions across the scan
window. The reason this card is high risk is also explicit: the v3 fixed-hedge
trade check was positive in DEV but negative OOS, with DEV net Sharpe 0.63,
OOS net Sharpe -0.39, OOS return -4.94%, 20 OOS state changes, and DEV hedge
`0.5301`.

## Concept

AUDCAD and EURUSD combine AUD/CAD commodity-bloc exposure with the broad EUR/USD
risk and dollar complex without being a pure common-leg spread. The positive
hedge ratio creates an opposing-leg package: long spread means long AUDCAD and
short EURUSD; short spread means short AUDCAD and long EURUSD. The basket is
meant to be market-neutral at the spread level, not a directional AUD, CAD, EUR,
or USD forecast.

## Hypothesis

Temporary dislocations in `ln(AUDCAD) - beta * ln(EURUSD)` can mean-revert if
commodity-bloc and broad-dollar risk premia overshoot relative to each other.
The scan result is in-house, the hedge magnitude drifted materially between
halves (`0.745` to `0.124`), and the OOS trade check is negative, so the
pipeline gates remain the judge.

## Markets And Timeframe

- Host symbol: AUDCAD.DWX.
- Basket legs: AUDCAD.DWX and EURUSD.DWX.
- Conversion/history dependency for USD tester accounting: USDCAD.DWX.
- Logical symbol: QM5_13062_AUDCAD_EURUSD_COINTEGRATION_D1.
- Period: D1.
- Backtest risk mode: RISK_FIXED.

## Rules

- Entry, exit, and broken-package handling are deterministic.
- The EA trades only the fixed AUDCAD/EURUSD basket; it does not reselect pairs
  or refit beta in-test.
- No averaging, grid, martingale, pyramiding, trailing stop, or ML component is
  allowed.

## Entry Rules

- Evaluate only after a new closed D1 bar.
- Compute `spread = ln(AUDCAD) - 0.5301 * ln(EURUSD)`.
- Compute a 60-bar rolling z-score of the spread.
- If no pair package is open and z > +2.0, open a short-spread package: short AUDCAD and long EURUSD.
- If no pair package is open and z < -2.0, open a long-spread package: long AUDCAD and short EURUSD.
- Size each leg from V5 fixed risk, split by absolute hedge weights.

## Exit Rules

- Close both legs when `abs(z) < 0.5`.
- Each leg receives a hard ATR(20) * 2.0 protective stop.
- If only one leg remains open, close it immediately as a broken package.
- Framework Friday close remains enabled.

## Filters

- Host chart must be AUDCAD.DWX or EURUSD.DWX on D1/H1, with slot 0 used for
  the logical host.
- No pyramiding, averaging, grid, martingale, partial close, or trailing stop.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Parameters To Test

- name: strategy_z_lookback_d1
  default: 60
  sweep_range: [40, 60, 90]
- name: strategy_beta
  default: 0.5301
  sweep_range: [0.25, 0.5301, 0.75]
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

No external performance claim is taken from Chan for AUDCAD/EURUSD specifically.
The in-house extended scan found this as a formal statistical survivor after the
certified AUDUSD/NZDUSD and EURJPY/GBPJPY anchors, but the same artifact marks
the v3 fixed-hedge mechanics as OOS-negative. It is routed only because the
mission requested a non-duplicate unbuilt FX cointegration pair. Pipeline gates
are the judge.

## Initial Risk Profile

- expected_pf: 0.95.
- expected_dd_pct: 30.
- expected_trade_frequency: approximately 4-8 basket packages/year.
- risk_class: high because this is an in-house extended-screen formal survivor with negative OOS fixed-hedge trade evidence.
- gridding: false.
- scalping: false.
- ml_required: false.

## Risk

Backtests use V5 `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No live risk is authorized by this card; any future live
burn-in would be assigned only by the standard portfolio pipeline after all
gates.

## Strategy Allowability Check

- [x] R1 reputable source: Chan cointegration method plus OWNER-directed in-house FX cointegration screen; no positive external performance claim is imported.
- [x] R2 mechanical: fixed beta, z-score entry/exit, ATR stop, broken-package close.
- [x] R3 testable: AUDCAD.DWX and EURUSD.DWX are Darwinex-native `.DWX` symbols in the exported scan data.
- [x] R4 compliant: no ML, no grid, no martingale, low-frequency D1.

## Framework Alignment

- no_trade: fixed host/symbol guard plus framework news/Friday/kill-switch.
- trade_entry: D1 cointegration spread z-score threshold with positive-beta opposing-leg direction.
- trade_management: broken-package cleanup only.
- trade_close: mean-reversion exit and framework Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-08 | initial extended-screen FX cointegration formal-survivor card with OOS-negative caveat | G0 | APPROVED |
