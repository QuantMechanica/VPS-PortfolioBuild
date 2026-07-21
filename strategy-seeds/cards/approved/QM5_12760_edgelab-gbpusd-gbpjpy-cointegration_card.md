---
ea_id: QM5_12760
slug: edgelab-gbpusd-gbpjpy-cointegration
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
target_symbols: [GBPUSD.DWX, GBPJPY.DWX]
conversion_symbols: [USDJPY.DWX]
logical_symbol: QM5_12760_GBPUSD_GBPJPY_COINTEGRATION_D1
period: D1
expected_trade_frequency: "D1 two-leg basket, approximately 4-8 logical spread packages/year."
expected_trades_per_year_per_symbol: 5
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02_QUEUED
last_updated: 2026-07-21
g0_approval_reasoning: "R1 PASS because the method comes from Chan cointegration pair-trading and pair selection comes from the OWNER-requested in-house 66-pair scan; R2 PASS deterministic fixed-pair z-score basket; R3 PASS GBPUSD.DWX and GBPJPY.DWX data exist in the exported scan universe; R4 PASS no ML/grid/martingale. Marked high-risk because DEV Sharpe was negative and OOS Sharpe was very low."
expected_pf: 1.01
expected_dd_pct: 30.0
portfolio_scope: basket
---

# Edge Lab GBPUSD/GBPJPY Cointegration Basket

## Source

This card uses Chan's cointegration pair-trading structure from
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`: form a
stationary two-asset spread, compute a z-score, enter against extreme deviations,
and exit near the mean. The pair was selected from the QuantMechanica 66-pair FX
scan in `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, rerun from
`framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py`.

The published scan hard-certified only QM5_12533 and QM5_12532. QM5_12624,
QM5_12712, QM5_12723, QM5_12728, QM5_12731, QM5_12732, QM5_12735, QM5_12739,
QM5_12747, QM5_12749, QM5_12751, QM5_12756, and QM5_12758 already cover later
exploratory baskets. This card is the strongest remaining unbuilt OOS-positive
candidate by OOS net Sharpe: GBPUSD/GBPJPY had DEV Sharpe -0.26, OOS net
Sharpe 0.10, OOS return +0.95%, 17 OOS state changes, hedge 0.01, and 109-day
half-life in the same rerun.

## Concept

GBPUSD and GBPJPY share the GBP base but differ by USD and JPY quote-side risk,
so this is a low-conviction macro relative-value residual rather than a strong
same-complex pair like EURJPY/GBPJPY. The weak scan result suggests occasional
mean reversion between cable and sterling-yen risk/funding expressions, but the
negative DEV Sharpe and very low sub-threshold OOS Sharpe make this a very
high-risk exploratory sleeve. The EA trades the spread, not either cross as a
standalone directional system.

## Markets And Timeframe

- Host symbol: GBPUSD.DWX.
- Basket legs: GBPUSD.DWX and GBPJPY.DWX.
- Conversion history: USDJPY.DWX for USD-denominated GBPJPY accounting; not a traded leg.
- Logical symbol: QM5_12760_GBPUSD_GBPJPY_COINTEGRATION_D1.
- Period: D1.
- Backtest risk mode: RISK_FIXED.

## Entry Rules

- Evaluate only after a new closed D1 bar.
- Compute `spread = ln(GBPUSD) - 0.01 * ln(GBPJPY)`.
- Compute a 60-bar rolling z-score of the spread.
- If no pair package is open and z > +2.0, open a short-spread package: short GBPUSD, long GBPJPY.
- If no pair package is open and z < -2.0, open a long-spread package: long GBPUSD, short GBPJPY.
- Size each leg from V5 fixed risk, split by absolute hedge weights.

## Exit Rules

- Close both legs when `abs(z) < 0.5`.
- Each leg receives a hard ATR(20) * 2.0 protective stop.
- If only one leg remains open, close it immediately as a broken package.
- Framework Friday close remains enabled.

## Filters

- Host chart must be GBPUSD.DWX or GBPJPY.DWX on D1/H1, with slot 0 used for the logical host.
- No pyramiding, averaging, grid, martingale, partial close, or trailing stop.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Parameters To Test

- name: strategy_z_lookback_d1
  default: 60
  sweep_range: [40, 60, 90]
- name: strategy_beta
  default: 0.01
  sweep_range: [0.005, 0.01, 0.02]
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

No external performance claim is taken from Chan for GBPUSD/GBPJPY specifically.
The in-house scan rerun found DEV Sharpe -0.26 and OOS net Sharpe 0.10 after
cost, below the original 0.8 survivor threshold. Pipeline gates are the judge.

## Initial Risk Profile

- expected_pf: 1.01.
- expected_dd_pct: 30.
- expected_trade_frequency: approximately 4-8 basket packages/year.
- risk_class: very high because this is a weak OOS-only sub-threshold candidate.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: Chan cointegration method plus OWNER-requested in-house 66-pair scan.
- [x] R2 mechanical: fixed beta, z-score entry/exit, ATR stop, broken-package close.
- [x] R3 testable: GBPUSD.DWX and GBPJPY.DWX are Darwinex-native `.DWX` symbols in the exported scan data; USDJPY.DWX is available as conversion history.
- [x] R4 compliant: no ML, no grid, no martingale, low-frequency D1.

## Framework Alignment

- no_trade: fixed host/symbol guard plus framework news/Friday/kill-switch.
- trade_entry: D1 cointegration spread z-score threshold.
- trade_management: broken-package cleanup only.
- trade_close: mean-reversion exit and framework Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-29 | initial OOS-positive next-best FX cointegration basket build | G0 | APPROVED |
| v1-q02 | 2026-06-29 | build task fa63237b-e268-475d-98a4-aa64147473c3 recorded | Q02 | PENDING work item 6154567b-875f-416c-903b-b171a4d4eefc |
| v1-q02a | 2026-06-30 | pending Q02 row repaired in place with USDJPY conversion-history manifest scope, tester deposit, fixed-risk, priority, and timeout hints | Q02 | PENDING work item 6154567b-875f-416c-903b-b171a4d4eefc |


