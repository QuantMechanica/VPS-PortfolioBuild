---
ea_id: QM5_12994
slug: iea-omr-fade
type: strategy
strategy_id: IEA-OMR-XTI-FADE-2026_S01
source_id: IEA-OMR-XTI-FADE-2026
source_citation: "International Energy Agency, Oil Market Report (OMR), https://www.iea.org/data-and-statistics/data-product/oil-market-report-omr; IEA Oil Market Report monthly analysis pages, https://www.iea.org/reports/oil-market-report-june-2026"
source_citations:
  - type: official_report
    citation: "International Energy Agency. Oil Market Report (OMR)."
    location: "https://www.iea.org/data-and-statistics/data-product/oil-market-report-omr"
    quality_tier: A
    role: primary
  - type: official_report
    citation: "International Energy Agency. Oil Market Report - June 2026."
    location: "https://www.iea.org/reports/oil-market-report-june-2026"
    quality_tier: A
    role: structural_context
sources:
  - "[[sources/IEA-OMR-XTI-FADE-2026]]"
concepts:
  - "[[concepts/monthly-oil-market-information-window]]"
  - "[[concepts/report-window-shock-fade]]"
  - "[[concepts/crude-oil-forecast-reaction]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-anomaly, official-release-window, shock-fade, atr-hard-stop, time-stop, symmetric-long-short, low-frequency, energy]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy]
single_symbol_only: true
logical_symbol: QM5_12994_XTI_IEA_OMR_FADE_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Monthly IEA OMR D1 shock-fade proxy; at most one entry per month, roughly 4-10 entries/year after range/body/window filters."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-03
expected_pf: 1.08
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-03: R1 PASS official IEA OMR source and monthly oil-market report pages; R2 PASS deterministic mid-month release-window proxy, D1 ATR-sized shock-fade entry, ATR stop/target, and time exit; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed."
---

# IEA OMR WTI Shock Fade

## Hypothesis

The IEA Oil Market Report is a scheduled monthly official oil-market reference
covering supply, demand, inventories, prices, refinery activity, and oil trade.
This card does not attempt to read or forecast the report contents. It tests
whether unusually large `XTIUSD.DWX` D1 moves inside the mid-month OMR release
window overreact and partially mean-revert over the next few sessions.

This is intended as a crude-oil information-window sleeve for the current
XAU/SP500/NDX/XNG book. It is deliberately different from `QM5_12992_eia-steo-brk`:
that EA follows EIA STEO breakout continuation on a computed EIA release proxy,
while this card fades an IEA OMR mid-month shock bar. It is also not WPSR,
Cushing, refinery, rig-count, OPEC, roll, expiry, weekday, month-seasonality,
XTI/XNG, XAU/XAG, commodity carry/reversal, or `QM5_12567_cum-rsi2-commodity`
oscillator pullback logic.

## Source

- Primary: International Energy Agency, Oil Market Report (OMR), URL
  https://www.iea.org/data-and-statistics/data-product/oil-market-report-omr.
- Structural context: International Energy Agency, Oil Market Report monthly
  analysis pages, including June 2026, URL
  https://www.iea.org/reports/oil-market-report-june-2026.

## Concept

The source establishes an official monthly oil-market information event. The EA
uses only Darwinex `XTIUSD.DWX` D1 OHLC, ATR, spread, broker-calendar dates, and
V5 framework state. Runtime never reads IEA data, PDFs, calendars, APIs, CSVs,
or analyst forecasts.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: `D1`.
- Expected frequency: at most one signal per monthly OMR cycle, about 4-10
  entries/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, broker calendar, and V5
  framework state only.

## Entry Rules

- Evaluate only on a new `XTIUSD.DWX` D1 bar.
- Inspect the previous completed D1 bar.
- The previous completed D1 bar must fall inside the OMR proxy window:
  broker-calendar day `strategy_event_start_day` through
  `strategy_event_end_day`, default 10 through 18.
- Compute ATR on completed D1 bars.
- Require event-bar range to be at least `strategy_min_range_atr * ATR`.
- Require absolute event-bar body to be at least `strategy_min_body_atr * ATR`.
- Require event-bar close location to be extreme:
  at or above `strategy_close_location_extreme` for an up shock, or at or below
  `1 - strategy_close_location_extreme` for a down shock.
- Up-shock fade: if the event bar closes above its open and near the high, sell
  `XTIUSD.DWX` on the next D1 bar.
- Down-shock fade: if the event bar closes below its open and near the low, buy
  `XTIUSD.DWX` on the next D1 bar.
- No more than one entry per broker-calendar month.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Profit target: fixed TP at ATR(`strategy_atr_period`) *
  `strategy_atr_tp_mult`.
- Close after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Magic slot offset must be 0.
- Skip entries when D1 history, ATR, event-calendar state, spread, entry price,
  or stop/target prices are unavailable.
- Framework news, kill-switch, magic, risk, and Friday-close guards remain
  active.

## Trade Management Rules

- Symmetric long/short.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_event_start_day
  default: 10
  sweep_range: [9, 10, 11]
- name: strategy_event_end_day
  default: 18
  sweep_range: [16, 18, 20]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_range_atr
  default: 1.10
  sweep_range: [0.90, 1.10, 1.30]
- name: strategy_min_body_atr
  default: 0.35
  sweep_range: [0.25, 0.35, 0.50]
- name: strategy_close_location_extreme
  default: 0.75
  sweep_range: [0.70, 0.75, 0.80]
- name: strategy_atr_sl_mult
  default: 2.5
  sweep_range: [2.0, 2.5, 3.0]
- name: strategy_atr_tp_mult
  default: 1.5
  sweep_range: [1.0, 1.5, 2.0]
- name: strategy_max_hold_days
  default: 4
  sweep_range: [3, 4, 6]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The source establishes monthly official oil-market report lineage and oil-market
context. This card imports no source performance claim. Q02 and later phases
must validate or reject the mechanical `XTIUSD.DWX` realization on Darwinex
bars.

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 4-10 entries/year.
- risk_class: medium-high because crude-oil gaps and the low-frequency sample
  require Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official IEA Oil Market Report source and monthly
  analysis pages.
- [x] R2 mechanical: fixed mid-month release-window proxy, ATR-sized shock-fade
  condition, ATR hard stop/target, and deterministic time exit.
- [x] R3 testable: `XTIUSD.DWX` exists in the DWX symbol universe.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic.
- [x] Non-duplicate: not EIA STEO breakout continuation, not WPSR/Cushing/
  refinery/rig-count/OPEC/roll/expiry/weekday/month-seasonality/carry/reversal/
  ORB/RSI logic, and not an XTI/XNG or metal relative-value basket.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX` D1
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: XTI/D1 host guard, magic-slot guard, parameter guard, spread cap,
  and valid data checks.
- trade_entry: monthly IEA OMR proxy-window ATR shock fade.
- trade_management: max-hold stale-position exit.
- trade_close: hard ATR stop/target plus deterministic strategy exits and
  framework Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-03 | initial IEA OMR WTI shock-fade card | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-03 | APPROVED | this card |
| Q01 Build Validation | 2026-07-03 | PASS | `artifacts/qm5_12994_build_result.json` |
| Q02 Baseline Screening | 2026-07-03 | QUEUED | `artifacts/qm5_12994_q02_enqueue_20260703.json` |
