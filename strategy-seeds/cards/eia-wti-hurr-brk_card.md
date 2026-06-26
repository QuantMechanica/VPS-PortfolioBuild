---
ea_id: QM5_12591
slug: eia-wti-hurr-brk
type: strategy
source_id: EIA-WTI-HURRICANE-2025
source_citation: "U.S. Energy Information Administration. Refining industry risks from 2025 hurricane season. Today in Energy. URL https://www.eia.gov/todayinenergy/detail.php?id=65304"
sources:
  - "[[sources/EIA-WTI-HURRICANE-2025]]"
concepts:
  - "[[concepts/wti-hurricane-season]]"
  - "[[concepts/energy-supply-risk-breakout]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
target_symbols: [XTIUSD.DWX]
logical_symbol: QM5_12591_XTI_HURR_BRK_D1
period: D1
expected_trade_frequency: "D1 WTI hurricane-season upside breakout; estimate 5-10 trades/year during June-November storm-risk windows."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-27
g0_approval_reasoning: "R1 PASS official EIA hurricane-season petroleum-risk source; R2 PASS deterministic D1 calendar breakout rules; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale and one magic position."
expected_pf: 1.13
expected_dd_pct: 18.0
---

# EIA WTI Hurricane Season Breakout

## Source

- Source: [[sources/EIA-WTI-HURRICANE-2025]]
- Primary citation: U.S. Energy Information Administration, "Refining industry risks from 2025 hurricane season", Today in Energy, URL https://www.eia.gov/todayinenergy/detail.php?id=65304.

## Concept

EIA documents recurring Atlantic hurricane-season petroleum risk: June through
November is the defined storm season, severe storms cluster around late summer,
and U.S. Gulf Coast refining and petroleum logistics can be disrupted by major
storms. This card does not forecast weather. It trades only the WTI price
response: during the hurricane-risk window, buy XTIUSD.DWX when D1 price breaks
up with a strong close and trend confirmation, then exit quickly if the breakout
fails or the season/risk window ends.

This is deliberately different from:

- `QM5_12563_donchian-turtle-trend-commodity`: full-year symmetric commodity Turtle trend across multiple commodities.
- `QM5_12576_eia-wti-season`: monthly refined-product demand trend/seasonality.
- `QM5_12581_eia-rbob-crack`: RBOB crack-spread seasonal channel logic with long and short regimes.
- `QM5_12590_eia-wti-wpsr-fade`: weekly WPSR event exhaustion fade.
- `QM5_12567_cum-rsi2-commodity`: short-horizon RSI-style commodity pullback.

## Markets And Timeframe

- Symbol: XTIUSD.DWX.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC only; no EIA feed, hurricane feed, weather API, refinery feed, inventory feed, or futures curve.

## Entry Rules

- Evaluate only on a new D1 bar.
- Trade only when the current broker-calendar month is within `strategy_start_month` through `strategy_end_month`; default June through November.
- Long-only supply-risk entry: BUY XTIUSD.DWX when the prior closed D1 close is above the highest high of the previous `strategy_entry_channel` completed D1 bars.
- Require the prior closed D1 close to be above SMA(`strategy_trend_period`).
- Require the prior closed D1 bar range to be at least ATR(`strategy_atr_period`) * `strategy_min_range_atr`.
- Require the prior closed D1 close location to be at or above `strategy_min_close_location` within that bar's high-low range.
- No entry if an open XTIUSD.DWX position already exists for this EA magic.
- No entry if the XTIUSD.DWX spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Exit if the active month leaves the hurricane-season window.
- Exit if the prior closed D1 close breaks below the lowest low of the previous `strategy_exit_channel` completed D1 bars.
- Exit if the prior closed D1 close falls below SMA(`strategy_trend_period`).
- Exit after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade XTIUSD.DWX on D1.
- Skip entries when ATR, SMA, or channel state is unavailable.
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

- name: strategy_entry_channel
  default: 12
  sweep_range: [8, 12, 16, 20]
- name: strategy_exit_channel
  default: 6
  sweep_range: [4, 6, 10]
- name: strategy_trend_period
  default: 50
  sweep_range: [34, 50, 84]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_range_atr
  default: 0.80
  sweep_range: [0.60, 0.80, 1.00, 1.25]
- name: strategy_min_close_location
  default: 0.65
  sweep_range: [0.60, 0.65, 0.75]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 12
  sweep_range: [6, 12, 20]
- name: strategy_start_month
  default: 6
  sweep_range: [6, 7, 8]
- name: strategy_end_month
  default: 11
  sweep_range: [9, 10, 11]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is taken from EIA. EIA is used only as official structural
lineage for hurricane-season petroleum supply risk. The edge claim is tested by
the QM Q02+ pipeline on Darwinex XTIUSD.DWX bars.

## Initial Risk Profile

- expected_pf: 1.13
- expected_dd_pct: 18
- expected_trade_frequency: approximately 5-10 trades/year during hurricane-risk windows.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 official source: EIA hurricane-season petroleum-risk article.
- [x] R2 mechanical: fixed calendar window, D1 breakout/range/close-location filters, ATR stop, channel/SMA/time exits.
- [x] R3 testable: XTIUSD.DWX exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one position per magic.
- [x] No duplicate of `QM5_12563`: this is long-only, XTI-only, hurricane-season gated, and time-bounded.
- [x] No duplicate of `QM5_12581`: this uses hurricane supply-risk timing, not RBOB crack-spread seasonal regimes.

## Framework Alignment

- no_trade: D1 and XTIUSD.DWX guard, hurricane-season calendar gate, parameter guard, spread cap.
- trade_entry: prior D1 upside channel breakout with SMA, ATR range, and close-location confirmation.
- trade_management: season exit, failed-breakout exit, SMA failure exit, and max-hold exit.
- trade_close: framework Friday close and strategy exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-27 | initial structural WTI hurricane-season breakout build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-27 | APPROVED | this card |
