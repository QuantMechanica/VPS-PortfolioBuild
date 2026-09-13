# WTI Winter Upper-CLV Reversion Source Approval

Date: 2026-09-13

Decision: `APPROVED_SOURCE` for one bounded extraction and one non-live V5
candidate only.

Authority: the current OWNER commodity/energy portfolio mission explicitly
authorizes one reputable-source, structural, low-frequency commodity edge,
branch-only build, and paced Q02 enqueue. It names a structural WTI edge as an
eligible sleeve and forbids live and portfolio-gate work.

## Complete-read evidence

Research read these durable parent packets end to end before this approval:

- `strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md`: peer-reviewed
  November-through-May positive WTI return leg and its source limitations.
- `strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md`:
  governed completed-week aggregation and close-location lineage.
- `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`: academic
  commodity-futures reversal lineage.

The new bounded packet is
`strategy-seeds/sources/BURAKOV-CRABEL-YANG-WTI-WINTER-HCLV-FADE-20260913/source.md`.
No parent claims the exact November-May, one-week upper-tercile WTI CFD short,
and no source performance statistic transfers.

## Approved extraction boundary

At the first tradable D1 bar of a normalized Monday-anchored week in November
through May, aggregate only the immediately completed week. Require three
through five valid sessions and positive full range. Compute
`CLV=(final_close-low)/(high-low)` and sell WTI only when `CLV > 2/3`.
Equality is flat. There is no long side or return, range-rank, candle-body,
wick, stretch, or moving-average gate. Exit in the next normalized week, with
a ten-day stale repair and frozen `3.5*ATR(20,D1)` hard stop.

## Reputable-source criteria

- R1: `PASS_WITH_CROSS_SOURCE_HORIZON_AND_COUNTER_SEASONAL_TRANSLATION_RISK`;
  the lineage is peer-reviewed WTI seasonality, governed reputable weekly
  construction, and academic commodity reversal evidence.
- R2: `PASS`; calendar, formation, strict inequality, side, attempt, stop,
  spread, and lifecycle are deterministic and locked.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`; registered native WTI D1 and MT5
  state supply every runtime input.
- R4: `PASS`; native price/calendar arithmetic and ATR risk only, without ML,
  a banned signal indicator, external runtime data, grid, or martingale.

## Non-duplicate decision

The canonical pre-allocation scan covered 4,948 EA-registry rows and 1,557
repository cards. It found no exact collision and five fuzzy family matches.
The checker failed closed because the external Strategy Wiki mount was
unavailable; that limitation is preserved in
`artifacts/qm5_candidate_wti_winter_hclv_fade_dedup_preallocation_20260913.json`.

Manual review separates `QM5_41442` and `QM5_41456`, which require two
completed weeks, a strict range expansion or contraction, and outer-quartile
states on both sides. `QM5_41444` and `QM5_41446` require two-week range state
and newest-week body sign rather than a one-week close-location state.
`QM5_41462` uses the same upper-tercile short construction only in the disjoint
June-October summer regime. `QM5_41463` trades the same winter upper-tercile
observation in the opposite direction under continuation lineage. The exact
WTI carrier, November-May clock, one completed-week package, strict upper-
tercile settlement, short-only reversion, and one-week lifecycle conjunction
is new in the available repository corpus.

Manual verdict:
`DISTINCT_WTI_NOVEMBER_MAY_SINGLE_WEEK_UPPER_TERCILE_SHORT_REVERSION_AFTER_FUZZY_FAMILY_REVIEW_WITH_EXTERNAL_WIKI_UNAVAILABLE`.

## Authorization boundary

Authorized: one approved card, deterministic allocation, branch-only non-live
build, governed compile/Q01, one fixed-risk backtest set, and one paced Q02
enqueue below the CPU ceiling. Forbidden: manual backtests, optimization,
demo/shadow/live artifacts, terminal control, portfolio admission or gate
changes, correlation waivers, `T_Live`, AutoTrading, and deploy/live manifests.
