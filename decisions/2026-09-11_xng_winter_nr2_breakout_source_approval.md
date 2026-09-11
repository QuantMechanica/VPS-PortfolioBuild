# XNG Winter NR2 Close Breakout - Source Approval

Date: 2026-09-11

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic EA-ID and magic
allocation, one branch-only non-live build, strict Q01 validation, and one paced Q02 enqueue if
the whole-host CPU ceiling permits.

Authority: the current explicit OWNER commodity/energy sleeve mission on branch
`agents/board-advisor`.

## Approved Source Basis

The following committed bounded records were read completely before approval:

1. `strategy-seeds/sources/EIA-XNG-SHOULDER-2026/source.md`, official U.S. Energy Information
   Administration natural-gas winter/shoulder seasonality context;
2. `strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md`, governed reputable
   range-state and subsequent-expansion lineage.

The source-of-record translation is
`strategy-seeds/sources/EIA-CRABEL-XNG-WINTER-NR2-BREAKOUT-20260911/source.md`. Neither parent
tests this exact November-March, two-completed-week, strict range-contraction, next-week completed-
D1-close breakout rule on the Darwinex natural-gas CFD.

## Locked Mechanic

During a November-March normalized week, aggregate the two immediately preceding consecutive
three-to-five-session weeks. If the newest full range is strictly smaller, use its high and low as
a frozen box. Enter in the direction of the first current-week completed D1 close strictly outside
that box, consume the week before fallible gates, and exit in the next normalized week with a
frozen `3.5*ATR(20,D1)` hard stop, no target, ten-day stale repair, and 1,500-point spread ceiling.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_CARRIER_TRANSLATION_RISK`: official EIA context plus governed
  reputable Crabel range-contraction/expansion lineage; the exact conjunction remains untested.
- R2 `PASS`: calendar, normalized completed-week construction, strict range comparison, fixed
  breakout box, completed-close trigger, attempt, risk, stop, and lifecycle are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native `XNGUSD.DWX` D1 supplies every
  runtime market input.
- R4 `PASS`: timestamps, OHLC, arithmetic, ATR risk, quotes, positions, deals, and persistent state
  only; no ML, banned signal indicator, external runtime feed, grid, or martingale.

## Non-Duplicate Decision

The canonical checker scanned 4,919 registry rows and 1,529 repository cards, found no exact
identity, and returned one expected fuzzy match while the configured external Strategy Wiki was
unavailable. The durable receipt is
`artifacts/qm5_candidate_xng_winter_nr2_breakout_dedup_preallocation_20260911.json`.

Manual review resolves that hit. `QM5_41437` uses the same contraction/breakout chronology on WTI
during the August-October hurricane window; the current hypothesis is a separately falsifiable
XNG carrier in the November-March heating-demand window. Within XNG, `QM5_41063` requires the
strict narrowest of seven weeks all year, `QM5_41438` requires range expansion and immediate CLV
direction, and `QM5_12567` is a long-only two-day oscillator pullback above a slow trend. Carrier,
winter clock, two-week relative contraction, no-containment definition, delayed completed-close
trigger, and one-week lifecycle are jointly load-bearing.

Verdict: `DISTINCT_XNG_WINTER_NR2_NEXT_WEEK_COMPLETED_CLOSE_BREAKOUT`.

## Safety Boundary

This approval excludes manual backtests, optimization, demo/shadow/live/stress presets, terminal
control, AutoTrading, `T_Live`, deploy/live manifests, portfolio-gate edits, portfolio admission,
decorrelation claims, and correlation waivers.
