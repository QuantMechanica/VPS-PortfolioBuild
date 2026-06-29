---
ea_id: QM5_12769
slug: eia-xng-lng-brk
type: strategy
source_id: EIA-XNG-LNG-BRK-2026
source_citation: "U.S. Energy Information Administration. Natural gas explained: factors affecting natural gas prices; Today in Energy LNG export and Henry Hub commentary. URLs https://www.eia.gov/energyexplained/natural-gas/factors-affecting-natural-gas-prices.php, https://www.eia.gov/todayinenergy/detail.php?id=64004, and https://www.eia.gov/todayinenergy/detail.php?id=67004"
sources:
  - "[[sources/EIA-XNG-LNG-BRK-2026]]"
concepts:
  - "[[concepts/natural-gas-lng-exports]]"
  - "[[concepts/structural-demand-breakout]]"
  - "[[concepts/energy-range-compression]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
strategy_type_flags: [lng-export-demand, channel-breakout, compression-breakout, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Low-frequency LNG-demand-month D1 upside breakout; estimate 5-9 trades/year after month, compression, SMA, spread, and one-entry-per-month filters."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-29
g0_approval_reasoning: "R1 PASS official EIA natural-gas price-factor and LNG export sources; R2 PASS deterministic D1 channel breakout after compression in fixed LNG-demand months with ATR stop, SMA/range/time exits, and no external runtime feed; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/oscillator pullback/external data."
expected_pf: 1.10
expected_dd_pct: 25.0
---

# EIA XNG LNG Export-Demand Breakout

## Source

- Source: [[sources/EIA-XNG-LNG-BRK-2026]]
- Price-factor citation: U.S. Energy Information Administration, "Natural gas
  explained: factors affecting natural gas prices", URL
  https://www.eia.gov/energyexplained/natural-gas/factors-affecting-natural-gas-prices.php.
- Henry Hub/LNG citation: U.S. Energy Information Administration, Today in
  Energy, "U.S. natural gas prices fell in 2024; we forecast prices will
  increase in 2025 and 2026", URL
  https://www.eia.gov/todayinenergy/detail.php?id=64004.
- LNG record citation: U.S. Energy Information Administration, Today in Energy,
  "U.S. LNG exports reached a record in March 2026", URL
  https://www.eia.gov/todayinenergy/detail.php?id=67004.

## Concept

EIA treats exports as a price-relevant natural-gas supply/demand factor. EIA
also links higher LNG exports to Henry Hub price pressure and reports record
U.S. LNG exports in March 2026. This card uses that official structural demand
theme, but does not import any EIA value, export flow, facility utilization,
weather, shipping, futures curve, CSV, API, or discretionary input at runtime.

The EA trades only when `XNGUSD.DWX` itself confirms the theme: a D1 close must
break above a prior channel after pre-breakout range compression, with the close
above a rising SMA. The rule is long-only and capped at one entry per
LNG-demand month bucket.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator, or short-term pullback.
- `QM5_12575_eia-xng-season`: not a broad two-sided monthly season map.
- `QM5_12584_eia-xng-storage`, `QM5_12744_eia-xng-storfade`, and
  `QM5_12761_eia-xng-stor-idbrk`: no storage-report event, aftershock, fade,
  or post-storage inside-day logic.
- `QM5_12586_eia-xng-winter-brk` and `QM5_12588_eia-xng-sum-sqz`: this is not
  a single winter-withdrawal or summer-power sleeve; it uses LNG-demand months,
  one-entry-per-month throttling, rising-SMA confirmation, and pre-breakout
  compression.
- `QM5_12601_eia-xng-hurr-brk`, `QM5_12602_eia-xng-frzfade`, and
  `QM5_12725_eia-xng-prestor`: no hurricane, freeze-off, or pre-storage event
  premise.
- `QM5_12706_xngusd-seasonal-dual-peak`, `QM5_12702`, `QM5_12703`,
  `QM5_12704`, and `QM5_12705`: not a monthly seasonal allocation or
  shoulder/storage-season short.

## Markets And Timeframe

- Symbol: `XNGUSD.DWX`.
- Period: D1.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only.

## Entry Rules

- Evaluate entries only on a new D1 bar.
- Only allow completed signal bars in LNG-demand months: January, February,
  July, August, September, November, and December.
- Only one new position may be opened per calendar month.
- Signal close must be above SMA(`strategy_trend_period`).
- SMA(`strategy_trend_period`) must be above its value
  `strategy_sma_slope_shift` D1 bars earlier.
- The signal close must exceed the prior
  `strategy_breakout_lookback`-bar high by at least
  `strategy_break_buffer_points`.
- The average high-low range of the prior
  `strategy_compression_lookback` bars must be no larger than
  ATR(`strategy_atr_period`) * `strategy_compression_atr_mult`.
- The signal-bar high-low range must be no larger than
  ATR(`strategy_atr_period`) * `strategy_max_signal_range_atr`.
- No entry if an open `XNGUSD.DWX` position already exists for this EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close when prior D1 close falls below SMA(`strategy_trend_period`).
- Close when prior D1 close falls below the prior `strategy_exit_channel`-bar
  low.
- Close after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XNGUSD.DWX` on D1.
- Only magic slot 0 is valid.
- Skip entries when ATR, SMA, channel, compression, or OHLC data are
  unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Long-only breakout.
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
  default: 10
  sweep_range: [5, 10, 15]
- name: strategy_breakout_lookback
  default: 55
  sweep_range: [42, 55, 70]
- name: strategy_exit_channel
  default: 12
  sweep_range: [8, 12, 18]
- name: strategy_compression_lookback
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_compression_atr_mult
  default: 0.90
  sweep_range: [0.75, 0.90, 1.05]
- name: strategy_break_buffer_points
  default: 20
  sweep_range: [10, 20, 40]
- name: strategy_max_signal_range_atr
  default: 2.40
  sweep_range: [2.0, 2.4, 3.0]
- name: strategy_atr_sl_mult
  default: 3.25
  sweep_range: [2.75, 3.25, 3.75]
- name: strategy_max_hold_days
  default: 18
  sweep_range: [12, 18, 28]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]

## Author Claims

No performance claim is imported from EIA. The sources are used only as
official structural lineage for LNG export demand as a natural-gas price
factor. Q02+ tests this deterministic D1 compression breakout on Darwinex
`XNGUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 25
- expected_trade_frequency: approximately 5-9 trades/year.
- risk_class: high for natural-gas volatility and gap risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA natural-gas price-factor and LNG export
  sources.
- [x] R2 mechanical: fixed LNG-demand months, close-confirmed channel
  breakout, ATR compression, rising-SMA confirmation, ATR stop, and
  trend/range/time exits.
- [x] R3 testable: `XNGUSD.DWX` exists in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  one position per magic.
- [x] Non-duplicate: LNG-demand compression breakout is not RSI pullback,
  storage event logic, broad monthly seasonality, freeze/hurricane/weather
  logic, weekend gap, or 4-week commodity reversal.

## Framework Alignment

- no_trade: D1 and `XNGUSD.DWX` guard, LNG-demand-month gate, parameter guard,
  spread cap, and one-entry-per-month throttle.
- trade_entry: close-confirmed D1 upside breakout after compression with rising
  SMA confirmation.
- trade_management: SMA trend failure, exit-channel failure, and max-hold
  exits.
- trade_close: hard ATR stop plus deterministic time exits and framework
  Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-29 | initial structural XNG LNG export-demand breakout build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-29 | APPROVED | this card |
