---
source_id: CRABEL-XNG-WEEKNR7-2026
title: XNG completed-week NR7 range expansion
publisher: Traders Press
source_type: governed_trading_book_carrier_translation
status: approved_source
approval_basis: OWNER commodity/energy portfolio mission 2026-08-20
created: 2026-08-20
created_by: Research+Development
parent_sources:
  - CRABEL-WTI-NR7-BRK-2026
  - CRABEL-WTI-WEEK-ORB-2026
  - CRABEL-WTI-WEEKNR7-2026
strategy_ids:
  - CRABEL-XNG-WEEKNR7-2026_S01
---

# XNG Completed-Week NR7 Expansion Source Packet

## Approval And Complete-Read Scope

The OWNER mission dated 2026-08-20 directs one new structural, low-frequency
commodity or energy card and explicitly permits a second `XNGUSD` edge when
its logic differs from `QM5_12567`. The following bounded governed source
records were read completely before extraction:

1. `strategy-seeds/sources/CRABEL-WTI-NR7-BRK-2026/source.md`, which records
   Toby Crabel's named 1990 Traders Press book and the narrowest-of-seven
   contraction followed by range expansion.
2. `strategy-seeds/sources/CRABEL-WTI-WEEK-ORB-2026/source.md`, which records
   complete-week aggregation and next-week range expansion.
3. `strategy-seeds/sources/CRABEL-WTI-WEEKNR7-2026/source.md`, which locks the
   exact strict seven-complete-week estimator and completed-close chronology
   on WTI.

The primary citation is Toby Crabel, *Day Trading with Short-Term Price
Patterns and Opening Range Breakout*, Traders Press, 1990. Crabel supplies
narrow-range contraction and later expansion lineage. Neither Crabel nor the
parent records test this rule on natural gas, and no WTI result transfers.

`CRABEL-XNG-WEEKNR7-2026_S01` is a pre-result carrier falsification. It keeps
the strict complete-week estimator, next-week close trigger, one-attempt state,
and Friday-flat lifecycle fixed while changing the traded information stream
to registered `XNGUSD.DWX`. No source or sibling return, profit factor, trade
count, drawdown, threshold, cost, continuous-CFD equivalence, or portfolio-
correlation statistic is imported.

## Bounded Mechanization

- Carrier: exact `XNGUSD.DWX`, D1, one slot.
- Label normalization: raw D1 dates must either match the broker date or all
  be exactly one day behind and receive one uniform `+1` calendar-day offset.
  Mixed, ambiguous, or other conventions fail closed.
- Weekly sample: the immediately prior normalized broker week must contain
  exactly one completed bar for Monday through Friday. Select the six next-
  most-recent valid complete weeks, skipping incomplete older holiday weeks
  without reordering them.
- Compression: compute each week's full high-low range. The immediately prior
  week's finite positive range must be strictly smaller than every older range;
  equality is not NR7.
- Trigger: from Tuesday through Friday of the following broker week, BUY on
  the first completed D1 close strictly above the compressed-week high or SELL
  on the first completed close strictly below its low. Equality is flat.
- Attempt: persist the current broker-Monday week key before spread, quote,
  ATR, sizing, news, or order gates once a strict break exists; never retry
  during that week.
- Risk: one `RISK_FIXED=1000` position against a frozen
  `3.5 * ATR(20,D1)` server-side stop, no target, and a 1,500-point spread cap.
- Lifecycle: Friday close at broker hour 21, later-week repair, and an eight-
  calendar-day stale guard.

There is no optimization surface, current-bar signal, oscillator, SMA, trend
filter, inventory input, external feed, target, retry, scale-in, grid,
martingale, pyramid, trailing stop, break-even move, or partial close.

## Non-Duplicate Boundary

The canonical pre-card checker scanned 4,550 EA-registry rows and 625 root
cards. It found no exact identity and raised one lexical family match to the
WTI weekly opening-range card. Manual signal/input/carrier/clock/lifecycle
review fixes these boundaries:

- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only cumulative-RSI2
  pullback aligned to a slow trend and held at most five bars. This candidate
  is symmetric, uses no oscillator or trend filter, forms only from seven full
  broker-week high-low ranges, and exits Friday.
- `QM5_13101_xng-1w-mom-vol` and `QM5_13102_xng-1w-rev-vol` threshold a five-
  D1 return under a volatility gate. This candidate uses no return-magnitude
  or volatility-regime threshold; its state is strict range rank and escape.
- `QM5_13105_xng-idnr4-brk` is a D1 inside-day/narrow-four pattern. This
  candidate aggregates exact Monday-Friday weeks and compares seven of them.
- `QM5_12812_xng-month-orb` forms a current-month opening range rather than a
  prior-week compression state.
- `QM5_41061_wti-week-nr7-brk` uses the same locked estimator on outright WTI.
  This card is the predeclared XNG carrier test demanded by the portfolio
  mission; it inherits no WTI result and does not create a parameter variant.
- `QM5_41060_xauxag-week-nr7-brk` operates on synchronized gold/silver close
  ratios with two-leg equal-notional execution, not outright XNG high-low
  ranges or a single energy position.

The exact XNG carrier, uniform energy-date convention, full high-low range,
seven valid complete weeks, next-week completed-close escape, continuation
direction, one weekly attempt, and Friday-flat lifecycle are jointly load-
bearing. Verdict:
`CLEAN_XNG_COMPLETE_WEEK_NR7_CARRIER_EXTENSION_AFTER_MANUAL_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_TIME_AGGREGATION_AND_CARRIER_RISK`: a named-author,
  named-publisher systematic trading book supplies the structural lineage;
  the untested weekly XNG continuous-CFD translation is explicit.
- R2 `PASS`: normalization, complete-week membership, seven-week range rank,
  strict breakout, side, attempt, risk, and lifecycle are fixed.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XNGUSD.DWX` D1 history supplies every runtime input; Q02 owns history,
  label, fill, density, and CFD-basis falsification.
- R4 `PASS`: native timestamps, OHLC, range comparison, ATR risk plumbing,
  quotes, positions, deals, and terminal state only; no banned signal, ML,
  external runtime data, adaptive fit, grid, martingale, or pyramiding.

## Kill And Safety Boundary

Expected cadence is five to ten completed positions per full post-warm-up
year. Q02 must retire the unchanged identity on zero trades, fewer than five
completed positions per year, nonpositive governed economics, wrong label or
week membership, non-strict range comparison, wrong breakout side, repeat or
late entry, missing hard stop, weekend hold, invalid fixed-risk mode, or
nondeterminism. It may not be rescued by changing the carrier, seven-week
sample, range definition, trigger, direction, stop, or hold after results.

This packet authorizes no manual backtest, terminal control, live/demo/shadow/
stress/optimization preset, AutoTrading action, `T_Live` change, deploy or
T_Live manifest, portfolio-gate mutation, portfolio admission, decorrelation
claim, or correlation waiver. One target-only Q02 enqueue is permitted only
after Q01 PASS and fresh tester/CPU checks are below the governed ceilings.

