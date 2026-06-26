---
ea_id: QM5_12588
slug: eia-xng-sum-sqz
type: strategy
source_id: EIA-XNG-SUMMER-POWER-2015
source_citation: "U.S. Energy Information Administration. Natural gas consumption, production respond to seasonal changes. Today in Energy, 2015-09-24. URL https://www.eia.gov/todayinenergy/detail.php?id=22892"
sources:
  - "[[sources/EIA-XNG-SUMMER-POWER-2015]]"
concepts:
  - "[[concepts/natural-gas-seasonality]]"
  - "[[concepts/volatility-compression-breakout]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
target_symbols: [XNGUSD.DWX]
period: D1
expected_trade_frequency: "Summer-only D1 compression breakout during June-August; estimate 2-6 trades/year."
expected_trades_per_year_per_symbol: 4
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-26
g0_approval_reasoning: "R1 PASS official EIA source; R2 PASS deterministic summer date-window/compression/channel-breakout/ATR rules; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale and one magic position."
expected_pf: 1.2
expected_dd_pct: 18.0
---

# EIA XNG Summer Power-Burn Squeeze

## Source

- Source: [[sources/EIA-XNG-SUMMER-POWER-2015]]
- Citation: U.S. Energy Information Administration, "Natural gas consumption, production respond to seasonal changes", Today in Energy, 2015-09-24, URL https://www.eia.gov/todayinenergy/detail.php?id=22892.

## Concept

Natural gas has a recurring summer demand component because electric-sector gas burn rises during high cooling-load months. This card isolates that summer component into a low-frequency XNGUSD.DWX sleeve: wait for D1 volatility compression in June-August, then buy an upside channel breakout with trend confirmation.

This is intentionally not a duplicate of `QM5_12575_eia-xng-season` because it is not a monthly two-sided season map. It is also distinct from `QM5_12584_eia-xng-storage` because it does not trade weekly storage-report aftershocks, from `QM5_12586_eia-xng-winter-brk` because it ignores winter withdrawal months, and from `QM5_12587_eia-xng-inj-brk` because it is long-only summer squeeze logic rather than short-only injection-season breakdown logic.

## Markets And Timeframe

- Symbol: XNGUSD.DWX.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC only; no EIA, weather, power-load, storage, or futures-curve feed.

## Entry Rules

- Evaluate only on a new D1 bar.
- Trade only when the prior closed D1 bar is in June, July, or August.
- Require the prior D1 close to be above SMA(63).
- Compute ATR(20) on the prior closed D1 bar.
- Compute the average high-low range over the previous 10 completed D1 bars.
- Compression gate: average range must be less than or equal to `ATR(20) * strategy_compression_atr_mult`.
- Entry channel: prior D1 close must break above the highest high of the previous 20 completed D1 bars, excluding the signal bar.
- No entry if an open XNGUSD.DWX position already exists for this EA magic.
- No entry if the current spread exceeds `strategy_max_spread_points`.
- Entry: BUY XNGUSD.DWX at market with a hard ATR stop.

## Exit Rules

- Stop loss: fixed hard SL at ATR(20) * 3.0 from entry.
- Exit if the prior D1 close breaks below the lowest low of the previous 10 completed D1 bars.
- Exit if the prior D1 close falls below SMA(63).
- Exit when the calendar moves outside June-August.
- Exit after `strategy_max_hold_days`.
- Friday close remains enabled by the V5 framework.

## Filters

- Host chart must be XNGUSD.DWX on D1.
- Summer window only: June through August.
- Skip entries when current spread exceeds 2500 points.
- Skip entries when channel, SMA, ATR, or compression history is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_entry_channel
  default: 20
  sweep_range: [15, 20, 30]
- name: strategy_exit_channel
  default: 10
  sweep_range: [7, 10, 15]
- name: strategy_trend_period
  default: 63
  sweep_range: [42, 63, 84]
- name: strategy_compression_lookback
  default: 10
  sweep_range: [7, 10, 15]
- name: strategy_compression_atr_mult
  default: 0.85
  sweep_range: [0.70, 0.85, 1.00]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 10
  sweep_range: [7, 10, 15]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]

## Author Claims

No performance claim is imported from EIA. The source is used only for official structural lineage of summer natural-gas electric-sector demand.

## Initial Risk Profile

- expected_pf: 1.20
- expected_dd_pct: 18
- expected_trade_frequency: approximately 2-6 trades/year.
- risk_class: medium.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 official source: one EIA URL and one source ID.
- [x] R2 mechanical: fixed date window, channel breakout, compression gate, trend confirmation, ATR stop, deterministic exits.
- [x] R3 testable: XNGUSD.DWX is in the Darwinex custom-symbol universe used by existing XNG builds.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one position per magic.
- [x] No duplicate of QM5_12567: this is not RSI pullback logic.

## Framework Alignment

- no_trade: D1/XNGUSD.DWX guard, summer window, spread cap, parameter sanity.
- trade_entry: summer compression plus upside Donchian breakout and SMA confirmation.
- trade_management: no trailing or partial management.
- trade_close: season-window end, channel failure, SMA failure, or max-hold timeout.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-26 | initial structural XNG summer power-burn squeeze build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-26 | APPROVED | this card |
