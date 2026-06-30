---
ea_id: QM5_12818
slug: xng-tue-prem
type: strategy
source_id: MEEK-HOELSCHER-XNG-DOW-2023
source_citation: "Meek, H. and Hoelscher, S. A. Day-of-the-week effect: Petroleum and petroleum products. Cogent Economics and Finance 11(1), 2023. DOI https://doi.org/10.1080/23322039.2023.2213876; open pointer https://www.econstor.eu/handle/10419/304091"
source_citations:
  - type: peer_reviewed_article
    citation: "Meek, H. and Hoelscher, S. A. Day-of-the-week effect: Petroleum and petroleum products. Cogent Economics and Finance 11(1), 2023."
    location: "https://doi.org/10.1080/23322039.2023.2213876"
    quality_tier: A
    role: primary
sources:
  - "[[sources/MEEK-HOELSCHER-XNG-DOW-2023]]"
concepts:
  - "[[concepts/natural-gas-day-of-week-seasonality]]"
  - "[[concepts/tuesday-calendar-premium]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, day-of-week, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12818_XNG_TUE_PREM_D1
period: D1
expected_trade_frequency: "Weekly D1 natural-gas Tuesday-calendar premium sleeve; estimate 45-52 trades/year after broker holidays and framework filters."
expected_trades_per_year_per_symbol: 48
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-30
expected_pf: 1.08
expected_dd_pct: 23.0
g0_approval_reasoning: "R1 PASS peer-reviewed petroleum and natural-gas day-of-week source; R2 PASS deterministic Tuesday D1 long/next-bar flat rule with ATR stop; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
---

# XNG Tuesday Calendar Premium

## Source

- Source: [[sources/MEEK-HOELSCHER-XNG-DOW-2023]]
- Primary citation: Meek, H. and Hoelscher, S. A., "Day-of-the-week effect:
  Petroleum and petroleum products", Cogent Economics and Finance 11(1), 2023,
  DOI https://doi.org/10.1080/23322039.2023.2213876.
- Open repository pointer: https://www.econstor.eu/handle/10419/304091.

## Concept

The peer-reviewed source studies day-of-week structure across petroleum markets
and Natural Gas. It reports positive Natural Gas weekday structure on Monday and
Tuesday and a negative Thursday effect. This card isolates only the Tuesday leg
as a low-frequency Darwinex CFD sleeve: buy `XNGUSD.DWX` on the
broker-calendar Tuesday D1 bar and flatten on the first subsequent non-Tuesday
D1 bar.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator, short-horizon pullback,
  ML, grid, or martingale logic.
- `QM5_12806_xng-rev-weekend`: that card buys Monday and sells Friday as a
  reverse-weekend profile. This card trades Tuesday only and never shorts.
- `QM5_12738_xng-weekend-gap`: no Monday weather gap, gap continuation, or
  prior-Friday close comparison.
- XNG storage, storage fade, storage inside-bar breakout, prestorage,
  hurricane, freeze-fade, LNG, month-open breakout, 52-week anchor, broad
  winter/summer/fall/spring seasonality, and XTI/XNG baskets: no event feed,
  storage timing, monthly window, breakout channel, relative-value basket, or
  multi-month trend/reversal rule is used.

## hypothesis

Natural Gas can carry weekday return asymmetry because demand, storage, and
weather expectations are repriced unevenly through the trading week. If the
Tuesday premium reported in the source survives the Darwinex `XNGUSD.DWX` CFD
realization, a Tuesday-only long sleeve should add a different energy exposure
than RSI pullback, broad seasonality, storage events, or weekend effects.

## Markets And Timeframe

- Target symbol: `XNGUSD.DWX`.
- Period: D1.
- Expected trade frequency: about 45-52 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, broker calendar, broker spread, and ATR
  only. No storage report, weather feed, EIA feed, futures curve, CSV, API,
  analyst forecast, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Current broker-calendar D1 bar must be Tuesday, using MQL5
  `day_of_week == 2`.
- Entry direction is long only: BUY `XNGUSD.DWX` at market.
- Use ATR(`strategy_atr_period`) on prior completed D1 bars for the hard stop.
- No entry if an open `XNGUSD.DWX` position already exists for this EA magic.
- No entry if `XNGUSD.DWX` spread exceeds `strategy_max_spread_points`.

## rules

- Trade only `XNGUSD.DWX` on D1.
- Buy the broker-calendar Tuesday bar only.
- Place a hard stop at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult` from entry.
- Close on the first new D1 bar whose broker-calendar day is not Tuesday, or
  after `strategy_max_hold_days` calendar days.
- Do not pyramid, grid, martingale, trail, partial-close, or call external data.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close the position on the first new D1 bar whose broker-calendar day is not
  Tuesday.
- Also close after `strategy_max_hold_days` calendar days as a stale-position
  guard.
- Friday close remains enabled by the V5 framework.

## Filters

- Host chart must be `XNGUSD.DWX` on D1.
- Magic slot must be 0.
- Skip entries when ATR or broker-calendar state is unavailable.
- Framework news, kill-switch, magic, spread, and Friday-close guards remain
  active.

## Trade Management Rules

- Long-only.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_entry_dow
  default: 2
  sweep_range: [2]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.75
  sweep_range: [2.0, 2.75, 3.5]
- name: strategy_max_hold_days
  default: 1
  sweep_range: [1, 2]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]

## Author Claims

The source is used for structural lineage around Natural Gas day-of-week
effects. No source performance number is imported into QM. The Q02+ pipeline
must test the deterministic Tuesday-long realization on Darwinex `XNGUSD.DWX`
bars.

## risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XNGUSD.DWX` D1
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, or the portfolio gate.

## Initial Risk Profile

- expected_pf: 1.08
- expected_dd_pct: 23
- expected_trade_frequency: approximately 45-52 trades/year.
- risk_class: high for natural-gas volatility and weekday event risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: peer-reviewed petroleum/Natural Gas DOW article
  with DOI and repository pointer; exactly one `source_id`.
- [x] R2 mechanical: fixed broker-calendar Tuesday, single D1 long entry, ATR
  stop, and next-bar/time exit.
- [x] R3 testable: `XNGUSD.DWX` exists in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  and one position per magic.
- [x] Non-duplicate: Tuesday-only Natural Gas long premium is not RSI2
  commodity pullback, Monday/Friday reverse weekend, Monday gap continuation,
  XNG storage/weather/seasonality/event logic, XNG 52-week anchor, XNG
  month-open breakout, XNG volatility-shock fade, or an energy ratio basket.

## Framework Alignment

- no_trade: D1 and `XNGUSD.DWX` guard, slot guard, parameter guard, spread cap.
- trade_entry: Tuesday broker-calendar D1 long entry.
- trade_management: non-Tuesday stale exit and max-hold guard.
- trade_close: hard ATR stop plus deterministic time exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-30 | initial structural XNG Tuesday calendar-premium card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-30 | APPROVED | this card |
