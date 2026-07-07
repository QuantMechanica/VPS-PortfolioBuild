---
ea_id: QM5_13027
slug: xti-cot-mom
type: strategy
strategy_id: CFTC-COT-XTI-FRI-MOM-2026
source_id: CFTC-COT-RELEASE-2026
source_citation: "U.S. Commodity Futures Trading Commission, Commitments of Traders main page and release schedule. URLs https://www.cftc.gov/MarketReports/CommitmentsofTraders/index.htm and https://www.cftc.gov/MarketReports/CommitmentsofTraders/ReleaseSchedule/index.htm"
source_citations:
  - type: government_market_data
    citation: "U.S. Commodity Futures Trading Commission. Commitments of Traders."
    location: "https://www.cftc.gov/MarketReports/CommitmentsofTraders/index.htm"
    quality_tier: A
    role: primary
  - type: government_release_schedule
    citation: "U.S. Commodity Futures Trading Commission. Commitments of Traders Release Schedule."
    location: "https://www.cftc.gov/MarketReports/CommitmentsofTraders/ReleaseSchedule/index.htm"
    quality_tier: A
    role: primary
  - type: exchange_context
    citation: "CME Group. Commitment of Traders tool and CFTC report context."
    location: "https://www.cmegroup.com/tools-information/quikstrike/commitment-of-traders.html"
    quality_tier: B
    role: supplement
sources:
  - "[[sources/CFTC-COT-RELEASE-2026]]"
concepts:
  - "[[concepts/cftc-cot-release-cadence]]"
  - "[[concepts/managed-money-positioning-proxy]]"
  - "[[concepts/d1-event-momentum]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
  - "[[indicators/donchian-channel]]"
