# XNG Shoulder Upper-CLV Fade Source Approval

Date: 2026-09-13

Decision: `APPROVED_SOURCE` for one bounded extraction and one non-live V5
candidate only.

Authority: the current OWNER commodity/energy portfolio mission explicitly
authorizes one reputable-source, structural, low-frequency commodity edge,
branch-only build, and paced Q02 enqueue. It expressly permits a second XNG
edge when its logic differs from `QM5_12567`, and forbids live and portfolio-
gate work.

## Complete-read evidence

Research read these durable parent packets end to end before this approval:

- `strategy-seeds/sources/EIA-XNG-SHOULDER-2026/source.md`: official U.S. EIA
  spring/fall shoulder-season demand-lull context and runtime-data limits.
- `strategy-seeds/sources/MOP-XNG-WCLOSE-LOCATION-MOM-2026/source.md`:
  governed peer-reviewed natural-gas completed-week and close-location lineage.
- `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`: academic
  commodity-futures reversal lineage.

The new bounded packet is
`strategy-seeds/sources/EIA-MOP-YANG-XNG-SHOULDER-HCLV-FADE-20260913/source.md`.
No parent claims the exact shoulder-calendar, one-week upper-tercile XNG CFD
short, and no source performance statistic transfers.

## Approved extraction boundary

At the first tradable D1 bar of a normalized Monday-anchored week in April,
May, September, or October, aggregate only the immediately completed week.
Require three through five valid sessions and positive full range. Compute
`CLV=(final_close-low)/(high-low)` and sell XNG only when `CLV > 2/3`.
Equality is flat. There is no long side or return, range-rank, candle-body,
wick, stretch, or moving-average gate. Exit in the next normalized week, with
a ten-day stale repair and frozen `3.5*ATR(20,D1)` hard stop.

## Reputable-source criteria

- R1: `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`; the lineage is
  official-government XNG seasonality, governed peer-reviewed XNG weekly
  construction, and academic commodity reversal evidence.
- R2: `PASS`; calendar, formation, strict inequality, side, attempt, stop,
  spread, and lifecycle are deterministic and locked.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`; registered native
  `XNGUSD.DWX` D1 bars supply all runtime market data.
- R4: `PASS`; native price/calendar arithmetic and ATR risk only, without ML,
  a banned signal indicator, external runtime data, grid, or martingale.

## Non-duplicate decision

The canonical pre-allocation scan covered 4,946 EA-registry rows and 1,555
repository cards. It found no exact collision and one expected fuzzy match for
`xng-shoulder-hclv-fade` or
`EIA-MOP-YANG-XNG-SHOULDER-HCLV-FADE-20260913_S01`. The checker failed
closed solely because the external Strategy Wiki mount was unavailable; that
limitation is preserved in
`artifacts/qm5_candidate_xng_shoulder_hclv_fade_dedup_preallocation_20260913.json`.

Manual review separates `QM5_41462`, which trades WTI only in June-October.
`QM5_41392` uses completed-week open-to-close return sign and trades both
sides; `QM5_41401` requires two same-sign weeks; `QM5_12595` requires a D1
slow-mean stretch, channel high, and upper wick; `QM5_12567` is an all-year
long-only two-day cumulative-RSI pullback. The exact XNG carrier, four shoulder
months, one completed week, upper-tercile close location, short-only side, and
one-week lifecycle conjunction is new in the available repository corpus.

Manual verdict:
`DISTINCT_XNG_SHOULDER_SINGLE_WEEK_UPPER_TERCILE_SHORT_REVERSION_AFTER_FUZZY_FAMILY_REVIEW_WITH_EXTERNAL_WIKI_UNAVAILABLE`.

## Authorization boundary

Authorized: one approved card, deterministic allocation, branch-only non-live
build, governed compile/Q01, one fixed-risk backtest set, and one paced Q02
enqueue below the CPU ceiling. Forbidden: manual backtests, optimization,
demo/shadow/live artifacts, terminal control, portfolio admission or gate
changes, correlation waivers, `T_Live`, AutoTrading, and deploy/live
manifests.
