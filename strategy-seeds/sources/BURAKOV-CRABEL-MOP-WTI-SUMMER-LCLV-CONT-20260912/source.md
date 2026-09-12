---
source_id: BURAKOV-CRABEL-MOP-WTI-SUMMER-LCLV-CONT-20260912
title: WTI summer lower-tercile weekly-close continuation
status: approved_source_complete
source_type: governed_peer_reviewed_reputable_and_academic_cross_source_mechanization
approval_basis: decisions/2026-09-12_wti_summer_lower_clv_continuation_source_approval.md
primary_instrument: XTIUSD.DWX
decision_timeframe: D1
strategy_ids:
  - BURAKOV-CRABEL-MOP-WTI-SUMMER-LCLV-CONT-20260912_S01
parent_sources:
  - source_id: BURAKOV-WTI-HALLOWEEN-2018
    role: peer_reviewed_wti_june_october_negative_return_leg
  - source_id: CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026
    role: governed_completed_week_and_close_location_lineage
  - source_id: MOP-TSMOM-2012
    role: peer_reviewed_commodity_continuation_lineage
---

# WTI Summer Lower-Tercile Weekly-Close Continuation

## Complete-Read Record

The three bounded parent records above were read end to end before approval. Burakov, Freidin,
and Solovyev provide the peer-reviewed June-through-October negative WTI return leg. The governed
Crabel composite provides reproducible Monday-anchored completed-week construction and weekly
close-location arithmetic. Moskowitz, Ooi, and Pedersen provide peer-reviewed commodity
time-series-continuation lineage, explicitly including WTI futures.

## Claim And Translation Boundary

No parent tests the exact conjunction below. The papers use monthly reference prices or
exchange-traded futures and do not establish a lower-tercile completed-week settlement, a
one-week WTI CFD short, fixed-dollar ATR risk, or Darwinex execution. This is a transparent,
pre-result QM hypothesis. No source return, significance, causality, portfolio correlation, or
live-fitness claim transfers.

## Bounded Mechanization

At the first tradable `XTIUSD.DWX` D1 bar of each normalized Monday-anchored broker week:

1. Persist the decision-week attempt before calendar, history, signal, news, spread, quote, ATR,
   sizing, margin, or order gates; never retry the week.
2. Require the anchor month to be June, July, August, September, or October and processing within
   180 elapsed minutes of the new D1 bar.
3. Aggregate exactly the immediately preceding completed broker week from D1 bars, requiring
   three through five valid, unique, ordered sessions and excluding the current partial week.
4. Compute full weekly range `R=high-low` and close location `CLV=(final_close-low)/R`.
5. Sell only when `CLV < 1/3`. Equality, zero range, malformed history, or an ineligible month is
   flat. There is no long side and no weekly range-rank or candle-body predicate.
6. Close on the first processed tick in the next normalized week; ten elapsed calendar days is
   stale repair.
7. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Cadence And Falsification

The five-month interval contains roughly twenty-two weekly decisions. A lower-tercile close is
expected to produce about seven positions per full post-warm-up year before data and framework
losses. Q02 retires on zero trades, fewer than five completed positions in any full scored year,
nonpositive governed economics, or a contract defect. No threshold, calendar, direction, or
lifecycle may be changed after Q02 to rescue failure.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`: peer-reviewed WTI season evidence,
  peer-reviewed commodity continuation, and governed reputable close-location lineage; the exact
  conjunction is explicitly untested.
- R2 `PASS`: the calendar, completed-week construction, strict close-location comparison,
  short-only orientation, attempt, stop, spread, and lifecycle are deterministic and locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native `XTIUSD.DWX` D1 supplies every
  runtime market input.
- R4 `PASS`: native timestamps, OHLC, arithmetic, ATR, quotes, positions, deals, and persistent
  state only; no ML, banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Non-Duplicate Boundary

The canonical pre-allocation checker found no exact identity across 4,942 registry rows, 1,551
repository cards, and 45 Strategy Wiki nodes. It reported only `QM5_41459` and `QM5_41460` as
fuzzy family matches. Both siblings aggregate two completed weeks, compare newest range with the
prior range, and require a negative newest-week candle body. This candidate aggregates one week,
does not rank its range, ignores the candle body, and keys only on a strict lower-tercile close.

`QM5_20093` is unconditional in each summer month, while `QM5_41406` requires two negative weekly
returns. The closest close-location cards operate in refinery-maintenance, hurricane, or winter
windows and/or add range-state predicates. Carrier, June-October clock, one-week package, strict
lower-tercile settlement, short-only orientation, and one-week lifecycle are jointly load-bearing.

Manual verdict:
`DISTINCT_WTI_JUNE_OCTOBER_SINGLE_WEEK_LOWER_TERCILE_SHORT_CONTINUATION_AFTER_FUZZY_REVIEW`.

## Prohibited Interpretations

Do not add moving averages, oscillators, ML features, long entries, adaptive thresholds, body or
range-rank gates, extra attempts, targets, pyramiding, scale-ins, or parameter searches. Do not
substitute current-week partial data for the completed week or interpret the source as guaranteed
profitability.

## Authorization Boundary

The current explicit OWNER mission authorizes this source record, one approved card,
deterministic allocation, branch-only build, governed Q01 compile, and one paced non-live Q02
enqueue only. It does not authorize manual backtests, optimization, demo/shadow/live work,
terminal control, portfolio admission, a correlation waiver, `T_Live`, AutoTrading, or deploy/live
manifest changes.
