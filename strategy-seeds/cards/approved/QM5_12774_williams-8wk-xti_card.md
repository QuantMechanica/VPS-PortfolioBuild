---
ea_id: QM5_12774
slug: williams-8wk-xti
type: strategy
source_id: SRC03_S11_XTI
source_citation: "Williams, Larry R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading; SRC03 extraction slot S11, 8-Week Box Congestion Breakout."
sources:
  - "[[sources/SRC03]]"
concepts:
  - "[[concepts/wti-congestion-breakout]]"
  - "[[concepts/commodity-structural-breakout]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [narrow-range-breakout, atr-hard-stop, time-stop, friday-close-flatten, symmetric-long-short]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Low-frequency D1 WTI congestion-breakout sleeve; estimate 4-12 trades/year after framework filters."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-06-29
g0_approval_reasoning: "R1 PASS curated Tier-A Williams source already approved as SRC03; R2 PASS deterministic D1 40-bar box breakout with pre-box trend filter, ATR stop, max-hold exit; R3 PASS XTIUSD.DWX is available in the DWX matrix; R4 PASS no ML/grid/martingale/external feed."
expected_pf: 1.10
expected_dd_pct: 18.0
---

# Williams 8-Week WTI Box Breakout

## Source

- Source: [[sources/SRC03]]
- Primary citation: Williams, Larry R. (1999). *Long-Term Secrets to Short-Term Trading*. Wiley Trading.
- Local extraction note: `strategy-seeds/sources/SRC03/source.md`, slot S11, identifies the "8-Week Box Congestion Breakout" as a go-with breakout after an 8-week sideways range.

## Concept

Williams' structural premise is that a multi-week congestion box can store energy; when price leaves that box in the direction of the trend that preceded the box, the breakout should be followed rather than faded. This card maps the rule to a single `XTIUSD.DWX` WTI sleeve using daily Darwinex OHLC only.

The implementation is deliberately different from existing QM commodity and energy sleeves:

- It is not the existing `QM5_12577` XAU/XAG ratio-reversion basket.
- It is not the `QM5_12563` commodity Donchian/Turtle family, which fires on rolling extremes without an explicit 8-week congestion box plus pre-box trend requirement.
- It is not the `QM5_12767` Collins prior-day range stop-entry, which projects next-day stops from one prior bar.
- It is not WTI calendar, WPSR, refinery, hurricane, OPEC, expiry, ETF-roll, CAD/oil, XTI/XNG, oil/gold, oil/silver, month-of-year, or RSI pullback logic already in the registry.

## Markets And Timeframe

- Target symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: about 4-12 trades/year.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 D1 OHLC, broker spread, and ATR only. No futures curve, inventory feed, EIA feed, CFTC data, CSV, API, analyst forecast, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Build the congestion box from the prior 40 completed D1 bars before the signal bar.
- Require the 40-bar high-low range to be no wider than `strategy_box_atr_mult * ATR(strategy_atr_period)`.
- Define the pre-box trend as the return from `strategy_trend_lookback` bars before the box to the first bar of the box.
- Long entry: prior completed D1 close breaks above the box high by `strategy_break_buffer_points`, and the pre-box trend return is at least `strategy_min_trend_return_pct`.
- Short entry: prior completed D1 close breaks below the box low by `strategy_break_buffer_points`, and the pre-box trend return is no more than negative `strategy_min_trend_return_pct`.
- Enter at market on the next D1 bar after the confirmed close breakout.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`, frozen at entry.
- Time stop: close after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Magic slot must be 0.
- Skip entries when warmup bars, ATR, box prices, trend-reference close, or broker point value are unavailable.
- Framework news, kill-switch, magic, stress, and Friday-close guards remain active.

## Trade Management Rules

- Symmetric long/short entries.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.
- Re-entry is permitted only after the EA is flat and a fresh D1 breakout condition appears.

## Parameters To Test

- name: strategy_box_bars
  default: 40
  sweep_range: [30, 40, 50]
- name: strategy_trend_lookback
  default: 20
  sweep_range: [10, 20, 30]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_box_atr_mult
  default: 8.0
  sweep_range: [6.0, 8.0, 10.0]
- name: strategy_min_trend_return_pct
  default: 1.0
  sweep_range: [0.5, 1.0, 2.0]
- name: strategy_break_buffer_points
  default: 0
  sweep_range: [0, 20, 50]
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

The source is used only for structural lineage around the 8-week congestion-box breakout and the "KEEP SWINGING" re-entry concept. No source performance number is imported into QM; Q02 and later phases must validate the Darwinex `XTIUSD.DWX` realization.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 18
- expected_trade_frequency: approximately 4-12 trades/year.
- risk_class: medium.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: SRC03 is an owner-approved Tier-A Williams source in the local source queue.
- [x] R2 mechanical: fixed D1 box length, fixed trend lookback, fixed ATR compression, fixed close-breakout trigger, ATR stop, time stop.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one position per magic.
- [x] Non-duplicate: this is a WTI-specific multi-week congestion breakout, not a ratio-reversion basket, WTI calendar/event/roll/seasonality sleeve, XNG sleeve, RSI pullback, Donchian/Turtle rule, or prior-day range projection.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, slot guard, parameter guard, warmup guard, spread cap.
- trade_entry: 40-bar box compression plus pre-box trend plus prior-close breakout.
- trade_management: max-hold stale-position close.
- trade_close: hard ATR stop plus deterministic time exit.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-29 | initial structural WTI 8-week congestion-box breakout card | G0 | APPROVED |
| v1-q02 | 2026-06-29 | strict build PASS and paced-fleet Q02 enqueued | Q02 | PENDING e333f988-aa6e-4c77-9119-3bb39e9b12ca |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-29 | APPROVED | this card |
| Q02 Baseline Screening | 2026-06-29 | QUEUED | work_items/e333f988-aa6e-4c77-9119-3bb39e9b12ca |
