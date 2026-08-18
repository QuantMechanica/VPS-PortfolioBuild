---
source_id: CRABEL-WTI-WEEKNR7-2026
title: WTI completed-week NR7 range expansion
publisher: Traders Press
source_type: governed_trading_book_translation
status: cards_ready
approval_basis: OWNER commodity/energy portfolio mission 2026-08-18
created: 2026-08-18
created_by: Research+Development
parent_sources:
  - CRABEL-WTI-NR7-BRK-2026
  - CRABEL-WTI-WEEK-ORB-2026
strategy_ids:
  - CRABEL-WTI-WEEKNR7-2026_S01
---

# WTI Completed-Week NR7 Expansion Source Packet

## Approval And Complete-Read Scope

The OWNER mission dated 2026-08-18 directs one new structural, low-frequency
commodity or energy card, requires a reputable source, and specifically permits
an `XTIUSD` trend or seasonality edge. The following bounded governed source
records were read completely before extraction:

1. `strategy-seeds/sources/CRABEL-WTI-NR7-BRK-2026/source.md`, which records
   Toby Crabel's named 1990 Traders Press book and the narrowest-of-seven
   contraction followed by range expansion.
2. `strategy-seeds/sources/CRABEL-WTI-WEEK-ORB-2026/source.md`, which records
   the governed translation of Crabel-style range states to complete WTI
   broker weeks and later-week D1 close breakouts.

The primary citation is Toby Crabel, *Day Trading with Short-Term Price
Patterns and Opening Range Breakout*, Traders Press, 1990. The parent packets
already support a daily WTI NR7 card and separate weekly opening-range and
inside-week cards. Neither parent tests whether the immediately prior complete
WTI week is the strict narrowest of seven complete weeks and whether a later
completed close in the next week escapes that compressed week's full high-low
range.

No source return, profit factor, trade count, drawdown, threshold, hold period,
CFD equivalence, or portfolio-correlation statistic transfers. Complete-week
aggregation, energy-session label normalization, close confirmation, fixed
cash risk, hard stop, one-attempt state, and Friday-flat lifecycle are disclosed
QM choices that Q02 must falsify.

## Bounded Mechanization

`CRABEL-WTI-WEEKNR7-2026_S01` locks one `XTIUSD.DWX` D1 strategy:

- carrier: exact `XTIUSD.DWX`, D1, magic slot zero;
- session labels: accept raw D1 dates matching the broker date or one uniform
  `+1` calendar-day normalization, then apply the selected convention to all
  setup and decision bars;
- weekly sample: the immediately prior normalized broker week must contain
  exactly one completed D1 bar for each Monday through Friday; select the six
  next-most-recent valid complete weeks, allowing incomplete older holiday
  weeks to be skipped without reordering them;
- compression: compute each week's full range as maximum D1 high minus minimum
  D1 low; the immediately prior week's finite positive range must be strictly
  smaller than all six older ranges;
- trigger window: Tuesday through Friday of the immediately following broker
  week, using only the latest completed normalized D1 close;
- direction: BUY on the first close strictly above the compressed-week high;
  SELL on the first close strictly below its low; equality and non-breaks are
  flat;
- attempt: persist the current broker-Monday week key before spread, quote,
  ATR, sizing, news, or order gates once a strict break exists; never retry in
  that week;
- risk: one frozen `3.5 * ATR(20,D1)` server-side hard stop, no target, one
  aggregate `RISK_FIXED=1000` budget, and a 1,500-point spread ceiling; and
- lifecycle: framework and explicit broker-Friday 21 closure, later-week
  repair, and an eight-calendar-day stale guard.

Both news axes are OFF. The only backtest contract is `RISK_PERCENT=0`,
`RISK_FIXED=1000`, and `PORTFOLIO_WEIGHT=1`. There is no optimization surface,
scale-in, retry, grid, martingale, pyramid, trail, break-even move, partial
close, external feed, or current-bar signal.

## Non-Duplicate Boundary

The canonical pre-card checker scanned 4,548 EA-registry rows and 625 root
cards. It found no exact identity and surfaced only the expected fuzzy family
match to `QM5_12965_wti-week-orb`, requiring manual review. The load-bearing
boundaries are:

- `QM5_13096_xti-nr7-brk` defines one completed D1 bar as the NR7 setup and
  requires the immediately next completed bar plus SMA, slope, candle, and
  close-location filters. This candidate aggregates seven complete weeks,
  contains none of those filters, and permits the next week's first strict
  completed-close escape.
- `QM5_12965_wti-week-orb` defines the current week's range from its first
  completed D1 bar. This candidate ignores the current-week opening bar as a
  range definition and trades only after a prior complete week is strict NR7.
- `QM5_13075_xti-inweek-brk` requires one week to sit inside its parent week.
  This candidate imposes no inside-week relation and instead compares the
  prior full range with six older full ranges.
- `QM5_41060_xauxag-week-nr7-brk` computes five synchronized XAU/XAG
  close-ratio observations and executes a two-leg equal-notional metal basket.
  This candidate computes outright WTI D1 high-low ranges and owns one energy
  position; it has no ratio, second leg, basket sizing, or metal beta.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback on
  XNG and other carriers, not a symmetric WTI weekly expansion rule.

The exact WTI carrier, normalized complete-week membership, full high-low
range, strict seven-week comparison, next-week completed-close escape,
continuation direction, weekly attempt, and Friday-flat lifecycle are jointly
load-bearing. Verdict:
`CLEAN_WTI_COMPLETE_WEEK_NR7_NEXT_WEEK_EXPANSION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_TIME_AGGREGATION_RISK`: a named-author, named-publisher
  systematic trading book supplies narrow-range/expansion lineage; the weekly
  WTI translation and lack of transferred efficacy are explicit.
- R2 `PASS`: label normalization, weekly membership, strict NR7 comparison,
  breakout boundary, side, attempt, stop, spread, and lifecycle are fixed.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native WTI D1
  history supplies every runtime observation; Q02 owns history and basis
  falsification.
- R4 `PASS`: native timestamps, OHLC, range comparison, ATR risk plumbing,
  quotes, positions, deals, and terminal state only; no banned signal,
  trained output, adaptive fit, external runtime data, grid, or martingale.

## Kill And Safety Boundary

Expected cadence is five to ten completed positions per full post-warm-up year.
Q02 must retire the unchanged identity on zero trades, fewer than five
completed positions per year, nonpositive governed economics, wrong label or
week membership, non-strict range comparison, wrong breakout side, repeat or
late entry, missing hard stop, wrong Friday lifecycle, invalid fixed-risk mode,
or nondeterminism. A weak result may not be rescued by changing seven weeks,
using close-only setup ranges, adding a trend filter, changing the trigger,
stop, hold, or carrier, or allowing a retry.

This packet authorizes no manual backtest, terminal control, live/demo/shadow/
stress/optimization preset, AutoTrading action, `T_Live` change, deploy or
T_Live manifest, portfolio-gate mutation, portfolio admission, decorrelation
claim, or correlation waiver. One target-only Q02 enqueue is permitted only
after Q01 PASS and fresh tester/CPU checks remain below the governed ceilings.

