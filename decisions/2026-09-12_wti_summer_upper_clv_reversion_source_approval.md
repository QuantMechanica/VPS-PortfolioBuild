# WTI Summer Upper-CLV Reversion Source Approval

Date: 2026-09-12

Decision: `APPROVED_SOURCE` for one bounded extraction and one non-live V5
candidate only.

Authority: the current OWNER commodity/energy portfolio mission explicitly
authorizes one reputable-source, structural, low-frequency commodity edge,
branch-only build, and paced Q02 enqueue. It forbids live and portfolio-gate
work.

## Complete-read evidence

Research read these durable parent packets end to end before this approval:

- `strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md`: peer-reviewed
  WTI evidence for the negative June-through-October leg, including the
  methods/table direction conflict and CFD translation limits.
- `strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md`:
  governed completed-week construction and close-location arithmetic.
- `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`: academic
  commodity-futures reversal lineage.

The new bounded packet is
`strategy-seeds/sources/BURAKOV-CRABEL-YANG-WTI-SUMMER-HCLV-FADE-20260912/source.md`.
No parent claims the exact one-week upper-tercile WTI CFD fade, and no source
performance statistic transfers.

## Approved extraction boundary

At the first tradable D1 bar of a normalized Monday-anchored week in June
through October, aggregate only the immediately completed week. Require three
through five valid sessions and positive full range. Compute
`CLV=(final_close-low)/(high-low)` and sell WTI only when `CLV > 2/3`.
Equality is flat. There is no range-rank comparison or candle-body-sign gate.
Exit in the next normalized week, with a ten-day stale repair and frozen
`3.5*ATR(20,D1)` hard stop.

## Reputable-source criteria

- R1: `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`; the lineage is
  peer-reviewed WTI seasonality, governed reputable completed-week/CLV
  construction, and academic commodity reversal.
- R2: `PASS`; calendar, formation, strict inequality, side, attempt, stop,
  spread, and lifecycle are deterministic and locked.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`; registered native
  `XTIUSD.DWX` D1 bars supply all runtime market data.
- R4: `PASS`; native price/calendar arithmetic and ATR risk only, without ML,
  a banned signal indicator, external runtime data, grid, or martingale.

## Non-duplicate decision

The canonical pre-allocation scan covered 4,943 EA-registry rows and 1,552
repository cards. It found no exact collision for `wti-summer-hclv-fade` or
`BURAKOV-CRABEL-YANG-WTI-SUMMER-HCLV-FADE-20260912_S01`. The unavailable
external Strategy Wiki mount is recorded in
`artifacts/qm5_candidate_wti_summer_hclv_fade_dedup_preallocation_20260912.json`.

The two fuzzy hits, `QM5_41457` and `QM5_41458`, aggregate two completed
weeks, compare newest range with prior range, and require a positive newest
weekly body. This rule aggregates one week, does not rank range, ignores body
direction, and requires only a strict upper-tercile settlement. `QM5_20093`
is unconditional summer short. The exact carrier/calendar/one-week/upper-CLV
conjunction is new.

Manual verdict:
`DISTINCT_WTI_JUNE_OCTOBER_SINGLE_WEEK_UPPER_TERCILE_SHORT_REVERSION_AFTER_FUZZY_REVIEW`.

## Authorization boundary

Authorized: one approved card, deterministic allocation, branch-only non-live
build, governed compile/Q01, one fixed-risk backtest set, and one paced Q02
enqueue below the CPU ceiling. Forbidden: manual backtests, optimization,
demo/shadow/live artifacts, terminal control, portfolio admission or gate
changes, correlation waivers, `T_Live`, AutoTrading, and deploy/live manifests.

