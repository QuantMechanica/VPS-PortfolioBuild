# XAU/XAG WR2 Body Momentum - Source Approval

Date: 2026-09-12

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic EA-ID and magic
allocation, one branch-only non-live build, governed Q01 compile validation, and one paced Q02
enqueue if the whole-host CPU ceiling and deterministic intake guards permit.

Authority: the current explicit OWNER commodity/energy diversification mission on branch
`agents/board-advisor`.

## Approved Source Basis

The following committed bounded records were read completely before approval:

1. `strategy-seeds/sources/FMR-MOMTS-2010/source.md`, preserving the complete accepted manuscript
   and DOI for Fuertes, Miffre, and Rallis (2010) and its one-month commodity-momentum lineage;
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, preserving CME's gold/silver ratio and
   intermarket-spread carrier; and
3. `strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md`, preserving the governed
   reputable range-state and Monday-anchored completed-week construction.

The source-of-record translation is
`strategy-seeds/sources/FMR-CRABEL-CME-XAUXAG-WR2-BODY-MOM-20260912/source.md`. None of the
parents tests the exact two-week gold/silver ratio-range expansion and weekly-body continuation
on Darwinex CFDs.

## Locked Mechanic

At the first tradable D1 bar of each normalized week, reconstruct the two immediately completed,
consecutive, synchronized XAU/XAG weeks. Form daily log-ratio closes and require the newest weekly
ratio-close range to be strictly wider than its predecessor. Continue only a strict newest-week
ratio body: buy XAU/sell XAG when the final ratio close exceeds the first, and sell XAU/buy XAG
when it is lower. Use opposed equal-notional legs, consume the week before fallible gates, close
in the next normalized week, and enforce frozen `3.5*ATR(20,D1)` per-leg hard stops under one
aggregate fixed-risk budget.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_HORIZON_AND_CARRIER_TRANSLATION_RISK`: peer-reviewed commodity-
  momentum evidence, official-exchange gold/silver spread evidence, and reputable range-state
  lineage; the exact conjunction and weekly horizon are untested.
- R2 `PASS`: timestamps, synchronization, ranges, body sign, direction, attempt, risk, stops,
  notional tolerance, spreads, and lifecycle are deterministic.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 data supply every runtime market input.
- R4 `PASS`: deterministic native arithmetic only, without ML, banned signal indicator, external
  runtime feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,929 registry rows, 1,539 repository cards, and 45 current
Strategy Wiki records. It found no exact identity and no fuzzy match above threshold. The durable
receipt is
`artifacts/qm5_candidate_xauxag_wr2_body_mom_dedup_preallocation_20260912.json`.

Manual family review separates the two-week ratio-range/outer-quartile fade in `QM5_41448`, the
three-return alternation continuation in `QM5_41413`, the same-sign weekly streak continuation in
`QM5_41418`, and the directional November-May WTI WR2/body continuation in `QM5_41443`. None
requires a two-week XAU/XAG ratio-range expansion followed by continuation of the newest
completed ratio-week body. Verdict:
`DISTINCT_XAUXAG_TWO_WEEK_RATIO_RANGE_EXPANSION_BODY_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Safety Boundary

This approval excludes manual backtests, optimization, demo/shadow/live/stress presets, terminal
control, AutoTrading, `T_Live`, deploy/live manifests, portfolio-gate edits, portfolio admission,
decorrelation claims, and correlation waivers.
