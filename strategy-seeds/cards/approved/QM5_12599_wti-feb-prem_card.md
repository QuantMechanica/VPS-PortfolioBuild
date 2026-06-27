---
ea_id: QM5_12599
slug: wti-feb-prem
type: strategy
source_id: GORSKA-WTI-CAL-2015
source_citation: "Gorska, A. and Krawiec, M. Calendar Effects in the Market of Crude Oil. Quantitative Methods in Economics 16(4), 2015. URL https://ageconsearch.umn.edu/record/230857/files/2015_4_7.pdf"
sources:
  - "[[sources/GORSKA-WTI-CAL-2015]]"
concepts:
  - "[[concepts/crude-oil-month-of-year-seasonality]]"
  - "[[concepts/calendar-premium]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, month-of-year, atr-hard-stop, time-stop, long-only]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "February-only D1 WTI month-of-year sleeve; estimate 18-22 entries/year after weekends, broker holidays, and framework filters."
expected_trades_per_year_per_symbol: 20
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-27
g0_approval_reasoning: "R1 PASS academic WTI calendar-effects source; R2 PASS deterministic February D1 long/time-flat rule with ATR stop; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.08
expected_dd_pct: 16.0
---

# WTI February Calendar Premium

## Source

- Source: [[sources/GORSKA-WTI-CAL-2015]]
- Primary citation: Gorska, A. and Krawiec, M., "Calendar Effects in the Market
  of Crude Oil", Quantitative Methods in Economics, 16(4), 2015, URL
  https://ageconsearch.umn.edu/record/230857/files/2015_4_7.pdf.

## Concept

Academic WTI calendar-effects research reports month-of-year seasonality in
crude-oil returns, with February the strongest positive month in the studied
WTI sample. This card isolates that month-of-year effect as a low-frequency
XTIUSD.DWX sleeve: take long-only D1 exposure during February and flatten each
entry after one D1 bar unless the ATR hard stop or framework Friday close acts
first.

This is deliberately different from:

- `QM5_12596_wti-mon-fade` and `QM5_12597_wti-fri-prem`: this card is a
  month-of-year February premium, not a generic weekday rule.
- `QM5_12576_eia-wti-season`: not broad EIA refined-product demand seasonality,
  not SMA/ROC-confirmed monthly hold logic, and February is neutral in that
  card.
- `QM5_12579`, `QM5_12590`, and `QM5_12592`: not WPSR continuation, fade, or
  pre-event positioning.
- `QM5_12591`, `QM5_12593`, and `QM5_12598`: not hurricane, refinery, or OPEC
  event-window logic.
- `QM5_12594_yang-wti-reversal`: not medium-term return-extreme reversal.
- `QM5_12567_cum-rsi2-commodity`: no RSI or oscillator pullback logic.

## Markets And Timeframe

- Symbol: XTIUSD.DWX.
- Period: D1.
- Expected trade frequency: about 18-22 trades/year.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no futures curve,
  inventory feed, EIA feed, CFTC data, CSV, API, analyst forecast, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Current broker-calendar D1 bar must be in February.
- Entry direction is long only: BUY XTIUSD.DWX at market.
- Use ATR(`strategy_atr_period`) on prior completed D1 bars for the hard stop.
- No entry if an open XTIUSD.DWX position already exists for this EA magic.
- No entry if XTIUSD.DWX spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Close the position on the first new D1 bar after entry.
- Close immediately if the current D1 bar is no longer in February.
- Also close after `strategy_max_hold_days` calendar days as a stale-position
  guard.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade XTIUSD.DWX on D1.
- Skip entries when ATR is unavailable.
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

- name: strategy_entry_month
  default: 2
  sweep_range: [2]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.25
  sweep_range: [1.5, 2.25, 3.0]
- name: strategy_max_hold_days
  default: 1
  sweep_range: [1, 2]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The source is used for structural lineage around month-of-year seasonality in
WTI returns, including February as the strongest positive average-return month
in the studied sample. No source performance number is imported into QM; the
Q02+ pipeline tests the rule on Darwinex XTIUSD.DWX bars.

## Initial Risk Profile

- expected_pf: 1.08
- expected_dd_pct: 16
- expected_trade_frequency: approximately 18-22 trades/year.
- risk_class: medium.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: academic WTI crude-oil calendar-effects paper.
- [x] R2 mechanical: fixed broker-calendar month, single D1 long entry, ATR
  stop, next-bar/month-end time exit.
- [x] R3 testable: XTIUSD.DWX exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one
  position per magic.
- [x] Non-duplicate: February month-of-year premium is not the existing weekday,
  monthly demand, WPSR, refinery, hurricane, OPEC, reversal, ratio, or RSI
  commodity sleeve.

## Framework Alignment

- no_trade: D1 and XTIUSD.DWX guard, parameter guard, spread cap.
- trade_entry: February broker-calendar long entry.
- trade_management: first post-entry D1 bar, month-end, and max-hold stale
  position exits.
- trade_close: hard ATR stop plus deterministic time exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-27 | initial structural WTI February calendar-premium build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-27 | APPROVED | this card |
