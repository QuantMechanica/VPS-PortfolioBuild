---
ea_id: QM5_12608
slug: eia-oilgas-breakout
type: strategy
source_id: EIA-OILGAS-BREAKOUT-2026
source_citation: "U.S. Energy Information Administration. Relationship between crude oil and natural gas prices. URL https://www.eia.gov/naturalgas/articles/reloilgaspriindex.php"
sources:
  - "[[sources/EIA-OILGAS-BREAKOUT-2026]]"
concepts:
  - "[[concepts/oil-gas-ratio]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/channel-breakout]]"
  - "[[indicators/atr]]"
strategy_type_flags: [pair-spread-channel-breakout, market-neutral-basket, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
logical_symbol: QM5_12608_XTI_XNG_BREAKOUT_D1
period: D1
expected_trade_frequency: "D1 oil/gas ratio channel-breakout basket; estimate 5-12 spread packages/year."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-27
g0_approval_reasoning: "R1 PASS EIA government source; R2 PASS deterministic D1 oil/gas log-ratio channel breakout basket; R3 PASS XTIUSD.DWX and XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
expected_pf: 1.12
expected_dd_pct: 20.0
---

# EIA Oil/Gas Ratio Breakout

## Source

- Source: [[sources/EIA-OILGAS-BREAKOUT-2026]]
- Primary citation: U.S. Energy Information Administration, "Relationship
  between crude oil and natural gas prices", URL
  https://www.eia.gov/naturalgas/articles/reloilgaspriindex.php.

## Concept

Crude oil and natural gas are both energy commodities, but their relative price
relationship is not fixed. EIA documents a significant relationship as well as
periods of changed linkage and decoupling. This card tests whether large D1
breakouts in the oil/gas log ratio persist long enough to trade as a structural
energy relative-value basket.

This is deliberately different from `QM5_12578_eia-oilgas-ratio`, which fades
oil/gas z-score extremes and exits on mean reversion. This card does not use a
z-score reversion entry: it buys ratio strength after an upside channel break,
sells ratio weakness after a downside channel break, and exits on midline
failure or a time stop. It is also not `QM5_12567_cum-rsi2-commodity`, because
there is no RSI or short-horizon pullback logic.

## Markets And Timeframe

- Host symbol: XTIUSD.DWX.
- Basket leg symbols: XTIUSD.DWX and XNGUSD.DWX.
- Logical symbol: QM5_12608_XTI_XNG_BREAKOUT_D1.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC only; no EIA feed, inventory feed, futures
  curve, macro CSV, or external API.

## Entry Rules

- Evaluate only on a new D1 bar.
- Compute `spread = ln(XTIUSD.DWX close) - beta * ln(XNGUSD.DWX close)` on prior
  closed D1 bars.
- Upside breakout: if the latest completed spread is above the prior
  `strategy_channel_lookback_d1` spread high plus
  `strategy_breakout_buffer_sd` times the prior-channel spread standard
  deviation, BUY XTIUSD.DWX and SELL XNGUSD.DWX.
- Downside breakout: if the latest completed spread is below the prior
  `strategy_channel_lookback_d1` spread low minus the same buffer, SELL
  XTIUSD.DWX and BUY XNGUSD.DWX.
- No entry if either basket leg already has an open position for this EA magic.
- No entry if either symbol's current spread exceeds its configured spread cap.

## Exit Rules

- Stop loss: each leg receives a fixed hard SL at ATR(`strategy_atr_period_d1`)
  * `strategy_atr_sl_mult` from entry.
- Exit a long-ratio package when the completed spread closes below the rolling
  `strategy_exit_lookback_d1` spread average.
- Exit a short-ratio package when the completed spread closes above the rolling
  `strategy_exit_lookback_d1` spread average.
- Exit both legs after `strategy_max_hold_days`.
- If only one basket leg is open, close it immediately as a broken package.
- Friday close remains enabled by the V5 framework and closes both basket legs.

## Filters

- Host chart must be XTIUSD.DWX on D1.
- Skip entries when XTI spread exceeds `strategy_xti_max_spread_pts`.
- Skip entries when XNG spread exceeds `strategy_xng_max_spread_pts`.
- Skip entries when either close series or either ATR series is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open basket package at a time.

## Parameters To Test

- name: strategy_channel_lookback_d1
  default: 63
  sweep_range: [42, 63, 84, 126]
- name: strategy_exit_lookback_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_beta
  default: 1.0
  sweep_range: [0.7, 1.0, 1.3]
- name: strategy_breakout_buffer_sd
  default: 0.10
  sweep_range: [0.0, 0.10, 0.25]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 45
  sweep_range: [30, 45, 60]
- name: strategy_xti_max_spread_pts
  default: 1000
  sweep_range: [700, 1000, 1500]
- name: strategy_xng_max_spread_pts
  default: 2500
  sweep_range: [1500, 2500, 4000]
- name: strategy_deviation_points
  default: 20
  sweep_range: [10, 20, 50]

## Author Claims

No performance claim is imported from EIA. The source is used only for
structural lineage around the oil/natural-gas price relationship and its
regime-dependent decoupling behaviour.

## Initial Risk Profile

- expected_pf: 1.12
- expected_dd_pct: 20
- expected_trade_frequency: approximately 5-12 spread packages/year.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: single EIA government source packet.
- [x] R2 mechanical: fixed channel breakout entry, ATR hard stops, spread
  midline exit, and time stop.
- [x] R3 testable: XTIUSD.DWX and XNGUSD.DWX exist in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale.
- [x] Non-duplicate: opposite signal family from `QM5_12578` oil/gas ratio
  reversion and no overlap with `QM5_12567` RSI commodity logic.

## Framework Alignment

- no_trade: host chart guard, D1 guard, parameter guard, spread caps.
- trade_entry: two-leg basket entry on oil/gas log-ratio channel breakouts.
- trade_management: none beyond package integrity repair.
- trade_close: package repair, spread-average failure exit, max-hold exit, and
  per-leg ATR hard stops.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-06-27 | initial structural XTI/XNG oil-gas breakout basket build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-27 | APPROVED | this card |
