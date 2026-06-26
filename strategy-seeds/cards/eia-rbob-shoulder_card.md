---
ea_id: QM5_12589
slug: eia-rbob-shoulder
type: strategy
source_id: EIA-RBOB-CRACK-SEASON-2025
source_citation: "U.S. Energy Information Administration. Gasoline crack spreads rise ahead of the summer driving season. This Week in Petroleum, 2025-03-12. URL https://www.eia.gov/petroleum/weekly/archive/2025/250312/includes/analysis_print.php"
sources:
  - "[[sources/EIA-RBOB-CRACK-SEASON-2025]]"
concepts:
  - "[[concepts/gasoline-crack-spread]]"
  - "[[concepts/energy-seasonality]]"
  - "[[concepts/failed-rally]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
target_symbols: [XTIUSD.DWX]
logical_symbol: QM5_12589_XTI_RBOB_SHOULDER_D1
period: D1
expected_trade_frequency: "D1 WTI short-only autumn shoulder failed-rally sleeve; estimate 3-7 trades/year."
expected_trades_per_year_per_symbol: 5
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-26
g0_approval_reasoning: "R1 PASS official EIA source; R2 PASS deterministic D1 shoulder failed-rally rules; R3 PASS XTIUSD.DWX; R4 PASS no ML/grid/martingale."
expected_pf: 1.12
expected_dd_pct: 18.0
---

# EIA RBOB Autumn Shoulder Failed-Rally Short

## Source

- Source: [[sources/EIA-RBOB-CRACK-SEASON-2025]]
- Primary citation: U.S. Energy Information Administration, "Gasoline crack spreads rise ahead of the summer driving season", This Week in Petroleum, March 12, 2025. URL https://www.eia.gov/petroleum/weekly/archive/2025/250312/includes/analysis_print.php.

## Concept

EIA describes gasoline crack spreads as a proxy for refinery margins between
crude oil and finished gasoline. The source documents a recurring seasonal
structure: crack spreads tend to rise into the summer driving season and then
decline after the September 1 switch to winter-grade gasoline.

This card mechanizes the post-summer shoulder as a low-frequency, short-only
XTIUSD.DWX sleeve. Runtime data stays Darwinex MT5 OHLC-only: the EA waits for
a recent gasoline-season high to fail, then sells only when the D1 close has
fallen below slow trend confirmation and a short trigger low. It does not read
external EIA, RBOB, refinery, inventory, or futures-spread data.

This is deliberately different from:

- `QM5_12576_eia-wti-season`: monthly two-sided WTI SMA/ROC seasonality.
- `QM5_12579_eia-wti-aftershock`: post-WPSR event-day aftershock continuation.
- `QM5_12581_eia-rbob-crack`: two-sided seasonal channel breakout/breakdown.
- `QM5_12585_eia-rbob-pullback`: March-August long-only pullback continuation.
- `QM5_12567_cum-rsi2-commodity`: short-horizon RSI-style commodity pullback.

## Markets And Timeframe

- Symbol: XTIUSD.DWX.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC only.

## Entry Rules

- Evaluate only on a new D1 bar.
- Eligible calendar window: September 1 through November 15.
- Short only.
- Skip if an open XTIUSD.DWX position already exists for this EA magic.
- Skip if the XTIUSD.DWX spread exceeds `strategy_max_spread_points`.
- Recent-peak gate: the highest high of the last `strategy_setup_lookback` completed D1 bars must have occurred within `strategy_peak_recent_bars` bars.
- Trend failure gate: prior closed D1 close must be below SMA(`strategy_trend_period`), and that SMA must be lower than it was `strategy_sma_slope_shift` bars earlier.
- Trigger gate: prior closed D1 close must break below the lowest low of the previous `strategy_trigger_lookback` completed D1 bars.
- Entry: SELL XTIUSD.DWX at market after all gates pass.

## Exit Rules

- Stop loss: ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Close if the date leaves the September 1 through November 15 shoulder window.
- Close if prior closed D1 close recovers above SMA(`strategy_trend_period`).
- Close if prior closed D1 close breaks above the highest high of the previous `strategy_exit_lookback` completed D1 bars.
- Close if `strategy_max_hold_days` is exceeded.
- Friday close remains enabled by the V5 framework.

## Filters

- Host chart must be XTIUSD.DWX on D1.
- No long entries.
- No pyramiding, grid, martingale, partial close, trailing stop, or external feed.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Parameters To Test

- name: strategy_setup_lookback
  default: 42
  sweep_range: [30, 42, 63]
- name: strategy_peak_recent_bars
  default: 15
  sweep_range: [10, 15, 21]
- name: strategy_trend_period
  default: 63
  sweep_range: [42, 63, 84, 100]
- name: strategy_sma_slope_shift
  default: 10
  sweep_range: [5, 10, 15]
- name: strategy_trigger_lookback
  default: 5
  sweep_range: [3, 5, 8]
- name: strategy_exit_lookback
  default: 8
  sweep_range: [5, 8, 13]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 25
  sweep_range: [15, 25, 35]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is taken from the EIA source. The source is used only for
structural lineage: gasoline crack-spread seasonality and the post-September
decline window.

## Initial Risk Profile

- expected_pf: 1.12
- expected_dd_pct: 18
- expected_trade_frequency: approximately 3-7 trades/year.
- risk_class: medium.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA This Week in Petroleum source.
- [x] R2 mechanical: fixed date window, recent-peak failure gate, SMA trend failure, low-break trigger, ATR stop, and deterministic exits.
- [x] R3 testable: XTIUSD.DWX exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale.

## Framework Alignment

- no_trade: D1/XTIUSD.DWX guard and spread cap.
- trade_entry: D1 autumn shoulder failed-rally short.
- trade_management: date/trend/recovery/time exits.
- trade_close: framework Friday close and strategy exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-26 | initial structural XTI gasoline shoulder failed-rally short build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-26 | APPROVED | this card |
