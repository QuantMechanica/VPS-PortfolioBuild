---
ea_id: QM5_12766
slug: edgelab-usdjpy-usdchf-cointegration
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
target_symbols: [USDJPY.DWX, USDCHF.DWX]
logical_symbol: QM5_12766_USDJPY_USDCHF_COINTEGRATION_D1
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
g0_approval_reasoning: "R1 PASS because the method comes from Chan cointegration pair-trading and pair selection comes from the OWNER-requested in-house 66-pair scan; R2 PASS deterministic fixed-pair z-score basket; R3 PASS USDJPY.DWX and USDCHF.DWX data exist in the exported scan universe; R4 PASS no ML/grid/martingale. Marked very high-risk because DEV and OOS net Sharpe were both negative."
expected_pf: 0.98
expected_dd_pct: 30.0
portfolio_scope: basket
---

# Edge Lab USDJPY/USDCHF Cointegration Basket

## Source

This card uses Chan's cointegration pair-trading structure from
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`: form a
stationary two-asset spread, compute a z-score, enter against extreme deviations,
and exit near the mean. The pair was selected from the QuantMechanica 66-pair FX
scan in `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, rerun from
`framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py`.

The published scan hard-certified only QM5_12533 and QM5_12532. QM5_12624,
QM5_12712, QM5_12723, QM5_12728, QM5_12731, QM5_12732, QM5_12735, QM5_12739,
QM5_12747, QM5_12749, QM5_12751, QM5_12756, QM5_12758, QM5_12760, QM5_12762,
QM5_12764, and QM5_12765 already cover the stronger exploratory tail. This card
is the next unbuilt pair by OOS net Sharpe: USDJPY/USDCHF had DEV Sharpe
-0.2817, OOS net Sharpe -0.0884, OOS return -1.0114%, 15 OOS state changes,
hedge 0.435197, and 511.50-day half-life in the same rerun.

## Concept

USDJPY and USDCHF are both USD-base major pairs with different safe-haven and
funding expressions: yen funding/risk-off pressure on one leg and Swiss-franc
haven/rate pressure on the other. The scan result is weak because both DEV and
OOS Sharpe are negative; this is an exploratory rank-20 tail candidate, not a
certified survivor. The EA trades the spread, not either pair as a standalone
directional system.

## Hypothesis

Temporary dislocations between the USDJPY and USDCHF D1 log-price spread can
mean-revert because both pairs express USD plus safe-haven funding demand, but
with different JPY and CHF policy/risk channels. The negative scan metrics make
this a low-confidence tail test that must be killed by Q02+ if the live-cost
pipeline confirms no edge.

## Markets And Timeframe

- Host symbol: USDJPY.DWX.
- Basket legs: USDJPY.DWX and USDCHF.DWX.
- Logical symbol: QM5_12766_USDJPY_USDCHF_COINTEGRATION_D1.
- Period: D1.
- Backtest risk mode: RISK_FIXED.

## Rules

- Entry, exit, and broken-package handling are fully mechanical and specified
  in the following sections.
- The EA is fixed-pair only; it does not reselect symbols, refit beta, average
  down, pyramid, or use portfolio feedback.

## Entry Rules

- Evaluate only after a new closed D1 bar.
- Compute `spread = ln(USDJPY) - 0.435197 * ln(USDCHF)`.
- Compute a 60-bar rolling z-score of the spread.
- If no pair package is open and z > +2.0, open a short-spread package: short USDJPY, long USDCHF.
- If no pair package is open and z < -2.0, open a long-spread package: long USDJPY, short USDCHF.
- Size each leg from V5 fixed risk, split by absolute hedge weights.

## Exit Rules

- Close both legs when `abs(z) < 0.5`.
- Each leg receives a hard ATR(20) * 2.0 protective stop.
- If only one leg remains open, close it immediately as a broken package.
- Framework Friday close remains enabled.

## Filters

- Host chart must be USDJPY.DWX or USDCHF.DWX on D1/H1, with slot 0 used for the logical host.
- No pyramiding, averaging, grid, martingale, partial close, or trailing stop.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Parameters To Test

- name: strategy_z_lookback_d1
  default: 60
  sweep_range: [40, 60, 90]
- name: strategy_beta
  default: 0.435197
  sweep_range: [0.35, 0.435197, 0.55]
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

No external performance claim is taken from Chan for USDJPY/USDCHF specifically.
The in-house scan rerun found DEV Sharpe -0.2817 and OOS net Sharpe -0.0884
after cost, below the original 0.8 survivor threshold and below zero in both
windows. Pipeline gates are the judge.

## Initial Risk Profile

- expected_pf: 0.98.
- expected_dd_pct: 30.
- expected_trade_frequency: approximately 4-8 basket packages/year.
- risk_class: very high because this is the first remaining unbuilt tail pair after the rank-19 negative-OOS exploratory basket.
- gridding: false.
- scalping: false.
- ml_required: false.

## Risk

Backtests use V5 `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No live risk is authorized by this card; any future live
burn-in would be assigned by the standard portfolio pipeline after all gates.

## Strategy Allowability Check

- [x] R1 reputable source: Chan cointegration method plus OWNER-requested in-house 66-pair scan.
- [x] R2 mechanical: fixed beta, z-score entry/exit, ATR stop, broken-package close.
- [x] R3 testable: USDJPY.DWX and USDCHF.DWX are Darwinex-native `.DWX` symbols in the exported scan data.
- [x] R4 compliant: no ML, no grid, no martingale, low-frequency D1.

## Framework Alignment

- no_trade: fixed host/symbol guard plus framework news/Friday/kill-switch.
- trade_entry: D1 cointegration spread z-score threshold.
- trade_management: broken-package cleanup only.
- trade_close: mean-reversion exit and framework Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-29 | initial rank-20 next-unbuilt FX cointegration basket build | G0 | APPROVED |
| v1-q02 | 2026-06-29 | build task 2e99cc4b-453a-4b75-84a7-81ea844c8ff0 recorded and logical-basket Q02 enqueued | Q02 | PENDING c097d38d-f428-4c8b-a90c-104d1e072c0d |
