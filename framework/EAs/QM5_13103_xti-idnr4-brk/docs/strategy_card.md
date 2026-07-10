---
ea_id: QM5_13103
slug: xti-idnr4-brk
type: strategy
strategy_id: CRABEL-WTI-IDNR4-2026_S01
source_id: CRABEL-WTI-IDNR4-2026
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
  - "[[sources/CRABEL-WTI-IDNR4-2026]]"
concepts:
  - "[[concepts/narrow-range-breakout]]"
  - "[[concepts/volatility-compression-expansion]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [narrow-range-breakout, atr-hard-stop, time-stop, symmetric-long-short, friday-close-flatten]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13103_XTI_IDNR4_BRK_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 WTI ID/NR4 contraction followed by an immediate next-session close breakout; estimate 8-18 completed trades/year before Q02 validation."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.05
expected_dd_pct: 20.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Adds solo WTI energy price-expansion exposure to the XAU/SP500/NDX/XNG book; verify return-stream orthogonality only at Q09, never by prior assertion."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-10: R1 PASS Crabel book and primary-author article; R2 PASS fixed D1 ID/NR4 plus next-session close breakout, structural stop, 2R target, time exit; R3 PASS XTIUSD.DWX registered; R4 PASS native OHLC only with no ML, grid, martingale, or external feed."
---

# XTI ID/NR4 Contraction Breakout

## Hypothesis

Crabel's ID/NR4 setup isolates an unusually tight daily range that is also
fully contained by the prior session. The combination is a structural
volatility-contraction state; a close beyond that setup on the immediately
following session tests whether WTI range expansion persists far enough to pay
for overnight gap and CFD spread risk.

The return driver is solo crude-oil price expansion, not index or metal mean
reversion and not the cumulative-RSI2 logic in `QM5_12567`. It is also distinct
from `QM5_13096` (NR7 without an inside-day requirement) and `QM5_13075`
(completed inside-week breakout).

## Source Citation

The primary source is Crabel's 1990 Traders Press commodity-trading book; the
bounded extraction is supplemented by Crabel's 1988 trade Journal article in
*Technical Analysis of Stocks & Commodities*, Vol. 6:9, pp. 337-339. Its
ID/NR4 definition combines an inside bar with the narrowest range of the latest
four daily bars; its breakout research supplies the contraction-to-expansion
lineage. The source's compact definition is: "NR4 - A decrease in daily range
relative to the previous 3 day's ranges compared individually."

The QM card does not import source performance, a fixed-dollar futures trigger,
or an intraday opening-range statistic. It makes one explicit Darwinex-native
port: the next completed D1 bar must close outside the ID/NR4 extreme. This
avoids invented contract-roll and session-open assumptions while preserving the
source's testable price-pattern thesis.

## Concept

Only `XTIUSD.DWX` closed D1 OHLC, spread, ATR, broker calendar, and framework
state are read. There is no futures curve, inventory/WPSR/OPEC/COT input,
volume, open interest, external feed, API, CSV, ML model, adaptive sizing, grid,
martingale, pyramiding, or discretionary switch.

## Target Symbols And Period

- Symbol: `XTIUSD.DWX`, magic slot 0.
- Period: D1.
- Expected frequency: 8-18 trades/year; Q02 must enforce the binding five-
  trades/year floor.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Rules

### Setup

- Evaluate on each new `XTIUSD.DWX` D1 bar.
- Setup bar is the second-most-recent completed D1 bar; confirmation bar is the
  most recent completed D1 bar.
- Setup must be an inside day: `setup.high < prior.high` and
  `setup.low > prior.low`.
- Setup must be NR4: its high-low range is strictly smaller than each of the
  three completed D1 ranges before it.
- Setup range must be between `strategy_min_setup_range_atr * ATR(20)` and
  `strategy_max_setup_range_atr * ATR(20)`.
- Confirmation must be the immediately following completed D1 bar; stale
  setups are never carried forward.

### Entry

- Long when confirmation closes above setup high plus
  `strategy_break_buffer_atr * ATR`, confirmation is bullish, and its close
  location is at least `strategy_min_break_close_location`.
- Short when confirmation closes below setup low minus the same ATR buffer,
  confirmation is bearish, and its close location is at most
  `1 - strategy_min_break_close_location`.
- Entry is at market on the next D1 bar after the close-confirmed breakout.
- Reject if spread exceeds `strategy_max_spread_points`, a position for the
  magic is already open, or the setup/ATR data are invalid.

### Stop And Target

- Long stop: setup low minus `strategy_stop_buffer_atr * ATR`.
- Short stop: setup high plus `strategy_stop_buffer_atr * ATR`.
- Profit target: `strategy_rr_target` times actual entry-to-stop risk, default
  2R.
- The stop is always structural and fixed when the order opens.

### Exit And Management

- Close after `strategy_max_hold_days` calendar days if stop/target has not
  fired.
- Framework Friday close remains enabled at broker hour 21.
- No partial close, break-even move, trailing stop, reversal, grid, martingale,
  or pyramiding in v1.

## Filters

- Exact symbol/timeframe guard: `XTIUSD.DWX`, D1.
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
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No aggregate source performance claim is imported. The source supplies the
ID/NR4 definition and contraction/breakout research lineage only.

## Initial Risk Profile

- `expected_pf: 1.05` is a conservative ordering prior, not evidence or a gate.
- `expected_dd_pct: 20.0` is a risk-budget prior, not a forecast.
- WTI overnight gaps and a range-anchored stop make risk class high.
- Source silent on V5 risk mode; use `RISK_FIXED=1000` for backtests.

## Strategy Allowability Check

- [x] Mechanical OHLC-only structural setup and close-confirmed entry.
- [x] No ML, external runtime feed, grid, martingale, or pyramiding.
- [x] Expected frequency is above the Q02 five-trades/year floor before test.
- [x] Friday close remains enabled.
- [x] Primary source is precisely identified and reproducible.
- [x] Non-duplicate against WTI NR7, inside-week, month/week ORB, calendar,
  event, ratio, carry, RSI, and XNG logic already in the farm.

## Framework Alignment

- no_trade: symbol/timeframe, magic-slot, parameter, open-position, and spread
  guards; framework kill/news/Friday protections remain in force.
- trade_entry: D1 inside-day plus NR4 setup; immediate next-bar close breakout;
  structural stop and 2R target.
- trade_management: calendar-day max-hold close only.
- trade_close: hard structural SL/TP, max-hold close, and framework Friday
  flatten.

## Risk

Q02 falsifies the card if the realized trade density is below five trades/year,
the strategy fails the phase economics/drawdown gates, or the report is missing
or invalid. Portfolio correlation is not inferred here and may only be judged
at Q09 from surviving return evidence. This build must not touch `T_Live`,
AutoTrading, a deploy manifest, the portfolio gate, or a live setfile.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-10 | initial structural WTI ID/NR4 build | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-10 | APPROVED by mission directive | this card |
