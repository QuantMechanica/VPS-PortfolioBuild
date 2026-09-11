# WTI Hurricane NR2 Sign Continuation - Source Approval

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
2. `strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md`, governed range-state and
   peer-reviewed WTI time-series-momentum lineage.

The source-of-record translation is
`strategy-seeds/sources/EIA-CRABEL-MOP-WTI-HURR-NR2-SIGN-CONT-20260911/source.md`. Neither parent
tests this exact August-October, two-completed-week, strict range-contraction, own-week-sign,
symmetric Darwinex CFD rule.

## Locked Mechanic

At the first tradable D1 bar of an August-October normalized week, consume the attempt, aggregate
the two immediately preceding consecutive completed three-to-five-session weeks, and continue in
the newest week's own open-to-close direction only when its full range is strictly narrower than
the preceding week's range. Hold to the next normalized week with a frozen `3.5*ATR(20,D1)` hard
stop, no target, ten-day stale repair, and 1,500-point spread ceiling.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_TRANSLATION_RISK`: official EIA context plus governed reputable and
  peer-reviewed range/momentum lineage; the exact conjunction remains untested.
- R2 `PASS`: calendar, completed-week construction, strict range comparison, earliest-open and
  final-close direction, attempt, risk, stop, and lifecycle are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native `XTIUSD.DWX` D1 supplies all runtime
  market data.
- R4 `PASS`: timestamps, OHLC, arithmetic, ATR risk, quotes, positions, deals, and persistent
  state only; no ML, banned signal indicator, external runtime feed, grid, or martingale.

## Non-Duplicate Decision

The canonical checker scanned 4,916 registry rows and 1,526 repository cards, found no exact
identity, and returned six fuzzy family matches. The configured external Strategy Wiki was
unavailable, which remains explicit in
`artifacts/qm5_candidate_wti_hurr_nr2_sign_cont_dedup_preallocation_20260911.json`.

Manual review resolves the family matches. `QM5_41434` and `QM5_41435` require a strict two-week
range expansion plus upper-quartile close and are respectively long continuation and short
reversion; this rule requires contraction, ignores close location, and follows either own-week
body sign. `QM5_41080` has no seasonal window or range contraction and uses parent-close to
new-close momentum plus outer-fifth CLV. `QM5_41081` trades XNG. `QM5_41092` has no seasonal or
two-week range comparison and requires a body/range dominance threshold. `QM5_41061` waits for a
current-week completed-close breakout after the strict narrowest of seven completed weeks;
`QM5_21503` ranks realized volatility against forty older blocks. Neither enters immediately at
the hurricane-week boundary after a strict two-week range contraction.

Verdict: `DISTINCT_WTI_HURRICANE_NR2_OWN_WEEK_SIGN_CONTINUATION`.

## Safety Boundary

This approval excludes manual backtests, optimization, demo/shadow/live/stress presets, terminal
control, AutoTrading, `T_Live`, deploy or live manifests, portfolio-gate edits, portfolio
admission, decorrelation claims, and correlation waivers.
