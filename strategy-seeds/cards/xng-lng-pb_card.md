---
ea_id: QM5_13084
slug: xng-lng-pb
type: strategy
strategy_id: EIA-XNG-LNG-PB-2026
source_id: EIA-XNG-LNG-PB-2026
source_citation: "U.S. Energy Information Administration natural-gas price-factor and LNG export demand pages. URLs https://www.eia.gov/energyexplained/natural-gas/factors-affecting-natural-gas-prices.php, https://www.eia.gov/todayinenergy/detail.php?id=67004, https://www.eia.gov/todayinenergy/detail.php?id=67484, and https://www.eia.gov/naturalgas/weekly/."
source_citations:
  - type: official_energy_reference
    citation: "U.S. Energy Information Administration. Factors affecting natural gas prices."
    location: "https://www.eia.gov/energyexplained/natural-gas/factors-affecting-natural-gas-prices.php"
    quality_tier: A
    role: primary
  - type: official_energy_analysis
    citation: "U.S. Energy Information Administration. We expect Henry Hub natural gas spot prices to fall slightly in 2026 before rising in 2027. Today in Energy, 2026-01-14."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=67004"
    quality_tier: A
    role: demand_growth_context
  - type: official_energy_analysis
    citation: "U.S. Energy Information Administration. U.S. natural gas exports to grow nearly 30% by 2027 as LNG facilities ramp up. Today in Energy, 2026-05-26."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=67484"
    quality_tier: A
    role: lng_export_context
  - type: official_weekly_report
    citation: "U.S. Energy Information Administration. Natural Gas Weekly Update."
    location: "https://www.eia.gov/naturalgas/weekly/"
    quality_tier: A
    role: market_context
sources:
  - "[[sources/EIA-XNG-LNG-PB-2026]]"
concepts:
  - "[[concepts/natural-gas-lng-exports]]"
  - "[[concepts/structural-demand-continuation]]"
  - "[[concepts/post-breakout-pullback]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [lng-export-demand, post-breakout-pullback, trend-continuation, atr-hard-stop, atr-profit-target, time-stop, long-only, low-frequency]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [commodities, energy, natural_gas]
single_symbol_only: true
logical_symbol: QM5_13084_XNG_LNG_PB_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Low-frequency LNG-demand-month post-breakout pullback continuation; estimate 4-8 entries/year after recent-breakout, SMA reclaim, ATR, spread, and one-entry-per-month filters."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-09
expected_pf: 1.08
expected_dd_pct: 24.0
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, natural_gas_volatility, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed commodity/energy sleeve 2026-07-09: R1 PASS official EIA natural-gas price-factor, LNG export demand, and weekly market sources; R2 PASS deterministic D1 LNG-demand-month recent breakout memory plus SMA/ATR pullback reclaim entry, ATR stop/target, SMA/channel/time exits, one-position and one-entry-per-month guards; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed. Non-duplicate because this waits for a post-breakout pullback/reclaim after LNG demand confirmation, unlike QM5_12769 immediate compression breakout and unlike QM5_12567 RSI mean reversion."
---

# XNG LNG Export-Demand Pullback Continuation

## Hypothesis

EIA identifies exports as a price-relevant natural-gas supply-demand factor and
links medium-term U.S. natural-gas demand growth to LNG export-facility ramp-up.
This card tests whether `XNGUSD.DWX` can express that structural demand theme
through a D1 price-only continuation setup: a recent upside breakout in
LNG-demand months, followed by a controlled pullback toward the slow SMA and a
bullish reclaim bar.

No EIA data, LNG flow, terminal utilization, weather, storage values, futures
curve, CSV file, API, forecast value, or discretionary input is read at runtime.
The source is used only for structural lineage. The executable rule uses
Darwinex MT5 D1 OHLC, broker calendar state, spread, ATR, SMA, and V5 framework
state.

## Source

- Primary: U.S. Energy Information Administration, "Factors affecting natural
  gas prices." URL
  https://www.eia.gov/energyexplained/natural-gas/factors-affecting-natural-gas-prices.php.
- LNG demand context: U.S. Energy Information Administration, "We expect Henry
  Hub natural gas spot prices to fall slightly in 2026 before rising in 2027."
  URL https://www.eia.gov/todayinenergy/detail.php?id=67004.
- LNG export context: U.S. Energy Information Administration, "U.S. natural gas
  exports to grow nearly 30% by 2027 as LNG facilities ramp up." URL
  https://www.eia.gov/todayinenergy/detail.php?id=67484.
- Market context: U.S. Energy Information Administration, "Natural Gas Weekly
  Update." URL https://www.eia.gov/naturalgas/weekly/.

## Concept

This is a single-symbol natural-gas structural demand sleeve. The rule is long
only because the source thesis is LNG export demand growth and facility ramp-up,
not a symmetric storage shock or weather-reversal premise.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator, short-horizon oversold
  mean reversion, or commodity basket logic.
- `QM5_12769_eia-xng-lng-brk`: this card does not enter the immediate
  compression breakout. It first requires a recent close-confirmed upside
  breakout, then waits for a pullback/reclaim bar near the SMA.
- XNG storage, pre-storage, storage fade, production, COT, rig-count,
  hurricane, freeze, month ORB, weekend gap, broad winter/summer/shoulder
  seasonality, XTI/XNG, gas-metal, and volatility-shock cards: no release data,
  no storage aftershock, no weather event, no month-opening range, no basket,
  and no external runtime feed.

## Markets And Timeframe

