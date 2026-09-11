---
source_id: BURAKOV-CRABEL-MOP-WTI-WINTER-NR2-CLV-MOM-20260912
title: WTI winter weekly range-contraction upper-quartile continuation
status: approved_source_complete
source_type: governed_peer_reviewed_and_reputable_cross_source_mechanization
approval_basis: decisions/2026-09-12_wti_winter_nr2_clv_momentum_source_approval.md
primary_instrument: XTIUSD.DWX
decision_timeframe: D1
strategy_ids:
  - BURAKOV-CRABEL-MOP-WTI-WINTER-NR2-CLV-MOM-20260912_S01
parent_sources:
  - source_id: BURAKOV-WTI-HALLOWEEN-2018
    role: peer_reviewed_wti_november_may_seasonality
  - source_id: MOP-TSMOM-2012
    role: peer_reviewed_own_return_continuation_lineage
  - source_id: CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026
    role: governed_range_state_and_completed_week_lineage
---

# WTI Winter Weekly Range-Contraction Upper-Quartile Continuation

## Complete-Read Record

The three bounded parent records named above were read end to end before the durable approval at
`decisions/2026-09-12_wti_winter_nr2_clv_momentum_source_approval.md`. Burakov, Freidin, and
Solovyev provide the peer-reviewed November-through-May WTI interval. Moskowitz, Ooi, and
Pedersen provide peer-reviewed own-return continuation lineage across liquid futures including
WTI. The governed Crabel packet provides reproducible Monday-anchored completed-week construction
and range-state lineage.

## Claim And Translation Boundary

No parent tests the exact rule below. The sources use monthly reference prices, different range
patterns, or exchange-traded futures; they do not establish a two-week contraction filter, weekly
close-location threshold, fixed-dollar ATR risk, or one-week holding period on the Darwinex
continuous CFD. This is a transparent pre-result QM cross-source hypothesis. No source return,
significance, causality, correlation, or live-fitness claim transfers.

## Bounded Mechanization

At the first tradable `XTIUSD.DWX` D1 bar of each normalized Monday-anchored broker week:

1. Persist the decision-week attempt before calendar, history, signal, news, spread, quote, ATR,
   sizing, margin, or order gates; never retry the week.
2. Require the anchor month to be November, December, January, February, March, April, or May and
   processing to be within 180 elapsed minutes of the new bar.
3. Aggregate exactly the two immediately preceding consecutive completed broker weeks from D1
   bars, requiring three through five valid, unique, ordered sessions per week.
4. Compute each full weekly range `R=high-low` and newest-week
   `CLV=(final_close-low)/R`.
5. Require the newest range to be strictly less than the prior range and `CLV>0.75`. Equality,
   invalid data, zero range, a lower close location, or an ineligible month is flat. Range
   containment and weekly body sign are irrelevant.
6. Buy WTI only; there is no short branch.
7. Close on the first processed tick in the next normalized week; ten elapsed calendar days is
   stale repair.
8. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Cadence And Falsification

The seven-month interval contains roughly thirty weekly decisions. Strict two-week contraction
plus upper-quartile settlement is expected to produce approximately five to twelve completed
positions per full post-warm-up year. Q02 retires on zero trades, fewer than five completed
positions in any full scored year, nonpositive governed economics, or any contract defect. No
threshold, range orientation, or direction may be changed after Q02.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`: named-author peer-reviewed WTI
  seasonality and futures momentum plus governed reputable range-state lineage; exact conjunction
  explicitly untested.
- R2 `PASS`: calendar, two completed weeks, strict range and CLV inequalities, long-only side,
  attempt, stop, spread, and lifecycle are deterministic and locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native `XTIUSD.DWX` D1 supplies every
  runtime market input.
- R4 `PASS`: native timestamps, OHLC, arithmetic, ATR, quotes, positions, deals, and persistent
  state only; no ML, banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Non-Duplicate Boundary

The canonical scan found no exact identity and returned expected family relatives. `QM5_41440`
requires strict range expansion, the opposite volatility state. `QM5_41438` trades XNG over a
shorter winter window, requires expansion, and has both sides. `QM5_20209/20218` use completed
calendar-month return sign and no weekly range or CLV. `QM5_41441` delays entry until a current-
week completed close breaks the contraction box. `QM5_41445/41446` read the newest weekly body,
not close location. Certified `QM5_12567` is an XNG cumulative-RSI pullback. Carrier,
November-May clock, strict contraction, upper-quartile settlement, long-only continuation, and
one-week lifecycle are jointly load-bearing.

Manual verdict:
`DISTINCT_WTI_NOVEMBER_MAY_NR2_UPPER_QUARTILE_LONG_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Prohibited Interpretations

Do not add body-sign filters, breakouts, moving averages, oscillators, trained models, adaptive
thresholds, external weather/inventory/curve data, current-week leakage, targets, trails,
scale-in, retry, optimization, grid, or martingale.

