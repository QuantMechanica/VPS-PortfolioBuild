---
ea_id: QM5_12806
slug: xng-rev-weekend
type: strategy
source_id: TGIF-XNG-WEEKEND-2017
source_citation: "Hoelscher, S. A., Mbanga, C. L., and Nelson, G. S. TGIF? The Weekend Effect in Energy Commodities. Journal of Finance Issues. URL https://jfi-aof.org/index.php/jfi/article/view/2264"
source_citations:
  - type: paper
    citation: "Hoelscher, S. A., Mbanga, C. L., and Nelson, G. S. TGIF? The Weekend Effect in Energy Commodities. Journal of Finance Issues."
    location: "natural gas weekend-effect results"
    quality_tier: A
    role: primary
sources:
  - "[[sources/TGIF-XNG-WEEKEND-2017]]"
concepts:
  - "[[concepts/natural-gas-weekend-effect]]"
  - "[[concepts/reverse-weekend-effect]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, day-of-week, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Weekly D1 natural-gas reverse-weekend sleeve; estimate 85-105 entries/year after broker holidays, spread, news, and one-position filters."
expected_trades_per_year_per_symbol: 96
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-29
g0_approval_reasoning: "R1 PASS academic energy-commodity weekend-effect source; R2 PASS deterministic Monday long and Friday short D1 calendar rule with ATR stop and next-session exits; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.08
expected_dd_pct: 22.0
---

# Natural Gas Reverse Weekend Effect

## Source

- Source: [[sources/TGIF-XNG-WEEKEND-2017]]
- Primary citation: Hoelscher, S. A., Mbanga, C. L., and Nelson, G. S.,
  "TGIF? The Weekend Effect in Energy Commodities", Journal of Finance Issues,
  URL https://jfi-aof.org/index.php/jfi/article/view/2264.

## Concept

The source studies weekend effects across energy commodities and reports a
reverse weekend profile in natural gas. This card converts that structural
calendar anomaly into a low-frequency Darwinex CFD sleeve: buy the
broker-calendar Monday D1 bar, sell the broker-calendar Friday D1 bar, and
flatten on the first subsequent D1 bar or by a stale-position guard.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator, or short-horizon pullback
  logic.
- `QM5_12738_xng-weekend-gap`: that card requires an ATR-normalized Monday
  weather gap and same-day continuation; this card uses pure day-of-week
  reverse-weekend seasonality and does not inspect gap direction.
- XNG winter/summer/fall/spring seasonality, storage, hurricane, freeze-fade,
  LNG, prestorage, storage-report, and weekend-gap cards: no weather shock,
  inventory/event timing, month-of-year window, or gap/body trigger is used.
- XTI/XNG, oil/gold, oil/silver, and XAU/XAG baskets: this is single-symbol
  natural-gas calendar exposure, not a market-neutral spread.

## hypothesis

Natural gas can show systematic weekend return asymmetry because weather,
storage, and demand expectations are repriced around the weekend while the
tradable market is closed or thin. If the reverse weekend effect survives the
Darwinex `XNGUSD.DWX` CFD realization, Monday long exposure and Friday short
exposure should add a different natural-gas sleeve than RSI pullback or broad
seasonality.

## Markets And Timeframe

- Target symbol: `XNGUSD.DWX`.
- Period: D1.
- Expected trade frequency: about 85-105 entries/year.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no storage report,
  weather feed, EIA feed, futures curve, CSV, API, analyst forecast, or ML
  model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Current broker-calendar D1 bar must be Monday or Friday.
- Monday entry direction is long: BUY `XNGUSD.DWX`.
- Friday entry direction is short: SELL `XNGUSD.DWX`.
- Use ATR(`strategy_atr_period`) on prior completed D1 bars for the hard stop.
- No entry if an open `XNGUSD.DWX` position already exists for this EA magic.
- No entry if `XNGUSD.DWX` spread exceeds `strategy_max_spread_points`.

## rules

- Trade only `XNGUSD.DWX` on D1.
- Buy the broker-calendar Monday bar when `strategy_enable_monday_long=true`.
- Sell the broker-calendar Friday bar when `strategy_enable_friday_short=true`.
- Place a hard stop at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult` from entry.
- Close on the first new D1 bar that is not the entry weekday, or after
  `strategy_max_hold_days` calendar days.
- Do not pyramid, grid, martingale, trail, partial-close, or call external data.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close Monday-long exposure on the first non-Monday D1 bar.
- Close Friday-short exposure on the first non-Friday D1 bar or by framework
  Friday close if still open.
- Also close after `strategy_max_hold_days` calendar days as a stale-position
  guard.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XNGUSD.DWX` on D1.
- Magic slot must be 0.
- Skip entries when ATR or broker-calendar D1 state is unavailable.
- Framework news, kill-switch, magic, spread, and Friday-close guards remain
  active.

## Trade Management Rules

- Monday long / Friday short.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.50
  sweep_range: [2.0, 2.5, 3.0]
- name: strategy_max_hold_days
  default: 1
  sweep_range: [1, 2]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]
- name: strategy_enable_monday_long
  default: true
  sweep_range: [true, false]
- name: strategy_enable_friday_short
  default: true
  sweep_range: [true, false]

## Author Claims

The source is used for structural lineage around energy weekend effects and
the reported reverse weekend effect in natural gas. No source performance
number is imported into QM; Q02 and later phases must validate the rule on
Darwinex `XNGUSD.DWX` bars.

## risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XNGUSD.DWX` D1
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, or the portfolio gate.

## Initial Risk Profile

- expected_pf: 1.08
- expected_dd_pct: 22
- expected_trade_frequency: approximately 85-105 trades/year.
- risk_class: high for natural-gas volatility and weekend headline risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: academic energy-commodity weekend-effect paper.
- [x] R2 mechanical: fixed broker-calendar Monday/Friday direction, ATR stop,
  and deterministic time exits.
- [x] R3 testable: `XNGUSD.DWX` exists in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  one position per magic.
- [x] Non-duplicate: reverse-weekend XNG day-of-week logic is not RSI
  commodity pullback, XNG weekend-gap continuation, XNG seasonality/event
  sleeves, XTI/XNG relative value, or WTI weekend-effect logic.

## Framework Alignment

- no_trade: D1 and `XNGUSD.DWX` guard, slot guard, parameter guard, spread cap.
- trade_entry: Monday broker-calendar long entry and Friday broker-calendar
  short entry.
- trade_management: first non-entry-weekday D1 bar and max-hold stale-position
  exits.
- trade_close: hard ATR stop plus deterministic time exits and framework
  Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-29 | initial structural XNG reverse-weekend build | G0 | APPROVED |
| v1-q02 | 2026-06-29 | build compiled and Q02 work item enqueued | Q02 | PENDING 6926273a-22be-40e5-aa81-9c60c7ef0ac1 |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-29 | APPROVED | this card |
| Q01 Build Validation | 2026-06-29 | PASS | `artifacts/qm5_12806_build_result.json` |
| Q02 Baseline Screening | 2026-06-29 | PENDING | `docs/ops/evidence/2026-06-29_qm5_12806_xng_rev_weekend_q02_enqueue.md` |
