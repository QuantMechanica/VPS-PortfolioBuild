---
source_id: EIA-MOP-YANG-XNG-SHOULDER-HCLV-FADE-20260913
title: XNG shoulder-season upper-tercile weekly-close fade
status: approved_source_complete
source_type: official_government_and_peer_reviewed_academic_cross_source_mechanization
approval_basis: decisions/2026-09-13_xng_shoulder_upper_clv_fade_source_approval.md
primary_instrument: XNGUSD.DWX
decision_timeframe: D1
strategy_ids:
  - EIA-MOP-YANG-XNG-SHOULDER-HCLV-FADE-20260913_S01
parent_sources:
  - source_id: EIA-XNG-SHOULDER-2026
    role: official_spring_and_autumn_low_demand_regime
  - source_id: MOP-XNG-WCLOSE-LOCATION-MOM-2026
    role: governed_xng_completed_week_and_close_location_construction
  - source_id: YANG-COMM-REVERSAL-2017
    role: academic_commodity_reversal_lineage
---

# XNG Shoulder-Season Upper-Tercile Weekly-Close Fade

## Complete-Read Record

The three bounded parent records above were read end to end before approval.
The U.S. Energy Information Administration packet records recurring April-May
and September-October natural-gas shoulder periods between winter heating and
summer electric-generation demand peaks. The governed XNG packet supplies a
reproducible Monday-anchored completed-week and close-location construction.
Yang, Goncu, and Pantelous supply academic commodity-futures reversal lineage.

## Claim And Translation Boundary

No parent tests the exact conjunction below. EIA supplies a physical-demand
regime but no trading rule. The XNG close-location packet follows an outer-
fifth state only when close-to-close return direction agrees, while this rule
uses no parent-close return and fades a strict upper-tercile settlement. The
reversal paper uses other horizons and exchange-traded futures. The exact
single-week XNG CFD short is therefore a transparent pre-result QM hypothesis.
No source return, significance, causality, portfolio correlation, or live-
fitness claim transfers.

## Bounded Mechanization

At the first tradable `XNGUSD.DWX` D1 bar of each normalized Monday-anchored
broker week:

1. Persist the decision-week attempt before calendar, history, signal, news,
   spread, quote, ATR, sizing, margin, or order gates; never retry the week.
2. Require the anchor month to be April, May, September, or October and
   processing within 180 elapsed minutes of the new D1 bar.
3. Aggregate exactly the immediately preceding completed broker week from D1
   bars, requiring three through five valid, unique, ordered sessions and
   excluding the current partial week.
4. Compute full weekly range `R=high-low` and close location
   `CLV=(final_close-low)/R`.
5. Sell only when `CLV > 2/3`. Equality, zero range, malformed history, or an
   ineligible month is flat. There is no long side, parent-close return sign,
   range rank, candle-body sign, wick, stretch, or moving-average predicate.
6. Close on the first processed tick in the next normalized week; ten elapsed
   calendar days is stale repair.
7. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Cadence And Falsification

The four shoulder months contain roughly seventeen weekly decisions. An
upper-tercile close is expected to produce roughly five or six positions per
full post-warm-up year before data and framework losses. Q02 retires on zero
trades, fewer than five completed positions in any full scored year,
nonpositive governed economics, or a contract defect. No threshold, calendar,
direction, or lifecycle may be changed after Q02 to rescue failure.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`: official EIA
  natural-gas seasonality context, a governed peer-reviewed XNG completed-week
  construction, and academic commodity reversal; the exact conjunction is
  explicitly untested.
- R2 `PASS`: calendar, formation, strict inequality, side, attempt, stop,
  spread, and lifecycle are deterministic and locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XNGUSD.DWX` D1 bars supply every runtime market input.
- R4 `PASS`: native price/calendar arithmetic and ATR risk only, without ML,
  a banned signal indicator, external runtime data, grid, martingale, scale-in,
  or pyramid.

## Non-Duplicate Boundary

The canonical pre-allocation checker covered 4,946 EA-registry rows and 1,555
repository cards. It found no exact collision and one expected fuzzy family
match, while failing closed because the external Strategy Wiki mount was
unavailable. The receipt is
`artifacts/qm5_candidate_xng_shoulder_hclv_fade_dedup_preallocation_20260913.json`.

Manual review separates the fuzzy `QM5_41462` WTI summer sibling because that
EA uses crude oil and a June-October calendar; neither signal stream nor
position can be shared. `QM5_41392` fades the sign of the completed XNG week's
open-to-close return symmetrically, whereas this candidate ignores open and
return sign, reads the final close within the full weekly range, and is short
only. `QM5_41401` requires two adjacent same-sign weeks. `QM5_12595` requires a
D1 slow-mean stretch, channel high, and upper wick. Certified `QM5_12567` is an
all-year long-only two-day cumulative-RSI pullback above a slow trend filter.
Carrier, four shoulder months, one completed-week package, strict upper-
tercile settlement, short-only orientation, and one-week lifecycle are jointly
load-bearing.

Manual verdict:
`DISTINCT_XNG_SHOULDER_SINGLE_WEEK_UPPER_TERCILE_SHORT_REVERSION_AFTER_FUZZY_FAMILY_REVIEW_WITH_EXTERNAL_WIKI_UNAVAILABLE`.

## Prohibited Interpretations

Do not add moving averages, oscillators, ML features, long entries, adaptive
thresholds, return-sign, wick, body, stretch, or range-rank gates, extra
attempts, targets, pyramids, scale-ins, or parameter searches. Do not
substitute current-week partial data or interpret the sources as guaranteed
profitability.

## Authorization Boundary

The explicit OWNER mission authorizes this source record, one approved card,
deterministic allocation, branch-only build, governed Q01 compile, and one
paced non-live Q02 enqueue only. It does not authorize manual backtests,
optimization, demo/shadow/live work, terminal control, portfolio admission,
correlation waiver, `T_Live`, AutoTrading, deploy/live manifests, or portfolio-
gate changes.
