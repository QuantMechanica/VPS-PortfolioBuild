# WTI Winter NR2 Upper-Quartile Continuation - Source Approval

Date: 2026-09-12

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic EA-ID and magic
allocation, one branch-only non-live build, governed Q01 compile validation, and one paced Q02
enqueue if the whole-host CPU ceiling and deterministic intake guards permit.

Authority: the current explicit OWNER commodity/energy sleeve mission on branch
`agents/board-advisor`.

## Approved Source Basis

The following committed bounded records were read completely before approval:

1. `strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md`, the named-author,
   peer-reviewed, open-access WTI study defining the November-through-May interval;
2. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, the completely reviewed peer-reviewed
   futures time-series-momentum record that includes WTI; and
3. `strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md`, the governed reputable
   range-state and Monday-anchored completed-week construction record.

The source-of-record translation is
`strategy-seeds/sources/BURAKOV-CRABEL-MOP-WTI-WINTER-NR2-CLV-MOM-20260912/source.md`. None of
the parents tests this exact November-May, two-week range-contraction, upper-quartile settlement
rule on the Darwinex continuous WTI CFD.

## Locked Mechanic

At the first tradable D1 bar of each normalized Monday-anchored November-May week, aggregate the
two immediately completed consecutive weeks. Require the newest full range to be strictly
narrower than its predecessor and its final close to be strictly above the 0.75 close-location
threshold. Buy only, consume the week before fallible gates, exit in the next normalized week,
use a frozen `3.5*ATR(20,D1)` hard stop, ten-day stale repair, and a 1,500-point spread ceiling.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`: peer-reviewed WTI seasonality and
  own-return continuation plus governed reputable range-state lineage; the exact conjunction is
  untested.
- R2 `PASS`: calendar, completed-week construction, strict contraction and CLV comparisons,
  side, attempt, risk, stop, and lifecycle are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native `XTIUSD.DWX` D1 supplies runtime
  data.
- R4 `PASS`: deterministic native data and arithmetic only, without ML, banned signal indicator,
  external runtime feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,927 registry rows and 1,537 repository cards, found no exact
identity, and returned expected family relatives while the external Strategy Wiki was unavailable.
The durable receipt is
`artifacts/qm5_candidate_wti_winter_nr2_clv_mom_dedup_preallocation_20260912.json`.

Manual review distinguishes `QM5_41440`, whose newest week must be strictly wider rather than
narrower; `QM5_41438`, which trades XNG in November-March, uses expansion, and is symmetric;
`QM5_20209/20218`, which use one completed calendar-month return rather than weekly range and CLV;
`QM5_41441`, which waits for a later completed-close breakout beyond the contraction box; and
`QM5_41445/41446`, which use weekly body sign rather than upper-quartile close location. Certified
`QM5_12567` is a two-day cumulative-RSI XNG pullback. Verdict:
`DISTINCT_WTI_NOVEMBER_MAY_NR2_UPPER_QUARTILE_LONG_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Safety Boundary

This approval excludes manual backtests, optimization, demo/shadow/live/stress presets, terminal
control, AutoTrading, `T_Live`, deploy/live manifests, portfolio-gate edits, portfolio admission,
decorrelation claims, and correlation waivers.

