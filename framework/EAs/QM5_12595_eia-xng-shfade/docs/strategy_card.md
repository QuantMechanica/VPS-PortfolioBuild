---
ea_id: QM5_12595
slug: eia-xng-shfade
type: strategy
source_id: EIA-XNG-SHOULDER-2026
source_citation: "U.S. Energy Information Administration. Natural gas consumption, production respond to seasonal changes. Today in Energy, 2015-09-24. URL https://www.eia.gov/todayinenergy/detail.php?id=22892"
sources:
  - "[[sources/EIA-XNG-SHOULDER-2026]]"
concepts:
  - "[[concepts/natural-gas-seasonality]]"
  - "[[concepts/shoulder-season-demand-lull]]"
  - "[[concepts/failed-rally-mean-reversion]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
target_symbols: [XNGUSD.DWX]
logical_symbol: QM5_12595_XNG_SHFADE_D1
period: D1
expected_trade_frequency: "Shoulder-season D1 failed-rally fade during April-May and September-October; estimate 4-8 trades/year."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-27
g0_approval_reasoning: "R1 PASS official EIA natural-gas seasonality source; R2 PASS deterministic shoulder-month/SMA/ATR/rejection-candle rules; R3 PASS XNGUSD.DWX available in the DWX matrix; R4 PASS no ML/grid/martingale and one magic position."
expected_pf: 1.15
expected_dd_pct: 20.0
---

# EIA XNG Shoulder-Season Failed-Rally Fade

## Source

- Source: [[sources/EIA-XNG-SHOULDER-2026]]
- Citation: U.S. Energy Information Administration, "Natural gas consumption, production respond to seasonal changes", Today in Energy, 2015-09-24, URL https://www.eia.gov/todayinenergy/detail.php?id=22892.
- Supplemental citation: U.S. Energy Information Administration, Weekly Natural Gas Storage Report, URL https://www.eia.gov/naturalgas/storage/.

## Concept

Natural gas demand is structurally seasonal: winter heating demand and summer electric-sector demand create demand peaks, while spring and fall shoulder periods normally have lower heating and cooling demand. This card converts that official EIA lineage into a Darwinex-native XNGUSD.DWX sleeve: during April-May and September-October, fade upside failed rallies that are stretched above a slow D1 mean and reject from a recent high.

This is intentionally not a duplicate of:

- `QM5_12567_cum-rsi2-commodity`: short-horizon cumulative RSI pullback logic.
- `QM5_12575_eia-xng-season`: broad monthly two-sided season map.
- `QM5_12582_chan-ng-spring`: fixed spring long-only calendar window.
- `QM5_12584_eia-xng-storage`: weekly storage-report aftershock continuation.
- `QM5_12586_eia-xng-winter-brk`: winter withdrawal-season breakout.
- `QM5_12587_eia-xng-inj-brk`: April-October downside Donchian breakdown.
- `QM5_12588_eia-xng-sum-sqz`: summer upside compression breakout.

## Markets And Timeframe

- Symbol: XNGUSD.DWX.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC only; no EIA, storage, weather, power-load, or futures-curve feed.

## Entry Rules

- Evaluate only on a new D1 bar.
- Trade only when the prior closed D1 bar is in April, May, September, or October.
- No entry if an open XNGUSD.DWX position already exists for this EA magic.
- No entry if the current spread exceeds `strategy_max_spread_points`.
- Compute ATR(20) and SMA(63) on the prior closed D1 bar.
- Require the prior close to be at least `strategy_min_stretch_atr * ATR(20)` above SMA(63).
- Require the prior high to equal or exceed the highest high of the previous `strategy_reject_lookback` completed D1 bars, excluding the signal bar.
- Require a bearish rejection candle: close below open, close below prior close, and upper wick at least `strategy_min_upper_wick_ratio` of the signal-bar range.
- Entry: SELL XNGUSD.DWX at market with a hard ATR stop.

## Exit Rules

- Stop loss: fixed hard SL at ATR(20) * `strategy_atr_sl_mult` from entry.
- Exit when the prior D1 close returns to or below SMA(63).
- Exit if the prior D1 close breaks above the highest high of the previous `strategy_exit_channel` completed D1 bars, excluding the signal bar.
- Exit when the calendar moves outside April-May or September-October.
- Exit after `strategy_max_hold_days`.
- Friday close remains enabled by the V5 framework.

## Filters

- Host chart must be XNGUSD.DWX on D1.
- Shoulder window only: April-May and September-October.
- Skip entries when current spread exceeds 2500 points.
- Skip entries when SMA, ATR, channel, or candle history is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

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
- name: strategy_min_stretch_atr
  default: 1.25
  sweep_range: [1.0, 1.25, 1.75]
- name: strategy_min_upper_wick_ratio
  default: 0.35
  sweep_range: [0.25, 0.35, 0.50]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 7
  sweep_range: [5, 7, 10]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]

## Author Claims

No performance claim is imported from EIA. The source is used only for official structural lineage of lower shoulder-season natural-gas demand.

## Initial Risk Profile

- expected_pf: 1.15
- expected_dd_pct: 20
- expected_trade_frequency: approximately 4-8 trades/year.
- risk_class: high for natural-gas volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 official source: EIA natural-gas seasonality and storage material.
- [x] R2 mechanical: fixed date window, ATR/SMA stretch, rejection-candle filter, ATR stop, deterministic exits.
- [x] R3 testable: XNGUSD.DWX exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one position per magic.
- [x] No duplicate of QM5_12567: this is shoulder-season failed-rally mean reversion, not RSI pullback.
- [x] No duplicate of existing XNG EIA sleeves: it is not broad season mapping, storage aftershock, winter breakout, injection breakdown, or summer squeeze.

## Framework Alignment

- no_trade: D1/XNGUSD.DWX guard, shoulder-month entry gate, spread cap, parameter sanity.
- trade_entry: short-only shoulder-season failed-rally rejection after ATR stretch above SMA.
- trade_management: close on SMA mean reversion, channel invalidation, season exit, or max-hold timeout.
- trade_close: framework Friday close and strategy exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-27 | initial structural XNG shoulder-season failed-rally fade build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-27 | APPROVED | this card |
