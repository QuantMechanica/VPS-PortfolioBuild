# XNG Winter WR2 Close-Location Momentum - Source Approval

Date: 2026-09-11

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic EA-ID and magic
allocation, one branch-only non-live build, strict Q01 validation, and one paced Q02 enqueue if
the whole-host CPU ceiling permits.

Authority: the current explicit OWNER commodity/energy sleeve mission on branch
`agents/board-advisor`.

## Approved Source Basis

The following committed bounded records were read completely before approval:

1. `strategy-seeds/sources/EIA-XNG-SHOULDER-2026/source.md`, official EIA natural-gas seasonality
   context;
2. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, complete-read peer-reviewed own-return
   momentum evidence with natural gas in the source universe;
3. `strategy-seeds/sources/CRABEL-WTI-WR4-CLOSE-MOM-2026/source.md`, governed reputable range-
   state and completed-week construction lineage.

The source of record is
`strategy-seeds/sources/EIA-CRABEL-MOP-XNG-WINTER-WR2-CLV-MOM-20260911/source.md`. No parent tests
this exact November-March, two-week relative-range, outer-quartile rule on the Darwinex CFD.

## Locked Mechanic

At each eligible winter week boundary, reconstruct two immediately completed consecutive weeks.
If the newest full range is strictly wider, buy only after a strict upper-quartile settlement and
sell only after a strict lower-quartile settlement. Body sign is irrelevant. Consume the attempt
before fallible gates, use a frozen `3.5*ATR(20,D1)` hard stop and no target, and exit in the next
normalized week with ten-day stale repair and a 1,500-point spread ceiling.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`.
- R2 `PASS`: all calendar, arithmetic, execution, risk, and lifecycle rules are frozen.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native XNG D1 data only.
- R4 `PASS`: deterministic native state only, with no trained or prohibited signal.

## Non-Duplicate Decision

The canonical checker scanned 4,918 registry rows and 1,528 repository cards, found no exact
identity, and raised expected fuzzy family matches while the configured Strategy Wiki was
unavailable. The durable receipt is
`artifacts/qm5_candidate_xng_winter_wr2_clv_mom_dedup_preallocation_20260911.json`.

Manual review resolves the candidates. `QM5_41081` requires strict return-sign agreement and
outer-fifth CLV but has neither range expansion nor winter conditioning. `QM5_41395` follows one
winter-week return sign; `QM5_41402` follows two agreeing return signs. `QM5_41063` ranks seven
weeks and waits for a current-week breakout. The WTI winter hits are monthly carrier strategies.
`QM5_41434` is a different WTI hurricane-season, long-only upper-quartile carrier. `QM5_12567` is
the incumbent long-only two-day oscillator pullback. Carrier, winter clock, two-week strict range
expansion, symmetric outer-quartile settlement, body-sign irrelevance, boundary entry, and weekly
lifecycle are jointly load-bearing.

Verdict: `DISTINCT_XNG_WINTER_WR2_OUTER_QUARTILE_MOMENTUM_AFTER_MANUAL_REVIEW`.

## Safety Boundary

This approval excludes manual backtests, optimization, demo/shadow/live/stress presets, terminal
control, AutoTrading, `T_Live`, deploy/live manifests, portfolio-gate edits, portfolio admission,
decorrelation claims, and correlation waivers.
