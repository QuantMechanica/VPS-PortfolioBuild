---
ea_id: QM5_12784
slug: progo-xti
type: strategy
strategy_id: SRC03_S16_XTI
source_id: SRC03
source_citation: "Williams, Larry R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading; SRC03_S16 Pro-Go public/professional flow decomposition."
sources:
  - "[[sources/SRC03]]"
concepts:
  - "[[concepts/wti-session-flow-crossover]]"
  - "[[concepts/commodity-structural-flow]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [flow-crossover, atr-hard-stop, signal-reversal-exit, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
timeframes: [D1]
single_symbol_only: true
period: D1
expected_trade_frequency: "D1 WTI Pro-Go flow-line crossover sleeve; estimate 10-24 trades/year after 14-day smoothing and framework filters."
expected_trades_per_year_per_symbol: 16
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-06-29
g0_approval_reasoning: "R1 PASS Tier-A Williams SRC03 source already approved; R2 PASS deterministic D1 prior-close-to-open versus open-to-close flow-line crossover, ATR stop, opposite-cross exit, and max-hold guard; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed."
expected_pf: 1.10
expected_dd_pct: 20.0
risk_class: medium
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
---

# Williams Pro-Go XTI Flow Crossover

## Source

- Primary source: [[sources/SRC03]]
- Citation: Williams, Larry R. (1999). *Long-Term Secrets to Short-Term Trading*. Wiley Trading.
- Local extraction note: `strategy-seeds/cards/williams-pro-go_card.md` records SRC03_S16 and the Pro-Go rule from the Williams source.

## Concept

Williams separates daily price movement into two flow components: the move from the prior close to today's open, framed as public or overnight flow, and the move from today's open to today's close, framed as professional session flow. This card specializes that Pro-Go idea to `XTIUSD.DWX`: when the smoothed professional session-flow line crosses above the smoothed public/overnight-flow line, the EA buys WTI; when it crosses below, the EA sells WTI.

This is deliberately different from the existing WTI and commodity builds:

- It is not WTI calendar, month, weekday, weekend-gap, WPSR, refinery, hurricane, OPEC, expiry, ETF-roll, SPR, CAD/oil, XTI/XNG, oil/gold, oil/silver, seasonal pseudo-price, 52-week anchor, box breakout, Donchian, RSI pullback, or commodity reversal logic.
- It is not a metal-ratio sleeve such as XAU/XAG.
- It uses only Darwinex D1 open/high/low/close and broker spread at runtime.

## Markets And Timeframe

- Target symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: about 10-24 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC and ATR only. No futures curve, inventory feed, EIA feed, CFTC data, CSV, API, analyst forecast, or ML model.

## 4. Entry Rules

- Evaluate only on a new D1 bar.
- For each completed D1 bar, compute:
  - `public_change = Open[bar] - Close[bar + 1]`.
  - `pro_change = Close[bar] - Open[bar]`.
- Compute `public_line = SMA(public_change, strategy_flow_ma_period)`.
- Compute `pro_line = SMA(pro_change, strategy_flow_ma_period)`.
- Long entry: `pro_line` crosses above `public_line` on the prior completed D1 bar.
- Short entry: `pro_line` crosses below `public_line` on the prior completed D1 bar.
- Enter at market on the next D1 bar after the confirmed cross.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## 5. Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`, frozen at entry.
- Signal reversal exit: close a long if `pro_line` crosses back below `public_line`; close a short if it crosses back above.
- Time exit after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## 6. Filters (No-Trade Module)

- Only trade `XTIUSD.DWX` on D1.
- Only magic slot 0 is valid.
- Skip entries when flow-line warmup, ATR, broker point value, or current spread is unavailable.
- Framework news, kill-switch, magic, stress, and Friday-close guards remain active.

## 7. Trade Management Rules

- Symmetric long/short entries.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## 8. Parameters To Test

- name: strategy_flow_ma_period
  default: 14
  sweep_range: [10, 14, 21, 28]
- name: strategy_signal_mode
  default: signed_value
  sweep_range: [signed_value, sign_only]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 12
  sweep_range: [8, 12, 20]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

Williams describes the Pro-Go idea as a way to separate public buying from professional buying and states that crossings of the two indicators have provided intermediate-term buy and sell signals. No source performance number is imported into QM; Q02 and later phases must validate the Darwinex `XTIUSD.DWX` realization.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 20
- expected_trade_frequency: approximately 10-24 trades/year.
- risk_class: medium.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: SRC03 is an owner-approved Tier-A Williams source in the local source queue.
- [x] R2 mechanical: fixed D1 flow definitions, fixed SMA period, deterministic line cross, ATR stop, reversal exit, and time stop.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one position per magic.
- [x] Non-duplicate: WTI Pro-Go flow decomposition is distinct from all existing WTI calendar/event/ratio/trend/reversal and commodity RSI sleeves.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, slot guard, parameter guard, warmup guard, spread cap.
- trade_entry: 14-day Pro-Go professional-flow versus public-flow SMA crossover.
- trade_management: signal-reversal close and max-hold stale-position close.
- trade_close: ATR hard stop plus deterministic opposite-cross/time exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-29 | initial structural WTI Pro-Go flow-crossover card | G0 | APPROVED |
| v1-q02 | 2026-06-29 | strict build PASS and paced-fleet Q02 enqueued | Q02 | PENDING e04d6c58-8b0d-461c-a0f3-22912b484695 |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-29 | APPROVED | this card |
| Q02 Baseline Screening | 2026-06-29 | QUEUED | work_items/e04d6c58-8b0d-461c-a0f3-22912b484695 |
