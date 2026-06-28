---
ea_id: QM5_12740
slug: eia-wti-postdrive
type: strategy
source_id: EIA-WTI-POSTDRIVE-2026
source_citation: "U.S. Energy Information Administration. Gasoline price fluctuations. Energy Explained. URL https://www.eia.gov/energyexplained/gasoline/price-fluctuations.php"
sources:
  - "[[sources/EIA-WTI-POSTDRIVE-2026]]"
concepts:
  - "[[concepts/wti-post-driving-season]]"
  - "[[concepts/channel-breakdown]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, channel-breakdown, atr-hard-stop, time-stop, short-only, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12740_XTI_POSTDRIVE_D1
period: D1
expected_trade_frequency: "D1 WTI post-driving-season channel-breakdown sleeve; estimate 2-6 trades/year after channel, spread, and framework filters."
expected_trades_per_year_per_symbol: 4
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-28
expected_pf: 1.08
expected_dd_pct: 18.0
g0_approval_reasoning: "R1 PASS official EIA gasoline-seasonality URL; R2 PASS deterministic D1 post-driving-season channel breakdown with ATR/time/window exits; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
---

# EIA WTI Post-Driving-Season Breakdown

## Source

- Source: [[sources/EIA-WTI-POSTDRIVE-2026]]
- Primary citation: U.S. Energy Information Administration, "Gasoline price fluctuations", Energy Explained, URL https://www.eia.gov/energyexplained/gasoline/price-fluctuations.php.

## Concept

U.S. gasoline prices and demand have recurring seasonal pressure around the
spring and summer driving season. This card trades the structural unwind side:
after the main driving-season support window has ended, take short-only D1
WTI channel breakdowns during the early autumn shoulder period.

This is deliberately different from:

- `QM5_12576_eia-wti-season`: broad monthly WTI season map with SMA/ROC confirmation across long, short, and neutral months.
- `QM5_12737_eia-wti-drive`: long-only D1 channel breakouts during the April-August driving-season window.
- `QM5_12701_wti-oct-fade` and `QM5_12726_wti-nov-fade`: static month-of-year one-bar calendar shorts; this card requires a D1 downside channel break and uses a post-driving shoulder window.
- `QM5_12736_wti-roll-fade`: not ETF roll pressure.
- `QM5_12603`, `QM5_12616`, `QM5_12708`, and `QM5_12711`: not medium-term WTI time-series momentum.
- `QM5_12567_cum-rsi2-commodity`: no RSI or oscillator pullback logic.
- XTI/XNG, XAU/XAG, oil/gold, and oil/silver ratio baskets: this is a single-symbol WTI structural calendar-breakdown sleeve.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: approximately 2-6 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no EIA feed, product-spread feed, futures curve, refinery feed, inventory feed, CSV, API, or external input.

## Entry Rules

- Evaluate only on a new D1 bar.
- The prior closed D1 bar must fall inside the post-driving shoulder window: September 1 through October 15, inclusive.
- Short only.
- Skip if an open `XTIUSD.DWX` position already exists for this EA magic.
- Skip if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.
- Entry: SELL `XTIUSD.DWX` when the prior closed D1 close breaks below the lowest low of the previous `strategy_entry_channel` completed D1 bars, excluding the signal bar.
- Re-entry is allowed during the same post-driving window if the framework Friday-close guard flattened the position and the breakdown condition appears again.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Exit when the prior closed D1 bar is outside the post-driving shoulder window.
- Exit when prior closed D1 close breaks above the highest high of the previous `strategy_exit_channel` completed bars, excluding the signal bar.
- Exit when the position has been held for more than `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Host chart must be `XTIUSD.DWX` on D1.
- Magic slot must be 0.
- No long entries.
- Skip entries when ATR or channel OHLC is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Short-only.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## 8. Parameters To Test

- name: strategy_start_month
  default: 9
  sweep_range: [9]
- name: strategy_start_day
  default: 1
  sweep_range: [1, 10]
- name: strategy_end_month
  default: 10
  sweep_range: [10]
- name: strategy_end_day
  default: 15
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
  default: 15
  sweep_range: [10, 15, 25]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is imported from EIA. The source is used only for official
structural lineage around gasoline-season price fluctuations. The Q02+ pipeline
tests whether this deterministic post-driving-season WTI channel-breakdown rule
has value on Darwinex `XTIUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.08
- expected_dd_pct: 18
- expected_trade_frequency: approximately 2-6 trades/year on D1.
- risk_class: medium-high for crude-oil volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA gasoline-seasonality URL.
- [x] R2 mechanical: fixed date window, D1 channel breakdown entry, channel/date/time exits, and ATR stop.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one position per magic.
- [x] Non-duplicate: not existing WTI broad seasonality, driving-season long breakout, winter distillate, WPSR, hurricane, refinery, OPEC, expiry, ETF-roll, medium-term momentum, XTI/XNG, XAU/XAG, XNG, or RSI commodity logic.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, slot guard, parameter guard, spread cap.
- trade_entry: post-driving-season D1 short breakdown.
- trade_management: season-window end, channel reversal, and max-hold exits.
- trade_close: hard ATR stop plus deterministic time/window exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-28 | initial structural WTI post-driving-season breakdown card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-28 | APPROVED | this card |
