---
source_id: BURAKOV-CRABEL-WTI-WINTER-NR2-BREAKOUT-20260911
title: WTI winter weekly contraction close breakout
status: approved_source_complete
source_type: governed_cross_source_mechanization
approval_basis: decisions/2026-09-11_wti_winter_nr2_breakout_source_approval.md
primary_instrument: XTIUSD.DWX
decision_timeframe: D1
strategy_ids:
  - BURAKOV-CRABEL-WTI-WINTER-NR2-BREAKOUT-20260911_S01
parent_sources:
  - source_id: BURAKOV-WTI-HALLOWEEN-2018
    role: peer_reviewed_wti_november_may_seasonality
  - source_id: CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026
    role: governed_range_contraction_and_completed_week_lineage
---

# WTI Winter Weekly Contraction Close Breakout

## Source Claim

Burakov, Freidin, and Solovyev report a materially stronger November-through-May return interval
for West Texas crude oil than the complementary summer interval in their 1985-2016 sample.
Crabel supplies systematic volatility-contraction and subsequent range-expansion lineage, while
the governed weekly packet supplies reproducible Monday-anchored completed-week construction.

Neither source tests the exact rule below. This is a transparent QM cross-source hypothesis asking
whether a completed WTI week whose full range contracts relative to the preceding week becomes a
useful reference box for directional repricing during the next week of the November-May interval.

## Deterministic Translation

Evaluate only when a new `XTIUSD.DWX` D1 bar makes the immediately preceding D1 close complete.

1. Continue only when the current Monday-anchored decision week begins in November, December,
   January, February, March, April, or May.
2. Aggregate the two immediately preceding consecutive completed broker weeks from normalized D1
   bars. Require three through five valid, unique, ordered sessions in each week.
3. Let `R0` be the newest completed week's full high-low range and `R1` the preceding week's.
   Require `R0 < R1`; equality is flat. Range containment is not required.
4. Treat the newest completed week's high and low as the fixed breakout box for the current week.
5. BUY when the just-completed current-week D1 close is strictly above the box high. SELL when it
   is strictly below the box low. Equality is flat. Intrabar ticks never trigger an entry.
6. Persist the current-week attempt immediately after the first fully valid breakout is known and
   before news, spread, quote, ATR, sizing, margin, or order gates. Never retry that week.
7. Missing weeks, malformed or nonfinite OHLC, zero range, ineligible month, no completed
   current-week close, or no strict close breakout means no signal. Hold no more than one owned
   position.

## Frozen Trade Management

- entry grace: 180 elapsed minutes after the new D1 bar begins;
- stop loss: frozen `3.5 * ATR(20,D1)`;
- take profit: none;
- maximum spread: 1,500 points;
- normal exit: first processed tick in the normalized broker week after entry;
- stale repair: ten elapsed calendar days;
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`;
- Q02 news temporal/compliance: off; Friday close: off.

## Expected Cadence And Falsification

The seven-month winter interval contains roughly thirty weekly boxes. Contraction plus a completed-
close breakout is expected to yield approximately five to fifteen positions per full post-warm-up
year. Q02 retires at zero trades, below five completed positions in a full scored year, nonpositive
governed economics, or any execution-contract defect. No threshold may be relaxed after Q02.

## Provenance, Non-Duplicate Boundary, And Limitations

The complete bounded parent records are `strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md`
and `strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md`. The former is a named-
author peer-reviewed open-access energy-market study. The latter preserves reputable systematic
range-state lineage and labels the exact CFD translation as untested.

`QM5_41439` applies the same two-week contraction and delayed-close chronology to natural gas only
during November-March. `QM5_41437` applies it to WTI only during the disjoint August-October
hurricane-risk window. `QM5_41440` uses this WTI winter interval but requires range expansion and
an immediate upper-quartile long signal. Certified `QM5_12567` is an XNG cumulative-RSI pullback.
The present identity uses a WTI winter clock, strict two-week contraction, frozen weekly box,
symmetric delayed completed-close trigger, and one-week lifecycle.

Futures-to-CFD roll/basis, financing, session labels, gaps, delayed close confirmation, seasonal-
regime instability, multiple comparisons, and source translation can dominate. Nothing here
establishes efficacy, causality, decorrelation, portfolio admission, or live fitness.

## Prohibited Interpretations

Do not add moving averages, oscillators, ML, adaptive thresholds, range containment, external
inventory/weather/curve data, intrabar breakout, current-week partial-bar leakage, retry, target,
scale-in, grid, martingale, or parameter search.
