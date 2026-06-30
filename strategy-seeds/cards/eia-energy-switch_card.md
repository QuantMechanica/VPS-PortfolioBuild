---
ea_id: QM5_12813
slug: eia-energy-switch
type: strategy
source_id: EIA-ENERGY-SEASON-SWITCH-2026
source_citation: "U.S. Energy Information Administration, Energy Explained: Gasoline price fluctuations; EIA Today in Energy natural gas seasonal consumption and storage context."
sources:
  - "[[sources/EIA-ENERGY-SEASON-SWITCH-2026]]"
concepts:
  - "[[concepts/commodity-seasonality]]"
  - "[[concepts/energy-relative-value]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity-seasonality, energy-relative-value, atr-hard-stop, time-stop, symmetric-long-short]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
logical_symbol: QM5_12813_XTI_XNG_SEASON_SWITCH_D1
period: D1
expected_trade_frequency: "Two-leg XTI/XNG seasonal package, capped to one entry per calendar month inside the summer oil window and winter gas window."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-30
g0_approval_reasoning: "R1 PASS official EIA energy seasonality source lineage; R2 PASS fixed calendar windows, SMA confirmation, ATR stops, monthly package cap; R3 PASS XTIUSD.DWX and XNGUSD.DWX available in Darwinex symbol matrix; R4 PASS no ML/grid/martingale/runtime external data."
expected_pf: 1.10
expected_dd_pct: 22.0
---

# XTI/XNG EIA Seasonal Energy Switch

## hypothesis

EIA documents recurring energy seasonality: gasoline and oil-linked demand pressures rise around the spring and summer driving season, while natural gas demand and storage withdrawal behavior rise during winter heating months. A low-frequency paired basket can express those structural differences without adding another outright gold, index, or single XNG exposure.

## rules

- Host chart: `XTIUSD.DWX` D1.
- Basket legs: `XTIUSD.DWX` magic slot 0 and `XNGUSD.DWX` magic slot 1.
- Logical symbol: `QM5_12813_XTI_XNG_SEASON_SWITCH_D1`.
- Summer oil window: from May 15 through August 31, buy XTIUSD.DWX and sell XNGUSD.DWX.
- Winter gas window: from November 1 through March 31, sell XTIUSD.DWX and buy XNGUSD.DWX.
- Entry is allowed only on a new D1 bar and is capped to one two-leg package per calendar month.
- If `strategy_require_relative_trend` is true, the summer package requires XTI above its D1 SMA and XNG below its D1 SMA; the winter package requires XNG above its D1 SMA and XTI below its D1 SMA.
- No entry when either leg spread exceeds its configured cap.
- No pyramiding, gridding, martingale, partial close, runtime source data, or ML.

## risk

- Backtest risk mode: `RISK_FIXED=1000`.
- Per-leg hard stop: ATR(`strategy_atr_period_d1`) times `strategy_atr_sl_mult`.
- Package exits on season window end or flip, monthly rebalance, `strategy_max_hold_days`, Friday close, broken-package repair, or per-leg stop.
- Risk is split symmetrically across the two legs.

## Source

- Primary source: `strategy-seeds/sources/EIA-ENERGY-SEASON-SWITCH-2026/source.md`.
- Official references: U.S. Energy Information Administration gasoline seasonality and natural gas seasonal consumption/storage discussion.

## Non-Duplicate Rationale

This is not `QM5_12578` XTI/XNG z-score ratio reversion, `QM5_12608` XTI/XNG channel breakout, `QM5_12733` XTI/XNG cross-sectional momentum, `QM5_12810` WTI month ORB, `QM5_12812` XNG month ORB, or `QM5_12567` XNG RSI. The edge is a fixed seasonal oil-versus-gas switch with trend confirmation.

## Parameters To Test

- name: strategy_trend_period_d1
  default: 84
  sweep_range: [63, 84, 126]
- name: strategy_require_relative_trend
  default: true
  sweep_range: [true]
- name: strategy_xti_start_month
  default: 5
  sweep_range: [5]
- name: strategy_xti_start_day
  default: 15
  sweep_range: [1, 15]
- name: strategy_xti_end_month
  default: 8
  sweep_range: [8, 9]
- name: strategy_xng_start_month
  default: 11
  sweep_range: [11]
- name: strategy_xng_end_month
  default: 3
  sweep_range: [3]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 35
  sweep_range: [25, 35, 45]

## Strategy Allowability Check

- [x] R1 reputable source: official EIA energy seasonality pages.
- [x] R2 mechanical: fixed dates, fixed SMA confirmation, fixed exits.
- [x] R3 testable: both target symbols exist in the Darwinex symbol matrix.
- [x] R4 compliant: no banned or ML indicators, grid, martingale, or external runtime data.
- [x] Portfolio intent: commodity/energy sleeve distinct from the current XAU/SP500/NDX/XNG book.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-30 | initial EIA seasonal energy-switch basket | G0 | APPROVED |
