# WTI Hurricane WR2 Close-Location Continuation - Source Approval

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
2. `strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md`, governed range-expansion
   and peer-reviewed time-series-momentum lineage.

The source-of-record translation is
`strategy-seeds/sources/EIA-CRABEL-WTI-HURR-WR2-CLV-CONT-20260911/source.md`. Neither parent
tests this exact August-October, two-completed-week, strict range-expansion, upper-quartile,
long-only Darwinex CFD rule.

## Locked Mechanic

At the first tradable D1 bar of an August-October normalized week, consume the attempt, aggregate
the two immediately preceding consecutive completed three-to-five-session weeks, and buy only
when the newest full range strictly exceeds the prior range and its final close lies strictly
above 0.75 of its own range. Hold to the next normalized week with a frozen `3.5*ATR(20,D1)` hard
stop, no target, ten-day stale repair, and 1,500-point spread ceiling.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_TRANSLATION_RISK`: official EIA context plus governed reputable and
  peer-reviewed range/momentum lineage; the exact conjunction remains untested.
- R2 `PASS`: calendar, completed-week construction, range comparison, CLV inequality, side,
  attempt, risk, stop, and lifecycle are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native `XTIUSD.DWX` D1 supplies all runtime
  market data.
- R4 `PASS`: timestamps, OHLC, arithmetic, ATR risk, quote, position, and persistent state only;
  no ML, banned signal indicator, external runtime feed, grid, or martingale.

## Non-Duplicate Decision

The canonical checker scanned 4,914 registry rows and 1,524 repository cards, found no exact
identity, and returned one fuzzy neighbor. The configured external Strategy Wiki was unavailable,
which is retained in
`artifacts/qm5_candidate_wti_hurr_wr2_clv_cont_dedup_preallocation_20260911.json`.

`QM5_41087` is all-year and symmetric, requires the newest week to be strict widest of four,
requires own-body direction, and permits a lower-quartile short. This candidate is
August-October-only, compares exactly two weeks, ignores body sign, requires only upper-quartile
settlement, and is long-only. `QM5_41430` is hurricane-season long continuation after any strictly
positive completed-week return; it has no range expansion or close-location requirement.
`QM5_12591` is an intraseason D1 channel breakout, not a completed-week boundary rule.

Verdict: `DISTINCT_WTI_HURRICANE_WR2_UPPER_QUARTILE_LONG_CONTINUATION`.

## Safety Boundary

This approval excludes manual backtests, optimization, demo/shadow/live/stress presets, terminal
control, AutoTrading, `T_Live`, deploy or live manifests, portfolio-gate edits, portfolio
admission, decorrelation claims, and correlation waivers.
