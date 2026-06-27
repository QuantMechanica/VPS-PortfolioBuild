---
ea_id: QM5_12602
slug: eia-xng-frzfade
type: strategy
source_id: EIA-XNG-FREEZE-2026
source_citation: "U.S. Energy Information Administration. U.S. natural gas prices spiked in February 2021, then generally increased through October. Today in Energy, 2022-01-06. URL https://www.eia.gov/todayinenergy/detail.php?id=50778; February 2021 weather triggers largest monthly decline in U.S. natural gas production. Today in Energy, 2021-05-10. URL https://www.eia.gov/todayinenergy/detail.php?id=47896"
sources:
  - "[[sources/EIA-XNG-FREEZE-2026]]"
concepts:
  - "[[concepts/natural-gas-winter-freeze-off]]"
  - "[[concepts/weather-shock-mean-reversion]]"
  - "[[concepts/rejection-candle]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
  - "[[indicators/donchian-channel]]"
strategy_type_flags: [calendar-seasonality, weather-shock-proxy, failed-rally-mean-reversion, atr-hard-stop, time-stop, short-only]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12602_XNG_FRZFADE_D1
period: D1
expected_trade_frequency: "January-February D1 natural-gas winter freeze-off spike fade; estimate 2-6 trades/year after stretch, rejection, and spread filters."
expected_trades_per_year_per_symbol: 4
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-27
expected_pf: 1.1
expected_dd_pct: 24.0
g0_approval_reasoning: "R1 PASS official EIA winter natural-gas price shock source; R2 PASS deterministic Jan-Feb D1 ATR/SMA/rejection fade rules; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
---

# EIA XNG Winter Freeze-Off Spike Fade

## Source

- Source: [[sources/EIA-XNG-FREEZE-2026]]
- Primary citation: U.S. Energy Information Administration, "U.S. natural gas prices spiked in February 2021, then generally increased through October", Today in Energy, 2022-01-06, URL https://www.eia.gov/todayinenergy/detail.php?id=50778.
- Supplemental citation: U.S. Energy Information Administration, "February 2021 weather triggers largest monthly decline in U.S. natural gas production", Today in Energy, 2021-05-10, URL https://www.eia.gov/todayinenergy/detail.php?id=47896.
- Supplemental citation: U.S. Energy Information Administration, "Cold weather brings near record-high natural gas spot prices", Today in Energy, 2021-03-05, URL https://www.eia.gov/todayinenergy/detail.php?id=47016.

## Concept

EIA documents that severe winter weather can create abrupt natural-gas price
spikes through heating demand, production interruptions, and market constraints.
The same official source packet documents post-shock normalization once the
acute weather stress passes. This card mechanizes that structural setup as a
Darwinex-native XNGUSD.DWX D1 sleeve: during January-February only, fade an
extreme upside spike only after the signal bar itself prints bearish rejection
and remains stretched above a slow D1 mean.

Runtime data stays Darwinex MT5 OHLC only. The EA does not read weather,
production, storage, pipeline-flow, cash-market, futures-curve, EIA, CSV, API,
analyst forecast, or ML data at runtime.

This is intentionally not a duplicate of:

- `QM5_12567_cum-rsi2-commodity`: short-horizon cumulative RSI pullback logic.
- `QM5_12575_eia-xng-season`: broad monthly two-sided natural-gas season map.
- `QM5_12582_chan-ng-spring`: fixed spring long-only calendar window.
- `QM5_12584_eia-xng-storage`: weekly storage-report aftershock continuation.
- `QM5_12586_eia-xng-winter-brk`: winter withdrawal-season breakout.
- `QM5_12587_eia-xng-inj-brk`: April-October downside Donchian breakdown.
- `QM5_12588_eia-xng-sum-sqz`: summer power-demand compression breakout.
- `QM5_12595_eia-xng-shfade`: shoulder-season failed-rally fade.
- `QM5_12601_eia-xng-hurr-brk`: hurricane-season upside breakout.

