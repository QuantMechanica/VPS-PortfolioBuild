# WTI Winter Lower-CLV Reversion Source Approval

Date: 2026-09-13

Decision: `APPROVED_SOURCE` for one bounded extraction and one non-live V5
candidate only.

Authority: the current OWNER commodity/energy portfolio mission explicitly
authorizes one reputable-source, structural, low-frequency commodity edge,
branch-only build, and paced Q02 enqueue. It forbids live and portfolio-gate
work.

## Complete-read evidence

Research read these durable parent packets end to end before this approval:

- `strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md`: peer-reviewed
  WTI evidence for the positive November-through-May leg, including the
  methods/table direction conflict and CFD translation limits.
- `strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md`:
  governed completed-week construction and close-location arithmetic.
- `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`: academic commodity-futures reversal lineage.

The new bounded packet is
`strategy-seeds/sources/BURAKOV-CRABEL-YANG-WTI-WINTER-LCLV-FADE-20260913/source.md`.
No parent claims the exact one-week lower-tercile WTI CFD reversion, and no
source performance statistic transfers.

## Approved extraction boundary

At the first tradable D1 bar of a normalized Monday-anchored week in November
through May, aggregate only the immediately completed week. Require three
through five valid sessions and positive full range. Compute
`CLV=(final_close-low)/(high-low)` and buy WTI only when `CLV < 1/3`.
Equality is flat. There is no range-rank comparison or candle-body-sign gate.
Exit in the next normalized week, with a ten-day stale repair and frozen
`3.5*ATR(20,D1)` hard stop.

## Reputable-source criteria

- R1: `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`; the lineage is
  peer-reviewed WTI seasonality, governed reputable completed-week/CLV
  construction, and academic commodity-reversal evidence.
- R2: `PASS`; calendar, formation, strict inequality, side, attempt, stop,
  spread, and lifecycle are deterministic and locked.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`; registered native
  `XTIUSD.DWX` D1 bars supply all runtime market data.
- R4: `PASS`; native price/calendar arithmetic and ATR risk only, without ML,
  a banned signal indicator, external runtime data, grid, or martingale.

## Non-duplicate decision

The canonical pre-allocation scan covered 4,945 EA-registry rows and 1,554
repository cards. It found no exact collision and four expected fuzzy family matches for
`wti-winter-lclv-fade` or
`BURAKOV-CRABEL-YANG-WTI-WINTER-LCLV-FADE-20260913_S01`. The checker failed
closed solely because the external Strategy Wiki mount was unavailable; that
limitation is preserved in
`artifacts/qm5_candidate_wti_winter_lclv_fade_dedup_preallocation_20260913.json`.

Manual repository review separates the nearest family members. `QM5_41442` and `QM5_41456` require two completed weeks and a strict newest-versus-prior range comparison, then trade symmetric outer-quartile fades; this rule uses one completed week, no range state, and the winter-premium long side only. `QM5_20209` and `QM5_20218` use one completed calendar-month return
sign and no weekly close-location state. `QM5_41461` uses the disjoint summer calendar and short continuation. Certified `QM5_12567` is an XNG
two-day oscillator pullback. The exact carrier/calendar/one-week/lower-CLV/
long-only conjunction is new in the available repository corpus.

Manual verdict:
`DISTINCT_WTI_NOVEMBER_MAY_SINGLE_WEEK_LOWER_TERCILE_LONG_REVERSION_AFTER_FUZZY_FAMILY_REVIEW_WITH_EXTERNAL_WIKI_UNAVAILABLE`.

## Authorization boundary

Authorized: one approved card, deterministic allocation, branch-only non-live
build, governed compile/Q01, one fixed-risk backtest set, and one paced Q02
enqueue below the CPU ceiling. Forbidden: manual backtests, optimization,
demo/shadow/live artifacts, terminal control, portfolio admission or gate
changes, correlation waivers, `T_Live`, AutoTrading, and deploy/live manifests.

