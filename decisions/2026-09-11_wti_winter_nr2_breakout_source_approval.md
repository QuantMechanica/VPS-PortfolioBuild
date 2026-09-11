# WTI Winter NR2 Close Breakout - Source Approval

Date: 2026-09-11

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic EA-ID and magic
allocation, one branch-only non-live build, strict Q01 validation, and one paced Q02 enqueue if
the whole-host CPU ceiling permits.

Authority: the current explicit OWNER commodity/energy sleeve mission on branch
`agents/board-advisor`.

## Approved Source Basis

The following committed bounded records were read completely before approval:

1. `strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md`, a named-author peer-reviewed
   open-access WTI study whose methods define the November-through-May winter interval; and
2. `strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md`, the governed reputable
   range-state lineage and exact Monday-anchored completed-week construction record.

The source-of-record translation is
`strategy-seeds/sources/BURAKOV-CRABEL-WTI-WINTER-NR2-BREAKOUT-20260911/source.md`. Neither
parent tests the exact November-May, two-week contraction, subsequent completed-close breakout
rule on the Darwinex continuous WTI CFD.

## Locked Mechanic

During a normalized Monday-anchored week beginning in November through May, aggregate the two
immediately completed consecutive weeks and require the newest full range to be strictly narrower
than its predecessor. Freeze the newest high-low box. Enter WTI in the direction of the first
current-week completed D1 close strictly outside that box, consume the week before fallible gates,
and exit in the next normalized week with a frozen `3.5*ATR(20,D1)` stop, no target, ten-day stale
repair, and a 1,500-point spread ceiling.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`: peer-reviewed WTI seasonality plus
  governed reputable range-state lineage; the conjunction is untested.
- R2 `PASS`: calendar, completed-week construction, strict contraction, delayed close breakout,
  attempt timing, risk, stop, and lifecycle rules are fixed and deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native `XTIUSD.DWX` D1 supplies all
  runtime market data.
- R4 `PASS`: deterministic native data and arithmetic only, with no ML, banned signal indicator,
  external runtime feed, grid, martingale, or scale-in.

## Non-Duplicate Decision

The canonical checker scanned 4,921 registry rows and 1,531 repository cards, found no exact
identity, and returned two expected fuzzy relatives while the external Strategy Wiki was
unavailable. The durable receipt is
`artifacts/qm5_candidate_wti_winter_nr2_breakout_dedup_preallocation_20260911.json`.

Manual review rejects both as the same strategy. `QM5_41439` uses natural gas and only the
November-March heating-demand window. `QM5_41440` uses WTI in November-May but requires range
expansion, an immediate upper-quartile settlement, and a long-only entry; it has no contraction
box or delayed breakout. The selected WTI carrier also differs from `QM5_41437`, whose identical
breakout chronology is confined to the disjoint August-October hurricane-risk window. Certified
`QM5_12567` is an XNG cumulative-RSI pullback. Verdict:
`DISTINCT_WTI_NOVEMBER_MAY_NR2_NEXT_WEEK_COMPLETED_CLOSE_BREAKOUT_AFTER_FAMILY_REVIEW`.

## Safety Boundary

This approval excludes manual backtests, optimization, demo/shadow/live/stress presets, terminal
control, AutoTrading, `T_Live`, deploy/live manifests, portfolio-gate edits, portfolio admission,
decorrelation claims, and correlation waivers.
