---
source_id: SCHWEIKERT-CRABEL-CME-XAUXAG-NR2-CLV-RV-20260912
title: Gold-silver weekly ratio contraction outer-quartile reversion
status: approved_source_complete
source_type: governed_peer_reviewed_exchange_and_range_state_mechanization
approval_basis: decisions/2026-09-12_xauxag_nr2_clv_reversion_source_approval.md
primary_instruments: [XAUUSD.DWX, XAGUSD.DWX]
decision_timeframe: D1
strategy_ids:
  - SCHWEIKERT-CRABEL-CME-XAUXAG-NR2-CLV-RV-20260912_S01
parent_sources:
  - source_id: FMR-CRABEL-CME-XAUXAG-NR2-CLV-MOM-20260912
    role: synchronized_two_week_ratio_range_contraction_and_clv_construction
  - source_id: SCHWEIKERT-CRABEL-CME-XAUXAG-WR2-CLV-RV-20260912
    role: peer_reviewed_exchange_relative_value_and_outer_quartile_reversion_lineage
---

# Gold-Silver Weekly Ratio Contraction Outer-Quartile Reversion

## Complete-Read Record

The two bounded repository parent records named above were read end to end before the durable
approval at `decisions/2026-09-12_xauxag_nr2_clv_reversion_source_approval.md`. The first carries
the exact synchronized two-completed-week ratio-range contraction and CLV construction. The
second carries named-author peer-reviewed gold/silver relation evidence, CME's definition of the
gold/silver ratio as an intermarket spread, and a governed outer-quartile relative-value
reversion translation. No unrecorded online content is used.

## Claim And Translation Boundary

No parent tests this exact rule. The sources support investigating a structural gold/silver
relative-value carrier, systematic completed-period range states, and contrarian response to a
relative settlement extreme. They do not establish that an outer-quartile close after weekly
ratio-range contraction reverses during the next week. Equal-notional neutrality, Darwinex CFD
equivalence, activity, profitability, decorrelation, and live fitness are unproven. This is a
pre-result QM hypothesis.

## Bounded Mechanization

At the first tradable `XAUUSD.DWX` D1 bar of each new normalized Monday-anchored broker week:

1. Persist the decision-week attempt before history, signal, news, spread, quote, ATR, sizing,
   margin, or order gates; never retry the week.
2. Aggregate exactly the two immediately preceding consecutive completed broker weeks from
   synchronized XAU and XAG D1 bars. Each week must contain three through five positive, finite,
   unique, strictly ordered sessions, and both legs must share every timestamp.
3. For every session compute `s=ln(XAU_close)-ln(XAG_close)`. For each week compute
   `R=max(s)-min(s)`. Require both ranges positive and finite and newest `R` strictly less than
   prior `R`; equality or expansion is flat. Containment is irrelevant.
4. Compute newest-week `CLV=(s_final-min(s))/R`. If `CLV>0.75`, SELL XAU and BUY XAG. If
   `CLV<0.25`, BUY XAU and SELL XAG. Equality or an interior value is flat. Ratio-week body sign
   is irrelevant.
5. Target equal absolute USD notionals under one aggregate fixed-dollar stop-risk budget.
6. Close both legs on the first processed tick in the next normalized week; ten elapsed calendar
   days is stale repair.
7. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, independent frozen
   `3.5*ATR(20,D1)` hard stops, no target, a 20% notional-mismatch cap, and XAU/XAG spread
   ceilings of 1500/500 points.

## Cadence And Falsification

The strict NR2 state plus outer-quartile filter is deliberately sparse, with an ex-ante
expectation of roughly eight to sixteen completed packages per full post-warm-up year. Q02
retires on zero packages, fewer than five completed packages in any full scored year,
nonpositive governed economics, or contract mismatch. No range orientation, CLV threshold,
side, carrier, stop, or lifecycle may be changed after Q02 to rescue a failure.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_HORIZON_AND_CARRIER_TRANSLATION_RISK`: named-author peer-reviewed
  evidence, CME exchange carrier evidence, and governed reputable range-state lineage; the exact
  conjunction and horizon are explicitly untested.
- R2 `PASS`: synchronization, two completed weeks, strict contraction, strict outer-quartile
  close, contrarian sides, attempt, aggregate risk, stops, and lifecycle are deterministic.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XAUUSD.DWX`/`XAGUSD.DWX` D1 histories provide all runtime market data.
- R4 `PASS`: native timestamps, prices, logarithms, comparisons, ATR, quotes, positions, deals,
  and persistent state only; no ML, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Non-Duplicate Boundary

The canonical pre-allocation checker found no exact identity across 4,934 registry rows, 1,543
repository cards, and 45 Strategy Wiki nodes. Its token matcher raised expected XAU/XAG family
relatives; the durable receipt is
`artifacts/qm5_candidate_xauxag_nr2_clv_rv_dedup_preallocation_20260912.json`.

Manual review distinguishes `QM5_41448` (range expansion plus CLV fade), `QM5_41450`
(contraction plus body fade), `QM5_41451` (contraction plus CLV continuation), and `QM5_41452`
(expansion plus CLV continuation). `QM5_41060` waits for a current-week breakout after a
seven-week compression state, while `QM5_12724` uses a 120-day channel. The paired carrier,
strict two-week contraction, ratio CLV, contrarian side, immediate weekly entry, and one-week
package are jointly load-bearing.

Manual verdict:
`DISTINCT_XAUXAG_TWO_WEEK_RATIO_RANGE_CONTRACTION_OUTER_QUARTILE_REVERSION_AFTER_FAMILY_REVIEW`.

## Prohibited Interpretations

Do not add containment, a fitted center or beta, moving average, oscillator, body-sign filter,
seasonal gate, current-week breakout, adaptive threshold, external feed, target, trail, partial,
scale-in, retry, optimization, grid, or martingale.

## Safety Boundary

This packet supports one V5 card, deterministic allocation, one branch-only non-live build,
strict Q01, and one paced fixed-risk Q02 handoff if CPU permits. It does not authorize manual
backtests, portfolio-gate edits or admission, a correlation waiver, deploy/live manifests,
`T_Live`, AutoTrading, terminal control, or live use.
