---
ea_id: QM5_12977
slug: wti-propane-draw
type: strategy
strategy_id: EIA-PROPANE-DRAW-2026
source_id: EIA-PROPANE-DRAW-2026
source_citation: "U.S. Energy Information Administration. Prices for hydrocarbon gas liquids: propane; Heating Oil and Propane Update. URLs https://www.eia.gov/energyexplained/hydrocarbon-gas-liquids/prices-for-hydrocarbon-gas-liquids-propane.php and https://www.eia.gov/petroleum/heatingoilpropane/"
source_citations:
  - type: government_energy_analysis
    citation: "U.S. Energy Information Administration. Prices for hydrocarbon gas liquids: propane."
    location: "https://www.eia.gov/energyexplained/hydrocarbon-gas-liquids/prices-for-hydrocarbon-gas-liquids-propane.php"
    quality_tier: A
    role: primary
  - type: government_energy_statistics
    citation: "U.S. Energy Information Administration. Heating Oil and Propane Update."
    location: "https://www.eia.gov/petroleum/heatingoilpropane/"
    quality_tier: A
    role: heating_season_window
sources:
  - "[[sources/EIA-PROPANE-DRAW-2026]]"
concepts:
  - "[[concepts/propane-heating-season-draw]]"
  - "[[concepts/structural-energy-demand]]"
  - "[[concepts/displacement-continuation]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, structural-demand, propane-draw-seasonality, displacement-continuation, trend-filter-ma, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
timeframes: [D1]
logical_symbol: QM5_12977_XTI_PROPANE_DRAW_D1
single_symbol_only: true
period: D1
expected_trade_frequency: "Low-frequency October-March WTI propane heating-season draw displacement continuation; estimate 6-12 trades/year before Q02 validates history and fills."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-03
expected_pf: 1.08
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [symbol_history_sufficiency, low_frequency_sample, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "R1 PASS official EIA propane/heating-season source packet; R2 PASS deterministic October-March D1 long-only displacement-continuation rule with rising SMA trend gate, ATR-normalized positive close-to-close and body displacement, upper-range close filter, ATR hard stop, and time/window/trend exits; R3 PASS XTIUSD.DWX is in the DWX symbol matrix; R4 PASS no ML/grid/martingale/external runtime feed."
---

# WTI Propane Heating-Season Draw Displacement

## Source

- Source: [[sources/EIA-PROPANE-DRAW-2026]]
- Primary citation: U.S. Energy Information Administration, "Prices for
  hydrocarbon gas liquids: propane", URL
  https://www.eia.gov/energyexplained/hydrocarbon-gas-liquids/prices-for-hydrocarbon-gas-liquids-propane.php.
- Heating-season supplement: U.S. Energy Information Administration, "Heating
  Oil and Propane Update", URL https://www.eia.gov/petroleum/heatingoilpropane/.

## Concept

EIA describes propane consumption as highly seasonal, with stocks typically
building during spring and summer and being used during autumn and winter.
The EIA Heating Oil and Propane Update explicitly covers the October through
March heating season. This card does not forecast propane inventories or
ingest EIA data. It expresses that structural autumn/winter energy-demand
regime as a low-frequency WTI D1 displacement-continuation sleeve: buy only
inside the October-March propane heating-season draw window after WTI closes
above a rising trend and prints an ATR-normalized upside displacement bar that
closes in the upper part of its daily range.

This is deliberately different from:

- `QM5_12583_eia-distillate-winter`: winter distillate demand channel breakout.
  This card is propane-source lineage and uses displacement/body/upper-range
  continuation, not a 20-day Donchian breakout.
- `QM5_12963_wti-winter-exhaust`: winter heating-oil exhaustion fade. This
  card is long-only continuation, not a short fade.
- `QM5_12869_wti-ref-ramp-pb` and `QM5_12763_wti-ref-sqz-brk`: refinery
  utilization ramp and pre-summer squeeze sleeves in May-July, not an
  October-March propane draw window.
- WTI WPSR, Cushing, hurricane, OPEC, expiry, ETF-roll, weekday/month,
  XTI/XNG, oil/gold, oil/silver, XNG, XAU/XAG, index, and
  `QM5_12567_cum-rsi2-commodity` sleeves: no event surprise, no ratio basket,
  no RSI, no oscillator, no ML, no grid, no martingale.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected frequency: about 6-12 entries/year before Q02.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, SMA, broker calendar, and
  V5 framework state only. No propane price, propane inventory, weather,
  product-spread, futures-curve, CSV, API, analyst forecast, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- The prior completed D1 bar must fall inside the October 1 through March 31
  heating-season draw window.
- Host chart must be `XTIUSD.DWX` on D1 with magic slot 0.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.
- Trend gate: prior close must be above SMA(`strategy_trend_period`) and that
  SMA must be above its value `strategy_sma_slope_shift` bars earlier.
- Displacement gate: prior close minus the previous completed D1 close must be
  at least `strategy_min_return_atr` ATR.
- Body gate: prior close must be above prior open by at least
  `strategy_min_body_atr` ATR.
- Close-location gate: prior close must be at or above
  `strategy_min_close_location` of the prior bar's high-low range.
- Entry direction is long only: BUY `XTIUSD.DWX` at market.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close when the active date leaves the October-March draw window.
- Close when prior completed D1 close falls below SMA(`strategy_trend_period`).
- Close when prior completed D1 close breaks below the lowest low of the
  previous `strategy_exit_channel` completed D1 bars.
- Close after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Magic slot offset must be 0.
- Skip entries when ATR, SMA, bar OHLC, range, or spread metadata is
  unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Long only.
- No pyramiding, gridding, martingale, partial close, or trailing stop.
- One open position per magic/symbol.

## 8. Parameters To Test

- name: strategy_start_month
  default: 10
  sweep_range: [10]
- name: strategy_start_day
  default: 1
  sweep_range: [1]
- name: strategy_end_month
  default: 3
  sweep_range: [3]
- name: strategy_end_day
  default: 31
  sweep_range: [15, 31]
- name: strategy_trend_period
  default: 55
  sweep_range: [34, 55, 84]
- name: strategy_sma_slope_shift
  default: 5
  sweep_range: [3, 5, 10]
- name: strategy_exit_channel
  default: 6
  sweep_range: [4, 6, 10]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_return_atr
  default: 0.45
  sweep_range: [0.35, 0.45, 0.60]
- name: strategy_min_body_atr
  default: 0.20
  sweep_range: [0.10, 0.20, 0.35]
- name: strategy_min_close_location
  default: 0.70
  sweep_range: [0.60, 0.70, 0.80]
- name: strategy_atr_sl_mult
  default: 2.75
  sweep_range: [2.25, 2.75, 3.50]
- name: strategy_max_hold_days
  default: 10
  sweep_range: [6, 10, 15]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The EIA source establishes propane heating-season draw structure as source
lineage only. This card imports no source performance claim. Q02 and later
phases must validate or reject the mechanical rule on Darwinex `XTIUSD.DWX`
bars.

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 20.
- expected_trade_frequency: approximately 6-12 entries/year.
- risk_class: medium-high because crude volatility and low-frequency sample
  size need Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA propane/heating-season source packet.
- [x] R2 mechanical: fixed calendar window, rising SMA trend gate,
  ATR-normalized return/body displacement, close-location filter, ATR hard
  stop, and deterministic exits.
- [x] R3 data available: `XTIUSD.DWX` D1 OHLC is in the DWX symbol matrix.
- [x] R4 forbidden methods absent: no ML, neural network, genetic optimizer,
  grid, martingale, discretionary feed, or external runtime data.
