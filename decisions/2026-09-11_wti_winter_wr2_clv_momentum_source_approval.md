# WTI Winter WR2 Upper-Quartile Continuation - Source Approval

Date: 2026-09-11

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic EA-ID and magic
allocation, one branch-only non-live build, strict Q01 validation, and one paced Q02 enqueue if
the whole-host CPU ceiling permits.

Authority: the current explicit OWNER commodity/energy sleeve mission on branch
`agents/board-advisor`.

## Approved Source Basis

The following committed bounded records were read completely before approval:

1. `strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md`, a named-author peer-reviewed
   open-access WTI seasonality paper whose methods define November through May;
2. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, the complete-read peer-reviewed JFE
   time-series-momentum paper and WTI universe record;
3. `strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md`, the governed reputable
   weekly range-state and completed-week construction record.

The source-of-record translation is
`strategy-seeds/sources/BURAKOV-CRABEL-MOP-WTI-WINTER-WR2-CLV-MOM-20260911/source.md`. None of
the parents tests the exact November-May, two-week WR2, upper-quartile-close, long-only rule on
the Darwinex continuous WTI CFD.

## Locked Mechanic

At a normalized new-week boundary in November through May, require the newest of two exact
completed weeks to have a strictly wider full range than its predecessor and a final close
strictly above its own 0.75 close-location threshold. Buy WTI once, consume the week before
fallible gates, and exit in the next normalized week with a frozen `3.5*ATR(20,D1)` stop, no
target, ten-day stale repair, and a 1,500-point spread ceiling.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`: peer-reviewed WTI seasonality and
  futures momentum plus governed reputable range-state lineage; the conjunction is untested.
- R2 `PASS`: all calendar, completed-week, range, CLV, side, attempt, risk, stop, and lifecycle
  rules are fixed and deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native `XTIUSD.DWX` D1 provides all
  runtime market data.
- R4 `PASS`: deterministic native data and arithmetic only, with no ML, banned signal indicator,
  external runtime feed, grid, martingale, or scale-in.

## Non-Duplicate Decision

The canonical checker scanned 4,920 registry rows and 1,530 repository cards, found no exact
identity, and returned five expected fuzzy relatives while the external Strategy Wiki was
unavailable. The durable receipt is
`artifacts/qm5_candidate_wti_winter_wr2_clv_mom_dedup_preallocation_20260911.json`.

Manual review rejects each as the same mechanic. The two WTI winter neighbors use a completed
calendar-month return sign with no weekly range or close-location state. `QM5_41438` uses XNG,
a shorter November-March window, and symmetric directions. `QM5_41434/41435` use a disjoint WTI
August-October hurricane window. Certified `QM5_12567` is an XNG cumulative-RSI pullback. The
verdict is
`DISTINCT_WTI_NOVEMBER_MAY_WR2_UPPER_QUARTILE_LONG_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Safety Boundary

This approval excludes manual backtests, optimization, demo/shadow/live/stress presets, terminal
control, AutoTrading, `T_Live`, deploy/live manifests, portfolio-gate edits, portfolio admission,
decorrelation claims, and correlation waivers.
