---
source_id: BURAKOV-CRABEL-YANG-WTI-WINTER-WR2-BODY-FADE-20260911
title: WTI winter weekly range-expansion body reversion
status: approved_source_complete
source_type: governed_peer_reviewed_reputable_and_academic_cross_source_mechanization
approval_basis: decisions/2026-09-11_wti_winter_wr2_body_reversion_source_approval.md
primary_instrument: XTIUSD.DWX
decision_timeframe: D1
strategy_ids:
  - BURAKOV-CRABEL-YANG-WTI-WINTER-WR2-BODY-FADE-20260911_S01
parent_sources:
  - source_id: BURAKOV-WTI-HALLOWEEN-2018
    role: peer_reviewed_wti_november_may_seasonality
  - source_id: CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026
    role: governed_range_state_and_completed_week_lineage
  - source_id: YANG-COMM-REVERSAL-2017
    role: academic_commodity_reversal_lineage
---

# WTI Winter Weekly Range-Expansion Body Reversion

## Complete-Read Record

The three bounded parent records named above were read end to end before the durable approval at
`decisions/2026-09-11_wti_winter_wr2_body_reversion_source_approval.md`. Burakov, Freidin, and
Solovyev provide the peer-reviewed November-through-May WTI interval. The governed Crabel packet
provides reproducible Monday-anchored completed-week construction and range-state lineage. Yang,
Goncu, and Pantelous provide academic commodity-futures reversal lineage.

## Claim And Translation Boundary

No parent tests the exact rule below. The papers use monthly reference prices or exchange-traded
futures and do not establish a two-week range comparison, weekly body-sign fade, fixed-dollar ATR
risk, or one-week holding period on the Darwinex continuous CFD. This is a transparent pre-result
QM cross-source hypothesis. No source return, significance, causality, correlation, or live-fitness
claim transfers.

## Bounded Mechanization

At the first tradable `XTIUSD.DWX` D1 bar of each normalized Monday-anchored broker week:

1. Persist the decision-week attempt before calendar, history, signal, news, spread, quote, ATR,
   sizing, margin, or order gates; never retry the week.
2. Require the anchor month to be November, December, January, February, March, April, or May and
   processing to be within 180 elapsed minutes of the new bar.
3. Aggregate exactly the two immediately preceding consecutive completed broker weeks from D1
   bars, requiring three through five valid, unique, ordered sessions per week.
4. Compute each full weekly range `R=high-low` and the newest week's body from its chronological
   first open to final close.
5. Require the newest range to be strictly greater than the prior range. Equality, invalid data,
   zero range, or an ineligible month is flat.
6. Sell when the newest body is strictly positive; buy when it is strictly negative. Body equality
   is flat. Close location within the weekly range is irrelevant.
7. Close on the first processed tick in the next normalized week; ten elapsed calendar days is
   stale repair.
8. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Cadence And Falsification

The seven-month interval contains roughly thirty weekly decisions. A strict two-week expansion
and nonzero weekly body is expected to produce approximately twelve to twenty-two completed
positions per full post-warm-up year. Q02 retires on zero trades, fewer than five completed
positions in any full scored year, nonpositive governed economics, or any contract defect. No
threshold or orientation may be changed after Q02.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`: peer-reviewed WTI seasonality,
  governed reputable range-state lineage, and academic commodity-reversal lineage; the exact
  conjunction is explicitly untested.
- R2 `PASS`: calendar, two completed weeks, strict range and body inequalities, symmetric
  contrarian sides, attempt, stop, spread, and lifecycle are deterministic and locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native `XTIUSD.DWX` D1 supplies every
  runtime market input.
- R4 `PASS`: native timestamps, OHLC, arithmetic, ATR, quotes, positions, deals, and persistent
  state only; no ML, banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Non-Duplicate Boundary

The canonical pre-allocation scan found no exact identity. `QM5_41442` fades only strict
outer-quartile close-location states and ignores body sign; this rule fades every nonzero body
after expansion, including middle-range closes and body/CLV disagreement states. `QM5_41443`
uses the identical body predicate but follows rather than fades it. `QM5_41403` and `QM5_41408`
fade two same-sign weekly returns without an expansion predicate or winter clock. `QM5_41096`
uses intraweek excursion rejection, not the completed-week body. Certified `QM5_12567` is an XNG
cumulative-RSI pullback. Carrier, November-May clock, strict range expansion, body-only predicate,
contrarian orientation, and one-week lifecycle are jointly load-bearing.

Manual verdict:
`DISTINCT_WTI_NOVEMBER_MAY_WR2_OWN_BODY_SYMMETRIC_REVERSION_AFTER_FAMILY_REVIEW`.

## Prohibited Interpretations

Do not add close-location thresholds, moving averages, oscillators, trained models, adaptive
thresholds, external weather/inventory/curve data, current-week leakage, targets, trails,
scale-in, retry, optimization, grid, or martingale.

