---
source_id: SCHWEIKERT-CRABEL-CME-XAUXAG-NR2-BODY-RV-20260912
title: Gold-silver weekly ratio contraction body reversion
status: approved_source_complete
source_type: governed_peer_reviewed_exchange_and_range_state_mechanization
approval_basis: decisions/2026-09-12_xauxag_nr2_body_reversion_source_approval.md
primary_instruments: [XAUUSD.DWX, XAGUSD.DWX]
decision_timeframe: D1
strategy_ids:
  - SCHWEIKERT-CRABEL-CME-XAUXAG-NR2-BODY-RV-20260912_S01
parent_sources:
  - source_id: SCHWEIKERT-CME-XAUXAG-WCLOSE-EXTREME-RV-2026
    role: peer_reviewed_cointegration_lineage_exchange_ratio_carrier_and_weekly_reversion_translation
  - source_id: CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026
    role: governed_range_state_and_monday_anchored_completed_week_construction
---

# Gold-Silver Weekly Ratio Contraction Body Reversion

## Complete-Read Record

The two bounded approved parent records named above and their underlying repository packets were
read end to end before the durable approval at
`decisions/2026-09-12_xauxag_nr2_body_reversion_source_approval.md`.
`SCHWEIKERT-CME-XAUXAG-WCLOSE-EXTREME-RV-2026` carries named-author peer-reviewed evidence that
the gold/silver relation can be state dependent, CME's definition of the gold/silver ratio as an
intermarket spread, and a governed weekly relative-value reversion translation.
`CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026` carries reputable range-state lineage and a reproducible
Monday-anchored completed-week construction. No unrecorded online content is used.

## Claim And Translation Boundary

No parent tests this exact rule. The sources support investigating a state-dependent gold/silver
relative-value carrier and systematic range states. They do not establish that contraction from
one completed ratio week to the next, followed by a nonzero weekly ratio body, reverses over the
following week. They also do not establish equal-notional neutrality, the weekly horizon,
Darwinex CFD equivalence, activity, profitability, decorrelation, or live fitness. This is a
pre-result QM hypothesis.

## Bounded Mechanization

At the first tradable `XAUUSD.DWX` D1 bar of each new normalized Monday-anchored broker week:

1. Persist the decision-week attempt before history, signal, news, spread, quote, ATR, sizing,
   margin, or order gates; never retry the week.
2. Aggregate exactly the two immediately preceding consecutive completed broker weeks from
   synchronized XAU and XAG D1 bars. Each week must contain three through five positive, finite,
   unique, strictly ordered sessions, and both legs must share every timestamp.
3. For each session compute `s=ln(XAU_close)-ln(XAG_close)`. For each week compute the ratio-close
   range `R=max(s)-min(s)`. Require both ranges positive and finite and newest `R` strictly less
   than prior `R`; equality or expansion is flat.
4. Compute newest completed ratio-week body `B=s_final-s_first`. Require strict
   `abs(B)>1e-10`. If `B>1e-10`, SELL XAU and BUY XAG. If `B<-1e-10`, BUY XAU and SELL XAG.
   A tied body is flat. Close location, containment, and absolute ratio level are irrelevant.
5. Target equal absolute USD notionals under one aggregate fixed-dollar stop-risk budget.
6. Close both legs on the first processed tick in the next normalized week; ten elapsed calendar
   days is stale repair.
7. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, independent frozen
   `3.5*ATR(20,D1)` hard stops, no target, a 20% notional-mismatch cap, and XAU/XAG spread ceilings
   of 1500/500 points.

## Cadence And Falsification

A newest strict NR2 state should occur roughly every second completed week before operational
losses, while a strict body tie should be rare. The pre-result expectation is approximately
eighteen to twenty-six completed packages per full post-warm-up year. Q02 retires on zero
packages, fewer than ten distinct entry days in any full scored year, nonpositive governed
economics, or contract mismatch. No range orientation, side, carrier, stop, or lifecycle may be
changed after Q02 to rescue a failure.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_WEEKLY_TRANSLATION_RISK`: named-author peer-reviewed
  gold/silver relationship evidence, CME exchange carrier evidence, and governed reputable
  range-state lineage; the exact contraction/body-fade conjunction is explicitly untested.
- R2 `PASS`: synchronization, two completed weeks, strict contraction, strict body sign,
  contrarian sides, attempt, aggregate risk, stops, and lifecycle are deterministic and locked.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XAUUSD.DWX`/`XAGUSD.DWX` D1 histories provide all runtime market data.
- R4 `PASS`: native timestamps, prices, logarithms, comparisons, ATR, quotes, positions, deals,
  and persistent state only; no ML, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Non-Duplicate Boundary

The canonical pre-allocation checker found no exact identity across 4,930 registry rows, 1,540
repository cards, and 45 Strategy Wiki records. It raised the expected fuzzy relatives
`QM5_41448` and `QM5_41449`; the durable receipt is
`artifacts/qm5_candidate_xauxag_nr2_body_rv_dedup_preallocation_20260912.json`.

Manual review distinguishes this candidate from `QM5_41448`, which requires ratio-range
expansion plus an outer-quartile final close and ignores body sign, and `QM5_41449`, which requires
ratio-range expansion and continues rather than fades the newest body. Earlier weekly XAU/XAG
families use endpoint streaks, alternation, close-location divergence, current-week breakouts, or
multiweek fitted centers. This candidate's strict two-week contraction state, strict body sign,
contrarian package, and one-week lifecycle are jointly load-bearing.

Manual verdict:
`DISTINCT_XAUXAG_TWO_WEEK_RATIO_RANGE_CONTRACTION_BODY_REVERSION_AFTER_FAMILY_REVIEW`.

## Prohibited Interpretations

Do not add containment, a fitted center or beta, moving average, oscillator, close-location
filter, seasonal gate, current-week breakout, adaptive threshold, external feed, target, trail,
partial, scale-in, retry, optimization, grid, or martingale.

## Safety Boundary

This packet supports one V5 card, deterministic allocation, one branch-only non-live build,
strict Q01, and one paced fixed-risk Q02 handoff if CPU permits. It does not authorize manual
backtests, portfolio-gate edits or admission, a correlation waiver, deploy/live manifests,
`T_Live`, AutoTrading, terminal control, or live use.
