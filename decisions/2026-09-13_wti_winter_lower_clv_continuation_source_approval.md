# WTI Winter Lower-CLV Continuation Source Approval

Date: 2026-09-13

Decision: `APPROVED_SOURCE` for one bounded extraction and one non-live V5
candidate only.

Authority: the current OWNER commodity/energy portfolio mission explicitly
authorizes one reputable-source, structural, low-frequency commodity edge,
branch-only build, and paced Q02 enqueue. It names structural WTI as eligible
and forbids live and portfolio-gate work.

## Complete-read evidence

Research read these durable parent packets end to end before this approval:

- `strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md`: peer-reviewed
  WTI evidence for the positive November-through-May leg, including its
  methods/table direction conflict and continuous-CFD translation limits.
- `strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md`:
  governed completed-week construction and close-location arithmetic.
- `strategy-seeds/sources/MOP-TSMOM-2012/source.md`: peer-reviewed own-return
  continuation evidence across liquid futures including WTI.

The new bounded packet is
`strategy-seeds/sources/BURAKOV-CRABEL-MOP-WTI-WINTER-LCLV-CONT-20260913/source.md`.
No parent claims the exact one-week lower-tercile WTI CFD short continuation,
and no source performance statistic transfers.

## Approved extraction boundary

At the first tradable D1 bar of a normalized Monday-anchored week in November
through May, aggregate only the immediately completed week. Require three
through five valid sessions and positive full range. Compute
`CLV=(final_close-low)/(high-low)` and sell WTI only when `CLV < 1/3`.
Equality is flat. There is no long side, return-sign, range-rank,
candle-body, wick, stretch, or moving-average gate. Exit in the next
normalized week, with a ten-day stale repair and frozen `3.5*ATR(20,D1)` hard
stop.

## Reputable-source criteria

- R1: `PASS_WITH_CROSS_SOURCE_HORIZON_AND_COUNTER_SEASONAL_TRANSLATION_RISK`;
  the lineage is peer-reviewed WTI seasonality, governed reputable weekly
  construction, and peer-reviewed commodity continuation. The short side is
  deliberately counter to the regime's positive average drift.
- R2: `PASS`; calendar, formation, strict inequality, side, attempt, stop,
  spread, and lifecycle are deterministic and locked.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`; registered native
  `XTIUSD.DWX` D1 bars and MT5 state supply all runtime inputs.
- R4: `PASS`; native price/calendar arithmetic and ATR risk only, without ML,
  a banned signal indicator, external runtime data, grid, or martingale.

## Non-duplicate decision

The canonical pre-allocation scan covered 4,949 EA-registry rows and 1,558
repository cards. It found no exact collision and two fuzzy family matches.
The checker failed closed because the external Strategy Wiki mount was
unavailable; that limitation is preserved in
`artifacts/qm5_candidate_wti_winter_lclv_cont_dedup_preallocation_20260913.json`.

Manual review separates both matches. `QM5_41461` uses the same lower-tercile
short continuation only in the disjoint June-through-October summer regime.
`QM5_41463` uses the same November-through-May calendar but requires an
upper-tercile close and buys rather than sells. `QM5_41464` is the closest
opposite-direction sibling: it buys the winter lower-tercile state under
reversion lineage. The exact WTI carrier, November-May clock, one completed
week, strict lower-tercile settlement, short-only continuation, and one-week
lifecycle conjunction is new in the available repository corpus.

Manual verdict:
`DISTINCT_WTI_NOVEMBER_MAY_SINGLE_WEEK_LOWER_TERCILE_SHORT_CONTINUATION_AFTER_FUZZY_FAMILY_REVIEW_WITH_EXTERNAL_WIKI_UNAVAILABLE`.

## Authorization boundary

Authorized: one approved card, deterministic allocation, branch-only non-live
build, governed compile/Q01, one fixed-risk backtest set, and one paced Q02
enqueue below the CPU ceiling. Forbidden: manual backtests, optimization,
demo/shadow/live artifacts, terminal control, portfolio admission or gate
changes, correlation waivers, `T_Live`, AutoTrading, and deploy/live manifests.

