---
source_id: FMR-CRABEL-CME-XAUXAG-NR2-CLV-MOM-20260912
title: Gold-silver weekly ratio contraction outer-quartile continuation
status: approved_source_complete
source_type: governed_peer_reviewed_exchange_and_range_state_mechanization
approval_basis: decisions/2026-09-12_xauxag_nr2_clv_momentum_source_approval.md
primary_instruments: [XAUUSD.DWX, XAGUSD.DWX]
decision_timeframe: D1
strategy_ids:
  - FMR-CRABEL-CME-XAUXAG-NR2-CLV-MOM-20260912_S01
parent_sources:
  - source_id: FMR-MOMTS-2010
    role: peer_reviewed_commodity_momentum_lineage
  - source_id: CME-GSR-SPREAD-2025
    role: official_exchange_gold_silver_ratio_and_spread_carrier
  - source_id: CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026
    role: governed_range_state_and_monday_anchored_completed_week_construction
---

# Gold-Silver Weekly Ratio Contraction Outer-Quartile Continuation

## Complete-Read Record

The three bounded repository parent records named above were read end to end before the durable
approval at `decisions/2026-09-12_xauxag_nr2_clv_momentum_source_approval.md`.
`FMR-MOMTS-2010` preserves the complete 47-page accepted manuscript for Fuertes, Miffre, and
Rallis (2010), including its one-month commodity-momentum formation/holding lineage.
`CME-GSR-SPREAD-2025` defines the gold/silver ratio and its intermarket-spread carrier.
`CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026` carries reputable range-state lineage and a reproducible
Monday-anchored completed-week construction. No unrecorded online content is used.

## Claim And Translation Boundary

No parent tests this exact rule. The sources support investigating systematic commodity
momentum, gold/silver relative-value exposure, and completed-period range states. They do not
establish that contraction in weekly ratio-close range followed by an outer-quartile settlement
continues during the next week. They also do not establish equal-notional neutrality, the weekly
horizon, Darwinex CFD equivalence, activity, profitability, decorrelation, or live fitness. This
is a pre-result QM hypothesis.

## Bounded Mechanization

At the first tradable `XAUUSD.DWX` D1 bar of each new normalized Monday-anchored broker week:

1. Persist the decision-week attempt before history, signal, news, spread, quote, ATR, sizing,
   margin, or order gates; never retry the week.
2. Aggregate exactly the two immediately preceding consecutive completed broker weeks from
   synchronized XAU and XAG D1 bars. Each week must contain three through five positive, finite,
   unique, strictly ordered sessions, and both legs must share every timestamp.
3. For each session compute `s=ln(XAU_close)-ln(XAG_close)`. For each week compute ratio-close
   range `R=max(s)-min(s)`. Require both ranges positive and finite and newest `R` strictly less
   than prior `R`; equality or expansion is flat. Containment is irrelevant.
4. Compute newest-week `CLV=(s_final-min(s))/R`. If `CLV>0.75`, BUY XAU and SELL XAG. If
   `CLV<0.25`, SELL XAU and BUY XAG. Equality or an interior value is flat. Ratio-week body sign
   is irrelevant.
5. Target equal absolute USD notionals under one aggregate fixed-dollar stop-risk budget.
6. Close both legs on the first processed tick in the next normalized week; ten elapsed calendar
   days is stale repair.
7. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, independent frozen
   `3.5*ATR(20,D1)` hard stops, no target, a 20% notional-mismatch cap, and XAU/XAG spread ceilings
   of 1500/500 points.

## Cadence And Falsification

A newest strict NR2 state should occur roughly every second completed week before the outer-
quartile filter and operational losses. The pre-result expectation is approximately eight to
sixteen completed packages per full post-warm-up year. Q02 retires on zero packages, fewer than
five completed packages in any full scored year, nonpositive governed economics, or contract
mismatch. No range orientation, CLV threshold, side, carrier, stop, or lifecycle may be changed
after Q02 to rescue a failure.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_HORIZON_AND_CARRIER_TRANSLATION_RISK`: named-author peer-reviewed
  commodity-momentum evidence, CME exchange carrier evidence, and governed reputable range-state
  lineage; the exact conjunction and horizon are explicitly untested.
- R2 `PASS`: synchronization, two completed weeks, strict range contraction, strict outer-
  quartile close, continuation sides, attempt, aggregate risk, stops, and lifecycle are
  deterministic and locked.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XAUUSD.DWX`/`XAGUSD.DWX` D1 histories provide all runtime market data.
- R4 `PASS`: native timestamps, prices, logarithms, comparisons, ATR, quotes, positions, deals,
  and persistent state only; no ML, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Non-Duplicate Boundary

The canonical pre-allocation checker found no exact identity across 4,931 registry rows, 1,541
repository cards, and 45 Strategy Wiki records. Its coarse token matcher raised expected XAU/XAG
family relatives; the durable receipt is
`artifacts/qm5_candidate_xauxag_nr2_clv_mom_dedup_preallocation_20260912.json`.

Manual review distinguishes this candidate from `QM5_41448`, which requires range expansion and
fades the outer-quartile close; `QM5_41449`, which requires expansion and continues body sign;
`QM5_41450`, which requires contraction but fades body sign while ignoring CLV; and `QM5_41060`,
which requires the narrowest of seven completed weekly ranges and a later current-week close
breakout. `QM5_12724` uses a 120-day ratio channel and channel exit rather than a two-week range
state or one-week time exit. The paired carrier, strict two-week contraction, ratio CLV, momentum
side, immediate weekly entry, and one-week package are jointly load-bearing.

Manual verdict:
`DISTINCT_XAUXAG_TWO_WEEK_RATIO_RANGE_CONTRACTION_OUTER_QUARTILE_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Prohibited Interpretations

Do not add containment, a fitted center or beta, moving average, oscillator, body-sign filter,
seasonal gate, current-week breakout, adaptive threshold, external feed, target, trail, partial,
scale-in, retry, optimization, grid, or martingale.

## Safety Boundary

This packet supports one V5 card, deterministic allocation, one branch-only non-live build,
strict Q01, and one paced fixed-risk Q02 handoff if CPU permits. It does not authorize manual
backtests, portfolio-gate edits or admission, a correlation waiver, deploy/live manifests,
`T_Live`, AutoTrading, terminal control, or live use.
