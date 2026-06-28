---
ea_id: QM5_12737
slug: eia-wti-drive
type: strategy
source_id: EIA-WTI-DRIVE-2026
source_citation: "U.S. Energy Information Administration. Gasoline price fluctuations. Energy Explained. URL https://www.eia.gov/energyexplained/gasoline/price-fluctuations.php"
sources:
  - "[[sources/EIA-WTI-DRIVE-2026]]"
concepts:
  - "[[concepts/wti-driving-season]]"
  - "[[concepts/channel-breakout]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, channel-breakout, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12737_XTI_DRIVE_D1
period: D1
expected_trade_frequency: "D1 WTI gasoline driving-season channel-breakout sleeve; estimate 4-9 trades/year after channel, spread, and framework filters."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-28
expected_pf: 1.1
expected_dd_pct: 18.0
g0_approval_reasoning: "R1 PASS official EIA gasoline-seasonality source; R2 PASS deterministic D1 driving-season channel breakout with ATR/time/window exits; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
---

# EIA WTI Driving-Season Breakout

## Source

- Source: [[sources/EIA-WTI-DRIVE-2026]]
- Primary citation: U.S. Energy Information Administration, "Gasoline price fluctuations", Energy Explained, URL https://www.eia.gov/energyexplained/gasoline/price-fluctuations.php.

## Concept

U.S. gasoline prices and demand have recurring seasonal pressure around the spring and summer driving season. This card mechanizes that official EIA structural lineage as a low-frequency WTI continuation sleeve on `XTIUSD.DWX`: trade only long D1 channel breakouts during the gasoline demand window, then flatten on channel failure, season end, or max-hold timeout.

This is deliberately different from:

- `QM5_12576_eia-wti-season`: broad monthly WTI season map with SMA/ROC confirmation across May-August plus winter months.
- `QM5_12583_eia-distillate-winter`: winter distillate/heating-demand breakout, not gasoline driving season.
- `QM5_12579`, `QM5_12590`, and `QM5_12592`: not WPSR continuation, fade, or pre-event positioning.
- `QM5_12591`, `QM5_12593`, `QM5_12598`, and `QM5_12600`: not hurricane, refinery-turnaround, OPEC, or expiry-window logic.
- `QM5_12603`, `QM5_12616`, `QM5_12708`, and `QM5_12711`: not medium-term WTI time-series momentum.
- `QM5_12736_wti-roll-fade`: not early-month ETF roll pressure.
- `QM5_12567_cum-rsi2-commodity`: no RSI or oscillator pullback logic.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: approximately 4-9 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no EIA feed, product-spread feed, futures curve, refinery feed, inventory feed, CSV, API, or external input.

## Entry Rules

- Evaluate only on a new D1 bar.
- The prior closed D1 bar must fall inside the gasoline driving-season window: April 15 through August 31, inclusive.
- Long only.
- Skip if an open `XTIUSD.DWX` position already exists for this EA magic.
- Skip if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.
- Entry: BUY `XTIUSD.DWX` when the prior closed D1 close breaks above the highest high of the previous `strategy_entry_channel` completed D1 bars, excluding the signal bar.
- The V5 Friday-close guard remains enabled; re-entry is allowed during the same driving-season window if Friday close flattened the position and the breakout condition is again true.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Exit when the prior closed D1 bar is outside the driving-season window.
- Exit when prior closed D1 close breaks below the lowest low of the previous `strategy_exit_channel` completed bars, excluding the signal bar.
- Exit when the position has been held for more than `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Host chart must be `XTIUSD.DWX` on D1.
- Magic slot must be 0.
- No short entries.
- Skip entries when ATR or channel OHLC is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Long-only.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_start_month
  default: 4
  sweep_range: [4]
- name: strategy_start_day
  default: 15
  sweep_range: [1, 15]
- name: strategy_end_month
  default: 8
  sweep_range: [8]
- name: strategy_end_day
  default: 31
  sweep_range: [15, 31]
- name: strategy_entry_channel
  default: 30
  sweep_range: [20, 30, 40, 55]
- name: strategy_exit_channel
  default: 15
  sweep_range: [10, 15, 20]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 20
  sweep_range: [10, 20, 30]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is imported from EIA. The source is used only for official structural lineage around gasoline driving-season price fluctuations. The Q02+ pipeline tests whether this deterministic WTI channel-continuation rule has value on Darwinex `XTIUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 18
- expected_trade_frequency: approximately 4-9 trades/year on D1.
- risk_class: medium-high for crude-oil volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA gasoline-seasonality URL.
- [x] R2 mechanical: fixed date window, D1 channel breakout entry, channel/date/time exits, and ATR stop.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one position per magic.
- [x] Non-duplicate: not existing WTI broad seasonality, winter distillate, WPSR, hurricane, refinery, OPEC, expiry, ETF-roll, medium-term momentum, XTI/XNG, XAU/XAG, XNG, or RSI commodity logic.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, slot guard, parameter guard, spread cap.
- trade_entry: driving-season D1 long breakout.
- trade_management: season-window end, channel failure, and max-hold exits.
- trade_close: hard ATR stop plus deterministic time/window exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-06-28 | initial structural WTI driving-season breakout card | G0 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-28 | PENDING | this card |
