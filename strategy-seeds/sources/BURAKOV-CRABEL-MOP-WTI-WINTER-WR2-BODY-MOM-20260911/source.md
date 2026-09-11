---
source_id: BURAKOV-CRABEL-MOP-WTI-WINTER-WR2-BODY-MOM-20260911
title: WTI winter weekly range-expansion body momentum
status: approved_source_complete
source_type: governed_peer_reviewed_and_reputable_cross_source_mechanization
approval_basis: decisions/2026-09-11_wti_winter_wr2_body_momentum_source_approval.md
primary_instrument: XTIUSD.DWX
decision_timeframe: D1
strategy_ids:
  - BURAKOV-CRABEL-MOP-WTI-WINTER-WR2-BODY-MOM-20260911_S01
parent_sources:
  - source_id: BURAKOV-WTI-HALLOWEEN-2018
    role: peer_reviewed_wti_november_may_seasonality
  - source_id: MOP-TSMOM-2012
    role: peer_reviewed_own_return_continuation_lineage
  - source_id: CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026
    role: governed_reputable_range_state_and_completed_week_construction
---

# WTI Winter Weekly Range-Expansion Body Momentum

## Complete-Read Record

The bounded parent records `strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md`,
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, and
`strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md` were read completely before
approval. Burakov, Freidin, and Solovyev provide peer-reviewed November-through-May WTI
seasonality. Moskowitz, Ooi, and Pedersen provide peer-reviewed own-return continuation lineage
across liquid futures including WTI. The governed Crabel packet provides reputable range-state
lineage and exact Monday-anchored completed-week construction.

## Claim And Translation Boundary

No parent tests this conjunction. The sources use futures or monthly reference data rather than
the Darwinex continuous CFD, and they do not establish a two-week range comparison, weekly body
direction, fixed-cash ATR risk, or a one-week hold. This is a pre-result QM hypothesis; no source
return, causality, portfolio correlation, or live-fitness claim transfers.

## Bounded Mechanization

At the first tradable `XTIUSD.DWX` D1 bar of each normalized Monday-anchored broker week:

1. Persist the decision-week attempt before calendar, history, signal, news, spread, quote, ATR,
   sizing, margin, or order gates; never retry the week.
2. Continue only when the week anchor month is November, December, January, February, March,
   April, or May and processing is within 180 elapsed minutes of the new bar.
3. Aggregate exactly the two immediately preceding consecutive completed broker weeks from D1
   bars, requiring three through five valid, unique, ordered sessions in each week.
4. Compute each full weekly range `R=high-low` and the newest completed week's body from its
   chronological first open to final close.
5. Require the newest range to be strictly greater than the preceding range. Equality,
   contraction, invalid geometry, missing sessions, or anchor gaps are flat.
6. Buy when the newest completed week's final close is strictly above its first open; sell when
   it is strictly below. Body equality is flat. Close location inside the range is irrelevant.
7. Exit on the first processed tick in the next normalized broker week, with ten elapsed calendar
   days as stale repair.
8. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Cadence And Falsification

The seven-month source window contains roughly thirty weekly decisions. A strict two-week range
expansion followed by nonzero body direction is expected to produce approximately 12-22 completed
positions per full post-warm-up year. Q02 retires on zero trades, fewer than five completed
positions in any full scored year, nonpositive governed economics, or contract mismatch. No
threshold or direction rule may be changed after observing Q02.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`: two named-author peer-reviewed
  lineages plus governed reputable Crabel range-state lineage; the conjunction is untested.
- R2 `PASS`: calendar, completed-week construction, strict range comparison, strict body-sign
  mapping, attempt timing, fixed risk, frozen stop, and lifecycle are deterministic and locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native `XTIUSD.DWX` D1 supplies every
  runtime market input.
- R4 `PASS`: native timestamps, OHLC, arithmetic, ATR, quotes, positions, deals, and persistent
  state only; no ML, banned signal indicator, external feed, grid, martingale, scale-in, or
  pyramiding.

## Non-Duplicate Boundary

The governed pre-allocation checker found no exact identity and surfaced two fuzzy family
neighbors. `QM5_41440` requires an upper-quartile close and buys only; body sign is deliberately
irrelevant. `QM5_41441` requires range contraction and waits for a later completed-current-week
close breakout. `QM5_41442` fades outer-quartile close location. `QM5_41087` is all-year, requires
the widest of four weeks plus an outer-quartile close, and therefore has a different state and
signal. Certified `QM5_12567` is a short-horizon long-only XNG cumulative-RSI pullback. This
candidate requires WTI, November-May, two-week range expansion, the newest completed week's own
body sign, symmetric continuation, and one-week holding jointly.

Manual verdict:
`DISTINCT_WTI_NOVEMBER_MAY_WR2_OWN_BODY_SYMMETRIC_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Prohibited Interpretations

Do not add close-location thresholds, moving averages, oscillators, trained models, adaptive
thresholds, external weather/inventory/curve data, current-week leakage, targets, trails,
scale-in, retry, optimization, grid, or martingale.