strategy_type_flags: [official-release-window, positioning-proxy, channel-breakout, trend-filter-ma, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13027_XTI_COT_FRI_MOM_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 WTI first-new-week continuation after a large Friday COT-release-window displacement that also confirms trend and Donchian breakout; roughly 4-10 entries/year before Q02 validation."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-07
expected_pf: 1.07
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, friday_close, crude_oil_volatility, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-07: R1 PASS official CFTC COT source and release-schedule packet plus CME exchange-context supplement; R2 PASS deterministic D1 first-new-week continuation after a large Friday XTI displacement with close-location, SMA trend/slope, Donchian breakout, ATR hard stop, favorable/adverse closed-bar exits, and time exit; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed. Non-duplicate because this follows COT-window trend-confirmed breakouts, while QM5_13004 fades stretched Friday displacement extremes."
---

# XTI COT Friday Positioning Momentum

## Hypothesis

CFTC Commitments of Traders reports provide a weekly public view of futures
market positioning and are normally released Friday afternoon using data from
the prior Tuesday. This card does not download or parse CFTC data at runtime.
It uses the official release cadence as structural lineage and asks whether a
large completed Friday `XTIUSD.DWX` D1 displacement can continue into the next
broker week when the move also confirms trend and breaks the prior D1 channel.

## Source

- Primary official source: U.S. Commodity Futures Trading Commission,
  "Commitments of Traders", URL
  https://www.cftc.gov/MarketReports/CommitmentsofTraders/index.htm.
- Primary release-cadence source: U.S. Commodity Futures Trading Commission,
  "Commitments of Traders Release Schedule", URL
  https://www.cftc.gov/MarketReports/CommitmentsofTraders/ReleaseSchedule/index.htm.
- Supplemental market-context source: CME Group, "Commitment of Traders", URL
  https://www.cmegroup.com/tools-information/quikstrike/commitment-of-traders.html.

## Concept

This is a single-symbol crude-oil positioning-window continuation sleeve. On
the first D1 bar of a new broker week, the EA inspects the prior completed
Friday D1 bar. If that COT-window proxy bar posts a large directional move,
closes near the directional extreme, closes on the same side of a rising or
falling SMA, and breaks the prior Donchian channel, the EA follows the move.

This is deliberately different from:

- `QM5_13004_xti-cot-fade`: same official COT release cadence, but opposite
  entry side and different confirmation. `QM5_13004` fades stretched extremes;
  this card follows only trend-confirmed Donchian breakouts.
- WPSR/inventory, import/export, PSM, DPR, STEO, SPR, Cushing, refinery,
  distillate/RBOB/jet fuel, hurricane, OPEC, IEA OMR, roll, expiry, rig-count,
  and WTI/Brent sleeves: no such source family or event window is used.
- Weekday/month seasonality: this requires a COT-release-window Friday
  displacement plus trend/channel confirmation, not a static day premium.
- Broad commodity TSMOM/reversal/carry, XTI/XNG, oil/gold, oil/silver,
  XAU/XAG, XNG, and `QM5_12567_cum-rsi2-commodity`: no basket, hedge ratio,
  RSI, oscillator pullback, or external runtime feed.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: approximately 4-10 trades/year before Q02.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, SMA, broker calendar, and
  V5 framework state only.

## Rules

- Evaluate only on a new `XTIUSD.DWX` D1 bar.
- Host chart must be `XTIUSD.DWX` on D1 and magic slot 0.
- Require the current D1 bar to be the first trading bar of a new broker week.
- Use the prior completed D1 bar as the COT-release-window proxy.
- Require that prior bar's day-of-week to be Friday by default.
- Compute `signal_return_pct = 100 * ln(Close[1] / Close[2])`.
- Compute ATR(`strategy_atr_period`)[1], SMA(`strategy_trend_period`)[1], and
  SMA(`strategy_trend_period`)[1 + `strategy_sma_slope_shift`].
- Require `abs(signal_return_pct) >= strategy_min_signal_return_pct`.
- Require `abs(signal_return_pct) >= strategy_min_atr_return_mult * atr_pct`,
  where `atr_pct = 100 * ATR / Close[1]`.
- Skip if `abs(signal_return_pct) > strategy_max_signal_return_pct`.
- Long entry:
  - `signal_return_pct` is positive.
  - `Close[1]` is in the top `strategy_close_location_min` fraction of the
    signal bar range.
  - `Close[1]` is above SMA(`strategy_trend_period`).
  - SMA is above its value `strategy_sma_slope_shift` bars earlier.
  - `Close[1]` breaks above the prior Donchian high over
    `strategy_channel_lookback` completed D1 bars excluding the signal bar.
  - Enter BUY.
- Short entry:
  - `signal_return_pct` is negative.
  - `Close[1]` is in the bottom `strategy_close_location_min` fraction of the
    signal bar range.
  - `Close[1]` is below SMA(`strategy_trend_period`).
  - SMA is below its value `strategy_sma_slope_shift` bars earlier.
  - `Close[1]` breaks below the prior Donchian low over
    `strategy_channel_lookback` completed D1 bars excluding the signal bar.
  - Enter SELL.
- Skip if an open `XTIUSD.DWX` position already exists for this EA magic.
- Skip if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Close after `strategy_max_hold_days` calendar days.
- Close a long if the latest completed D1 close falls below
  SMA(`strategy_trend_period`).
- Close a short if the latest completed D1 close rises above
  SMA(`strategy_trend_period`).
- Close a long if a completed D1 close has moved at least
  `strategy_profit_close_atr_mult * ATR(strategy_atr_period)` above entry.
- Close a short if a completed D1 close has moved at least
  `strategy_profit_close_atr_mult * ATR(strategy_atr_period)` below entry.
- Close early if a completed D1 close continues against the entry beyond
  `strategy_adverse_close_atr_mult * ATR(strategy_atr_period)`.
- Friday Close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Magic slot offset must be 0.
- Skip entries when D1 history, ATR, SMA, channel state, spread, entry price,
  or stop price is unavailable.
- Framework news, kill-switch, magic, risk, and Friday-close guards remain
  active.

## Trade Management Rules

- Symmetric long/short.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_min_signal_return_pct
  default: 1.10
  sweep_range: [0.80, 1.10, 1.50]
- name: strategy_min_atr_return_mult
  default: 0.55
  sweep_range: [0.40, 0.55, 0.75]
- name: strategy_max_signal_return_pct
  default: 9.0
  sweep_range: [7.0, 9.0, 12.0]
- name: strategy_close_location_min
  default: 0.62
  sweep_range: [0.58, 0.62, 0.72]
- name: strategy_signal_dow
  default: 5
  sweep_range: [5]
- name: strategy_channel_lookback
  default: 20
  sweep_range: [15, 20, 30]
- name: strategy_trend_period
  default: 80
  sweep_range: [50, 80, 120]
- name: strategy_sma_slope_shift
  default: 5
  sweep_range: [3, 5, 10]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.75
  sweep_range: [2.25, 2.75, 3.50]
- name: strategy_max_hold_days
  default: 5
  sweep_range: [3, 5, 8]
- name: strategy_profit_close_atr_mult
  default: 1.40
  sweep_range: [1.00, 1.40, 2.00]
- name: strategy_adverse_close_atr_mult
  default: 1.00
  sweep_range: [0.75, 1.00, 1.30]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The CFTC sources establish the COT publication and release cadence only. This
card imports no source performance claim. Q02 and later phases must validate
or reject the mechanical `XTIUSD.DWX` realization on Darwinex bars.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX` D1
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Initial Risk Profile

- expected_pf: 1.07.
- expected_dd_pct: 20.
- expected_trade_frequency: approximately 4-10 entries/year on D1.
- risk_class: medium-high because crude-oil gaps, event timing, and sparse
  positioning-window samples require Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official CFTC COT pages and official release
  schedule; CME COT page used only as exchange-context supplement.
- [x] R2 mechanical: fixed new-week gate, prior Friday displacement,
  close-location, trend/channel confirmation, ATR stop, and deterministic
  trend/profit/adverse/time exits.
- [x] R3 testable: `XTIUSD.DWX` exists in the DWX symbol matrix.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  no external runtime data, and one position per magic.
- [x] Non-duplicate: CFTC COT release-cadence WTI positioning momentum, not
  `QM5_13004` COT fade and not the existing WTI/XNG source families listed
  above.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard,
  spread cap, first-new-week gate, and signal-quality checks.
- trade_entry: first-new-week COT-release-window continuation after a large
  prior Friday D1 displacement with trend/channel confirmation.
- trade_management: trend-failure, favorable ATR, adverse ATR, and max-hold
  exits.
- trade_close: hard ATR stop plus deterministic strategy exits and framework
  Friday close.

## Pipeline

- G0: APPROVED by mission-directed card criteria on 2026-07-07.
- Q01: implemented as `framework/EAs/QM5_13027_xti-cot-mom`.
- Q02: queued after compile.
