# XNG Shoulder Lower-CLV Continuation Source Approval

Date: 2026-09-13

Decision: `APPROVED_SOURCE` for one bounded extraction and one non-live V5
candidate only.

Authority: the current OWNER commodity/energy portfolio mission explicitly
authorizes one reputable-source, structural, low-frequency commodity edge,
branch-only build, and paced Q02 enqueue. It names a second XNG edge with logic
different from `QM5_12567` as eligible and forbids live and portfolio-gate work.

## Complete-read evidence

Research read these durable parent packets end to end before this approval:

- `strategy-seeds/sources/EIA-XNG-SHOULDER-2026/source.md`: official EIA
  evidence for recurring spring and autumn natural-gas demand lulls.
- `strategy-seeds/sources/MOP-XNG-WCLOSE-LOCATION-MOM-2026/source.md`:
  governed completed-week, close-location, and XNG momentum lineage.
- `strategy-seeds/sources/MOP-TSMOM-2012/source.md`: peer-reviewed own-return
  continuation evidence across liquid futures, explicitly including natural gas.

The new bounded packet is
`strategy-seeds/sources/EIA-MOP-XNG-SHOULDER-LCLV-CONT-20260913/source.md`.
No parent claims the exact shoulder-calendar, lower-tercile completed-week XNG
CFD short continuation, and no source performance statistic transfers.

## Approved extraction boundary

At the first tradable D1 bar of a normalized Monday-anchored week in April,
May, September, or October, aggregate only the immediately completed week.
Require three through five valid sessions and positive full range. Compute
`CLV=(final_close-low)/(high-low)` and sell XNG only when `CLV < 1/3`.
Equality is flat. There is no long side, parent-close return sign, range rank,
candle-body, wick, stretch, or moving-average gate. Exit in the next normalized
week, with a ten-day stale repair and frozen `3.5*ATR(20,D1)` hard stop.

## Reputable-source criteria

- R1: `PASS_WITH_CROSS_SOURCE_AND_WEEKLY_HORIZON_TRANSLATION_RISK`; official
  EIA XNG seasonality, governed peer-reviewed completed-week construction, and
  peer-reviewed commodity continuation provide the bounded lineage. The exact
  lower-tercile shoulder conjunction is explicitly untested.
- R2: `PASS`; calendar, formation, strict inequality, side, attempt, stop,
  spread, and lifecycle are deterministic and locked.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`; registered native
  `XNGUSD.DWX` D1 bars and MT5 state supply all runtime inputs.
- R4: `PASS`; native price/calendar arithmetic and ATR risk only, without ML,
  a banned signal indicator, external runtime data, grid, or martingale.

## Non-duplicate decision

The canonical pre-allocation scan covered 4,950 EA-registry rows and 1,559
repository cards. It found no exact collision and five fuzzy family matches.
The checker failed closed because the external Strategy Wiki mount was
unavailable; that limitation is preserved in
`artifacts/qm5_candidate_xng_shoulder_lclv_cont_dedup_preallocation_20260913.json`.

Manual review separates every match. `QM5_41461` and `QM5_41468` use the same
lower-tercile short continuation on WTI under disjoint June-October and
November-May calendars; neither carrier, seasonal state, nor position can be
shared with this XNG package. `QM5_41465` fades an upper-tercile close; this
candidate follows a lower-tercile close downward. `QM5_41392` reverses the sign
of the completed week's open-to-close return symmetrically. `QM5_41420`
requires two adjacent same-sign completed weeks. Certified `QM5_12567` is an
all-year long-only two-day cumulative-RSI pullback above a slow mean. Carrier,
four shoulder months, one completed week, strict lower-tercile settlement,
short-only continuation, and one-week hold are jointly load-bearing.

Manual verdict:
`DISTINCT_XNG_SHOULDER_SINGLE_WEEK_LOWER_TERCILE_SHORT_CONTINUATION_AFTER_FUZZY_FAMILY_REVIEW_WITH_EXTERNAL_WIKI_UNAVAILABLE`.

## Authorization boundary

Authorized: one approved card, deterministic allocation, branch-only non-live
build, governed compile/Q01, one fixed-risk backtest set, and one paced Q02
enqueue below the CPU ceiling. Forbidden: manual backtests, optimization,
demo/shadow/live artifacts, terminal control, portfolio admission or gate
changes, correlation waivers, `T_Live`, AutoTrading, and deploy/live manifests.
