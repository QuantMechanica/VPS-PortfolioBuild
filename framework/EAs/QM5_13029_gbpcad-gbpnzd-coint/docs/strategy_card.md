---
ea_id: QM5_13029
slug: gbpcad-gbpnzd-coint
type: strategy
source_id: QM-COINT-SCREEN-EXT-2026-07-06_GBPCAD-GBPNZD
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
target_symbols: [GBPCAD.DWX, GBPNZD.DWX]
logical_symbol: QM5_13029_GBPCAD_GBPNZD_COINTEGRATION_D1
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
g0_approval_reasoning: "R1 PASS Chan cointegration method plus OWNER-directed in-house FX cointegration screen; R2 PASS deterministic fixed-pair z-score basket; R3 PASS GBPCAD.DWX and GBPNZD.DWX data exist in the extended Darwinex scan; R4 PASS no ML/grid/martingale. Owner mission accepted the borderline OOS-heavy profile as the next non-duplicate FX cointegration sleeve."
expected_pf: 1.05
expected_dd_pct: 30.0
portfolio_scope: basket
---

# GBPCAD/GBPNZD Cointegration Basket

## Source

This card uses Chan's cointegration pair-trading structure from
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`: form a
two-asset spread, compute a z-score, enter against extreme deviations, and exit
near the mean. The pair was selected from the QuantMechanica extended FX
cointegration screen on Darwinex `.DWX` D1 data after the original positive
hedge scan certified only `QM5_12533` and `QM5_12532`, and after
`QM5_13024` AUDCAD/GBPAUD had already been built and passed Q02.

source_citation: Chan, Ernest P. (2009). Quantitative Trading. Wiley. Chapter 7;
QuantMechanica 2026 extended FX cointegration screen on Darwinex `.DWX` D1 data.

The extended screen flags `GBPCAD~GBPNZD` as the next non-duplicate
card-worthy sibling candidate after AUDCAD/GBPAUD. It is not a formal
all-gates survivor because the estimated half-life is 84.8 days versus the
original strict 60-day filter, and its DEV net Sharpe is -0.11. The reason to
route it anyway is explicit and limited: the trade-check output showed the
strongest OOS result in the extension, with OOS net Sharpe 1.66, OOS return
14.15%, 30 OOS state changes, and DEV hedge `0.3460`.

## Concept

GBPCAD and GBPNZD share GBP exposure while their quote currencies, CAD and NZD,
both carry commodity-bloc and risk-premium structure. The positive hedge ratio
creates an opposite-direction pair package: long spread means long GBPCAD and
short GBPNZD; short spread means short GBPCAD and long GBPNZD. The basket is
meant to be market-neutral at the spread level, not a directional GBP forecast.

## Hypothesis

Temporary dislocations in `ln(GBPCAD) - beta * ln(GBPNZD)` can mean-revert
because the two GBP crosses express similar sterling risk through different
commodity-linked quote currencies. The evidence is OOS-heavy and half-life slow,
so the pipeline gates remain the judge.

## Markets And Timeframe

- Host symbol: GBPCAD.DWX.
- Basket legs: GBPCAD.DWX and GBPNZD.DWX.
- Conversion/history dependencies for USD tester accounting: USDCAD.DWX and NZDUSD.DWX.
- Logical symbol: QM5_13029_GBPCAD_GBPNZD_COINTEGRATION_D1.
- Period: D1.
- Backtest risk mode: RISK_FIXED.

## Rules

- Entry, exit, and broken-package handling are deterministic.
- The EA trades only the fixed GBPCAD/GBPNZD basket; it does not reselect pairs
  or refit beta in-test.
- No averaging, grid, martingale, pyramiding, trailing stop, or ML component is
  allowed.

## Entry Rules

- Evaluate only after a new closed D1 bar.
- Compute `spread = ln(GBPCAD) - 0.3460 * ln(GBPNZD)`.
- Compute a 60-bar rolling z-score of the spread.
- If no pair package is open and z > +2.0, open a short-spread package: short GBPCAD and long GBPNZD.
- If no pair package is open and z < -2.0, open a long-spread package: long GBPCAD and short GBPNZD.
- Size each leg from V5 fixed risk, split by absolute hedge weights.

## Exit Rules

- Close both legs when `abs(z) < 0.5`.
- Each leg receives a hard ATR(20) * 2.0 protective stop.
- If only one leg remains open, close it immediately as a broken package.
- Framework Friday close remains enabled.

## Filters

- Host chart must be GBPCAD.DWX or GBPNZD.DWX on D1/H1, with slot 0 used for
  the logical host.
- No pyramiding, averaging, grid, martingale, partial close, or trailing stop.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Parameters To Test

- name: strategy_z_lookback_d1
  default: 60
  sweep_range: [40, 60, 90]
- name: strategy_beta
  default: 0.3460
  sweep_range: [0.25, 0.3460, 0.50]
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

No external performance claim is taken from Chan for GBPCAD/GBPNZD specifically.
The in-house extended scan found this as a borderline OOS-heavy sibling
candidate after the certified anchors and the already-built AUDCAD/GBPAUD
sleeve. Pipeline gates are the judge.

## Initial Risk Profile

- expected_pf: 1.05.
- expected_dd_pct: 30.
- expected_trade_frequency: approximately 4-8 basket packages/year.
- risk_class: high because this is an in-house extended-screen sibling with negative DEV evidence and a slow half-life.
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
- [x] R3 testable: GBPCAD.DWX and GBPNZD.DWX are Darwinex-native `.DWX` symbols in the exported scan data.
- [x] R4 compliant: no ML, no grid, no martingale, low-frequency D1.

## Framework Alignment

- no_trade: fixed host/symbol guard plus framework news/Friday/kill-switch.
- trade_entry: D1 cointegration spread z-score threshold with positive-beta leg direction.
- trade_management: broken-package cleanup only.
- trade_close: mean-reversion exit and framework Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-07 | initial extended-screen FX cointegration sibling card | G0 | APPROVED |
