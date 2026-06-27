---
ea_id: QM5_12610
slug: wti-tue-fade
type: strategy
source_id: GORSKA-WTI-CAL-2015
source_citation: "Gorska, A. and Krawiec, M. Calendar Effects in the Market of Crude Oil. Quantitative Methods in Economics 16(4), 2015. URL https://ageconsearch.umn.edu/record/230857/files/2015_4_7.pdf"
sources:
  - "[[sources/GORSKA-WTI-CAL-2015]]"
concepts:
  - "[[concepts/crude-oil-day-of-week-seasonality]]"
  - "[[concepts/weekday-calendar-premium]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, day-of-week, atr-hard-stop, time-stop, short-only]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Weekly D1 WTI Tuesday negative-return sleeve; estimate 45-52 trades/year after broker holidays and framework filters."
expected_trades_per_year_per_symbol: 48
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-27
g0_approval_reasoning: "R1 PASS academic WTI calendar-effects source; R2 PASS deterministic Tuesday D1 short/next-bar flat rule with ATR stop; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.08
expected_dd_pct: 16.0
---

# WTI Tuesday Seasonality Fade

## Source

- Source: [[sources/GORSKA-WTI-CAL-2015]]
- Primary citation: Gorska, A. and Krawiec, M., "Calendar Effects in the Market
  of Crude Oil", Quantitative Methods in Economics, 16(4), 2015, URL
  https://ageconsearch.umn.edu/record/230857/files/2015_4_7.pdf.

## Concept

Academic WTI calendar-effects research reports weekday return structure in
crude oil, including negative Tuesday average WTI returns in the studied
2000-2014 sample. This card isolates that calendar effect as a low-frequency
XTIUSD.DWX sleeve: short only on the broker-calendar Tuesday D1 bar and flatten
on the next D1 bar.

This is deliberately different from:

- `QM5_12596_wti-mon-fade`: Monday short side from a different weekday.
- `QM5_12597_wti-fri-prem`: Friday long side, opposite weekday and direction.
- `QM5_12599_wti-feb-prem`: month-of-year February premium, not weekday.
- `QM5_12576_eia-wti-season`: broad EIA refined-product demand seasonality.
- `QM5_12579`, `QM5_12590`, and `QM5_12592`: not WPSR continuation, fade, or
  pre-event positioning.
- `QM5_12591`, `QM5_12593`, `QM5_12598`, and `QM5_12600`: not hurricane,
  refinery, OPEC, or expiry-window logic.
- `QM5_12603_wti-tsmom12m`: not 12-month return-sign trend following.
- `QM5_12567_cum-rsi2-commodity`: no RSI or oscillator pullback logic.

## Markets And Timeframe

- Symbol: XTIUSD.DWX.
- Period: D1.
- Expected trade frequency: about 45-52 trades/year.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no futures curve,
  inventory feed, EIA feed, CFTC data, CSV, API, analyst forecast, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Current broker-calendar D1 bar must be Tuesday.
- Entry direction is short only: SELL XTIUSD.DWX at market.
- Use ATR(`strategy_atr_period`) on prior completed D1 bars for the hard stop.
- No entry if an open XTIUSD.DWX position already exists for this EA magic.
- No entry if XTIUSD.DWX spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Close the position on the first new D1 bar after Tuesday.
- Also close after `strategy_max_hold_days` calendar days as a stale-position guard.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade XTIUSD.DWX on D1.
- Skip entries when ATR is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Short-only.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## 8. Parameters To Test

- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.25
  sweep_range: [1.5, 2.25, 3.0]
- name: strategy_max_hold_days
  default: 1
  sweep_range: [1, 2]
- name: strategy_entry_dow
  default: 2
  sweep_range: [2]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The source is used for structural lineage around day-of-week seasonality in WTI
returns, including negative Tuesday average returns in the paper's weekday
table. No source performance number is imported into QM; the Q02+ pipeline
tests the rule on Darwinex XTIUSD.DWX bars.

## Initial Risk Profile

- expected_pf: 1.08
- expected_dd_pct: 16
- expected_trade_frequency: approximately 45-52 trades/year.
- risk_class: medium.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: academic crude-oil calendar-effects paper.
- [x] R2 mechanical: fixed broker-calendar weekday, single D1 short entry, ATR
  stop, and next-bar exit.
- [x] R3 testable: XTIUSD.DWX exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one
  position per magic.
- [x] Non-duplicate: Tuesday short is not the existing Monday short, Friday
  long, February month, WTI event, WTI trend, XNG, XAU/XAG, or RSI commodity
  sleeve.

## Framework Alignment

- no_trade: D1 and XTIUSD.DWX guard, parameter guard, spread cap.
- trade_entry: Tuesday broker-calendar short entry.
- trade_management: first non-Tuesday D1 bar and max-hold stale-position exits.
- trade_close: hard ATR stop plus deterministic time exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-27 | initial structural WTI Tuesday weekday-seasonality build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-27 | APPROVED | this card |
