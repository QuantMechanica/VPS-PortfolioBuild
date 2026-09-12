# XAU/XAG NR2 Body Momentum - Source Approval

Date: 2026-09-12

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic EA-ID and magic
allocation, one branch-only non-live build, governed Q01 compile validation, and one paced Q02
enqueue if the whole-host CPU ceiling and deterministic intake guards permit.

Authority: the current explicit OWNER commodity/energy diversification mission on branch
`agents/board-advisor`.

## Approved Source Basis

The following committed bounded records were read completely before approval:

1. `strategy-seeds/sources/FMR-MOMTS-2010/source.md`, preserving the complete accepted
   manuscript for Fuertes, Miffre, and Rallis (2010), *Journal of Banking & Finance* 34(10),
   2530-2548, DOI `10.1016/j.jbankfin.2010.04.009`, and its commodity-momentum lineage;
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, CME's governed gold/silver ratio
   and intermarket-spread carrier record;
3. `strategy-seeds/sources/FMR-CRABEL-CME-XAUXAG-WR2-BODY-MOM-20260912/source.md`, the approved
   momentum-plus-exchange weekly body-continuation translation; and
4. `strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md`, the approved reputable
   range-state and Monday-anchored completed-week construction packet.

The source-of-record translation is
`strategy-seeds/sources/FMR-CRABEL-CME-XAUXAG-NR2-BODY-MOM-20260912/source.md`. None of the
parents tests the exact two-week ratio-range contraction and body continuation on Darwinex CFDs.

## Locked Mechanic

At the first tradable D1 bar of each normalized week, reconstruct the two immediately completed,
consecutive, synchronized XAU/XAG weeks. Form daily log-ratio closes and require the newest weekly
ratio-close range to be strictly narrower than its predecessor. Continue only a strict newest-
week ratio body: buy XAU/sell XAG after a positive body and sell XAU/buy XAG after a negative
body. Use opposed equal-notional legs, consume the week before fallible gates, close in the next
normalized week, and enforce frozen `3.5*ATR(20,D1)` per-leg hard stops under one aggregate
fixed-risk budget.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_HORIZON_AND_CARRIER_TRANSLATION_RISK`: named-author peer-reviewed
  commodity-momentum evidence, CME carrier evidence, and reputable range-state lineage; the exact
  contraction/body-continuation conjunction is untested.
- R2 `PASS`: timestamps, synchronization, ranges, body sign, continuation direction, attempt,
  aggregate risk, stops, and lifecycle are deterministic.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 data supply every runtime market input.
- R4 `PASS`: deterministic native arithmetic only, without ML, banned signal indicator,
  external runtime feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,935 registry rows, 1,544 repository cards, and 45 Strategy Wiki
nodes. It found no exact identity and raised four expected family relatives. The durable receipt
is `artifacts/qm5_candidate_xauxag_nr2_body_mom_dedup_preallocation_20260912.json`.

Manual family review separates `QM5_41449` (strict expansion plus body continuation),
`QM5_41450` (strict contraction but body reversion), `QM5_41451` (strict contraction plus
outer-quartile CLV continuation), and `QM5_41452` (strict expansion plus outer-quartile CLV
continuation). The proposed identity alone combines strict two-week contraction, strict ratio-
week body sign, continuation side, and one-week basket lifecycle. Verdict:
`DISTINCT_XAUXAG_TWO_WEEK_RATIO_RANGE_CONTRACTION_BODY_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Safety Boundary

This approval excludes manual backtests, optimization, demo/shadow/live/stress presets, terminal
control, AutoTrading, `T_Live`, deploy/live manifests, portfolio-gate edits, portfolio admission,
decorrelation claims, and correlation waivers.
