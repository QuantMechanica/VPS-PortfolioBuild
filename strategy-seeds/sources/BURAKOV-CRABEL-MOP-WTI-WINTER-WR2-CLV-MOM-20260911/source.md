---
source_id: BURAKOV-CRABEL-MOP-WTI-WINTER-WR2-CLV-MOM-20260911
title: WTI winter weekly range-expansion upper-quartile continuation
status: approved_source_complete
source_type: governed_peer_reviewed_and_reputable_cross_source_mechanization
approval_basis: decisions/2026-09-11_wti_winter_wr2_clv_momentum_source_approval.md
primary_instrument: XTIUSD.DWX
decision_timeframe: D1
strategy_ids:
  - BURAKOV-CRABEL-MOP-WTI-WINTER-WR2-CLV-MOM-20260911_S01
parent_sources:
  - source_id: BURAKOV-WTI-HALLOWEEN-2018
    role: peer_reviewed_wti_november_may_seasonality
  - source_id: MOP-TSMOM-2012
    role: peer_reviewed_own_return_continuation_lineage
  - source_id: CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026
    role: governed_reputable_range_state_and_completed_week_construction
---

# WTI Winter Weekly Range-Expansion Upper-Quartile Continuation

## Complete-Read Record

The bounded parent records `strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md`,
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, and
`strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md` were read completely before
approval. Burakov, Freidin, and Solovyev provide the peer-reviewed November-through-May WTI
winter-season result. Moskowitz, Ooi, and Pedersen provide peer-reviewed own-return continuation
lineage across liquid futures, including WTI. The governed Crabel packet provides reputable
range-expansion lineage and an exact Monday-anchored completed-week construction.

## Claim And Translation Boundary

No parent tests the conjunction below. The source papers use futures or monthly reference data,
not the Darwinex continuous CFD, and do not establish weekly range expansion, a close-location
threshold, an ATR stop, fixed-cash sizing, or a one-week holding period. This packet is a
transparent pre-result QM hypothesis; no return, causality, correlation, or live-fitness claim
transfers.

## Bounded Mechanization

At the first tradable `XTIUSD.DWX` D1 bar of each normalized Monday-anchored broker week:

1. Persist the decision-week attempt before every fallible gate; never retry the week.
2. Continue only when the week anchor month is November, December, January, February, March,
   April, or May and processing is within 180 elapsed minutes of the new bar.
3. Aggregate exactly the two immediately preceding consecutive completed broker weeks from D1
   bars, requiring three through five valid, unique, ordered sessions per week.
4. Compute each full weekly range `R=high-low` and the newest week's
   `CLV=(final_close-low)/R`.
5. Require the newest range to be strictly greater than the preceding range and `CLV>0.75`.
   Equality, invalid data, zero range, a lower close location, or an ineligible month is flat.
6. Buy WTI only. Weekly body sign is deliberately irrelevant; there is no short branch.
7. Exit on the first processed tick in the next normalized broker week, with ten elapsed calendar
   days as stale repair.
8. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Cadence And Falsification

The seven-month source window contains roughly thirty weekly decisions. A strict two-week range
expansion plus upper-quartile settlement is expected to produce approximately five to twelve
completed positions per full post-warm-up year. Q02 retires on zero trades, fewer than five
completed positions in a full scored year, nonpositive governed economics, or any contract
defect. No threshold may be relaxed after Q02.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`: two named-author peer-reviewed
  papers with DOI or official journal pages plus governed reputable Crabel range-state lineage;
  the exact conjunction is explicitly untested.
- R2 `PASS`: the calendar, two completed weeks, strict range and CLV inequalities, long-only side,
  attempt, stop, spread, and lifecycle are deterministic and locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native `XTIUSD.DWX` D1 history supplies
  every runtime market input.
- R4 `PASS`: native timestamps, OHLC, arithmetic, ATR, quotes, positions, deals, and persistent
  state only; no ML, banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramiding.

## Non-Duplicate Boundary

The governed pre-allocation checker found no exact identity and surfaced five fuzzy family
neighbors. `QM5_41438` applies a symmetric rule to XNG in November-March; this card trades WTI,
uses the full Burakov November-May regime, and is long-only. `QM5_20209` and `QM5_20218` use the
sign of one completed calendar-month WTI return and contain no weekly range or close-location
state. Their duplicate card-store copies add no new identity. The closest WTI WR2/CLV builds,
`QM5_41434` and `QM5_41435`, are restricted to August-October hurricane risk and respectively
buy or fade only that disjoint seasonal state. Certified `QM5_12567` is a long-only two-day
cumulative-RSI XNG pullback above a slow trend. Carrier, November-May clock, strict two-week range
expansion, upper-quartile settlement, long-only side, and one-week lifecycle are jointly
load-bearing.

Manual verdict:
`DISTINCT_WTI_NOVEMBER_MAY_WR2_UPPER_QUARTILE_LONG_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Prohibited Interpretations

Do not add moving averages, oscillators, trained models, adaptive thresholds, body-sign filters,
external weather/inventory/curve data, current-week leakage, targets, trails, scale-in, retry,
optimization, grid, or martingale.
