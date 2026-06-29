---
ea_id: QM5_12761
slug: eia-xng-stor-idbrk
type: strategy
source_id: EIA-XNG-STOR-IDBRK-2026
source_citation: "U.S. Energy Information Administration. Weekly Natural Gas Storage Report and release schedule. URLs https://www.eia.gov/naturalgas/storage/ and https://www.eia.gov/naturalgas/schedule/"
sources:
  - "[[sources/EIA-XNG-STOR-IDBRK-2026]]"
concepts:
  - "[[concepts/natural-gas-storage]]"
  - "[[concepts/post-event-compression-breakout]]"
  - "[[concepts/energy-event-risk]]"
indicators:
  - "[[indicators/inside-day]]"
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
strategy_type_flags: [storage-report, inside-day-breakout, compression-breakout, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Weekly natural-gas storage-report inside-day breakout on D1 bars; estimate 5-12 trades/year after event-day, compression, SMA, spread, and setup-validity filters."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-29
g0_approval_reasoning: "R1 PASS official EIA weekly natural-gas storage report and release schedule; R2 PASS deterministic D1 event-bar plus inside-day compression breakout with ATR stop, SMA/time exits, and no external runtime feed; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.10
expected_dd_pct: 24.0
---

# EIA XNG Storage Inside-Day Breakout

## Source

- Source: [[sources/EIA-XNG-STOR-IDBRK-2026]]
- Primary citation: U.S. Energy Information Administration, "Weekly Natural
  Gas Storage Report", URL https://www.eia.gov/naturalgas/storage/.
- Release schedule citation: U.S. Energy Information Administration, "Natural
  Gas Weekly Update and Storage Report Schedule", URL
  https://www.eia.gov/naturalgas/schedule/.
- Structural supplement: U.S. Energy Information Administration, "Natural gas
  explained", URL https://www.eia.gov/energyexplained/natural-gas/.

## Concept

The EIA Weekly Natural Gas Storage Report is a recurring official information
event for natural gas. This card does not forecast storage data or import any
report feed. It waits for the market to compress after a likely storage-report
D1 bar, then trades only a live break of that compressed inside-day range.

This is deliberately different from:

- `QM5_12584_eia-xng-storage`: follows large storage-report reaction bars.
- `QM5_12744_eia-xng-storfade`: fades stretched storage-report bars.
- `QM5_12725_eia-xng-prestor`: pre-event positioning, not post-event range
  compression.
- `QM5_12575`, `QM5_12586`, `QM5_12587`, `QM5_12588`, `QM5_12595`,
  `QM5_12601`, `QM5_12602`, `QM5_12702`, and `QM5_12704`: seasonal, weather,
  shoulder, freeze, hurricane, or broad monthly XNG logic, not post-storage
  inside-day compression.
- `QM5_12620_comm-reversal-4wk-xngusd` and `QM5_12567_cum-rsi2-commodity`:
  no fixed return reversal and no RSI/oscillator pullback.

## Markets And Timeframe

- Symbol: `XNGUSD.DWX`.
- Period: D1.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no storage level,
  consensus forecast, surprise feed, weather feed, futures curve, CSV, API, or
  discretionary input.

## Entry Rules

- Evaluate storage setup state only on a new D1 bar.
- A setup requires two completed D1 bars:
  - event bar: Wednesday, Thursday, or Friday to tolerate EIA holiday shifts.
  - setup bar: Thursday, Friday, or Monday after the event bar.
- Event-bar range must be at least `strategy_min_event_range_atr` times
  ATR(`strategy_atr_period`).
- Setup bar must be inside the event bar: setup high below event high and setup
  low above event low.
- Setup-bar range must be no larger than
  `strategy_inside_max_range_ratio` times event-bar range and no larger than
  `strategy_setup_max_atr` times ATR.
- The setup remains valid for `strategy_setup_valid_days`.
- Long breakout: live ask breaks above setup high plus
  `strategy_break_buffer_points` and setup close is above
  SMA(`strategy_trend_period`).
- Short breakout: live bid breaks below setup low minus
  `strategy_break_buffer_points` and setup close is below
  SMA(`strategy_trend_period`).
- No entry if an open `XNGUSD.DWX` position already exists for this EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close a long when prior D1 close falls below SMA(`strategy_trend_period`).
- Close a short when prior D1 close rises above SMA(`strategy_trend_period`).
- Close after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XNGUSD.DWX` on D1.
- Only magic slot 0 is valid.
- Skip setups when ATR, SMA, or event/setup OHLC are unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Symmetric long/short range breakout.
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
  default: 50
  sweep_range: [40, 50, 63]
- name: strategy_min_event_range_atr
  default: 0.90
  sweep_range: [0.75, 0.90, 1.10]
- name: strategy_inside_max_range_ratio
  default: 0.70
  sweep_range: [0.60, 0.70, 0.80]
- name: strategy_setup_max_atr
  default: 0.85
  sweep_range: [0.70, 0.85, 1.00]
- name: strategy_break_buffer_points
  default: 30
  sweep_range: [20, 30, 50]
- name: strategy_atr_sl_mult
  default: 3.00
  sweep_range: [2.5, 3.0, 3.5]
- name: strategy_max_hold_days
  default: 3
  sweep_range: [2, 3, 5]
- name: strategy_setup_valid_days
  default: 3
  sweep_range: [2, 3, 4]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]

## Author Claims

No performance claim is imported from EIA. The source is used only as official
structural lineage for the weekly natural-gas storage information event. Q02+
tests this deterministic post-storage compression breakout on Darwinex
`XNGUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 24
- expected_trade_frequency: approximately 5-12 trades/year.
- risk_class: high for natural-gas volatility and event-gap risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA weekly storage report and release
  schedule.
- [x] R2 mechanical: fixed event-day set, inside-day compression setup, live
  range breakout, ATR stop, SMA trend exit, and max-hold exit.
- [x] R3 testable: `XNGUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  one position per magic.
- [x] Non-duplicate: post-storage inside-day compression breakout is not
  storage aftershock, storage fade, pre-storage positioning, seasonal XNG,
  weather XNG, weekend gap, 4-week commodity reversal, or RSI commodity logic.

## Framework Alignment

- no_trade: D1 and `XNGUSD.DWX` guard, setup-day/event-day gate, parameter
  guard, spread cap.
- trade_entry: live break of a cached post-storage inside-day range with SMA
  confirmation.
- trade_management: SMA trend failure and max-hold exits.
- trade_close: hard ATR stop plus deterministic time exits and framework
  Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-06-29 | initial structural XNG storage inside-day breakout build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-29 | APPROVED | this card |
