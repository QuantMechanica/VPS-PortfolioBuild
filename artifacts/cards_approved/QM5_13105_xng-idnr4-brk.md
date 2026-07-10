---
ea_id: QM5_13105
slug: xng-idnr4-brk
type: strategy
strategy_id: CRABEL-XNG-IDNR4-2026_S01
source_id: CRABEL-XNG-IDNR4-2026
status: APPROVED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
g0_status: APPROVED
source_citation: "Crabel, Toby. Day Trading with Short-Term Price Patterns and Opening Range Breakout. Traders Press, 1990. ISBN 9780934380171."
source_citations:
  - type: book
    citation: "Crabel, Toby. Day Trading with Short-Term Price Patterns and Opening Range Breakout. Traders Press, 1990. ISBN 9780934380171."
    location: "Sections on patterns of expansion and contraction, ID/NR4, and opening-range breakouts."
    quality_tier: A
    role: primary
  - type: article
    citation: "Crabel, Toby. Playing the Opening Range Breakout, Part 1. Technical Analysis of Stocks & Commodities, Vol. 6:9, pp. 337-339, 1988."
    location: "Opening-range breakout definitions and daily-bias study."
    quality_tier: A
    role: supplement
source_links:
  - "https://books.google.com/books?id=xpgbAAAACAAJ"
sources:
  - "[[sources/CRABEL-XNG-IDNR4-2026]]"
concepts:
  - "[[concepts/narrow-range-breakout]]"
  - "[[concepts/volatility-compression-expansion]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [narrow-range-breakout, atr-hard-stop, time-stop, symmetric-long-short, friday-close-flatten]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [commodities, energy, natural_gas]
single_symbol_only: true
logical_symbol: QM5_13105_XNG_IDNR4_BRK_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 XNG ID/NR4 contraction followed by an immediate next-session close breakout; estimate 8-18 completed trades/year before Q02 validation."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.05
expected_dd_pct: 24.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Adds XNG volatility-expansion exposure that is mechanically distinct from QM5_12567 cumulative-RSI pullback; portfolio orthogonality remains a Q09 evidence question."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-10: R1 PASS Crabel book and primary-author article; R2 PASS fixed D1 ID/NR4 plus next-session close breakout, structural stop, 2R target, and time exit; R3 PASS XNGUSD.DWX registered; R4 PASS native OHLC only with no ML, grid, martingale, or external feed."
---

# XNG ID/NR4 Contraction Breakout

## Hypothesis

Crabel's ID/NR4 setup isolates an unusually tight daily range that is also
fully contained by the prior session. This is a structural volatility-
contraction state; a close outside the setup on the immediately following
session tests whether natural-gas range expansion persists far enough to pay
for gaps and CFD spread.

The return driver is XNG price expansion after compression. It is not the
cumulative-RSI2 commodity pullback in `QM5_12567`, a storage/news proxy, a
weekday premium, seasonal direction, long-horizon momentum/reversal, relative-
value basket, or Monday-only range rule.

## Source Citation

The primary source is Crabel's 1990 Traders Press commodity-pattern book,
supplemented by his 1988 *Technical Analysis of Stocks & Commodities* article.
The bounded extraction combines the source's inside-day/NR4 contraction
definition with its breakout lineage. No source performance statistic is
imported, and no fixed-dollar futures trigger is reused.

The Darwinex-native port makes one explicit choice: the immediately following
completed D1 bar must close outside the setup extreme. This preserves the
closed-bar contraction/expansion thesis without inventing a futures session or
contract-roll assumption.

## Concept

Only `XNGUSD.DWX` completed D1 OHLC, spread, ATR, broker calendar, and V5
framework state are read. There is no weather or storage report, futures curve,
volume, open interest, external feed, API, CSV, ML model, adaptive sizing,
grid, martingale, pyramiding, or discretionary switch.

## Target Symbols And Period

- Symbol: `XNGUSD.DWX`, magic slot 0.
- Period: D1.
- Expected frequency: 8-18 trades/year; Q02 enforces the binding five-trades-
  per-year floor.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Rules

### Setup

- Evaluate on each new `XNGUSD.DWX` D1 bar.
- Setup bar is the second-most-recent completed D1 bar; confirmation bar is the
  most recent completed D1 bar.
- Setup is a strict inside day: `setup.high < prior.high` and
  `setup.low > prior.low`.
- Setup is NR4: its high-low range is strictly smaller than each of the three
  completed D1 ranges before it.
