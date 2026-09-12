---
source_id: FMR-CRABEL-CME-XAUXAG-WR2-BODY-MOM-20260912
title: Gold-silver weekly ratio range-expansion body continuation
status: approved_source_complete
source_type: governed_peer_reviewed_exchange_and_range_state_mechanization
approval_basis: decisions/2026-09-12_xauxag_wr2_body_momentum_source_approval.md
primary_instruments: [XAUUSD.DWX, XAGUSD.DWX]
decision_timeframe: D1
strategy_ids:
  - FMR-CRABEL-CME-XAUXAG-WR2-BODY-MOM-20260912_S01
parent_sources:
  - source_id: FMR-MOMTS-2010
    role: peer_reviewed_commodity_momentum_lineage
  - source_id: CME-GSR-SPREAD-2025
    role: official_exchange_gold_silver_ratio_and_spread_carrier
  - source_id: CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026
    role: governed_range_state_and_monday_anchored_completed_week_construction
---

# Gold-Silver Weekly Ratio Range-Expansion Body Continuation

## Complete-Read Record

The three bounded approved parent records named above were read end to end before the durable
approval at `decisions/2026-09-12_xauxag_wr2_body_momentum_source_approval.md`.
`FMR-MOMTS-2010` preserves the complete 47-page accepted manuscript for Fuertes, Miffre, and
Rallis (2010), including the one-month commodity-momentum formation/holding lineage.
`CME-GSR-SPREAD-2025` defines the gold/silver ratio and its intermarket-spread carrier.
`CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026` carries reputable range-state lineage and a reproducible
Monday-anchored completed-week construction. No unrecorded online content is used.

## Claim And Translation Boundary

No parent tests this exact rule. The sources support investigating systematic commodity momentum,
gold/silver relative-value exposure, and completed-period range states. They do not establish that
an expanding weekly ratio-close range followed by continuation of that week's body is profitable.
They also do not establish equal-notional neutrality, the weekly horizon, Darwinex CFD
equivalence, activity, profitability, decorrelation, or live fitness. This is a pre-result QM
hypothesis.

## Bounded Mechanization

At the first tradable `XAUUSD.DWX` D1 bar of each new normalized Monday-anchored broker week:

1. Persist the decision-week attempt before history, signal, news, spread, quote, ATR, sizing,
   margin, or order gates; never retry the week.
2. Aggregate exactly the two immediately preceding consecutive completed broker weeks from
   synchronized XAU and XAG D1 bars. Each week must contain three through five positive, finite,
   unique, strictly ordered sessions, and both legs must share every timestamp.
3. For each session compute `s=ln(XAU_close)-ln(XAG_close)`. For each week compute ratio-close
   range `R=max(s)-min(s)`. Require both ranges positive and finite and newest `R` strictly greater
   than prior `R`; equality or contraction is flat.
4. Compute the newest completed ratio-week body `B=s_final-s_first`. Require strict
   `abs(B)>1e-10`. If `B>1e-10`, BUY XAU and SELL XAG. If `B<-1e-10`, SELL XAU and BUY XAG.
   A tied body is flat. Close-location and absolute ratio level are irrelevant.
5. Target equal absolute USD notionals under one aggregate fixed-dollar stop-risk budget.
6. Close both legs on the first processed tick in the next normalized week; ten elapsed calendar
   days is stale repair.
7. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, independent frozen
   `3.5*ATR(20,D1)` hard stops, no target, a 20% notional-mismatch cap, and XAU/XAG spread ceilings
   of 1500/500 points.

## Cadence And Falsification

A newest strict WR2 state should occur roughly every second completed week before operational
losses, while a strict body tie should be rare. The pre-result expectation is approximately
eighteen to twenty-six completed packages per full post-warm-up year. Q02 retires on zero
packages, fewer than ten distinct entry days in any full scored year, nonpositive governed
economics, or contract mismatch. No range orientation, side, carrier, stop, or lifecycle may be
changed after Q02 to rescue a failure.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_HORIZON_AND_CARRIER_TRANSLATION_RISK`: named-author peer-reviewed
  commodity-momentum evidence, CME exchange carrier evidence, and governed reputable range-state
  lineage; the exact conjunction and horizon are explicitly untested.
- R2 `PASS`: synchronization, two completed weeks, strict range expansion, strict body sign,
  continuation sides, attempt, aggregate risk, stops, and lifecycle are deterministic and locked.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XAUUSD.DWX`/`XAGUSD.DWX` D1 histories provide all runtime market data.
- R4 `PASS`: native timestamps, prices, logarithms, comparisons, ATR, quotes, positions, deals,
  and persistent state only; no ML, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Non-Duplicate Boundary

The corrected canonical pre-allocation checker used the current Vault path and found no exact
identity or fuzzy match across 4,929 registry rows, 1,539 repository cards, and 45 Strategy Wiki
records. Its durable receipt is
`artifacts/qm5_candidate_xauxag_wr2_body_mom_dedup_preallocation_20260912.json`.

Manual review distinguishes this candidate from `QM5_41448`, which uses the same two-week
ratio-range state but requires an outer-quartile close and takes the contrarian side;
`QM5_41413`, which requires three alternating endpoint returns rather than a range expansion;
`QM5_41418`, which requires a same-sign weekly streak; and `QM5_41443`, which trades one
directional WTI leg only inside November-May. The carrier, range object, two-week expansion,
strict body direction, continuation side, and one-week package are jointly load-bearing.

Manual verdict:
`DISTINCT_XAUXAG_TWO_WEEK_RATIO_RANGE_EXPANSION_BODY_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Prohibited Interpretations

Do not add a fitted center or beta, moving average, oscillator, close-location filter, seasonal
gate, current-week breakout, adaptive threshold, external feed, target, trail, partial, scale-in,
retry, optimization, grid, or martingale.

## Safety Boundary

This packet supports one V5 card, deterministic allocation, one branch-only non-live build,
strict Q01, and one paced fixed-risk Q02 handoff if CPU permits. It does not authorize manual
backtests, portfolio-gate edits or admission, a correlation waiver, deploy/live manifests,
`T_Live`, AutoTrading, terminal control, or live use.
