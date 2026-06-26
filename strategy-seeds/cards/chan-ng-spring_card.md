---
ea_id: QM5_12582
slug: chan-ng-spring
type: strategy
source_id: SRC02
source_citation: "Chan, Ernest P. (2009). Quantitative Trading: How to Build Your Own Algorithmic Trading Business. Wiley Trading. Sidebar p. 150, natural gas June-expiry seasonal trade."
sources:
  - "[[sources/SRC02]]"
concepts:
  - "[[concepts/annual-calendar-trade]]"
  - "[[concepts/natural-gas-seasonality]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
target_symbols: [XNGUSD.DWX]
logical_symbol: QM5_12582_XNG_SPRING_D1
period: D1
expected_trade_frequency: "Annual natural-gas spring calendar window; with V5 Friday-close segmentation, estimate 5-8 D1 entries/year."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-26
g0_approval_reasoning: "R1 PASS Chan/Wiley source and prior SRC02 CEO ratification; R2 PASS deterministic annual date window with SMA/ATR rules; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale and one magic position."
expected_pf: 1.10
expected_dd_pct: 20.0
---

# Chan Natural Gas Spring Calendar

## Source

- Source: [[sources/SRC02]]
- Primary citation: Ernest P. Chan, *Quantitative Trading: How to Build Your Own Algorithmic Trading Business*, Wiley Trading, 2009. SRC02 records S08 as the natural-gas annual calendar trade from sidebar p. 150.

## Concept

Chan records a long-only annual natural-gas seasonal trade on NYMEX NG June
expiry, entering February 25 and exiting April 15. SRC02 already ratified this
as an `annual-calendar-trade` candidate, with the explicit Amaranth-class
natural-gas blow-up risk noted.

This V5 port maps the idea to the available Darwinex custom symbol
`XNGUSD.DWX` and keeps runtime data OHLC-only. It does not use futures expiry
selection, storage reports, weather, inventory data, or external APIs.

This is deliberately different from:

- `QM5_12575_eia-xng-season`: monthly two-sided natural-gas winter/summer/shoulder seasonality with SMA confirmation.
- `QM5_12567_cum-rsi2-commodity`: short-horizon cumulative RSI pullback logic.

## Markets And Timeframe

- Symbol: XNGUSD.DWX.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC only.

## Entry Rules

- Evaluate only on a new D1 bar.
- Eligible calendar window: February 25 through April 15, inclusive.
- Long only.
- Skip if an open XNGUSD.DWX position already exists for this EA magic.
- Skip if XNGUSD.DWX spread exceeds `strategy_max_spread_points`.
- Entry: BUY XNGUSD.DWX when the prior closed D1 close is above SMA(`strategy_trend_period`).
- The V5 Friday-close guard remains enabled. If it closes the position while the calendar window is still active, the EA may re-enter on the next eligible D1 bar if the SMA filter remains true.

## Exit Rules

- Stop loss: ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Exit when the current date is outside the February 25-April 15 window.
- Exit when prior closed D1 close falls below SMA(`strategy_trend_period`).
- Exit when the position has been held for more than `strategy_max_hold_days`.
- Friday close remains enabled by the V5 framework.

## Filters

- Host chart must be XNGUSD.DWX on D1.
- No short entries.
- No pyramiding, grid, martingale, partial close, or trailing stop.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Parameters To Test

- name: strategy_trend_period
  default: 63
  sweep_range: [42, 63, 84, 126]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0, 5.0]
- name: strategy_max_hold_days
  default: 10
  sweep_range: [5, 10, 15]
- name: strategy_max_spread_points
  default: 800
  sweep_range: [500, 800, 1200]

## Author Claims

SRC02 records Chan's sidebar claim of 14 consecutive profitable years for the
original NYMEX NG June-expiry seasonal trade. This V5 port does not inherit
that claim because `XNGUSD.DWX` is a CFD proxy and the V5 Friday-close guard
segments the original continuous hold.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 20
- expected_trade_frequency: approximately 5-8 entries/year under Friday-close segmentation.
- risk_class: high for commodity volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: Chan/Wiley book source with SRC02 ratification.
- [x] R2 mechanical: fixed date window, long-only SMA entry/exit, ATR stop, time exit.
- [x] R3 testable: XNGUSD.DWX exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale.

## Framework Alignment

- no_trade: D1/XNGUSD.DWX guard, date-window gate, spread cap.
- trade_entry: annual spring natural-gas long window with SMA confirmation.
- trade_management: date-window/SMA/time exits.
- trade_close: framework Friday close plus strategy exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-26 | initial XNG spring annual calendar port | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-26 | APPROVED | this card |
