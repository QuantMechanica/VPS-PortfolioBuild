---
ea_id: QM5_12898
slug: xng-eia-multiday-drift
type: strategy
source_id: EIA-XNG-MULTIDAY-DRIFT-2026
source_citation: "U.S. Energy Information Administration. Weekly Natural Gas Storage Report and release schedule. URLs https://www.eia.gov/naturalgas/storage/ and https://www.eia.gov/naturalgas/schedule/"
sources:
  - "[[sources/EIA-XNG-MULTIDAY-DRIFT-2026]]"
concepts:
  - "[[concepts/natural-gas-storage]]"
  - "[[concepts/post-event-drift]]"
  - "[[concepts/energy-event-risk]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
strategy_type_flags: [storage-report, post-event-drift, event-continuation, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Weekly natural-gas storage-report drift continuation on D1 bars; estimate 8-18 trades/year after event-range, close-location, trend, spread, and one-entry-per-event filters."
expected_trades_per_year_per_symbol: 12
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-07-02
g0_approval_reasoning: "R1 PASS official EIA weekly natural-gas storage report and release schedule; R2 PASS deterministic D1 post-report drift continuation using event-day range, close location, ATR stop, SMA/time exits, and no external runtime feed; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.10
expected_dd_pct: 25.0
---

# EIA XNG Multiday Drift

## Source

- Source: [[sources/EIA-XNG-MULTIDAY-DRIFT-2026]]
- Primary citation: U.S. Energy Information Administration, "Weekly Natural
  Gas Storage Report", URL https://www.eia.gov/naturalgas/storage/.
- Release schedule citation: U.S. Energy Information Administration, "Natural
  Gas Weekly Update and Storage Report Schedule", URL
  https://www.eia.gov/naturalgas/schedule/.
- Structural supplement: U.S. Energy Information Administration, "Natural gas
  explained", URL https://www.eia.gov/energyexplained/natural-gas/.

## Concept

The EIA Weekly Natural Gas Storage Report is a recurring official information
event for the natural-gas market. This card does not forecast inventory data,
does not consume a storage surprise feed, and does not use weather data. It
waits for a likely storage-report D1 bar that closes directionally, then enters
at market on the next eligible D1 bar for a short multiday continuation drift.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: this card has no RSI, oscillator, or
  two-day pullback condition.
- `QM5_12761_eia-xng-stor-idbrk`: this card does not wait for an inside-day
  compression bar or a live high/low breakout.
- `QM5_12584_eia-xng-storage`: this card does not follow an imported storage
  surprise or storage-level feed.
- `QM5_12744_eia-xng-storfade`: this card follows directional event-bar
  continuation instead of fading stretched report bars.
- `QM5_12725_eia-xng-prestor`: this card is post-event, not pre-storage.
- Seasonal, weather, hurricane, shoulder-month, carry, and broad XNG momentum
  cards: this is a fixed weekly official-event drift package.

## Markets And Timeframe

- Symbol: `XNGUSD.DWX`.
- Period: D1.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no storage level,
  consensus forecast, surprise feed, weather feed, futures curve, CSV, API, or
  discretionary input.

## Entry Rules

- Evaluate the setup only on a new D1 bar.
- The immediately preceding completed D1 bar must be a likely storage-report
  event bar. The default event-day window is Wednesday through Friday to
  tolerate EIA holiday shifts.
- The current entry D1 bar must be in the default Monday through Friday entry
  window.
- Event-bar range must be at least `strategy_min_event_range_atr` times
  ATR(`strategy_atr_period`) and no more than
  `strategy_max_event_range_atr` times ATR.
- Event-bar body must be at least `strategy_min_body_ratio` of the full bar
  range.
- Long drift: event bar closes above its open, closes in the upper portion of
  its range using `strategy_close_location_threshold`, and closes above
  SMA(`strategy_trend_period`) when `strategy_require_trend` is true.
- Short drift: event bar closes below its open, closes in the lower portion of
  its range using `strategy_close_location_threshold`, and closes below
  SMA(`strategy_trend_period`) when `strategy_require_trend` is true.
- At most one entry per event bar.
- No entry if this EA already has an open `XNGUSD.DWX` position.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Optional take profit: disabled by default; when enabled,
  `strategy_atr_tp_mult` times ATR from entry.
- Close a long when prior D1 close falls below SMA(`strategy_trend_period`).
- Close a short when prior D1 close rises above SMA(`strategy_trend_period`).
- Close after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XNGUSD.DWX` on D1.
- Only magic slot 0 is valid.
- Skip setups when ATR, SMA, event OHLC, or current D1 bar time are
  unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Symmetric long/short continuation drift.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_event_min_dow
  default: 3
  sweep_range: [3]
- name: strategy_event_max_dow
  default: 5
  sweep_range: [4, 5]
- name: strategy_entry_min_dow
  default: 1
  sweep_range: [1]
- name: strategy_entry_max_dow
  default: 5
  sweep_range: [5]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_trend_period
  default: 50
  sweep_range: [40, 50, 63]
- name: strategy_min_event_range_atr
  default: 0.80
  sweep_range: [0.70, 0.80, 1.00]
- name: strategy_max_event_range_atr
  default: 3.50
  sweep_range: [2.50, 3.50, 4.50]
- name: strategy_close_location_threshold
  default: 0.65
  sweep_range: [0.60, 0.65, 0.70]
- name: strategy_min_body_ratio
  default: 0.25
  sweep_range: [0.20, 0.25, 0.35]
- name: strategy_atr_sl_mult
  default: 3.00
  sweep_range: [2.50, 3.00, 3.50]
- name: strategy_atr_tp_mult
  default: 0.00
  sweep_range: [0.00, 3.00, 5.00]
- name: strategy_signal_valid_days
  default: 1
  sweep_range: [1, 2]
- name: strategy_max_hold_days
  default: 4
  sweep_range: [3, 4, 5]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]
- name: strategy_require_trend
  default: true
  sweep_range: [true]

## Author Claims

No performance claim is imported from EIA. The source is used only as official
structural lineage for the weekly natural-gas storage information event. Q02+
tests this deterministic post-storage multiday drift on Darwinex
`XNGUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 25
- expected_trade_frequency: approximately 8-18 trades/year.
- risk_class: high for natural-gas volatility, event gaps, and weekend gap
  exposure.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA weekly storage report and release
  schedule.
- [x] R2 mechanical: fixed event-day set, event range/body/close-location
  tests, ATR stop, SMA trend exit, max-hold exit, and one entry per event.
- [x] R3 testable: `XNGUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  one position per magic.
- [x] Non-duplicate: post-storage directional drift is not cumulative RSI2,
  post-storage inside-day breakout, storage fade, pre-storage positioning,
  seasonal XNG, weather XNG, weekend gap, carry, 4-week reversal, or basket
  logic.

## Framework Alignment

- no_trade: D1 and `XNGUSD.DWX` guard, event-day/entry-day gate, parameter
  guard, spread cap.
- trade_entry: first eligible D1 bar after a likely storage-report event bar
  with close-location and SMA confirmation.
- trade_management: SMA trend failure and max-hold exits.
- trade_close: hard ATR stop, optional ATR target, deterministic time exits,
  and framework Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-02 | initial structural XNG storage multiday drift build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-02 | APPROVED | this card |
