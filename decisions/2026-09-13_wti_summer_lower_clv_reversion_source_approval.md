# WTI Summer Lower-CLV Reversion Source Approval

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
  June-through-October negative WTI return leg and its source limitations.
- `strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md`:
  governed completed-week aggregation and close-location lineage.
- `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`: academic
  commodity-futures reversal lineage.

The new bounded packet is
`strategy-seeds/sources/BURAKOV-CRABEL-YANG-WTI-SUMMER-LCLV-FADE-20260913/source.md`.
No parent claims the exact June-October, one-week lower-tercile WTI CFD long,
and no source performance statistic transfers.

## Approved extraction boundary

At the first tradable D1 bar of a normalized Monday-anchored week in June
through October, aggregate only the immediately completed week. Require three
through five valid sessions and positive full range. Compute
`CLV=(final_close-low)/(high-low)` and buy WTI only when `CLV < 1/3`.
Equality is flat. There is no short side or return, range-rank, candle-body,
wick, stretch, or moving-average gate. Exit in the next normalized week, with
a ten-day stale repair and frozen `3.5*ATR(20,D1)` hard stop.

## Reputable-source criteria

- R1: `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`; the lineage is
  peer-reviewed WTI seasonality, governed reputable weekly construction, and
  academic commodity reversal evidence.
- R2: `PASS`; calendar, formation, strict inequality, side, attempt, stop,
  spread, and lifecycle are deterministic and locked.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`; registered native
  `XTIUSD.DWX` D1 bars supply all runtime market data.
- R4: `PASS`; native price/calendar arithmetic and ATR risk only, without ML,
  a banned signal indicator, external runtime data, grid, or martingale.

## Non-duplicate decision

The canonical pre-allocation scan covered 4,947 EA-registry rows and 1,556
repository cards. It found no exact collision and four expected fuzzy family
matches for `wti-summer-lclv-fade` or
`BURAKOV-CRABEL-YANG-WTI-SUMMER-LCLV-FADE-20260913_S01`. The checker failed
closed because the external Strategy Wiki mount was unavailable; that
limitation is preserved in
`artifacts/qm5_candidate_wti_summer_lclv_fade_dedup_preallocation_20260913.json`.

Manual review separates `QM5_41457` and `QM5_41458`, which require two
completed weeks, a strict range contraction/expansion, and positive newest-
week body. `QM5_41462` uses the disjoint upper tercile and sells rather than
buys. `QM5_41464` uses the same lower-tercile reversion construction only in
the disjoint November-May winter regime. `QM5_41461` trades the same summer
lower-tercile observation in the opposite direction under continuation
lineage. The exact WTI carrier, June-October clock, one completed-week
package, strict lower-tercile settlement, long-only reversion, and one-week
lifecycle conjunction is new in the available repository corpus.

Manual verdict:
`DISTINCT_WTI_JUNE_OCTOBER_SINGLE_WEEK_LOWER_TERCILE_LONG_REVERSION_AFTER_FUZZY_FAMILY_REVIEW_WITH_EXTERNAL_WIKI_UNAVAILABLE`.

## Authorization boundary

Authorized: one approved card, deterministic allocation, branch-only non-live
build, governed compile/Q01, one fixed-risk backtest set, and one paced Q02
enqueue below the CPU ceiling. Forbidden: manual backtests, optimization,
demo/shadow/live artifacts, terminal control, portfolio admission or gate
changes, correlation waivers, `T_Live`, AutoTrading, and deploy/live
manifests.