- Setup range must be between `strategy_min_setup_range_atr * ATR(20)` and
  `strategy_max_setup_range_atr * ATR(20)`.
- Confirmation must be the immediately following completed D1 bar; stale
  setups are never carried forward.

### Entry

- Long when confirmation closes above setup high plus
  `strategy_break_buffer_atr * ATR`, is bullish, and closes in at least the top
  `strategy_min_break_close_location` fraction of its range.
- Short when confirmation closes below setup low minus the same ATR buffer, is
  bearish, and closes in at most the complementary bottom fraction.
- Enter at market on the next D1 bar after close confirmation.
- Reject if spread exceeds `strategy_max_spread_points`, a position for this
  magic is open, or setup/ATR data are invalid.

### Stop And Target

- Long stop: setup low minus `strategy_stop_buffer_atr * ATR`.
- Short stop: setup high plus the same ATR buffer.
- Profit target: `strategy_rr_target` times actual entry-to-stop risk, default
  2R.
- The structural stop and target are fixed when the trade opens.

### Exit And Management

- Close after `strategy_max_hold_days` calendar days if stop/target has not
  fired.
- Framework Friday close remains enabled at broker hour 21.
- No partial close, break-even move, trailing stop, reversal, grid, martingale,
  or pyramiding in v1.

## Filters

- Exact symbol/timeframe guard: `XNGUSD.DWX`, D1.
- Magic slot must be 0; one open position per magic/symbol.
- Parameter-domain and spread guards fail closed.
- Standard V5 kill switch, news compliance, Friday close, and connection
  protections remain authoritative.

## Parameters To Test

- name: strategy_nr_lookback
  default: 4
  sweep_range: [4]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_setup_range_atr
  default: 0.15
  sweep_range: [0.10, 0.15, 0.25]
- name: strategy_max_setup_range_atr
  default: 0.90
  sweep_range: [0.70, 0.90, 1.20]
- name: strategy_break_buffer_atr
  default: 0.05
  sweep_range: [0.00, 0.05, 0.10]
- name: strategy_min_break_close_location
  default: 0.60
  sweep_range: [0.55, 0.60, 0.70]
- name: strategy_stop_buffer_atr
  default: 0.10
  sweep_range: [0.05, 0.10, 0.20]
- name: strategy_rr_target
  default: 2.00
  sweep_range: [1.50, 2.00, 2.50]
- name: strategy_max_hold_days
  default: 5
  sweep_range: [3, 5, 8]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]

## Author Claims

No aggregate source performance claim is imported. The source supplies the
ID/NR4 definition and contraction/breakout research lineage only.

## Initial Risk Profile

- `expected_pf: 1.05` is a conservative ordering prior, not evidence.
- `expected_dd_pct: 24.0` is a risk-budget prior, not a forecast.
- Natural-gas gaps and a range-anchored stop make risk class high.
- Source silent on V5 sizing; backtests use `RISK_FIXED=1000`.

## Strategy Allowability Check

- [x] Mechanical closed-OHLC structural setup and close-confirmed entry.
- [x] No ML, external runtime feed, grid, martingale, or pyramiding.
- [x] Expected frequency is above the Q02 five-trades/year floor before test.
- [x] Friday close remains enabled.
- [x] Primary source is precisely identified and reproducible.
- [x] Non-duplicate versus XNG cumulative RSI2, NR-event, weekly momentum/
  reversal, weekday, seasonal, storage, expiry, carry, and ratio builds.

## Framework Alignment

- no_trade: symbol/timeframe, magic-slot, parameter, open-position, and spread
  guards; framework kill/news/Friday protections remain in force.
- trade_entry: D1 inside-day plus NR4 setup; immediate next-bar close breakout;
  structural stop and 2R target.
- trade_management: calendar-day max-hold close only.
- trade_close: hard structural SL/TP, max-hold close, and framework Friday
  flatten.

## Risk

Q02 falsifies the card if realized trade density is below five trades/year,
phase economics/drawdown gates fail, or evidence is missing/invalid. Portfolio
correlation is not inferred here and may only be judged at Q09 from surviving
returns. This build must not touch `T_Live`, AutoTrading, a deploy manifest,
the portfolio gate, or a live setfile.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-10 | initial structural XNG ID/NR4 build | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-10 | APPROVED by mission directive | this card |
| Q02 Baseline Screening | 2026-07-10 | QUEUED | work_items/c04d7df8-acb1-4d12-9d4d-4b48bbf857cb |
