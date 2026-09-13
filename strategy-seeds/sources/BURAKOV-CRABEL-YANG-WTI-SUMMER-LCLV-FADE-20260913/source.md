---
source_id: BURAKOV-CRABEL-YANG-WTI-SUMMER-LCLV-FADE-20260913
title: WTI summer lower-tercile weekly-close reversion
status: approved_source_complete
source_type: governed_peer_reviewed_reputable_and_academic_cross_source_mechanization
approval_basis: decisions/2026-09-13_wti_summer_lower_clv_reversion_source_approval.md
primary_instrument: XTIUSD.DWX
decision_timeframe: D1
strategy_ids:
  - BURAKOV-CRABEL-YANG-WTI-SUMMER-LCLV-FADE-20260913_S01
parent_sources:
  - source_id: BURAKOV-WTI-HALLOWEEN-2018
    role: peer_reviewed_wti_june_october_negative_return_leg
  - source_id: CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026
    role: governed_completed_week_and_close_location_lineage
  - source_id: YANG-COMM-REVERSAL-2017
    role: academic_commodity_reversal_lineage
---

# WTI Summer Lower-Tercile Weekly-Close Reversion

## Complete-Read Record

The three bounded parent records above were read end to end before approval.
Burakov, Freidin, and Solovyev provide the peer-reviewed June-through-October
negative WTI return leg. The governed Crabel composite provides reproducible
Monday-anchored completed-week construction and close-location arithmetic.
Yang, Goncu, and Pantelous provide academic commodity-futures reversal
lineage.

## Claim And Translation Boundary

No parent tests the exact conjunction below. The papers use monthly reference
prices or exchange-traded futures and do not establish a lower-tercile
completed-week settlement, a one-week WTI CFD long, fixed-dollar ATR risk, or
Darwinex execution. In particular, buying after a weak week is counter to the
average negative summer leg, so seasonality defines a structural regime but
does not supply the trade direction. This is a transparent pre-result QM
hypothesis. No source return, significance, causality, portfolio correlation,
or live-fitness claim transfers.

## Bounded Mechanization

At the first tradable `XTIUSD.DWX` D1 bar of each normalized Monday-anchored
broker week:

1. Persist the decision-week attempt before calendar, history, signal, news,
   spread, quote, ATR, sizing, margin, or order gates; never retry the week.
2. Require the anchor month to be June, July, August, September, or October
   and processing within 180 elapsed minutes of the new D1 bar.
3. Aggregate exactly the immediately preceding completed broker week from D1
   bars, requiring three through five valid, unique, ordered sessions and
   excluding the current partial week.
4. Compute full weekly range `R=high-low` and close location
   `CLV=(final_close-low)/R`.
5. Buy only when `CLV < 1/3`. Equality, zero range, malformed history, or an
   ineligible month is flat. There is no short side, weekly return sign, range
   rank, candle-body, wick, stretch, or moving-average predicate.
6. Close on the first processed tick in the next normalized week; ten elapsed
   calendar days is stale repair.
7. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Cadence And Falsification

The five-month interval contains roughly twenty-two weekly decisions. A
lower-tercile close is expected to produce about seven positions per full
post-warm-up year before data and framework losses. Q02 retires on zero
trades, fewer than five completed positions in any full scored year,
nonpositive governed economics, or a contract defect. No threshold, calendar,
direction, or lifecycle may be changed after Q02 to rescue failure.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`: peer-reviewed WTI
  summer evidence, governed reputable close-location lineage, and academic
  commodity reversal; the exact conjunction and counter-seasonal direction
  are explicitly untested.
- R2 `PASS`: calendar, completed-week construction, strict close-location
  comparison, long-only orientation, attempt, stop, spread, and lifecycle are
  deterministic and locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 supplies every runtime market input.
- R4 `PASS`: native timestamps, OHLC, arithmetic, ATR, quotes, positions,
  deals, and persistent state only; no ML, banned signal indicator, external
  runtime feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Boundary

The canonical pre-allocation checker found no exact identity across 4,947
registry rows and 1,556 repository cards. It reported four fuzzy family
matches and recorded the unavailable external Strategy Wiki mount.
`QM5_41457` and `QM5_41458` aggregate two completed weeks, compare newest
range with prior range, and require positive newest-week body. This candidate
aggregates one week, does not rank range, ignores body direction, and keys only
on a strict lower-tercile close.

The closest one-week siblings are deliberately disjoint. `QM5_41462` sells
only after an upper-tercile close. `QM5_41464` buys lower-tercile closes only
during the November-May winter interval. `QM5_41461` sells the same summer
lower-tercile state as a continuation hypothesis; this candidate buys it as a
reversal hypothesis. Carrier, June-October clock, one-week package, strict
lower-tercile settlement, long-only orientation, and one-week lifecycle are
jointly load-bearing.

Manual verdict:
`DISTINCT_WTI_JUNE_OCTOBER_SINGLE_WEEK_LOWER_TERCILE_LONG_REVERSION_AFTER_FUZZY_FAMILY_REVIEW_WITH_EXTERNAL_WIKI_UNAVAILABLE`.

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
