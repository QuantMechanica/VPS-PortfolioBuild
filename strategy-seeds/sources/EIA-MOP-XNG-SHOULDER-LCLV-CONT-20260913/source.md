---
source_id: EIA-MOP-XNG-SHOULDER-LCLV-CONT-20260913
title: XNG shoulder-season lower-tercile weekly-close downside continuation
status: approved_source_complete
source_type: official_government_and_peer_reviewed_cross_source_mechanization
approval_basis: decisions/2026-09-13_xng_shoulder_lower_clv_continuation_source_approval.md
primary_instrument: XNGUSD.DWX
decision_timeframe: D1
strategy_ids:
  - EIA-MOP-XNG-SHOULDER-LCLV-CONT-20260913_S01
parent_sources:
  - source_id: EIA-XNG-SHOULDER-2026
    role: official_spring_and_autumn_low_demand_regime
  - source_id: MOP-XNG-WCLOSE-LOCATION-MOM-2026
    role: governed_xng_completed_week_and_close_location_construction
  - source_id: MOP-TSMOM-2012
    role: peer_reviewed_commodity_continuation_lineage
---

# XNG Shoulder-Season Lower-Tercile Weekly-Close Downside Continuation

## Complete-Read Record

The three bounded parent records above were read end to end before approval.
The U.S. Energy Information Administration packet records recurring April-May
and September-October natural-gas shoulder periods between winter heating and
summer electric-generation demand peaks. The governed XNG packet supplies a
reproducible Monday-anchored completed-week and close-location construction.
Moskowitz, Ooi, and Pedersen supply peer-reviewed own-return continuation
lineage across liquid futures, explicitly including natural gas.

## Claim And Translation Boundary

No parent tests the exact conjunction below. EIA supplies a physical-demand
regime but no trading rule. The governed XNG packet follows a completed-week
return only when outer-fifth close location agrees; this rule intentionally
removes the parent-close return and uses a strict lower-tercile state. The
paper's tested horizons are monthly, not weekly. The exact single-week XNG CFD
short is therefore a transparent pre-result QM hypothesis. No source return,
significance, causality, portfolio correlation, or live-fitness claim transfers.

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
5. Sell only when `CLV < 1/3`. Equality, zero range, malformed history, or an
   ineligible month is flat. There is no long side, parent-close return sign,
   range rank, candle-body sign, wick, stretch, or moving-average predicate.
6. Close on the first processed tick in the next normalized week; ten elapsed
   calendar days is stale repair.
7. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Cadence And Falsification

The four shoulder months contain roughly seventeen weekly decisions. A lower-
tercile close is expected to produce roughly five or six positions per full
post-warm-up year before data and framework losses. Q02 retires on zero trades,
fewer than five completed positions in any full scored year, nonpositive
governed economics, or a contract defect. No threshold, calendar, direction,
or lifecycle may be changed after Q02 to rescue failure.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_WEEKLY_HORIZON_TRANSLATION_RISK`: official
  EIA natural-gas seasonality context, governed peer-reviewed XNG completed-
  week construction, and peer-reviewed commodity continuation; the exact
  conjunction is explicitly untested.
- R2 `PASS`: calendar, formation, strict inequality, side, attempt, stop,
  spread, and lifecycle are deterministic and locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XNGUSD.DWX` D1 bars supply every runtime market input.
- R4 `PASS`: native price/calendar arithmetic and ATR risk only, without ML,
  a banned signal indicator, external runtime data, grid, martingale, scale-in,
  or pyramid.

## Non-Duplicate Boundary

The canonical pre-allocation checker covered 4,950 EA-registry rows and 1,559
repository cards. It found no exact collision and five fuzzy family matches,
while failing closed because the external Strategy Wiki mount was unavailable.
The receipt is
`artifacts/qm5_candidate_xng_shoulder_lclv_cont_dedup_preallocation_20260913.json`.

`QM5_41461` and `QM5_41468` apply lower-tercile short continuation to WTI
under disjoint summer and winter calendars; neither position package can be
shared with this XNG rule. `QM5_41465` uses the same carrier/calendar but fades
upper-tercile closes; this candidate follows lower-tercile closes downward.
`QM5_41392` fades weekly open-to-close return sign symmetrically, and
`QM5_41420` requires two same-sign weeks. Certified `QM5_12567` is an all-year
long-only two-day cumulative-RSI pullback above a slow trend filter. Carrier,
four shoulder months, one completed week, strict lower-tercile settlement,
short-only orientation, and one-week lifecycle are jointly load-bearing.

Manual verdict:
`DISTINCT_XNG_SHOULDER_SINGLE_WEEK_LOWER_TERCILE_SHORT_CONTINUATION_AFTER_FUZZY_FAMILY_REVIEW_WITH_EXTERNAL_WIKI_UNAVAILABLE`.

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
