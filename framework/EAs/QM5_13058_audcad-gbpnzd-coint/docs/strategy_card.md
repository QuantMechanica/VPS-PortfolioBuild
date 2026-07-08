---
ea_id: QM5_13058
slug: audcad-gbpnzd-coint
type: strategy
source_id: QM-COINT-SCREEN-EXT-2026-07-06_AUDCAD-GBPNZD
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
target_symbols: [AUDCAD.DWX, GBPNZD.DWX]
logical_symbol: QM5_13058_AUDCAD_GBPNZD_COINTEGRATION_D1
period: D1
expected_trade_frequency: "D1 two-leg basket, approximately 4-8 logical spread packages/year."
expected_trades_per_year_per_symbol: 5
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q04
last_updated: 2026-07-08
g0_approval_reasoning: "R1 PASS Chan cointegration method plus OWNER-directed in-house FX cointegration scan; R2 PASS deterministic fixed-pair z-score basket; R3 PASS AUDCAD.DWX and GBPNZD.DWX data exist in the extended Darwinex scan; R4 PASS no ML/grid/martingale. This is a watchlist replacement candidate after the stronger extended-screen siblings were already built and failed later gates."
expected_pf: 1.03
expected_dd_pct: 30.0
portfolio_scope: basket
---

# AUDCAD/GBPNZD Cointegration Basket

## Source

This card uses Chan's cointegration pair-trading structure from
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`: form a
two-asset spread, compute a z-score, enter against extreme deviations, and exit
near the mean. The pair was selected from the QuantMechanica extended FX
cointegration screen on Darwinex `.DWX` D1 data after the original positive
hedge scan certified only `QM5_12533` and `QM5_12532`.

source_citation: Chan, Ernest P. (2009). Quantitative Trading. Wiley, Chapter 7;
QuantMechanica 2026 extended FX cointegration screen on Darwinex `.DWX` D1 data.

The extended screen flags `AUDCAD~GBPNZD` as a watchlist replacement candidate,
not a formal strict survivor. It passed both half-sample ADF tests (`t=-3.167`,
`p=0.0768` and `t=-3.662`, `p=0.0211`), kept hedge sign stable, and the 60-bar
rolling z-score had 41 `|z| >= 2` excursions across the scan window. It missed
the original strict half-life gate at 76.5 days and its OOS net Sharpe was 0.76,
just under the 0.8 carding bar. The reason to route it after `QM5_13024` and
`QM5_13029` is explicit and limited: unlike those stronger-looking siblings, the
v3-mechanics trade check was profitable in both windows, with DEV net Sharpe
1.13, OOS return 7.94%, 22 OOS state changes, and DEV hedge `-0.7616`.

## Concept

AUDCAD and GBPNZD combine commodity/risk-bloc FX exposure through AUD, CAD, NZD,
and GBP without being a pure common-leg spread. The negative hedge ratio creates
a same-direction package: long spread means long AUDCAD and long GBPNZD; short
spread means short both legs. The basket is meant to be market-neutral at the
spread level, not a directional AUD or GBP forecast.

## Hypothesis

Temporary dislocations in `ln(AUDCAD) - beta * ln(GBPNZD)` can mean-revert
because AUD/CAD and GBP/NZD embed related commodity-bloc, risk-sentiment, and
local-rate premia. The scan result is in-house, the hedge magnitude drifted
materially between halves, and the half-life is slow, so the pipeline gates
remain the judge.

## Markets And Timeframe

- Host symbol: AUDCAD.DWX.
- Basket legs: AUDCAD.DWX and GBPNZD.DWX.
- Conversion/history dependencies for USD tester accounting: USDCAD.DWX and NZDUSD.DWX.
- Logical symbol: QM5_13058_AUDCAD_GBPNZD_COINTEGRATION_D1.
- Period: D1.
- Backtest risk mode: RISK_FIXED.

## Rules

- Entry, exit, and broken-package handling are deterministic.
- The EA trades only the fixed AUDCAD/GBPNZD basket; it does not reselect pairs
  or refit beta in-test.
- No averaging, grid, martingale, pyramiding, trailing stop, or ML component is
  allowed.

## Entry Rules

- Evaluate only after a new closed D1 bar.
- Compute `spread = ln(AUDCAD) - (-0.7616) * ln(GBPNZD)`.
- Compute a 60-bar rolling z-score of the spread.
- If no pair package is open and z > +2.0, open a short-spread package: short AUDCAD and short GBPNZD.
- If no pair package is open and z < -2.0, open a long-spread package: long AUDCAD and long GBPNZD.
- Size each leg from V5 fixed risk, split by absolute hedge weights.

## Exit Rules

- Close both legs when `abs(z) < 0.5`.
- Each leg receives a hard ATR(20) * 2.0 protective stop.
- If only one leg remains open, close it immediately as a broken package.
- Framework Friday close remains enabled.

## Filters

- Host chart must be AUDCAD.DWX or GBPNZD.DWX on D1/H1, with slot 0 used for
  the logical host.
- No pyramiding, averaging, grid, martingale, partial close, or trailing stop.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Parameters To Test

- name: strategy_z_lookback_d1
  default: 60
  sweep_range: [40, 60, 90]
- name: strategy_beta
  default: -0.7616
  sweep_range: [-1.00, -0.7616, -0.50]
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

No external performance claim is taken from Chan for AUDCAD/GBPNZD specifically.
The in-house extended scan found this as a watchlist sibling candidate after the
certified AUDUSD/NZDUSD and EURJPY/GBPJPY anchors. It is being routed only
because the higher-ranked extended siblings are already built and later failed.
Pipeline gates are the judge.

## Initial Risk Profile

- expected_pf: 1.03.
- expected_dd_pct: 30.
- expected_trade_frequency: approximately 4-8 basket packages/year.
- risk_class: high because this is an in-house extended-screen watchlist sibling with a slow half-life and OOS just below the original 0.8 Sharpe bar.
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
- [x] R3 testable: AUDCAD.DWX and GBPNZD.DWX are Darwinex-native `.DWX` symbols in the exported scan data.
- [x] R4 compliant: no ML, no grid, no martingale, low-frequency D1.

## Framework Alignment

- no_trade: fixed host/symbol guard plus framework news/Friday/kill-switch.
- trade_entry: D1 cointegration spread z-score threshold with negative-beta leg direction.
- trade_management: broken-package cleanup only.
- trade_close: mean-reversion exit and framework Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-08 | initial extended-screen FX cointegration watchlist replacement card | G0 | APPROVED |
| v2 | 2026-07-08 | compiled basket EA and logical basket Q02 auto-enqueued as work item df21c7a2-a0e2-467c-9be9-56f490d2e40d | Q02 | PENDING |
| v3 | 2026-07-08 | logical basket Q02 completed on AUDCAD host; 140 trades, PF 1.27, no ONINIT failure | Q02 | PASS |
| v4 | 2026-07-08 | Q04 walk-forward completed without infra errors; F1 pf_net 1.173, F2 pf_net 0.937, below fold bar | Q04 | FAIL |
| v5 | 2026-07-08 | companion Q03 deterministic row 19ddc71f-d9d8-4740-adb2-8ec7a1bc2ee7 completed after the Q04 aggregate; 140 trades, PF 1.27, no ONINIT failure | Q03 | PASS |

