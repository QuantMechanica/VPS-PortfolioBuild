# WTI Summer Lower-CLV Continuation - Source Approval

Date: 2026-09-12

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic EA-ID and magic
allocation, one branch-only non-live build, governed Q01 compile validation, and one paced Q02
enqueue if deterministic intake and whole-host CPU guards permit.

Authority: the current explicit OWNER commodity/energy diversification mission on branch
`agents/board-advisor`.

## Approved Source Basis

The following committed bounded records were read completely before approval:

1. `strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md`, the named-author,
   peer-reviewed, open-access WTI study defining the June-through-October negative-return leg;
2. `strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md`, the governed reputable
   completed-week and close-location construction record; and
3. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, the peer-reviewed commodity continuation
   source with WTI in its stated futures universe.

The source-of-record translation is
`strategy-seeds/sources/BURAKOV-CRABEL-MOP-WTI-SUMMER-LCLV-CONT-20260912/source.md`. None of the
parents tests the exact one-week lower-tercile, June-October, short-only Darwinex WTI rule.

## Locked Mechanic

At the first tradable D1 bar of each normalized Monday-anchored June-October week, aggregate only
the immediately completed week. Require its close location to be strictly below one third of its
full range, sell once, consume the week before fallible gates, exit in the next normalized week,
use a frozen `3.5*ATR(20,D1)` hard stop, ten-day stale repair, and a 1,500-point spread ceiling.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`: peer-reviewed WTI season and
  commodity continuation evidence plus governed reputable close-location lineage; the exact
  conjunction is untested.
- R2 `PASS`: calendar, completed-week construction, strict lower-tercile comparison, side,
  attempt, risk, stop, and lifecycle are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native `XTIUSD.DWX` D1 provides runtime
  data.
- R4 `PASS`: deterministic native arithmetic only, without ML, banned signal indicators,
  external runtime data, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,942 registry rows, 1,551 repository cards, and 45 Strategy Wiki
nodes. It found no exact identity and two fuzzy siblings. `QM5_41459` and `QM5_41460` each require
two completed weeks, a newest-versus-prior range comparison, and a negative newest-week candle
body. This candidate uses exactly one completed week, no range rank, no body direction, and only
strict lower-tercile close location. Manual verdict:
`DISTINCT_WTI_JUNE_OCTOBER_SINGLE_WEEK_LOWER_TERCILE_SHORT_CONTINUATION_AFTER_FUZZY_REVIEW`.

The evidence receipt is
`artifacts/qm5_candidate_wti_summer_lclv_cont_dedup_preallocation_20260912.json`.

## Safety Boundary

This approval excludes manual backtests, optimization, demo/shadow/live presets, terminal
control, AutoTrading, `T_Live`, deploy/live manifests, portfolio-gate edits, portfolio admission,
decorrelation claims, and correlation waivers.