- Symbol: `XNGUSD.DWX`.
- Period: `D1`.
- Expected frequency: approximately 4-8 entries/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, SMA, broker calendar, and
  framework state only.

## Rules

- Evaluate only on a new `XNGUSD.DWX` D1 bar.
- Inspect the previous completed D1 bar as the pullback/reclaim signal bar.
- The signal bar must be in an LNG-demand month:
  January, February, March, April, July, August, September, November, or
  December by default.
- Only one entry is allowed per calendar month.
- A recent breakout must exist within `strategy_breakout_memory` completed D1
  bars before the signal bar. That prior bar must have closed above the
  preceding `strategy_breakout_lookback`-bar channel high by at least
  `strategy_break_buffer_points`, above the SMA, with a rising SMA.
- The signal bar must pull back into the SMA/ATR zone:
  signal low <= SMA + `strategy_pullback_band_atr` * ATR.
- The signal bar must reclaim above the SMA by at least
  `strategy_reclaim_buffer_points`, close above open, and close above the slow
  SMA while the slow SMA remains rising.
- Require signal range and body filters so tiny bars and extreme news bars are
  ignored.
- No entry if an open `XNGUSD.DWX` position already exists for this EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Profit target: fixed TP at ATR(`strategy_atr_period`) *
  `strategy_atr_tp_mult`.
- Close after `strategy_max_hold_days` calendar days.
- Close if the latest completed D1 close falls below the slow SMA.
- Close if the latest completed D1 close falls below the prior
  `strategy_exit_channel`-bar low.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XNGUSD.DWX` on D1.
- Only magic slot 0 is valid.
- Skip setup formation when ATR, SMA, channel, spread, entry price, stop, or
  target prices are unavailable.
- Framework news, kill-switch, magic, risk, stress, and Friday-close guards
  remain active.

## Trade Management Rules

- Long-only.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_trend_period
  default: 63
  sweep_range: [50, 63, 84]
- name: strategy_sma_slope_shift
  default: 8
  sweep_range: [5, 8, 13]
- name: strategy_breakout_lookback
  default: 42
  sweep_range: [34, 42, 55]
- name: strategy_breakout_memory
  default: 10
  sweep_range: [6, 10, 15]
- name: strategy_exit_channel
  default: 13
  sweep_range: [8, 13, 21]
- name: strategy_break_buffer_points
  default: 20
  sweep_range: [10, 20, 40]
- name: strategy_reclaim_buffer_points
  default: 10
  sweep_range: [0, 10, 25]
- name: strategy_pullback_band_atr
  default: 0.45
  sweep_range: [0.25, 0.45, 0.70]
- name: strategy_min_signal_range_atr
  default: 0.45
  sweep_range: [0.30, 0.45, 0.70]
- name: strategy_max_signal_range_atr
  default: 2.20
  sweep_range: [1.80, 2.20, 2.80]
- name: strategy_min_body_atr
  default: 0.12
  sweep_range: [0.08, 0.12, 0.20]
- name: strategy_atr_sl_mult
  default: 3.00
  sweep_range: [2.50, 3.00, 3.75]
- name: strategy_atr_tp_mult
  default: 3.50
  sweep_range: [2.50, 3.50, 4.50]
- name: strategy_max_hold_days
  default: 16
  sweep_range: [10, 16, 24]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]

## Author Claims

No performance claim is imported from EIA. EIA is used only as official source
lineage for natural-gas price factors and LNG export demand growth. Q02 and
later phases must validate or reject the mechanical `XNGUSD.DWX` realization on
Darwinex bars.

## Risk

- expected_pf: 1.08.
- expected_dd_pct: 24.
- expected_trade_frequency: approximately 4-8 entries/year.
- risk_class: high because natural gas gaps and sparse structural samples need
  Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA natural-gas price-factor, LNG export
  demand, and weekly natural-gas market pages.
- [x] R2 mechanical: fixed demand-month map, recent breakout memory,
  SMA/ATR pullback zone, bullish reclaim, ATR stop/target, and deterministic
  SMA/channel/time exits.
- [x] R3 testable: `XNGUSD.DWX` exists in the DWX symbol universe.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic.
- [x] Non-duplicate: not RSI commodity logic, immediate LNG compression
  breakout, storage/freeze/hurricane/production/COT/rig-count/month-ORB,
  XTI/XNG, gas-metal, or broad seasonality logic.

## Framework Alignment

- no_trade: XNG/D1 host guard, magic-slot guard, parameter guard, spread cap,
  and valid-data checks.
- trade_entry: LNG-demand-month recent breakout memory followed by D1
  SMA/ATR pullback and bullish reclaim.
- trade_management: max-hold, SMA failure, and adverse exit-channel exits.
- trade_close: hard ATR stop/target plus deterministic strategy exits and
  framework Friday close.

## Pipeline History

- 2026-07-09: Mission-directed card created and assigned `QM5_13084`.
- 2026-07-09: Q01 build/spec validation PASS; strict compile/build_check PASS
  with 0 errors, 0 warnings, and RISK_FIXED backtest setfile hash
  `0dc34f513f71344717a82acf2af036bf3668a59c139ec9266aeb3e0be395ee37`.
- 2026-07-09: Q02 baseline backtest enqueued for `XNGUSD.DWX` D1 as work
  item `a9c7c7ea-ca75-4e83-b2e8-255c6ba28c67`.

## Pipeline Phase Status

- G0: APPROVED.
- Q01 build/spec: PASS.
- Q02 backtest enqueue: pending work item
  `a9c7c7ea-ca75-4e83-b2e8-255c6ba28c67`.
