---
ea_id: QM5_12827
slug: cme-gassilver-brk
type: strategy
source_id: CME-GAS-SILVER-RELVAL-2026
source_citation: "CME Group. Henry Hub Natural Gas Futures Overview. URL https://www.cmegroup.com/markets/energy/natural-gas/natural-gas.html; CME Group. Silver Futures Overview. URL https://www.cmegroup.com/markets/metals/precious/silver.html"
sources:
  - "[[sources/CME-GAS-SILVER-RELVAL-2026]]"
concepts:
  - "[[concepts/natural-gas-silver-ratio]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/channel-breakout]]"
  - "[[indicators/atr]]"
strategy_type_flags: [pair-spread-channel-breakout, market-neutral-basket, atr-hard-stop, neutral-band-exit, low-frequency]
target_symbols: [XNGUSD.DWX, XAGUSD.DWX]
logical_symbol: QM5_12827_XNG_XAG_BRK_D1
period: D1
expected_trade_frequency: "D1 natural-gas/silver ratio channel-breakout basket; estimate 4-9 spread packages/year."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-06-30
g0_approval_reasoning: "R1 PASS CME exchange product source packet for Henry Hub Natural Gas and Silver futures; R2 PASS deterministic D1 natural-gas/silver log-ratio channel breakout with ATR stops and neutral-band/time exits; R3 PASS XNGUSD.DWX and XAGUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
expected_pf: 1.10
expected_dd_pct: 24.0
---

# CME Natural Gas / Silver Channel Breakout

## Source

- Source: [[sources/CME-GAS-SILVER-RELVAL-2026]]
- Primary citations: CME Group Henry Hub Natural Gas futures overview and CME
  Group Silver futures overview.

## Concept

Natural gas and silver are structurally different commodity exposures: gas is
weather, storage, production, LNG, and power-burn driven, while silver combines
precious-metal and industrial demand exposure. This card prices natural gas in
silver terms and tests a market-neutral D1 continuation package after the
relative price breaks a multi-month channel.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator, or single-leg pullback.
- `QM5_12826_cme-gassilver-ratio`: this is channel breakout/continuation, not
  z-score mean reversion.
- `QM5_12577_cme-xauxag-ratio` and `QM5_12724_cme-xauxag-brk`: no gold/silver
  metals-ratio sleeve.
- `QM5_12578_eia-oilgas-ratio`, `QM5_12608_eia-oilgas-breakout`, and
  `QM5_12733_xti-xng-xmom`: no WTI leg and no oil/gas relationship.
- Existing XNG single-leg storage, weather, calendar, 52-week anchor, TSMOM,
  weekend, month-opening, weekday, and volatility-shock sleeves: this is a
  two-leg natural-gas/silver relative-value basket.

## Markets And Timeframe

- Host symbol: `XNGUSD.DWX`.
- Hedge leg: `XAGUSD.DWX`.
- Logical symbol: `QM5_12827_XNG_XAG_BRK_D1`.
- Period: D1.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, broker spread, ATR, and trade-session
  state only. No CME feed, futures curve, storage feed, weather feed, macro CSV,
  API, analyst forecast, or ML model.

## Entry Rules

- Evaluate once per new D1 bar after the configured broker entry time and only
  when both legs are tradable.
- Compute `spread = ln(XNGUSD.DWX close) - beta * ln(XAGUSD.DWX close)` on prior
  completed D1 bars.
- Compute the prior `strategy_channel_lookback_d1` high and low of the spread,
  excluding the signal bar itself.
- Upside break: if the latest completed spread closes above the channel high,
  BUY `XNGUSD.DWX` and SELL `XAGUSD.DWX`.
- Downside break: if the latest completed spread closes below the channel low,
  SELL `XNGUSD.DWX` and BUY `XAGUSD.DWX`.
- No entry if either basket leg already has an open position for this EA magic.
- No entry if either symbol's current spread exceeds its configured spread cap.

## Exit Rules

- Each leg receives a fixed hard stop at ATR(`strategy_atr_period_d1`) *
  `strategy_atr_sl_mult`.
- Close both legs when the spread returns inside the neutral band:
  `channel_low + neutral_fraction * range` through
  `channel_high - neutral_fraction * range`.
- Close both legs after `strategy_max_hold_d1` completed D1 bars.
- If only one basket leg is open, close it immediately as a broken package.
- Friday close remains enabled by the V5 framework and closes both basket legs.

## Parameters To Test

- name: strategy_channel_lookback_d1
  default: 120
  sweep_range: [90, 120, 180, 252]
- name: strategy_beta
  default: 1.0
  sweep_range: [0.6, 0.8, 1.0, 1.2]
- name: strategy_neutral_fraction
  default: 0.25
  sweep_range: [0.15, 0.25, 0.35]
- name: strategy_max_hold_d1
  default: 45
  sweep_range: [30, 45, 60]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0]
- name: strategy_xng_max_spread_pts
  default: 2500
  sweep_range: [1500, 2500, 3500]
- name: strategy_xag_max_spread_pts
  default: 200
  sweep_range: [120, 200, 350]
- name: strategy_deviation_points
  default: 20
  sweep_range: [10, 20, 50]
- name: strategy_entry_hour_broker
  default: 2
  sweep_range: [0, 2, 4]
- name: strategy_entry_minute_broker
  default: 0
  sweep_range: [0]

## Risk

- expected_pf: 1.10.
- expected_dd_pct: 24.
- expected_trade_frequency: approximately 4-9 D1 spread packages/year.
- risk_class: high for natural-gas volatility and broken-correlation shocks.
- gridding: false.
- scalping: false.
- ml_required: false.

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and a logical basket
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, or the portfolio gate.

## Strategy Allowability Check

- [x] R1 reputable source: official CME product pages for the two futures
  markets represented by the Darwinex legs.
- [x] R2 mechanical: fixed log-ratio channel breakout, fixed neutral-band/time
  exit, fixed ATR stops, spread caps, session checks, and broken-package close.
- [x] R3 testable: `XNGUSD.DWX` and `XAGUSD.DWX` exist in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one
  two-leg package per magic set.
- [x] Non-duplicate: not existing XAU/XAG, XTI/XNG, XNG/XAU, XNG/XAG reversion,
  oil/gold, oil/silver, WTI single-leg, XNG single-leg, or commodity-RSI logic.

## Framework Alignment

- no_trade: D1 host guard, `XNGUSD.DWX` slot-0 guard, parameter guard, spread
  caps, both-leg trade-session checks.
- trade_entry: two-leg natural-gas/silver log-ratio channel breaks.
- trade_management: neutral-band exit, max-hold exit, broken-package close, and
  Friday close.
- trade_close: hard ATR stop plus deterministic basket exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-06-30 | initial structural XNG/XAG channel-breakout basket | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-30 | APPROVED | this card |
| Q02 Baseline Screening | 2026-06-30 | PENDING | to be enqueued after build |
