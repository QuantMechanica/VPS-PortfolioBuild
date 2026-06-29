---
ea_id: QM5_12786
slug: edgelab-usdchf-eurgbp-cointegration
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
target_symbols: [USDCHF.DWX, EURGBP.DWX]
logical_symbol: QM5_12786_USDCHF_EURGBP_COINTEGRATION_D1
period: D1
expected_trade_frequency: "D1 two-leg basket, approximately 4-8 logical spread packages/year."
expected_trades_per_year_per_symbol: 5
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-06-29
g0_approval_reasoning: "R1 PASS Chan cointegration method plus OWNER-requested in-house 66-pair FX scan; R2 PASS deterministic fixed-pair z-score basket; R3 PASS USDCHF.DWX and EURGBP.DWX data exist in scan universe; R4 PASS no ML/grid/martingale."
expected_pf: 0.90
expected_dd_pct: 35.0
portfolio_scope: basket
---

# Edge Lab USDCHF/EURGBP Cointegration Basket

## Source

This card uses Chan's cointegration pair-trading structure from
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`: form a
stationary two-asset spread, compute a z-score, enter against extreme deviations,
and exit near the mean. The pair was selected from the QuantMechanica 66-pair FX
scan in `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, rerun from
`framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py`.

source_citation: Chan, Ernest P. (2009). Quantitative Trading. Wiley, Chapter 7;
QuantMechanica 2026 in-house 66-pair FX scan rerun on Darwinex `.DWX` D1 data.

The published scan hard-certified only QM5_12533 and QM5_12532. QM5_12624,
QM5_12712, QM5_12723, QM5_12728, QM5_12731, QM5_12732, QM5_12735, QM5_12739,
QM5_12747, QM5_12749, QM5_12751, QM5_12756, QM5_12758, QM5_12760, QM5_12762,
QM5_12764, QM5_12765, QM5_12766, QM5_12768, QM5_12770, QM5_12772, QM5_12776,
QM5_12778, QM5_12781, and QM5_12783 already cover stronger exploratory baskets. All
OOS-positive pairs with positive hedge in the scan are already built. This card
is the next unbuilt rank-28 tail candidate by OOS net Sharpe: USDCHF/EURGBP had
DEV Sharpe 0.0840, OOS net Sharpe -0.3881, OOS return -3.8501%, 15 OOS state
changes, hedge 0.138258947, and 92.63-day half-life in the same rerun.

## Concept

USDCHF and EURGBP are not a certified same-complex survivor like EURJPY/GBPJPY.
The structural link is weaker: developed-market European funding, CHF safe-haven
pressure, and EUR/GBP regional-rate risk can temporarily co-move and then
normalize. The scan found positive DEV but negative OOS Sharpe, making this a
very high-risk exploratory sleeve. The EA trades the spread, not either cross as
a standalone directional system.

## Hypothesis

Temporary dislocations between the USDCHF and EURGBP D1 log-price spread can
mean-revert when CHF safe-haven demand and EUR/GBP regional-rate premia normalize
after short macro shocks. The negative OOS scan result makes this a tail test
only; Q02+ must reject it if live-cost mechanics confirm no edge.

## Markets And Timeframe

- Host symbol: USDCHF.DWX.
- Basket legs: USDCHF.DWX and EURGBP.DWX.
- Logical symbol: QM5_12786_USDCHF_EURGBP_COINTEGRATION_D1.
- Period: D1.
- Backtest risk mode: RISK_FIXED.

## Rules

- Entry, exit, and broken-package handling are deterministic.
- The EA trades only the fixed USDCHF/EURGBP basket; it does not reselect pairs
  or refit beta in-test.
- No averaging, grid, martingale, pyramiding, trailing stop, or ML component is
  allowed.

## Entry Rules

- Evaluate only after a new closed D1 bar.
- Compute `spread = ln(USDCHF) - 0.138258947 * ln(EURGBP)`.
- Compute a 60-bar rolling z-score of the spread.
- If no pair package is open and z > +2.0, open a short-spread package: short USDCHF, long EURGBP.
- If no pair package is open and z < -2.0, open a long-spread package: long USDCHF, short EURGBP.
- Size each leg from V5 fixed risk, split by absolute hedge weights.

## Exit Rules

- Close both legs when `abs(z) < 0.5`.
- Each leg receives a hard ATR(20) * 2.0 protective stop.
- If only one leg remains open, close it immediately as a broken package.
- Framework Friday close remains enabled.

## Filters

- Host chart must be USDCHF.DWX or EURGBP.DWX on D1/H1, with slot 0 used for the logical host.
- EURUSD.DWX and GBPUSD.DWX are preselected as USD-account conversion history for EURGBP accounting; neither is a traded leg.
- No pyramiding, averaging, grid, martingale, partial close, or trailing stop.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Parameters To Test

- name: strategy_z_lookback_d1
  default: 60
  sweep_range: [40, 60, 90]
- name: strategy_beta
  default: 0.138258947
  sweep_range: [0.08, 0.138258947, 0.22]
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

No external performance claim is taken from Chan for USDCHF/EURGBP specifically.
The in-house scan rerun found DEV Sharpe 0.0840 and OOS net Sharpe -0.3881
after cost, below the original 0.8 survivor threshold. Pipeline gates are the
judge.

## Initial Risk Profile

- expected_pf: 0.90.
- expected_dd_pct: 30.
- expected_trade_frequency: approximately 4-8 basket packages/year.
- risk_class: very high because this is a rank-28 negative-OOS tail candidate after stronger exploratory baskets already built.
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
- [x] R3 testable: USDCHF.DWX and EURGBP.DWX are Darwinex-native `.DWX` symbols in the exported scan data; EURUSD.DWX and GBPUSD.DWX conversion history is also available.
- [x] R4 compliant: no ML, no grid, no martingale, low-frequency D1.

## Framework Alignment

- no_trade: fixed host/symbol guard plus framework news/Friday/kill-switch.
- trade_entry: D1 cointegration spread z-score threshold.
- trade_management: broken-package cleanup only.
- trade_close: mean-reversion exit and framework Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-29 | initial rank-28 next-unbuilt FX cointegration basket card | G0 | APPROVED |
| v2 | 2026-06-29 | strict compile/build-check recorded and Q02 enqueued as work item 560b4011-c09f-494a-aa8e-a52830f9013e | Q02 | PASS |
| v3 | 2026-06-29 | Q04 infra failure requeued in place after invalid folds with NO_HISTORY/M0_1970 report context | Q04 | PENDING 803159ab-cf78-4819-8691-26cdad47bd96 |

