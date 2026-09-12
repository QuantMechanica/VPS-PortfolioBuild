---
source_id: BURAKOV-CRABEL-MOP-WTI-WINTER-HCLV-CONT-20260913
title: WTI winter upper-tercile weekly-close continuation
status: approved_source_complete
source_type: governed_peer_reviewed_and_reputable_cross_source_mechanization
approval_basis: decisions/2026-09-13_wti_winter_upper_clv_continuation_source_approval.md
primary_instrument: XTIUSD.DWX
decision_timeframe: D1
strategy_ids:
  - BURAKOV-CRABEL-MOP-WTI-WINTER-HCLV-CONT-20260913_S01
parent_sources:
  - source_id: BURAKOV-WTI-HALLOWEEN-2018
    role: peer_reviewed_wti_november_may_positive_return_leg
  - source_id: CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026
    role: governed_completed_week_and_close_location_lineage
  - source_id: MOP-TSMOM-2012
    role: peer_reviewed_commodity_continuation_lineage
---

# WTI Winter Upper-Tercile Weekly-Close Continuation

## Complete-Read Record

The three bounded parent records above were read end to end before approval.
Burakov, Freidin, and Solovyev provide the peer-reviewed November-through-May
positive WTI return leg. The governed Crabel composite provides reproducible
Monday-anchored completed-week construction and close-location arithmetic.
Moskowitz, Ooi, and Pedersen provide peer-reviewed own-return continuation
lineage across liquid futures including WTI.

## Claim And Translation Boundary

No parent tests the exact conjunction below. The papers use monthly reference
prices, different weekly range patterns, or exchange-traded futures and do
not establish an upper-tercile completed-week settlement, a one-week WTI CFD
long, fixed-dollar ATR risk, or Darwinex execution. This is a transparent
pre-result QM hypothesis. No source return, significance, causality,
portfolio correlation, or live-fitness claim transfers.

## Bounded Mechanization

At the first tradable `XTIUSD.DWX` D1 bar of each normalized Monday-anchored
broker week:

1. Persist the decision-week attempt before calendar, history, signal, news,
   spread, quote, ATR, sizing, margin, or order gates; never retry the week.
2. Require the anchor month to be November, December, January, February,
   March, April, or May and processing within 180 elapsed minutes of the new
   D1 bar.
3. Aggregate exactly the immediately preceding completed broker week from D1
   bars, requiring three through five valid, unique, ordered sessions and
   excluding the current partial week.
4. Compute full weekly range `R=high-low` and close location
   `CLV=(final_close-low)/R`.
5. Buy only when `CLV > 2/3`. Equality, zero range, malformed history, or an
   ineligible month is flat. There is no short side, weekly range rank, or
   candle-body-sign predicate.
6. Close on the first processed tick in the next normalized week; ten elapsed
   calendar days is stale repair.
7. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Cadence And Falsification

The seven-month interval contains roughly thirty weekly decisions. An upper-
tercile close is expected to produce about ten positions per full post-warm-up
year before data and framework losses. Q02 retires on zero trades, fewer than
five completed positions in any full scored year, nonpositive governed
economics, or a contract defect. No threshold, calendar, direction, or
lifecycle may be changed after Q02 to rescue failure.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`: peer-reviewed WTI
  winter evidence, governed reputable close-location lineage, and peer-
  reviewed commodity continuation; the exact conjunction is explicitly
  untested.
- R2 `PASS`: calendar, completed-week construction, strict close-location
  comparison, long-only orientation, attempt, stop, spread, and lifecycle are
  deterministic and locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 supplies every runtime market input.
- R4 `PASS`: native timestamps, OHLC, arithmetic, ATR, quotes, positions,
  deals, and persistent state only; no ML, banned signal indicator, external
  runtime feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Boundary

The canonical pre-allocation checker found no exact identity or fuzzy match
across 4,944 registry rows and 1,553 repository cards. Its only failure was
the unavailable external Strategy Wiki mount, which remains explicit rather
than being treated as a successful external scan.

`QM5_41440` and `QM5_41447` aggregate two completed weeks and require a strict
newest-versus-prior range state. This candidate aggregates one week, does not
rank range, ignores body direction, and keys only on a strict upper-tercile
close. `QM5_20209/20218` use completed calendar-month return sign.
`QM5_41461` uses the disjoint June-October lower-tercile short continuation.
Certified `QM5_12567` is an XNG cumulative-RSI pullback. Carrier,
November-May clock, one-week package, strict upper-tercile settlement,
long-only orientation, and one-week lifecycle are jointly load-bearing.

Manual verdict:
`DISTINCT_WTI_NOVEMBER_MAY_SINGLE_WEEK_UPPER_TERCILE_LONG_CONTINUATION_AFTER_REPOSITORY_REVIEW_WITH_EXTERNAL_WIKI_UNAVAILABLE`.

## Prohibited Interpretations

Do not add moving averages, oscillators, ML features, short entries, adaptive
thresholds, body or range-rank gates, extra attempts, targets, pyramids,
scale-ins, or parameter searches. Do not substitute current-week partial data
or interpret the sources as guaranteed profitability.

## Authorization Boundary

The explicit OWNER mission authorizes this source record, one approved card,
deterministic allocation, branch-only build, governed Q01 compile, and one
paced non-live Q02 enqueue only. It does not authorize manual backtests,
optimization, demo/shadow/live work, terminal control, portfolio admission,
correlation waiver, `T_Live`, AutoTrading, or deploy/live manifest changes.

