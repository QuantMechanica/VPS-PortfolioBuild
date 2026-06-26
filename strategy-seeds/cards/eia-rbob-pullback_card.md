---
ea_id: QM5_12585
slug: eia-rbob-pullback
type: strategy
source_id: EIA-RBOB-PULLBACK-2026
source_citation: "U.S. Energy Information Administration. Gasoline crack spreads rise ahead of the summer driving season. This Week in Petroleum, 2025-03-12. URL https://www.eia.gov/petroleum/weekly/archive/2025/250312/includes/analysis_print.php"
sources:
  - "[[sources/EIA-RBOB-PULLBACK-2026]]"
concepts:
  - "[[concepts/gasoline-crack-spread]]"
  - "[[concepts/energy-seasonality]]"
  - "[[concepts/pullback-continuation]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
target_symbols: [XTIUSD.DWX]
logical_symbol: QM5_12585_XTI_RBOB_PULLBACK_D1
period: D1
expected_trade_frequency: "D1 WTI long-only pullback sleeve restricted to gasoline crack-spread support months; estimate 4-10 trades/year."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-26
g0_approval_reasoning: "R1 PASS official EIA source; R2 PASS deterministic D1 date-window/trend/pullback/depth/exit rules; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale and one magic position."
expected_pf: 1.12
expected_dd_pct: 18.0
---

# EIA RBOB Pullback Continuation

## Source

- Source: [[sources/EIA-RBOB-PULLBACK-2026]]
- Primary citation: U.S. Energy Information Administration, "Gasoline crack spreads rise ahead of the summer driving season", This Week in Petroleum, March 12, 2025.

## Concept

EIA describes gasoline crack spreads as a proxy for refinery margins between
crude oil and finished gasoline. The source documents a recurring seasonal
structure around the transition to summer-grade gasoline and the summer driving
season.

This card converts that structural gasoline-demand/refiner-margin setup into a
low-frequency XTIUSD.DWX sleeve. Runtime data stays Darwinex MT5 OHLC-only:
the EA buys controlled WTI D1 pullbacks during the March-August gasoline
support window when the broader D1 trend remains positive. It does not read
external EIA, RBOB, refinery, inventory, or futures-spread data.

This is deliberately different from:

- `QM5_12576_eia-wti-season`: monthly WTI SMA/ROC seasonality with winter and summer long windows.
- `QM5_12579_eia-wti-aftershock`: post-WPSR event-day aftershock continuation.
- `QM5_12581_eia-rbob-crack`: gasoline-window channel breakout/breakdown.
- `QM5_12583_eia-distillate-winter`: winter-only distillate breakout.
- `QM5_12567_cum-rsi2-commodity`: RSI-style commodity pullback logic.

## Markets And Timeframe

- Symbol: XTIUSD.DWX.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC only.

## Entry Rules

- Evaluate only on a new D1 bar.
- Eligible calendar window: March through August.
- Long only.
- Skip if an open XTIUSD.DWX position already exists for this EA magic.
- Skip if the XTIUSD.DWX spread exceeds `strategy_max_spread_points`.
- Trend gate: prior closed D1 close must be above SMA(`strategy_trend_period`).
- Pullback gate: prior D1 closes must be lower for `strategy_pullback_days` consecutive closed bars.
- Depth gate: pullback from the pre-pullback close to the prior close must be between `strategy_min_pullback_atr` and `strategy_max_pullback_atr` times ATR(`strategy_atr_period`).
- Entry: BUY XTIUSD.DWX at market after all gates pass.

## Exit Rules

- Stop loss: ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Close if the active month leaves the March-August support window.
- Close if prior closed D1 close falls below SMA(`strategy_trend_period`).
- Close if prior closed D1 close recovers above the highest close of the previous `strategy_bounce_exit_lookback` completed bars.
- Close if `strategy_max_hold_days` is exceeded.
- Friday close remains enabled by the V5 framework.

## Filters

- Host chart must be XTIUSD.DWX on D1.
- No short entries.
- No pyramiding, grid, martingale, partial close, or trailing stop.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Parameters To Test

- name: strategy_trend_period
  default: 100
  sweep_range: [63, 84, 100, 150]
- name: strategy_pullback_days
  default: 3
  sweep_range: [2, 3, 4, 5]
- name: strategy_min_pullback_atr
  default: 0.35
  sweep_range: [0.25, 0.35, 0.50, 0.75]
- name: strategy_max_pullback_atr
  default: 2.25
  sweep_range: [1.50, 2.25, 3.00]
- name: strategy_bounce_exit_lookback
  default: 8
  sweep_range: [5, 8, 13]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0, 5.0]
- name: strategy_max_hold_days
  default: 14
  sweep_range: [7, 14, 21]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is taken from the EIA source. The source is used only for
structural lineage: gasoline crack-spread definition and seasonality.

## Initial Risk Profile

- expected_pf: 1.12
- expected_dd_pct: 18
- expected_trade_frequency: approximately 4-10 trades/year.
- risk_class: medium.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA This Week in Petroleum source.
- [x] R2 mechanical: fixed month window, trend gate, consecutive lower-close pullback, ATR-depth band, ATR stop, and deterministic exits.
- [x] R3 testable: XTIUSD.DWX exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale.

## Framework Alignment

- no_trade: D1/XTIUSD.DWX guard and spread cap.
- trade_entry: D1 gasoline-window pullback continuation.
- trade_management: bounce/date/trend/time exits.
- trade_close: framework Friday close and strategy exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-26 | initial structural XTI gasoline crack-spread pullback build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-26 | APPROVED | this card |
