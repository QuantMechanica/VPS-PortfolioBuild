# XAU/XAG WR2 CLV Reversion - Source Approval

Date: 2026-09-12

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic EA-ID and magic
allocation, one branch-only non-live build, governed Q01 compile validation, and one paced Q02
enqueue if the whole-host CPU ceiling and deterministic intake guards permit.

Authority: the current explicit OWNER commodity/energy diversification mission on branch
`agents/board-advisor`.

## Approved Source Basis

The following committed bounded records were read completely before approval:

1. `strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-WCLOSE-EXTREME-RV-2026/source.md`, the approved
   peer-reviewed-plus-exchange packet for the state-dependent gold/silver relation, CME ratio
   carrier, and weekly relative-value reversion translation; and
2. `strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md`, the approved reputable
   range-state and Monday-anchored completed-week construction packet.

The source-of-record translation is
`strategy-seeds/sources/SCHWEIKERT-CRABEL-CME-XAUXAG-WR2-CLV-RV-20260912/source.md`. Neither
parent tests the exact two-week ratio-range expansion and outer-quartile fade on Darwinex CFDs.

## Locked Mechanic

At the first tradable D1 bar of each normalized week, reconstruct two immediately completed,
consecutive, synchronized XAU/XAG weeks. Form daily log-ratio closes, require the newest weekly
ratio-close range to be strictly wider than its predecessor, then fade only a strict outer-
quartile newest settlement with an opposed equal-notional XAU/XAG package. Consume the week before
fallible gates, close in the next normalized week, enforce frozen `3.5*ATR(20,D1)` per-leg hard
stops and one aggregate fixed-risk budget.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_WEEKLY_TRANSLATION_RISK`: peer-reviewed gold/silver relation,
  CME carrier, and reputable range-state lineage; the exact conjunction is untested.
- R2 `PASS`: timestamps, synchronization, ranges, thresholds, direction, attempt, risk, stops,
  and lifecycle are deterministic.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 data supply every runtime market input.
- R4 `PASS`: deterministic native arithmetic only, without ML, banned signal indicator, external
  runtime feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,928 registry rows and 1,538 repository cards and found no exact
identity. It returned generic XAU/XAG fuzzy relatives and reported the external Strategy Wiki
missing. The durable receipt is
`artifacts/qm5_candidate_xauxag_wr2_clv_rv_dedup_preallocation_20260912.json`.

Manual review separates the one-week closing-rank fade (`QM5_41079`), seven-week contraction then
breakout (`QM5_41060`), per-leg weekly CLV divergence (`QM5_41088`), weekly sign-streak siblings
(`QM5_41417/41418`), and directional seasonal WTI WR2/CLV systems (`QM5_41440/41442`). Verdict:
`DISTINCT_XAUXAG_TWO_WEEK_RATIO_RANGE_EXPANSION_OUTER_QUARTILE_REVERSION_AFTER_FAMILY_REVIEW`.

## Safety Boundary

This approval excludes manual backtests, optimization, demo/shadow/live/stress presets, terminal
control, AutoTrading, `T_Live`, deploy/live manifests, portfolio-gate edits, portfolio admission,
decorrelation claims, and correlation waivers.
