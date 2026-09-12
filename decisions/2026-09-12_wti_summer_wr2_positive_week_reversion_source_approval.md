# WTI Summer WR2 Positive-Week Reversion - Source Approval

Date: 2026-09-12

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic EA-ID and magic
allocation, one branch-only non-live build, governed Q01 compile validation, and one paced Q02
enqueue if the whole-host CPU ceiling and deterministic intake guards permit.

Authority: the current explicit OWNER commodity/energy diversification mission on branch
`agents/board-advisor`.

## Approved Source Basis

The following committed bounded records were read completely before approval:

1. `strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md`, the named-author,
   peer-reviewed, open-access WTI study defining the June-through-October negative-return leg;
2. `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`, the academic commodity-futures
   reversal record; and
3. `strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md`, the governed reputable
   range-state and Monday-anchored completed-week construction record.

The source-of-record translation is
`strategy-seeds/sources/BURAKOV-CRABEL-YANG-WTI-SUMMER-WR2-UPWEEK-FADE-20260912/source.md`.
None of the parents tests this exact June-October, two-week expansion, positive-week,
short-only rule on the Darwinex continuous WTI CFD.

## Locked Mechanic

At the first tradable D1 bar of each normalized Monday-anchored June-October week, aggregate the
two immediately completed consecutive weeks. Require the newest full range to be strictly
wider than its predecessor and its close to be strictly above its open. Sell only, consume the
week before fallible gates, exit in the next normalized week, use a frozen `3.5*ATR(20,D1)` hard
stop, ten-day stale repair, and a 1,500-point spread ceiling.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`: peer-reviewed WTI summer-season
  evidence, academic commodity reversal, and governed reputable range-state lineage; the exact
  conjunction is untested.
- R2 `PASS`: calendar, completed-week construction, strict expansion and positive-body
  comparisons, short-only side, attempt, risk, stop, and lifecycle are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native `XTIUSD.DWX` D1 supplies runtime
  data.
- R4 `PASS`: deterministic native data and arithmetic only, without ML, banned signal indicator,
  external runtime feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,939 registry rows and 1,548 repository cards, found no exact
identity, reported six fuzzy family matches, and failed closed because the external Strategy Wiki
root was unavailable. The durable receipt is
`artifacts/qm5_candidate_wti_summer_wr2_upweek_fade_dedup_preallocation_20260912.json`.

Manual review distinguishes `QM5_20093`, the unconditional June-October short carrier;
`QM5_41406` and `QM5_41407`, two-return-sign summer variants without a range state; and
`QM5_41440`, `QM5_41442`, and `QM5_41444`, November-May WR2 variants. The closest match,
`QM5_41457`, uses the same summer/body/side lifecycle but requires strict range contraction,
whereas this candidate requires strict expansion. Verdict:
`DISTINCT_WTI_JUNE_OCTOBER_WR2_POSITIVE_WEEK_SHORT_REVERSION_AFTER_FUZZY_FAMILY_REVIEW`.

## Safety Boundary

This approval excludes manual backtests, optimization, demo/shadow/live/stress presets, terminal
control, AutoTrading, `T_Live`, deploy/live manifests, portfolio-gate edits, portfolio admission,
decorrelation claims, and correlation waivers.

