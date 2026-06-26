---
ea_id: QM5_12584
slug: eia-xng-storage
type: strategy
source_id: EIA-XNG-STORAGE-AFTERSHOCK-2026
source_citation: "U.S. Energy Information Administration. Weekly Natural Gas Storage Report and release schedule. URLs https://www.eia.gov/naturalgas/storage/ and https://www.eia.gov/naturalgas/schedule/"
sources:
  - "[[sources/EIA-XNG-STORAGE-AFTERSHOCK-2026]]"
concepts:
  - "[[concepts/natural-gas-storage]]"
  - "[[concepts/information-event-aftershock]]"
  - "[[concepts/energy-event-risk]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
target_symbols: [XNGUSD.DWX]
logical_symbol: QM5_12584_XNG_STORAGE_D1
period: D1
expected_trade_frequency: "Weekly natural-gas storage report reaction filter on D1 bars; range/body/trend filters estimate 8-20 trades/year."
expected_trades_per_year_per_symbol: 12
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-26
g0_approval_reasoning: "R1 PASS official EIA weekly natural-gas storage report and schedule; R2 PASS deterministic D1 event-day reaction/range/body/SMA rules; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.15
expected_dd_pct: 20.0
---

# EIA Natural Gas Storage Aftershock

## Source

- Source: [[sources/EIA-XNG-STORAGE-AFTERSHOCK-2026]]
- Primary EIA storage report URL: https://www.eia.gov/naturalgas/storage/
- EIA release schedule URL: https://www.eia.gov/naturalgas/schedule/

## Concept

The EIA Weekly Natural Gas Storage Report is a recurring scheduled information
event for the natural-gas market. This card converts the event into a
Darwinex-native, OHLC-only XNGUSD.DWX sleeve: after a storage-report D1 bar has
closed, trade only if the event-day bar shows an unusually large, directional
reaction confirmed by a slow price filter.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: short-horizon RSI pullback logic.
- `QM5_12575_eia-xng-season`: monthly natural-gas demand seasonality.
- `QM5_12582_chan-ng-spring`: annual spring calendar window.
- `QM5_12578_eia-oilgas-ratio`: paired oil/gas ratio reversion basket.

## Markets And Timeframe

- Symbol: XNGUSD.DWX.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC only; no EIA feed, storage-level CSV,
  consensus forecast, surprise feed, or external API.

## Entry Rules

- Evaluate only on a new D1 bar.
- Inspect the prior closed D1 bar if its broker-time day is Wednesday,
  Thursday, or Friday. Thursday is the standard storage-report day; Wednesday
  and Friday are allowed only to tolerate holiday schedule shifts.
- Skip if an open XNGUSD.DWX position already exists for this EA magic.
- Skip if XNGUSD.DWX spread exceeds `strategy_max_spread_points`.
- Compute event-day range, body, ATR(20), and SMA(40) on closed D1 data.
- Long entry: if event-day range is at least `strategy_min_range_atr * ATR`,
  body/range is at least `strategy_min_body_ratio`, body is positive, and close
  is above SMA(40), BUY XNGUSD.DWX at market.
- Short entry: if the same range/body filters pass, body is negative, and close
  is below SMA(40), SELL XNGUSD.DWX at market.

## Exit Rules

- Stop loss: ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Time exit after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Host chart must be XNGUSD.DWX on D1.
- No pyramiding, grid, martingale, partial close, or trailing stop.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Parameters To Test

- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_trend_period
  default: 40
  sweep_range: [34, 40, 50, 63]
- name: strategy_min_range_atr
  default: 1.25
  sweep_range: [1.0, 1.25, 1.5, 1.75]
- name: strategy_min_body_ratio
  default: 0.30
  sweep_range: [0.25, 0.30, 0.40, 0.50]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 3.5, 4.5]
- name: strategy_max_hold_days
  default: 2
  sweep_range: [1, 2, 3, 5]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]

## Author Claims

No performance claim is taken from EIA. The source is used only for structural
lineage: the weekly storage report is a scheduled natural-gas information event.

## Initial Risk Profile

- expected_pf: 1.15
- expected_dd_pct: 20
- expected_trade_frequency: approximately 8-20 trades/year.
- risk_class: high for natural-gas volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA storage report and release schedule.
- [x] R2 mechanical: fixed event-day set, range/body/SMA filters, ATR stop, time exit.
- [x] R3 testable: XNGUSD.DWX exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale.
- [x] No duplicate of QM5_12567: this is storage-event reaction continuation, not RSI pullback.
- [x] No duplicate of existing XNG seasonality cards: this is weekly event aftershock logic.

## Framework Alignment

- no_trade: D1/XNGUSD.DWX guard, event-day gate, spread cap.
- trade_entry: D1 storage-report reaction continuation.
- trade_management: fixed time exit.
- trade_close: framework Friday close and strategy time exit.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-26 | initial structural XNG weekly storage aftershock build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-26 | APPROVED | this card |
