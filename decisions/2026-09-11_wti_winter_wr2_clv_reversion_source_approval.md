# WTI Winter WR2 Close-Location Reversion - Source Approval

Date: 2026-09-11

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic EA-ID and magic
allocation, one branch-only non-live build, strict Q01 validation, and one paced Q02 enqueue if
the whole-host CPU ceiling permits.

Authority: the current explicit OWNER commodity/energy sleeve mission on branch
`agents/board-advisor`.

## Approved Source Basis

The following committed bounded records were read completely before approval:

1. `strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md`, a named-author peer-reviewed
   open-access WTI study defining the November-through-May winter interval;
2. `strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md`, the governed reputable
   range-state and exact Monday-anchored completed-week construction record; and
3. `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`, the academic commodity-futures
   reversal lineage.

The source-of-record translation is
`strategy-seeds/sources/BURAKOV-CRABEL-YANG-WTI-WINTER-WR2-CLV-FADE-20260911/source.md`.
None of the parents tests this exact November-May, two-week range-expansion, outer-quartile
contrarian rule on the Darwinex continuous WTI CFD.

## Locked Mechanic

On the first tradable D1 bar of each normalized Monday-anchored November-May week, aggregate the
two immediately completed consecutive weeks. Require the newest full range to be strictly wider
than its predecessor. Buy after a strict lower-quartile final close (`CLV<0.25`) and sell after a
strict upper-quartile final close (`CLV>0.75`), irrespective of body sign. Consume the week before
fallible gates, exit in the next normalized week, use a frozen `3.5*ATR(20,D1)` hard stop, no
target, ten-day stale repair, and a 1,500-point spread ceiling.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`: peer-reviewed WTI seasonality,
  governed reputable range-state lineage, and academic commodity-reversal lineage; the exact
  conjunction is untested.
- R2 `PASS`: calendar, completed-week construction, strict range comparison, strict two-sided CLV
  predicates, attempt timing, fixed risk, stop, and lifecycle are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native `XTIUSD.DWX` D1 supplies all runtime
  market data.
- R4 `PASS`: deterministic native data and arithmetic only, with no ML, banned signal indicator,
  external runtime feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,922 registry rows and 1,532 repository cards, found no exact
identity, and returned two fuzzy sign-streak relatives while the external Strategy Wiki was
unavailable. The durable receipt is
`artifacts/qm5_candidate_wti_winter_wr2_clv_fade_dedup_preallocation_20260911.json`.

Manual review rejects both as the same strategy: `QM5_41403` and `QM5_41408` use only two
same-sign completed-week returns and no range comparison or close-location geometry. The closest
mechanical sibling, `QM5_41440`, buys upper-quartile WTI continuation and has no lower-quartile
branch. `QM5_41435` sells the upper-quartile state only in the disjoint August-October hurricane
window. `QM5_41438` follows both outer-quartile states on XNG in November-March. Certified
`QM5_12567` is a short-horizon long-only XNG cumulative-RSI pullback. Verdict:
`DISTINCT_WTI_NOVEMBER_MAY_WR2_OUTER_QUARTILE_SYMMETRIC_REVERSION_AFTER_FAMILY_REVIEW`.

## Safety Boundary

This approval excludes manual backtests, optimization, demo/shadow/live/stress presets, terminal
control, AutoTrading, `T_Live`, deploy/live manifests, portfolio-gate edits, portfolio admission,
decorrelation claims, and correlation waivers.

