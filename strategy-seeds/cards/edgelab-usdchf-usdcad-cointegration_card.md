---
ea_id: QM5_12756
slug: edgelab-usdchf-usdcad-cointegration
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
target_symbols: [USDCHF.DWX, USDCAD.DWX]
logical_symbol: QM5_12756_USDCHF_USDCAD_COINTEGRATION_D1
period: D1
expected_trade_frequency: "D1 two-leg basket, approximately 4-8 logical spread packages/year."
expected_trades_per_year_per_symbol: 5
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-06-28
g0_approval_reasoning: "R1 PASS because the method comes from Chan cointegration pair-trading and pair selection comes from the OWNER-requested in-house 66-pair scan; R2 PASS deterministic fixed-pair z-score basket; R3 PASS USDCHF.DWX and USDCAD.DWX data exist in the exported scan universe; R4 PASS no ML/grid/martingale. Marked very high-risk because DEV Sharpe was effectively zero and OOS Sharpe was far below the hard survivor bar."
expected_pf: 1.00
expected_dd_pct: 30.0
portfolio_scope: basket
---

# Edge Lab USDCHF/USDCAD Cointegration Basket

## Source

This card uses Chan's cointegration pair-trading structure from
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`: form a
stationary two-asset spread, compute a z-score, enter against extreme deviations,
and exit near the mean. The pair was selected from the QuantMechanica 66-pair FX
scan in `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, rerun from
`framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py`.

The published scan hard-certified only QM5_12533 and QM5_12532. QM5_12624,
QM5_12712, QM5_12723, QM5_12728, QM5_12731, QM5_12732, QM5_12735, QM5_12739,
QM5_12747, QM5_12749, and QM5_12751 already cover later exploratory baskets.
This card is the strongest remaining unbuilt OOS-positive candidate by OOS net
Sharpe: USDCHF/USDCAD had DEV Sharpe -0.00, OOS net Sharpe 0.13, OOS return
+1.06%, 16 OOS state changes, hedge 0.55, and 83-day half-life in the same
rerun.

## Concept

USDCHF and USDCAD share the USD base leg while expressing different defensive,
commodity, and rate exposures through CHF and CAD. Temporary divergence in that
USD-base relative-value spread can mean-revert, but the near-zero DEV Sharpe
and very low sub-threshold OOS Sharpe make this a very high-risk exploratory
sleeve. The EA trades the spread, not either cross as a standalone directional
system.

## Markets And Timeframe

- Host symbol: USDCHF.DWX.
- Basket legs: USDCHF.DWX and USDCAD.DWX.
- Logical symbol: QM5_12756_USDCHF_USDCAD_COINTEGRATION_D1.
- Period: D1.
- Backtest risk mode: RISK_FIXED.

## Entry Rules

- Evaluate only after a new closed D1 bar.
- Compute `spread = ln(USDCHF) - 0.55 * ln(USDCAD)`.
- Compute a 60-bar rolling z-score of the spread.
- If no pair package is open and z > +2.0, open a short-spread package: short USDCHF, long USDCAD.
- If no pair package is open and z < -2.0, open a long-spread package: long USDCHF, short USDCAD.
- Size each leg from V5 fixed risk, split by absolute hedge weights.

## Exit Rules

- Close both legs when `abs(z) < 0.5`.
- Each leg receives a hard ATR(20) * 2.0 protective stop.
- If only one leg remains open, close it immediately as a broken package.
- Framework Friday close remains enabled.

## Filters

- Host chart must be USDCHF.DWX or USDCAD.DWX on D1/H1, with slot 0 used for the logical host.
- No pyramiding, averaging, grid, martingale, partial close, or trailing stop.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Parameters To Test

- name: strategy_z_lookback_d1
  default: 60
  sweep_range: [40, 60, 90]
- name: strategy_beta
  default: 0.55
  sweep_range: [0.45, 0.55, 0.70]
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

No external performance claim is taken from Chan for USDCHF/USDCAD specifically.
The in-house scan rerun found DEV Sharpe -0.00 and OOS net Sharpe 0.13 after
cost, below the original 0.8 survivor threshold. Pipeline gates are the judge.

## Initial Risk Profile

- expected_pf: 1.00.
- expected_dd_pct: 30.
- expected_trade_frequency: approximately 4-8 basket packages/year.
- risk_class: very high because this is a weak OOS-only sub-threshold candidate.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: Chan cointegration method plus OWNER-requested in-house 66-pair scan.
- [x] R2 mechanical: fixed beta, z-score entry/exit, ATR stop, broken-package close.
- [x] R3 testable: USDCHF.DWX and USDCAD.DWX are Darwinex-native `.DWX` symbols in the exported scan data.
- [x] R4 compliant: no ML, no grid, no martingale, low-frequency D1.

## Framework Alignment

- no_trade: fixed host/symbol guard plus framework news/Friday/kill-switch.
- trade_entry: D1 cointegration spread z-score threshold.
- trade_management: broken-package cleanup only.
- trade_close: mean-reversion exit and framework Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-28 | initial OOS-positive next-best FX cointegration basket build | G0 | APPROVED |
| v1 | 2026-06-28 | logical-basket Q02 enqueued as non-duplicate paced worker item `3a06b01c-7b8c-4db0-86fb-d40e0a1c0000`; first T5 claim hit launch-fault cooldown | Q02 | PENDING |
| v1-q04 | 2026-06-29 | Q02 PASS advanced to a non-duplicate Q04 retry clamped to latest full year 2024 after prior 2025 fold NO_HISTORY/BARS_ZERO infra failure | Q04 | PENDING `fb626620-20ec-4ee6-9e64-b491ded2d6f2` |
