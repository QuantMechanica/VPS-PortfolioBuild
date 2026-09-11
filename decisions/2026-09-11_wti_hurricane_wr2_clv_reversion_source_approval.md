# WTI Hurricane WR2 Close-Location Reversion - Source Approval

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
2. `strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md`, governed systematic
   range-state lineage;
3. `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`, academic commodity-futures
   reversal lineage.

The source-of-record translation is
`strategy-seeds/sources/EIA-CRABEL-YANG-WTI-HURR-WR2-CLV-FADE-20260911/source.md`. None of the
parents tests this exact August-October, two-completed-week, strict range-expansion,
upper-quartile, short-only Darwinex CFD rule.

## Locked Mechanic

At the first tradable D1 bar of an August-October normalized week, consume the attempt, aggregate
the two immediately preceding consecutive completed three-to-five-session weeks, and sell only
when the newest full range strictly exceeds the prior range and its final close lies strictly
above 0.75 of its own range. Weekly body sign is irrelevant. Hold to the next normalized week
with a frozen `3.5*ATR(20,D1)` hard stop, no target, ten-day stale repair, and 1,500-point spread
ceiling.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`: one canonical child packet with
  complete official EIA, governed Crabel, and academic Yang-Goncu-Pantelous lineage; the exact
  conjunction is explicitly untested.
- R2 `PASS`: calendar, completed-week construction, range comparison, CLV inequality, short
  side, attempt, risk, stop, and lifecycle are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native `XTIUSD.DWX` D1 supplies all
  runtime market data.
- R4 `PASS`: timestamps, OHLC, arithmetic, ATR risk, quote, position, and persistent state only;
  no ML, banned signal indicator, external runtime feed, grid, or martingale.

## Non-Duplicate Decision

The canonical checker scanned 4,915 registry rows and 1,525 repository cards, found no exact
identity, and returned fuzzy family neighbors. The configured external Strategy Wiki was
unavailable, which is retained in
`artifacts/qm5_candidate_wti_hurr_wr2_clv_fade_dedup_preallocation_20260911.json`.

`QM5_41434` buys the exact WR2/upper-quartile state as continuation; this candidate sells it as
reversion, so their payoffs are opposite. `QM5_41433` sells after any positive completed-week
open-to-close return and has no range comparison or close-location gate; this candidate ignores
body sign and can fire after a negative-body expanded week. `QM5_12754` requires a single D1
bearish rejection above SMA with ATR stretch and exits at the mean/window, not a completed-week
WR2 state with a fixed one-week lifecycle. `QM5_12861` uses XNG. The remaining hits are duplicate
storage copies rather than exact candidate mechanics.

Verdict: `DISTINCT_WTI_HURRICANE_WR2_UPPER_QUARTILE_SHORT_REVERSION`.

## Safety Boundary

This approval excludes manual backtests, optimization, demo/shadow/live/stress presets, terminal
control, AutoTrading, `T_Live`, deploy or live manifests, portfolio-gate edits, portfolio
admission, decorrelation claims, and correlation waivers.