## Markets And Timeframe

- Symbol: XNGUSD.DWX.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC and broker calendar only.

## Entry Rules

- Evaluate only on a new D1 bar.
- Trade only when the prior closed D1 bar is in January or February.
- Short only.
- No entry if an open XNGUSD.DWX position already exists for this EA magic.
- No entry if the current spread exceeds `strategy_max_spread_points`.
- Compute prior closed D1 open/high/low/close, prior close, SMA(`strategy_trend_period`), ATR(`strategy_atr_period`), and the highest high of the previous `strategy_reject_lookback` completed D1 bars excluding the signal bar.
- Require the signal-bar high to equal or exceed that previous highest high.
- Require signal-bar range to be at least `strategy_min_range_atr * ATR`.
- Require signal-bar close to be at least `strategy_min_stretch_atr * ATR` above SMA.
- Require bearish rejection: close below open, close below the previous D1 close, and upper wick at least `strategy_min_upper_wick_ratio` of the signal-bar range.
- Entry: SELL XNGUSD.DWX at market with a hard ATR stop.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Exit when the broker date leaves January-February.
- Exit when prior closed D1 close returns to or below SMA(`strategy_trend_period`).
- Exit when prior closed D1 close breaks above the highest high of the previous `strategy_exit_channel` completed D1 bars excluding the signal bar.
- Exit when the position has been held for more than `strategy_max_hold_days`.
- Friday close remains enabled by the V5 framework.

## Filters

- Host chart must be XNGUSD.DWX on D1.
- No long entries in v1.
- Skip entries when SMA, ATR, channel, range, or candle values are unavailable.
- No pyramiding, grid, martingale, partial close, or trailing stop.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Parameters To Test

- name: strategy_reject_lookback
  default: 20
  sweep_range: [15, 20, 30]
- name: strategy_exit_channel
  default: 10
  sweep_range: [7, 10, 15]
- name: strategy_trend_period
  default: 63
  sweep_range: [42, 63, 84]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_range_atr
  default: 1.10
  sweep_range: [0.90, 1.10, 1.50]
- name: strategy_min_stretch_atr
  default: 1.75
  sweep_range: [1.25, 1.75, 2.25]
- name: strategy_min_upper_wick_ratio
  default: 0.30
  sweep_range: [0.25, 0.30, 0.40]
- name: strategy_atr_sl_mult
  default: 3.25
  sweep_range: [2.5, 3.25, 4.0]
- name: strategy_max_hold_days
  default: 8
  sweep_range: [5, 8, 12]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]

## Author Claims

No performance claim is imported from EIA. The sources are used only for
official structural lineage: severe winter weather can create natural-gas price
spikes and post-shock normalization risk. The EA waits for XNGUSD.DWX to print
a mechanical D1 spike/rejection pattern before entering.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 24
- expected_trade_frequency: approximately 2-6 trades/year.
- risk_class: high for natural-gas volatility and weather-gap risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 official source: EIA winter natural-gas price shock material.
- [x] R2 mechanical: fixed January-February window, ATR/SMA stretch, rejection-candle filter, ATR stop, deterministic exits.
- [x] R3 testable: XNGUSD.DWX exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one position per magic.
- [x] Non-duplicate: winter freeze-off spike fade is not broad XNG seasonality, storage aftershock, winter breakout, injection breakdown, summer squeeze, shoulder fade, hurricane breakout, or RSI commodity pullback.

## Framework Alignment

- no_trade: D1/XNGUSD.DWX guard, January-February entry gate, spread cap, parameter sanity.
- trade_entry: short-only winter spike/rejection fade after ATR stretch above SMA.
- trade_management: close on winter-window end, mean reversion to SMA, channel invalidation, or max-hold timeout.
- trade_close: hard ATR stop plus framework Friday close and strategy exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-27 | initial structural XNG winter freeze-off spike fade card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-27 | APPROVED | this card |
