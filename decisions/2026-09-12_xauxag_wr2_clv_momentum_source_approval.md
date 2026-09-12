# XAU/XAG WR2 CLV Momentum - Source Approval

Date: 2026-09-12

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic EA-ID and magic
allocation, one branch-only non-live build, governed Q01 compile validation, and one paced Q02
enqueue if the whole-host CPU ceiling and deterministic intake guards permit.

Authority: the current explicit OWNER commodity/energy diversification mission on branch
`agents/board-advisor`.

## Approved Source Basis

The following committed bounded records were read completely before approval:

1. `strategy-seeds/sources/FMR-CRABEL-CME-XAUXAG-NR2-CLV-MOM-20260912/source.md`, preserving
   peer-reviewed commodity-momentum lineage, CME's gold/silver intermarket-spread carrier, and
   the governed completed-week range construction; and
2. `strategy-seeds/sources/SCHWEIKERT-CRABEL-CME-XAUXAG-WR2-CLV-RV-20260912/source.md`, preserving
   the same synchronized two-week ratio-range expansion and outer-quartile geometry with the
   opposite, reversion-side hypothesis.

The source-of-record translation is
`strategy-seeds/sources/FMR-CRABEL-CME-XAUXAG-WR2-CLV-MOM-20260912/source.md`. Neither parent
tests the exact gold/silver ratio-range expansion and outer-quartile continuation rule on
Darwinex CFDs.

## Locked Mechanic

At the first tradable D1 bar of each normalized week, reconstruct the two immediately completed,
consecutive, synchronized XAU/XAG weeks. Form daily log-ratio closes and require the newest weekly
ratio-close range to be strictly wider than its predecessor. Continue only a strict outer-
quartile newest close: buy XAU/sell XAG above `0.75`, and sell XAU/buy XAG below `0.25`. Use
opposed equal-notional legs, consume the week before fallible gates, close in the next normalized
week, and enforce frozen `3.5*ATR(20,D1)` per-leg hard stops under one aggregate fixed-risk budget.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_HORIZON_AND_CARRIER_TRANSLATION_RISK`: peer-reviewed commodity-
  momentum evidence, official-exchange gold/silver spread evidence, and governed reputable
  range-state lineage; the exact conjunction and weekly horizon are untested.
- R2 `PASS`: timestamps, synchronization, strict range expansion, CLV thresholds, direction,
  attempt, risk, stops, notional tolerance, spreads, and lifecycle are deterministic.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 data supply every runtime market input.
- R4 `PASS`: deterministic native arithmetic only, without ML, banned signal indicator, external
  runtime feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,933 registry rows and 1,542 repository cards. The configured
Strategy Wiki root was absent, so that source remained explicitly unavailable; the scan found no
exact identity and returned coarse fuzzy XAU/XAG family matches. The durable receipt is
`artifacts/qm5_candidate_xauxag_wr2_clv_mom_dedup_preallocation_20260912.json`.

Manual family review separates `QM5_41448` (the identical WR2/CLV event faded), `QM5_41449`
(WR2 with ratio-body continuation and no close-location requirement), `QM5_41450` (NR2 with
ratio-body reversion), `QM5_41451` (NR2 with outer-quartile continuation), `QM5_41060`
(seven-week narrow-range state plus a later breakout), and `QM5_12724` (120-day channel
breakout/exit). No reviewed identity requires strict two-week XAU/XAG ratio-range expansion
followed by immediate continuation of a strict outer-quartile completed close for exactly one
week. Verdict:
`DISTINCT_XAUXAG_TWO_WEEK_RATIO_RANGE_EXPANSION_OUTER_QUARTILE_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Safety Boundary

This approval excludes manual backtests, optimization, demo/shadow/live/stress presets, terminal
control, AutoTrading, `T_Live`, deploy/live manifests, portfolio-gate edits, portfolio admission,
decorrelation claims, and correlation waivers.
