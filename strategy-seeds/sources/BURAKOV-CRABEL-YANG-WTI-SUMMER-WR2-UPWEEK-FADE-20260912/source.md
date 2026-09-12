---
source_id: BURAKOV-CRABEL-YANG-WTI-SUMMER-WR2-UPWEEK-FADE-20260912
title: WTI summer weekly range-expansion positive-week reversion
status: approved_source_complete
source_type: governed_peer_reviewed_reputable_and_academic_cross_source_mechanization
approval_basis: decisions/2026-09-12_wti_summer_wr2_positive_week_reversion_source_approval.md
primary_instrument: XTIUSD.DWX
decision_timeframe: D1
strategy_ids:
  - BURAKOV-CRABEL-YANG-WTI-SUMMER-WR2-UPWEEK-FADE-20260912_S01
parent_sources:
  - source_id: BURAKOV-WTI-HALLOWEEN-2018
    role: peer_reviewed_wti_june_october_negative_return_leg
  - source_id: CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026
    role: governed_range_state_and_completed_week_lineage
  - source_id: YANG-COMM-REVERSAL-2017
    role: academic_commodity_reversal_lineage
---

# WTI Summer Weekly Range-Expansion Positive-Week Reversion

## Complete-Read Record

The three bounded parent records named above were read end to end before the durable approval at
`decisions/2026-09-12_wti_summer_wr2_positive_week_reversion_source_approval.md`. Burakov,
Freidin, and Solovyev provide the peer-reviewed June-through-October WTI negative-return leg. The
governed Crabel packet provides reproducible Monday-anchored completed-week construction and
range-state lineage. Yang, Goncu, and Pantelous provide academic commodity-futures reversal
lineage.

## Claim And Translation Boundary

No parent tests the exact rule below. The papers use monthly reference prices or exchange-traded
futures and do not establish a two-week range expansion, positive weekly body, fixed-dollar
ATR risk, or one-week holding period on the Darwinex continuous CFD. This is a transparent
pre-result QM cross-source hypothesis. No source return, significance, causality, correlation,
or live-fitness claim transfers.

## Bounded Mechanization

At the first tradable `XTIUSD.DWX` D1 bar of each normalized Monday-anchored broker week:

1. Persist the decision-week attempt before calendar, history, signal, news, spread, quote, ATR,
   sizing, margin, or order gates; never retry the week.
2. Require the anchor month to be June, July, August, September, or October and processing to be
   within 180 elapsed minutes of the new bar.
3. Aggregate exactly the two immediately preceding consecutive completed broker weeks from D1
   bars, requiring three through five valid, unique, ordered sessions per week.
4. Compute each full weekly range `R=high-low` and the newest-week log body
   `B=ln(final_close/first_open)`.
5. Require the newest range to be strictly greater than the prior range. Equality, invalid data,
   zero range, or an ineligible month is flat.
6. Sell only when `B>0`. Zero or negative body is flat. There is no long side.
7. Close on the first processed tick in the next normalized week; ten elapsed calendar days is
   stale repair.
8. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Cadence And Falsification

The five-month interval contains roughly twenty-two weekly decisions. Strict two-week
expansion followed by a positive weekly body is expected to produce approximately five to
eight completed positions per full post-warm-up year. Q02 retires on zero trades, fewer than
five completed positions in any full scored year, nonpositive governed economics, or any
contract defect. No calendar, body direction, range orientation, side, or lifecycle may be
changed after Q02 to rescue a failure.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`: peer-reviewed WTI summer-season
  evidence, governed reputable range-state lineage, and academic commodity-reversal lineage;
  the exact conjunction is explicitly untested.
- R2 `PASS`: calendar, two completed weeks, strict range and body inequalities, short-only
  orientation, attempt, stop, spread, and lifecycle are deterministic and locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native `XTIUSD.DWX` D1 supplies every
  runtime market input.
- R4 `PASS`: native timestamps, OHLC, arithmetic, ATR, quotes, positions, deals, and persistent
  state only; no ML, banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Non-Duplicate Boundary

The canonical pre-allocation checker found no exact identity across 4,939 registry rows and 1,548
repository cards, reported six fuzzy family matches, and could not inspect the unavailable
external Strategy Wiki. That fail-closed limitation is preserved in
`artifacts/qm5_candidate_wti_summer_wr2_upweek_fade_dedup_preallocation_20260912.json`.

`QM5_20093` shorts every eligible summer month without weekly price conditioning. `QM5_41406`
and `QM5_41407` use two completed return signs but no range-state gate. The WR2 cards
`QM5_41440`, `QM5_41442`, and `QM5_41444` are November-May rather than summer-only. Closest
sibling `QM5_41457` has the same positive-week short lifecycle but requires strict range
contraction; this candidate requires strict expansion. Those opposite volatility states cannot
signal on the same non-tied observation. Carrier, June-October clock, strict expansion, positive
newest-week body, short-only orientation, and one-week lifecycle are jointly load-bearing.

Manual verdict:
`DISTINCT_WTI_JUNE_OCTOBER_WR2_POSITIVE_WEEK_SHORT_REVERSION_AFTER_FUZZY_FAMILY_REVIEW`.

## Prohibited Interpretations

Do not add moving averages, oscillators, ML features, discretionary patterns, long entries,
adaptive thresholds, extra attempts, pyramiding, scale-ins, targets, or parameter searches. Do
not substitute current-week partial data for a completed week or interpret summer evidence as a
guaranteed short premium.

## Authorization Boundary

The OWNER mission and approval decision authorize one approved card, deterministic allocation,
branch build, governed compile/Q01, and one paced non-live Q02 handoff only. They do not authorize
a manual backtest, optimization, demo/shadow/live work, terminal control, portfolio admission,
correlation waiver, `T_Live`, AutoTrading, or deploy/live manifest changes.

