---
ea_id: QM5_12750
slug: wti-weekend-gap-fade
type: strategy
source_id: TGIF-WTI-WEEKEND-2017
source_citation: "TGIF? The weekend effect in energy commodities. Journal of Finance Issues. URL https://jfi-aof.org/index.php/jfi/article/view/2264"
sources:
  - "[[sources/TGIF-WTI-WEEKEND-2017]]"
concepts:
  - "[[concepts/crude-oil-weekend-effect]]"
  - "[[concepts/weekend-gap-fade]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, weekend-gap, gap-fade, atr-hard-stop, time-stop, short-only, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "D1 WTI positive-weekend-gap fade; estimate 8-18 trades/year after Monday/friday-contiguity, gap-size, spread, and framework filters."
expected_trades_per_year_per_symbol: 12
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-28
g0_approval_reasoning: "R1 PASS academic energy-weekend-effect source; R2 PASS deterministic Monday positive-gap short with ATR stop, gap-fill TP, and time exit; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.10
expected_dd_pct: 17.0
---

# WTI Weekend Gap Fade

## Source

- Source: [[sources/TGIF-WTI-WEEKEND-2017]]
- Primary citation: "TGIF? The weekend effect in energy commodities", Journal
  of Finance Issues, URL https://jfi-aof.org/index.php/jfi/article/view/2264.

## Concept

The source documents weekend-effect structure in energy commodity returns. This
card does not trade every Monday and does not import source performance numbers.
It tests a narrower WTI CFD sleeve: when the Monday D1 bar opens meaningfully
above the prior Friday close, short the positive weekend gap and target a fill
back to the prior close.

This is deliberately different from:

- `QM5_12596_wti-mon-fade`: shorts every Monday D1 bar. This card trades only
  positive weekend gaps and uses a gap-fill take-profit.
- `QM5_12610_wti-tue-fade` and `QM5_12597_wti-fri-prem`: different weekdays and
  no gap-fill state.
- `QM5_12599`, `QM5_12726`, `QM5_12727`, `QM5_12729`, and `QM5_12730`:
  month-of-year WTI sleeves, not weekend-gap state.
- WPSR, hurricane, refinery, OPEC, expiry, ETF-roll, CAD-confirmation,
  XTI/XNG, oil/gold, oil/silver, and medium-term momentum WTI sleeves already
  in the registry.

## Markets And Timeframe

- Symbol: XTIUSD.DWX.
- Period: D1.
- Expected trade frequency: about 8-18 trades/year.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no futures curve,
  inventory feed, EIA feed, CFTC data, CSV, API, analyst forecast, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- The current D1 bar must be broker-calendar Monday.
- The previous completed D1 bar must be broker-calendar Friday.
- Compute weekend gap percent as `(current D1 open / previous D1 close - 1) * 100`.
- Entry direction is short only: SELL XTIUSD.DWX when gap percent is at least
  `strategy_min_gap_pct`.
- Use ATR(`strategy_atr_period`) on completed D1 bars for the hard stop.
- Set take-profit at the prior Friday close, i.e. the gap-fill level.
- No entry if an open XTIUSD.DWX position already exists for this EA magic.
- No entry if XTIUSD.DWX spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Take-profit: prior Friday close captured at entry.
- Close any remaining position when the current D1 bar is no longer Monday.
- Also close after `strategy_max_hold_days` calendar days as a stale-position
  guard.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade XTIUSD.DWX on D1.
- Magic slot must be 0.
- Skip entries when ATR, D1 open, prior close, or Friday/Monday calendar state
  is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Short-only.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_min_gap_pct
  default: 0.75
  sweep_range: [0.50, 0.75, 1.00, 1.25]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.25
  sweep_range: [1.5, 2.25, 3.0]
- name: strategy_max_hold_days
  default: 2
  sweep_range: [1, 2, 3]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The source is used for structural lineage around energy weekend effects. No
source performance number is imported into QM; the Q02+ pipeline tests the
gap-conditioned rule on Darwinex XTIUSD.DWX bars.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 17
- expected_trade_frequency: approximately 8-18 trades/year.
- risk_class: medium-high for crude-oil weekend gap risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: academic energy weekend-effect paper.
- [x] R2 mechanical: fixed Monday/Friday calendar state, positive-gap short,
  ATR stop, gap-fill TP, and time exit.
- [x] R3 testable: XTIUSD.DWX exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one
  position per magic.
- [x] Non-duplicate: gap-conditioned Monday short with gap-fill target is not
  the existing all-Monday short, Tuesday fade, Friday premium, month sleeves,
  WTI event sleeves, WTI momentum/reversal, XNG, or commodity RSI logic.

## Framework Alignment

- no_trade: D1 and XTIUSD.DWX guard, slot guard, parameter guard, spread cap.
- trade_entry: Monday positive weekend-gap short against prior Friday close.
- trade_management: non-Monday stale exit and max-hold guard.
- trade_close: hard ATR stop plus broker-side gap-fill TP.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-28 | initial structural WTI weekend-gap fade card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-28 | APPROVED | this card |
