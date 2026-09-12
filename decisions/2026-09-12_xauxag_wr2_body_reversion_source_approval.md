# XAU/XAG WR2 Body Reversion - Source Approval

Date: 2026-09-12

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic EA-ID and magic
allocation, one branch-only non-live build, governed Q01 compile validation, and one paced Q02
enqueue if the whole-host CPU ceiling and deterministic intake guards permit.

Authority: the current explicit OWNER commodity/energy diversification mission on branch
`agents/board-advisor`.

## Approved Source Basis

The following committed bounded records were read completely before approval:

1. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, covering Karsten Schweikert
   (2018), *Journal of Banking & Finance* 88, 44-51, DOI
   `10.1016/j.jbankfin.2017.11.010`, and its state-dependent gold/silver relation lineage;
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, CME's governed gold/silver ratio and
   intermarket-spread carrier record;
3. `strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-WCLOSE-EXTREME-RV-2026/source.md`, the approved
   peer-reviewed-plus-exchange weekly relative-value translation; and
4. `strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md`, the approved reputable
   range-state and Monday-anchored completed-week construction packet.

The source-of-record translation is
`strategy-seeds/sources/SCHWEIKERT-CRABEL-CME-XAUXAG-WR2-BODY-RV-20260912/source.md`. None of the
parents tests the exact two-week ratio-range expansion and body fade on Darwinex CFDs.

## Locked Mechanic

At the first tradable D1 bar of each normalized week, reconstruct the two immediately completed,
consecutive, synchronized XAU/XAG weeks. Form daily log-ratio closes and require the newest weekly
ratio-close range to be strictly wider than its predecessor. Fade only a strict newest-week
ratio body: sell XAU/buy XAG after a positive body and buy XAU/sell XAG after a negative body.
Use opposed equal-notional legs, consume the week before fallible gates, close in the next
normalized week, and enforce frozen `3.5*ATR(20,D1)` per-leg hard stops under one aggregate
fixed-risk budget.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_WEEKLY_TRANSLATION_RISK`: peer-reviewed gold/silver relation,
  CME carrier, and reputable range-state lineage; the exact expansion/body-fade conjunction is
  untested.
- R2 `PASS`: timestamps, synchronization, ranges, body sign, direction, attempt, risk, stops,
  and lifecycle are deterministic.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 data supply every runtime market input.
- R4 `PASS`: deterministic native arithmetic only, without ML, banned signal indicator, external
  runtime feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,936 registry rows, 1,545 repository cards, and 45 Strategy Wiki
records and found no exact identity. It raised five expected family relatives for manual review.
The durable receipt is
`artifacts/qm5_candidate_xauxag_wr2_body_rv_dedup_preallocation_20260912.json`.

`QM5_41448` uses expansion plus a strict outer-quartile ratio close and ignores body sign;
`QM5_41449` expands but continues the strict body; `QM5_41450` fades a body only after contraction;
`QM5_41453` uses contraction plus CLV reversion; and `QM5_41454` uses contraction plus body
continuation. The proposed card alone requires strict expansion and fades its strict body. Verdict:
`DISTINCT_XAUXAG_TWO_WEEK_RATIO_RANGE_EXPANSION_BODY_REVERSION_AFTER_FAMILY_REVIEW`.

## Safety Boundary

This approval excludes manual backtests, optimization, demo/shadow/live/stress presets, terminal
control, AutoTrading, `T_Live`, deploy/live manifests, portfolio-gate edits, portfolio admission,
decorrelation claims, and correlation waivers.

