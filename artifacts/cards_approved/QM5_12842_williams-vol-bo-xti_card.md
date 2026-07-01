---
ea_id: QM5_12842
slug: williams-vol-bo-xti
type: strategy
strategy_id: SRC03_S01_XTI_20260701
source_id: SRC03
source_citation: "Williams, Larry R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading. Source packet strategy-seeds/sources/SRC03/."
source_citations:
  - type: book
    citation: "Williams, Larry R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading."
    location: "SRC03 local source packet; volatility breakout rule in the Entry Techniques section."
    quality_tier: A
    role: primary
sources:
  - "[[sources/SRC03]]"
concepts:
  - "[[concepts/wti-volatility-expansion]]"
  - "[[concepts/prior-range-breakout]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [vol-expansion-breakout, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
timeframes: [D1]
single_symbol_only: true
period: D1
expected_trade_frequency: "D1 XTIUSD prior-range upside volatility expansion; estimate 12-30 trades/year after range floor, pending-order expiry, spread cap, ATR stop, and max-hold filters."
expected_trades_per_year_per_symbol: 20
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-01
expected_pf: 1.10
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, pending_order_expiry, enhancement_doctrine]
g0_approval_reasoning: "R1 PASS SRC03 Williams source packet; R2 PASS deterministic D1 prior-range buy-stop, ATR stop, pending-order expiry, and max-hold exit; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
---

# WTI Prior-Range Volatility Expansion

## Source

- Source: [[sources/SRC03]]
- Primary citation: Williams, Larry R. (1999). *Long-Term Secrets to
  Short-Term Trading*. Wiley Trading. Local source packet:
  `strategy-seeds/sources/SRC03/`.

## Concept

Williams describes a daily volatility-breakout technique that buys above the
new session open by a fraction of the prior day's range when a market is primed
for range expansion. This card specializes that structural range-expansion
idea to WTI CFD proxy `XTIUSD.DWX` and keeps v1 deliberately narrow: long-only,
single-symbol, D1, no external energy data, no inventory feed, and no broad
cross-asset basket.

This is deliberately different from:

- Existing WTI day-of-week, month-of-year, expiry, post-roll, WPSR, Cushing,
  refinery, hurricane, OPEC, SPR, CAD/FX, XTI/XNG, oil/gold, oil/silver,
  52-week-anchor, and return-reversal sleeves.
- `QM5_12567_cum-rsi2-commodity`: this card has no RSI or generic short-horizon
  pullback logic.
- XAU/XAG and gas/metal ratio sleeves: this card adds WTI exposure only and
  does not add more metal or natural-gas exposure to the current book.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: `D1`.
- Expected trade frequency: about 12-30 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only. No futures curve,
  inventory feed, CFTC data, volume, API, analyst forecast, CSV, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Read the current D1 open and the prior completed D1 high and low.
- Compute prior range as `prior_high - prior_low`.
- Skip entries when the prior range is less than
  `strategy_min_range_atr * ATR(strategy_atr_period)` to avoid tiny holiday or
  truncated bars.
- Place one long pending buy-stop at:
  `current_open + strategy_range_mult * prior_range`.
- The pending order expires after `strategy_order_expiry_hours`.
- No entry if an open `XTIUSD.DWX` position or pending order already exists for
  this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult` below the pending entry price.
- Optional take-profit: if `strategy_take_rr` is greater than zero, place a
  broker-side target at that risk multiple; default is 2.0R.
- Close any open position after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Magic slot must be 0.
- Skip entries when D1 open, prior range, ATR, stop, or pending stop price is
  unavailable.
- Framework news, kill-switch, magic, risk, and Friday-close guards remain
  active.

## Trade Management Rules

- Long-only v1, matching the source's explicit buy-side volatility-breakout
  framing.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_range_mult
  default: 0.75
  sweep_range: [0.50, 0.75, 1.00, 1.25]
- name: strategy_min_range_atr
  default: 0.35
  sweep_range: [0.00, 0.25, 0.35, 0.50]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.5
  sweep_range: [2.0, 2.5, 3.0, 4.0]
- name: strategy_take_rr
  default: 2.0
  sweep_range: [0.0, 1.5, 2.0, 3.0]
- name: strategy_order_expiry_hours
  default: 20
  sweep_range: [12, 20, 24]
- name: strategy_max_hold_days
  default: 5
  sweep_range: [3, 5, 8]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The source is used only for structural lineage around prior-day range
expansion. No source performance number is imported into QM; Q02 and later
phases must validate or reject the WTI specialization on Darwinex
`XTIUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.10.
- expected_dd_pct: 20.
- expected_trade_frequency: approximately 12-30 trades/year.
- risk_class: medium-high for WTI gap and trend volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: single local SRC03 Williams source packet.
- [x] R2 mechanical: fixed prior-range buy-stop, ATR stop, optional RR target,
  order expiry, and max-hold exit.
- [x] R3 testable: `XTIUSD.DWX` exists in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, or more than
  one position per magic.
- [x] Non-duplicate: this is a WTI prior-range volatility-expansion sleeve, not
  an existing WTI calendar/event/roll/inventory/ratio/reversal sleeve, XNG
  logic, XAU/XAG logic, or commodity RSI pullback.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX` setfile.
Live risk is intentionally not configured here; any future live allocation must
come from the portfolio process. The EA does not touch `T_Live`, AutoTrading,
deploy manifests, or the portfolio gate.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard,
  spread cap, and pending/order duplication guard.
- trade_entry: new-D1 prior-range buy-stop at open plus range multiple.
- trade_management: max-hold stale-position exit and pending-order expiry by
  broker order lifetime.
- trade_close: hard ATR stop plus optional fixed RR target.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-01 | initial WTI prior-range volatility-expansion build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-01 | APPROVED | this card |
| Q01 Build Validation | 2026-07-01 | PASS | `artifacts/qm5_12842_build_result.json` |
| Q02 Baseline Screening | 2026-07-01 | QUEUED | `D:\QM\strategy_farm\state\farm_state.sqlite` |
