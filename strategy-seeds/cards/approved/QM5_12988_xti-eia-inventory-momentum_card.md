---
ea_id: QM5_12988
slug: xti-eia-inventory-momentum
type: strategy
source_id: EIA-WPSR-2W-MOM-2026
sources:
  - "U.S. Energy Information Administration, Weekly Petroleum Status Report, https://www.eia.gov/petroleum/supply/weekly/"
  - "U.S. Energy Information Administration, Weekly Petroleum Status Report schedule, https://www.eia.gov/petroleum/supply/weekly/schedule.php"
  - "U.S. Energy Information Administration, Oil and petroleum products explained, https://www.eia.gov/energyexplained/oil-and-petroleum-products/"
concepts:
  - "crude-oil-inventory-information-cycle"
  - "multiweek-post-event-momentum"
  - "breakout-confirmation"
indicators:
  - "SMA"
  - "ATR"
  - "Donchian breakout"
strategy_type_flags: [inventory-event, structural-demand, channel-breakout, trend-filter-ma, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12988_XTI_WPSR_2W_MOM_D1
period: D1
expected_trade_frequency: "D1 WTI two-event WPSR reaction momentum; estimate 5-12 trades/year after two-event, breakout, trend, and spread filters."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-03
expected_pf: 1.12
expected_dd_pct: 18.0
g0_approval_reasoning: "R1 PASS official EIA WPSR/release schedule and petroleum-market structure pages; R2 PASS deterministic D1 two-event reaction momentum with SMA trend gate, Donchian confirmation, ATR stop, and time/trend exits; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
---

# XTI EIA Inventory Momentum

## Source

- Primary citation: U.S. Energy Information Administration, "Weekly Petroleum
  Status Report", URL https://www.eia.gov/petroleum/supply/weekly/.
- Release schedule citation: U.S. Energy Information Administration, "Weekly
  Petroleum Status Report Schedule", URL
  https://www.eia.gov/petroleum/supply/weekly/schedule.php.
- Structural supplement: U.S. Energy Information Administration, "Oil and
  petroleum products explained", URL
  https://www.eia.gov/energyexplained/oil-and-petroleum-products/.

## Concept

The EIA Weekly Petroleum Status Report is the recurring official U.S. petroleum
information cycle. This card does not forecast inventories and does not ingest
EIA data. It observes the WTI market's own D1 reaction to consecutive weekly
WPSR proxy bars, then only enters when those two event reactions align with a
closed-bar breakout and trend confirmation.

This is deliberately different from existing WTI inventory sleeves:

- `QM5_10319_eia-oil-momo` is an intraday M30 release-window momentum system.
- `QM5_12579_eia-wti-aftershock` follows one large WPSR event-day bar for a
  short aftershock window.
- `QM5_12590_eia-wti-wpsr-fade` fades one stretched WPSR event-day reaction.
- `QM5_12592_eia-wti-prewpsr` enters before the event-day bar develops.
- `QM5_12752_eia-wti-wpsr-idbrk` trades a post-event inside-bar breakout.

`QM5_12988` requires two same-direction weekly event reactions plus a 20-day
breakout, so it is lower-frequency and structurally separate from the one-bar
event variants.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: about 5-12 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only. No EIA feed,
  inventory surprise feed, futures curve, CSV, API, analyst forecast, or ML
  model is used at runtime.

## Entry Rules

- Evaluate only on a new D1 bar.
- Host chart must be `XTIUSD.DWX` on D1 and magic slot 0.
- Treat the prior completed D1 bar as the latest WPSR proxy only when its
  broker calendar day is Wednesday or Thursday.
- Find the prior WPSR proxy bar within `strategy_event_search_bars` completed
  D1 bars, requiring a calendar gap of at least
  `strategy_min_event_gap_days` and no more than
  `strategy_max_event_gap_days`.
- Latest and prior WPSR proxy bars must have the same close-minus-open sign.
- Latest close must also be beyond the prior WPSR proxy close in that same
  direction by at least `strategy_min_event_move_atr` times ATR.
- Long setup: both event bars are positive, latest close is above
  SMA(`strategy_trend_period`), and latest close breaks above the highest high
  of the prior `strategy_breakout_lookback` completed D1 bars excluding the
  latest event bar.
- Short setup: both event bars are negative, latest close is below
  SMA(`strategy_trend_period`), and latest close breaks below the lowest low of
  the prior `strategy_breakout_lookback` completed D1 bars excluding the latest
  event bar.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close a long if the prior completed D1 close falls below
  SMA(`strategy_trend_period`).
- Close a short if the prior completed D1 close rises above
  SMA(`strategy_trend_period`).
- Close after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Risk

- expected_pf: 1.12.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 5-12 trades/year.
- risk_class: medium-high for crude-oil volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 official source: EIA WPSR, release schedule, and petroleum-market
  structure pages.
- [x] R2 mechanical: fixed weekday event proxy, two-event direction check,
  breakout/trend gates, ATR stop, and deterministic trend/time exits.
- [x] R3 testable: `XTIUSD.DWX` exists in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  and one position per magic.
- [x] Non-duplicate: multiweek two-event momentum is not intraday release
  momentum, one-bar aftershock, one-bar fade, pre-event positioning, post-event
  inside-bar breakout, roll, month/weekday seasonality, XNG, XAU/XAG, or RSI
  commodity pullback logic.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard, and
  spread cap.
- trade_entry: prior closed WPSR proxy bar plus previous WPSR proxy bar,
  same-direction reaction, event-to-event ATR move, SMA trend gate, and
  Donchian breakout confirmation.
- trade_management: trend failure and fixed max-hold exits.
- trade_close: hard ATR stop plus deterministic time/trend exits and framework
  Friday close.

## Pipeline

- G0: APPROVED by card criteria on 2026-07-03.
- Q01: implemented as `framework/EAs/QM5_12988_xti-eia-inventory-momentum`.
- Q02: queued after compile.

