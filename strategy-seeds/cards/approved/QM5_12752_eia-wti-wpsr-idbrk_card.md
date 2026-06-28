---
ea_id: QM5_12752
slug: eia-wti-wpsr-idbrk
type: strategy
source_id: EIA-WTI-WPSR-IDBRK-2026
source_citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report and release schedule. URLs https://www.eia.gov/petroleum/supply/weekly/ and https://www.eia.gov/petroleum/supply/weekly/schedule.php"
sources:
  - "[[sources/EIA-WTI-WPSR-IDBRK-2026]]"
concepts:
  - "[[concepts/crude-oil-inventory-event]]"
  - "[[concepts/post-event-consolidation]]"
  - "[[concepts/inside-bar-breakout]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
strategy_type_flags: [inventory-event, inside-bar-breakout, trend-filter-ma, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12752_XTI_WPSR_IDBRK_D1
period: D1
expected_trade_frequency: "Weekly WTI post-WPSR inside-bar breakout; estimate 6-14 trades/year after event-range, inside-bar, spread, and trend filters."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-28
g0_approval_reasoning: "R1 PASS official EIA WPSR/release schedule source packet; R2 PASS deterministic D1 post-event inside-bar breakout with ATR stop and time/SMA exits; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
expected_pf: 1.10
expected_dd_pct: 18.0
---

# EIA WTI Post-WPSR Inside-Bar Breakout

## Source

- Source: [[sources/EIA-WTI-WPSR-IDBRK-2026]]
- Primary citation: U.S. Energy Information Administration, "Weekly Petroleum
  Status Report", URL https://www.eia.gov/petroleum/supply/weekly/.
- Release schedule citation: U.S. Energy Information Administration, "Weekly
  Petroleum Status Report Schedule", URL
  https://www.eia.gov/petroleum/supply/weekly/schedule.php.
- Structural supplement: U.S. Energy Information Administration, "Oil and
  petroleum products explained", URL
  https://www.eia.gov/energyexplained/oil-and-petroleum-products/.

## Concept

The EIA Weekly Petroleum Status Report is a recurring official weekly
information event for crude oil. This card does not forecast the report and
does not ingest inventory data. It waits for the market to absorb the WPSR
event bar, then trades only if the next D1 bar consolidates inside that event
range and the following live D1 bar breaks the inside range.

This is deliberately different from:

- `QM5_12579_eia-wti-aftershock`: follows the closed WPSR event-day direction
  immediately after a large reaction.
- `QM5_12590_eia-wti-wpsr-fade`: fades a stretched closed WPSR event-day bar.
- `QM5_12592_eia-wti-prewpsr`: enters before the report bar develops.
- `QM5_12743_wti-postroll-fade` and `QM5_12600_cme-wti-exp-brk`: WTI roll
  mechanics, not the WPSR information-event cycle.
- `QM5_12567_cum-rsi2-commodity`: short-horizon RSI-style commodity pullback.

## hypothesis

After a large scheduled WPSR information bar, a following inside D1 bar can
mark temporary absorption rather than immediate continuation or exhaustion. A
break of that inside range during the next D1 bar should capture short-term WTI
range expansion while remaining structurally different from event-day
aftershock and event-day fade logic.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: about 6-14 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no EIA feed,
  inventory surprise feed, analyst forecast, CSV, futures curve, API, or
  discretionary input.

## Entry Rules

- Evaluate setup formation only on a new D1 bar.
- Treat the event bar as eligible only if it is Wednesday or Thursday.
  Wednesday is the standard WPSR day; Thursday tolerates holiday-shifted
  releases without importing an external schedule.
- The event bar range must be at least `strategy_min_event_range_atr` times
  ATR(`strategy_atr_period`).
- The setup bar immediately after the event bar must be an inside bar:
  setup high below event high and setup low above event low.
- The setup bar range must be no more than
  `strategy_inside_max_range_ratio` of the event range and no more than
  `strategy_setup_max_atr` times ATR(`strategy_atr_period`).
- During the next D1 bar, enter long if live ask breaks above setup high plus
  `strategy_break_buffer_points` and the setup close is above
  SMA(`strategy_trend_period`).
- During the next D1 bar, enter short if live bid breaks below setup low minus
  `strategy_break_buffer_points` and the setup close is below
  SMA(`strategy_trend_period`).
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## rules

- Event bar: Wednesday or Thursday D1 bar, range at least
  `strategy_min_event_range_atr * ATR`.
- Setup bar: immediately following completed D1 bar, fully inside event high
  and low, with compressed range.
- Long trigger: live ask breaks above setup high plus buffer while setup close
  is above the trend SMA.
- Short trigger: live bid breaks below setup low minus buffer while setup close
  is below the trend SMA.
- Exit: ATR stop, SMA failure, max hold, or framework Friday close.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close a long if the prior completed D1 close falls below
  SMA(`strategy_trend_period`).
- Close a short if the prior completed D1 close rises above
  SMA(`strategy_trend_period`).
- Close after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX` D1
setfile. The strategy is one-position-only, with no grid, martingale,
pyramiding, partial close, adaptive sizing, external data, live manifest,
`T_Live` file, AutoTrading action, or portfolio-gate edit.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Only magic slot 0 is valid.
- Skip setup formation when ATR, SMA, or the two D1 bars are unavailable.
- The cached setup expires after `strategy_setup_valid_days` calendar days.
- Framework news, kill-switch, magic, spread, and Friday-close guards remain active.

## Trade Management Rules

- Symmetric long/short.
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
  sweep_range: [34, 50, 84]
- name: strategy_min_event_range_atr
  default: 1.00
  sweep_range: [0.80, 1.00, 1.25]
- name: strategy_inside_max_range_ratio
  default: 0.75
  sweep_range: [0.60, 0.75, 0.90]
- name: strategy_setup_max_atr
  default: 0.90
  sweep_range: [0.70, 0.90, 1.10]
- name: strategy_break_buffer_points
  default: 20
  sweep_range: [10, 20, 40]
- name: strategy_atr_sl_mult
  default: 2.75
  sweep_range: [2.0, 2.75, 3.5]
- name: strategy_max_hold_days
  default: 3
  sweep_range: [2, 3, 5]
- name: strategy_setup_valid_days
  default: 3
  sweep_range: [1, 2, 3]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is taken from EIA. EIA is used only as official structural
lineage for the weekly petroleum information-event schedule. The edge claim is
tested by the QM Q02+ pipeline on Darwinex `XTIUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 18
- expected_trade_frequency: approximately 6-14 trades/year on D1.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 official source: EIA WPSR and release schedule URLs.
- [x] R2 mechanical: WPSR weekday gate, D1 inside-bar setup, live range
  breakout, ATR stop, SMA failure exit, and max-hold exit.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one
  position per magic.
- [x] Non-duplicate: post-event inside-bar breakout is not pre-WPSR positioning,
  immediate event-day aftershock, event-day exhaustion fade, WTI roll logic,
  WTI month/weekday seasonality, WTI/XNG relative value, or RSI commodity
  pullback.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, slot guard, parameter guard, spread cap.
- trade_entry: cached post-WPSR inside-bar setup and live range breakout.
- trade_management: SMA failure and fixed max-hold exits.
- trade_close: hard ATR stop plus deterministic time/trend exits and framework
  Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-28 | initial structural WTI WPSR inside-bar breakout build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-28 | APPROVED | this card |
