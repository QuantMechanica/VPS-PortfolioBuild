---
ea_id: QM5_13106
strategy_id: AI-CLAUDE-FX-COINT66-20260609-AUDUSD-EURGBP
slug: aud-eurgbp-coint
status: APPROVED
type: strategy
source_id: AI-CLAUDE-FX-COINT66-20260609-AUDUSD-EURGBP
source_citation: "QuantMechanica OWNER-requested all-sign rerun of the 2026-06-09 66-pair FX cointegration scan on Darwinex .DWX D1 data; reproducible with framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py."
sources:
  - "docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md"
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
target_symbols: [AUDUSD.DWX, EURGBP.DWX]
logical_symbol: QM5_13106_AUDUSD_EURGBP_COINTEGRATION_D1
period: D1
expected_trade_frequency: "D1 two-leg basket, approximately 3-5 logical spread packages/year."
expected_trades_per_year_per_symbol: 4
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
g0_approval_reasoning: "R1 PASS single OWNER-requested in-house scan lineage; R2 PASS deterministic fixed-pair z-score basket; R3 PASS AUDUSD.DWX, EURGBP.DWX, and GBPUSD.DWX conversion history are available; R4 PASS no ML, grid, martingale, adaptive refit, or pyramiding."
expected_pf: 1.05
expected_dd_pct: 25.0
portfolio_scope: basket
---

# AUDUSD/EURGBP Cointegration Basket

## Source

The single lineage source is the OWNER-requested QuantMechanica 66-pair FX
cointegration scan documented in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` and reproduced with
`framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py`. The published
positive-hedge pass hard-certified `QM5_12533` and `QM5_12532`; the all-sign
rerun retains negative regression hedges and makes AUDUSD/EURGBP the highest
OOS-ranked strict row not already built after those anchors, QM5_12978, and
QM5_13003.

The fixed DEV hedge is `-0.0545763736541407`. The row recorded DEV net Sharpe
`0.5536`, OOS net Sharpe `1.0472`, OOS return `10.8647%`, 25 OOS state changes,
and a `112.50` day half-life. Those are in-house scan measurements, not a live
performance claim; the pipeline remains the judge.

## Concept

AUDUSD expresses Antipodean commodity/risk and broad USD pressure, while
EURGBP expresses relative European rate and growth pressure. The fitted
negative hedge turns the two legs in the same direction for a long spread and
in the opposite same-direction package for a short spread. Temporary
dislocations in the fixed log-price combination may mean-revert without making
a standalone forecast for either cross.

The hedge magnitude is small, so this sleeve can retain material AUDUSD
exposure even though it is regression-neutral at the spread level. That is an
explicit risk, not hidden evidence of diversification; Q02-Q09 must reject it
if realized behavior is directional or duplicates the book.

## Markets And Timeframe

- Host symbol: AUDUSD.DWX.
- Traded legs: AUDUSD.DWX and EURGBP.DWX.
- USD tester conversion dependency: GBPUSD.DWX.
- Logical symbol: QM5_13106_AUDUSD_EURGBP_COINTEGRATION_D1.
- Period: D1.
- Backtest risk mode: RISK_FIXED.

## Entry Rules

- Evaluate only after a new closed D1 bar.
- Compute `spread = ln(AUDUSD) - (-0.0545763736541407) * ln(EURGBP)`.
- Compute a 60-bar rolling z-score of the spread.
- With no package open and z > +2.0, open a short-spread package: short AUDUSD and short EURGBP.
- With no package open and z < -2.0, open a long-spread package: long AUDUSD and long EURGBP.
- Split the fixed-risk budget between the two legs in `1:abs(beta)` weight.
- Never refit beta, reselect the pair, or adapt parameters during a test.

## Exit Rules

- Close both legs when `abs(z) < 0.5`.
- Place a hard `ATR(20, D1) * 2.0` protective stop on each leg.
- If only one leg remains open, close it immediately as a broken package.
- Framework Friday close remains enabled.

## Filters And Management

- Run only from AUDUSD.DWX or EURGBP.DWX on H1/D1, with slot 0 as the logical host.
- Framework kill-switch, news, magic, and Friday-close guards remain active.
- No averaging, grid, martingale, pyramiding, partial close, or trailing stop.
- At most one position per leg magic; at most one logical pair package open.

## Parameters To Test

- name: strategy_z_lookback_d1
  default: 60
  sweep_range: [40, 60, 90]
- name: strategy_beta
  default: -0.0545763736541407
  sweep_range: [-0.08, -0.0545763736541407, -0.03]
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

No external performance claim is imported for AUDUSD/EURGBP. The reproducible
in-house scan measured positive DEV and OOS net Sharpe under its approximate
`0.8 bp/leg` cost model, but swap was unmodeled and the half-life was long.
Real-tick spread, commission, conversion, and swap effects are delegated to the
standard gates.

## Initial Risk Profile

- expected_pf: 1.05.
- expected_dd_pct: 25.
- expected_trade_frequency: approximately 3-5 basket packages/year.
- risk_class: high due to the small negative hedge and 112.50-day half-life.
- gridding: false.
- scalping: false.
- ml_required: false.

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No live risk or deployment is authorized by this card.

## Strategy Allowability Check

- [x] R1 single source: OWNER-requested in-house 66-pair scan with local reproducible code and data lineage.
- [x] R2 mechanical: fixed beta, rolling z-score entry/exit, ATR hard stops, and broken-package cleanup.
- [x] R3 testable: traded and conversion `.DWX` symbols are declared in the basket manifest.
- [x] R4 compliant: deterministic, no ML, no online/adaptive refit, no grid or martingale, one position per magic.

## Framework Alignment

- no_trade: fixed host/symbol guard plus framework news, Friday, kill-switch, and history warmup.
- trade_entry: closed-D1 fixed-beta spread z-score with sign-aware negative-beta leg direction.
- trade_management: broken-package cleanup only; hard stops are attached at entry.
- trade_close: mean-reversion exit plus framework Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-10 | initial all-sign 66-pair strict-survivor basket | G0 | APPROVED |

