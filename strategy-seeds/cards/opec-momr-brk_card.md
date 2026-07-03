---
ea_id: QM5_12995
slug: opec-momr-brk
type: strategy
strategy_id: OPEC-MOMR-XTI-BRK-2026
source_id: OPEC-MOMR-XTI-BRK-2026
source_citation: "Organization of the Petroleum Exporting Countries. Monthly Oil Market Report. https://www.opec.org/monthly-oil-market-report.html"
source_citations:
  - type: official_report
    citation: "Organization of the Petroleum Exporting Countries. Monthly Oil Market Report."
    location: "https://www.opec.org/monthly-oil-market-report.html"
    quality_tier: A
    role: primary
sources:
  - "[[sources/OPEC-MOMR-XTI-BRK-2026]]"
concepts:
  - "[[concepts/monthly-energy-information-window]]"
  - "[[concepts/crude-oil-forecast-reaction]]"
  - "[[concepts/d1-breakout-continuation]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/donchian-breakout]]"
strategy_type_flags: [calendar-anomaly, official-release-window, channel-breakout, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy]
single_symbol_only: true
logical_symbol: QM5_12995_XTI_OPEC_MOMR_BRK_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Monthly OPEC MOMR proxy-window D1 breakout; at most one package per month, roughly 4-9 entries/year after range/body/breakout filters."
expected_trades_per_year_per_symbol: 7
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
g0_approval_reasoning: "R1 PASS official OPEC MOMR source and release dates; R2 PASS deterministic monthly proxy window, D1 ATR-sized breakout, ATR stop/target, and time exit; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed."
---

# OPEC MOMR WTI Breakout

## Hypothesis

The OPEC Monthly Oil Market Report is a scheduled official oil-market report
covering demand, supply, and market-balance context. This card tests whether a
large directional `XTIUSD.DWX` D1 breakout inside the MOMR release proxy window
carries through for several sessions.

The strategy is intended to add a crude-oil information-window sleeve to the
current XAU/SP500/NDX/XNG book. It is not XAU/XAG, not XNG, not an OPEC
Conference June/December meeting-risk sleeve, not EIA STEO, not IEA OMR, not
WPSR/Cushing/refinery/rig-count/roll/expiry/month-seasonality/carry/reversal,
and not `QM5_12567_cum-rsi2-commodity` oscillator pullback logic.

## Source

- Primary: OPEC, Monthly Oil Market Report. URL:
  https://www.opec.org/monthly-oil-market-report.html.

## Concept

The EA uses only Darwinex `XTIUSD.DWX` D1 OHLC, ATR, spread, broker-calendar
dates, and V5 framework state. It does not read MOMR contents at runtime. The
event day is approximated by a fixed broker-calendar window covering day 10
through day 14 of each month, matching the official 2026 OPEC MOMR release-date
cluster documented on the OPEC page.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: `D1`.
- Expected frequency: at most one signal per monthly MOMR cycle, about 4-9
  entries/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, broker calendar, and V5
  framework state only.

## Entry Rules

- Evaluate only on a new `XTIUSD.DWX` D1 bar.
- Inspect the previous completed D1 bar.
- The previous completed D1 bar must be inside the OPEC MOMR proxy window:
  broker-calendar day `strategy_event_start_day` through
  `strategy_event_end_day`.
- Compute ATR on completed D1 bars.
- Require the proxy bar range to be at least
  `strategy_min_range_atr * ATR`.
- Require the absolute body to be at least `strategy_min_body_atr * ATR`.
- Long entry: proxy bar closes above its open and above the prior Donchian high.
- Short entry: proxy bar closes below its open and below the prior Donchian low.
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
  default: 14
  sweep_range: [13, 14, 15]
- name: strategy_breakout_lookback
  default: 20
  sweep_range: [10, 20, 30]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_range_atr
  default: 1.00
  sweep_range: [0.75, 1.00, 1.25]
- name: strategy_min_body_atr
  default: 0.35
  sweep_range: [0.25, 0.35, 0.50]
- name: strategy_atr_sl_mult
  default: 2.5
  sweep_range: [2.0, 2.5, 3.0]
- name: strategy_atr_tp_mult
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 5
  sweep_range: [3, 5, 8]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The source establishes the official monthly report and release-date lineage.
This card imports no source performance claim. Q02 and later phases must
validate or reject the mechanical `XTIUSD.DWX` realization on Darwinex bars.

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 4-9 entries/year.
- risk_class: medium-high because crude-oil gaps and the small monthly sample
  require Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official OPEC MOMR page and release dates.
- [x] R2 mechanical: fixed proxy window, D1 breakout condition, ATR hard
  stop/target, and deterministic time exit.
- [x] R3 testable: `XTIUSD.DWX` exists in the DWX symbol universe.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic.
- [x] Non-duplicate: not XAU/XAG, not XNG, not OPEC meeting, EIA STEO, IEA OMR,
  WTI WPSR/Cushing/refinery/rig-count/roll/expiry/weekday/month-seasonality/
  carry/reversal/ORB/RSI logic.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX` D1
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: XTI/D1 host guard, magic-slot guard, parameter guard, spread cap,
  and valid data checks.
- trade_entry: monthly OPEC MOMR proxy-window ATR breakout continuation.
- trade_management: max-hold stale-position exit.
- trade_close: hard ATR stop/target plus deterministic strategy exits and
  framework Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-03 | initial WTI OPEC MOMR breakout card | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-03 | APPROVED | this card |
| Q01 Build Validation | 2026-07-03 | PASS | `artifacts/qm5_12995_build_result.json` |
| Q02 Baseline Screening | 2026-07-03 | QUEUED | `artifacts/qm5_12995_q02_enqueue_20260703.json` |
