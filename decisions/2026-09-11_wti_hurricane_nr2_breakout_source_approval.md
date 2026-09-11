# WTI Hurricane NR2 Close Breakout - Source Approval

Date: 2026-09-11

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic EA-ID and magic
allocation, one branch-only non-live build, strict Q01 validation, and one paced Q02 enqueue if
the whole-host CPU ceiling permits.

Authority: the current explicit OWNER commodity/energy sleeve mission on branch
`agents/board-advisor`.

## Approved Source Basis

The following committed bounded records were read completely before approval:

1. `strategy-seeds/sources/EIA-WTI-HURRICANE-2025/index.md`, official U.S. Energy Information
   Administration hurricane-season petroleum-supply context;
2. `strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md`, governed reputable
   range-state and subsequent-expansion lineage.

The source-of-record translation is
`strategy-seeds/sources/EIA-CRABEL-WTI-HURR-NR2-BREAKOUT-20260911/source.md`. Neither parent tests
this exact August-October, two-completed-week, strict range-contraction, next-week completed-D1-
close breakout rule on the Darwinex CFD.

## Locked Mechanic

During an August-October normalized week, aggregate the two immediately preceding consecutive
three-to-five-session weeks. If the newest full range is strictly smaller, use its high and low as
a frozen box. Enter in the direction of the first current-week completed D1 close strictly outside
that box, consume the week before fallible gates, and exit in the next normalized week with a
frozen `3.5*ATR(20,D1)` hard stop, no target, ten-day stale repair, and 1,500-point spread ceiling.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_TRANSLATION_RISK`: official EIA context plus governed reputable
  Crabel range-contraction/expansion lineage; the exact conjunction remains untested.
- R2 `PASS`: calendar, normalized completed-week construction, strict range comparison, fixed
  breakout box, completed-close trigger, attempt, risk, stop, and lifecycle are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native `XTIUSD.DWX` D1 supplies every
  runtime market input.
- R4 `PASS`: timestamps, OHLC, arithmetic, ATR risk, quotes, positions, deals, and persistent state
  only; no ML, banned signal indicator, external runtime feed, grid, or martingale.

## Non-Duplicate Decision

The canonical checker scanned 4,917 registry rows and 1,527 repository cards, found no exact
identity, and returned three fuzzy hurricane-family matches. The configured external Strategy Wiki
was unavailable, which remains explicit in
`artifacts/qm5_candidate_wti_hurr_nr2_breakout_dedup_preallocation_20260911.json`.

Manual review resolves them. `QM5_41436` enters at the week boundary in the prior week's own body
direction; this rule waits for a later completed current-week close outside a fixed box and ignores
the prior body. `QM5_41434/41435` require range expansion and an upper-quartile close, then enter
immediately long/short; this rule requires contraction and a symmetric later breakout. Additional
manual family review separates `QM5_41061`, which requires the strict narrowest of seven full
weeks all year, and `QM5_13075`, which requires literal inside-week containment plus SMA, ATR-range,
buffer, and close-location filters. Calendar, two-week relative range, no-containment definition,
completed-close trigger chronology, and lifecycle are jointly load-bearing.

Verdict: `DISTINCT_WTI_HURRICANE_NR2_NEXT_WEEK_COMPLETED_CLOSE_BREAKOUT`.

## Safety Boundary

This approval excludes manual backtests, optimization, demo/shadow/live/stress presets, terminal
control, AutoTrading, `T_Live`, deploy/live manifests, portfolio-gate edits, portfolio admission,
decorrelation claims, and correlation waivers.
