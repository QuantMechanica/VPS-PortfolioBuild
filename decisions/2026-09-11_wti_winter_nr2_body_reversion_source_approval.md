# WTI Winter NR2 Body Reversion - Source Approval

Date: 2026-09-11

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic EA-ID and magic
allocation, one branch-only non-live build, strict Q01 validation, and one paced Q02 enqueue if
the whole-host CPU ceiling and other deterministic intake guards permit.

Authority: the current explicit OWNER commodity/energy sleeve mission on branch
`agents/board-advisor`.

## Approved Source Basis

The following committed bounded records were read completely before approval:

1. `strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md`, a named-author peer-reviewed
   open-access WTI study defining the November-through-May winter interval;
2. `strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md`, the governed reputable
   range-state and Monday-anchored completed-week construction record; and
3. `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`, the bounded academic
   commodity-futures reversal record.

The source-of-record translation is
`strategy-seeds/sources/BURAKOV-CRABEL-YANG-WTI-WINTER-NR2-BODY-FADE-20260911/source.md`. None of
the parents tests this exact November-May, two-week range-contraction, own-body reversion rule on
the Darwinex continuous WTI CFD.

## Locked Mechanic

At the first tradable D1 bar of each normalized Monday-anchored November-May week, aggregate the
two immediately completed consecutive weeks. Require the newest full range to be strictly
narrower than its predecessor. Sell after a strictly positive newest-week body and buy after a
strictly negative body; equality is flat and containment is irrelevant. Consume the week before
fallible gates, exit in the next normalized week, use a frozen `3.5*ATR(20,D1)` hard stop, no
target, ten-day stale repair, and a 1,500-point spread ceiling.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`: peer-reviewed WTI seasonality,
  governed reputable range-state lineage, and academic commodity-futures reversal; exact
  conjunction untested.
- R2 `PASS`: calendar, two completed weeks, strict contraction and body comparisons, attempt,
  risk, stop, and lifecycle are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native `XTIUSD.DWX` D1 supplies runtime
  data.
- R4 `PASS`: deterministic native data and arithmetic only, without ML, banned signal indicator,
  external runtime feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,926 registry rows and 1,536 repository cards, found no exact
identity, and returned the expected family relatives while the external Strategy Wiki was
unavailable. The durable receipt is
`artifacts/qm5_candidate_wti_winter_nr2_body_fade_dedup_preallocation_20260911.json`.

Manual review distinguishes `QM5_41444`, which uses the opposite volatility state (strict range
expansion); `QM5_41442`, which is expansion-gated and reads outer-quartile close location rather
than every nonzero body; and `QM5_41445`, which uses the same contraction/body predicate but
follows rather than fades it. Certified `QM5_12567` is a two-day cumulative-RSI XNG pullback.
Verdict: `DISTINCT_WTI_NOVEMBER_MAY_NR2_OWN_BODY_SYMMETRIC_REVERSION_AFTER_FAMILY_REVIEW`.

## Safety Boundary

This approval excludes manual backtests, optimization, demo/shadow/live/stress presets, terminal
control, AutoTrading, `T_Live`, deploy/live manifests, portfolio-gate edits, portfolio admission,
decorrelation claims, and correlation waivers.

