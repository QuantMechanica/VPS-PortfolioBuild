# XAU/XAG NR2 CLV Reversion - Source Approval

Date: 2026-09-12

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic EA-ID and magic
allocation, one branch-only non-live build, governed Q01 compile validation, and one paced Q02
enqueue if the whole-host CPU ceiling and deterministic intake guards permit.

Authority: the current explicit OWNER commodity/energy diversification mission on branch
`agents/board-advisor`.

## Approved Source Basis

The following committed bounded records were read completely before approval:

1. `strategy-seeds/sources/FMR-CRABEL-CME-XAUXAG-NR2-CLV-MOM-20260912/source.md`, preserving
   peer-reviewed commodity evidence, CME's gold/silver intermarket-spread carrier, and the
   governed synchronized two-week range-contraction/CLV construction; and
2. `strategy-seeds/sources/SCHWEIKERT-CRABEL-CME-XAUXAG-WR2-CLV-RV-20260912/source.md`,
   preserving the peer-reviewed gold/silver relation, the same official exchange carrier, and
   the outer-quartile contrarian interpretation on an expansion state.

Neither parent tests the exact Darwinex-CFD rule approved here. The source-of-record synthesis is
`strategy-seeds/sources/SCHWEIKERT-CRABEL-CME-XAUXAG-NR2-CLV-RV-20260912/source.md`.

## Locked Mechanic

At the first tradable D1 bar of each normalized week, reconstruct the two immediately completed,
consecutive, synchronized XAU/XAG weeks. Form daily log-ratio closes and require the newest
weekly ratio-close range to be strictly narrower than its predecessor. Fade only a strict
outer-quartile newest close: sell XAU/buy XAG above `0.75`, and buy XAU/sell XAG below `0.25`.
Use opposed equal-notional legs, consume the week before fallible gates, close in the next
normalized week, and enforce frozen `3.5*ATR(20,D1)` per-leg hard stops under one aggregate
fixed-risk budget.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_HORIZON_AND_CARRIER_TRANSLATION_RISK`: named-author peer-reviewed
  gold/silver and commodity evidence, official-exchange carrier evidence, and governed reputable
  range-state lineage; the exact conjunction and weekly horizon are explicitly untested.
- R2 `PASS`: timestamps, synchronization, strict contraction, strict CLV thresholds, contrarian
  sides, attempt, risk, stops, notional tolerance, spreads, and lifecycle are deterministic.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 data supply every runtime market input.
- R4 `PASS`: deterministic native arithmetic only, without ML, banned signal indicator, external
  runtime feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,934 registry rows, 1,543 repository cards, and 45 Strategy Wiki
nodes. It found no exact identity and returned only coarse XAU/XAG family matches. The durable
receipt is `artifacts/qm5_candidate_xauxag_nr2_clv_rv_dedup_preallocation_20260912.json`.

Manual family review separates `QM5_41448` (WR2/CLV fade), `QM5_41450` (NR2/body fade),
`QM5_41451` (NR2/CLV continuation), `QM5_41452` (WR2/CLV continuation), `QM5_41060`
(seven-week compression then current-week breakout), and `QM5_12724` (120-day ratio channel).
No reviewed identity combines strict two-week XAU/XAG ratio-range contraction, strict ratio CLV,
immediate contrarian entry, and a one-week equal-notional package. Verdict:
`DISTINCT_XAUXAG_TWO_WEEK_RATIO_RANGE_CONTRACTION_OUTER_QUARTILE_REVERSION_AFTER_FAMILY_REVIEW`.

## Safety Boundary

This approval excludes manual backtests, optimization, demo/shadow/live/stress presets, terminal
control, AutoTrading, `T_Live`, deploy/live manifests, portfolio-gate edits, portfolio admission,
decorrelation claims, and correlation waivers.

