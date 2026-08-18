# XAU/XAG Weekly NR7 Breakout - Source Approval

Date: 2026-08-18

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and host-CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission explicitly allows a market-neutral
`XAUUSD` / `XAGUSD` basket, requires a new non-duplicate structural low-
frequency edge with reputable sources and `RISK_FIXED` backtests, and forbids
live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `xauxag-week-nr7-brk`
- proposed strategy ID: `CRABEL-CME-XAUXAG-WEEKNR7-2026_S01`
- proposed source ID: `CRABEL-CME-XAUXAG-WEEKNR7-2026`
- carrier: exact `XAUUSD.DWX` / `XAGUSD.DWX` D1 paired basket
- state: immediately prior complete broker week's synchronized close-ratio
  range is strictly the narrowest of seven valid complete weeks
- trigger: next-week completed close-ratio break beyond that compressed range
- lifecycle: one attempt per broker week, paired continuation, Friday flat

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The bounded governed packets below were read completely before this approval:

1. CME Group gold/silver ratio research at
   `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, supplying the ratio
   definition, opposing-leg spread carrier, and different metal drivers.
2. Toby Crabel's NR7 lineage at
   `strategy-seeds/sources/CRABEL-WTI-NR7-BRK-2026/source.md`, with the named
   1990 Traders Press book supplying the range-compression/expansion pattern.
3. The governed weekly translation at
   `strategy-seeds/sources/CRABEL-WTI-WEEK-ORB-2026/source.md`.
4. The joined bounded lineage at
   `strategy-seeds/sources/CRABEL-CME-XAUXAG-WEEKNR7-2026/source.md`, which
   locks the exact translation and adverse boundaries.

Neither Crabel nor CME tests this synchronized weekly close-ratio event on a
Darwinex two-CFD package. The conjunction, equal-notional sizing, hard stops,
and V5 lifecycle are disclosed QM choices. No efficacy, density, neutrality,
CFD-equivalence, or decorrelation result transfers.

## Locked Mechanic

1. Repair orphan, duplicate, same-side, wrong-symbol, wrong-magic, stopless,
   notional-invalid, or stale owned exposure before entry-only gates.
2. Require exact `XAUUSD.DWX` D1 host, `XAGUSD.DWX` companion, synchronized
   D1 timestamps, and locked backtest/news/Friday inputs.
3. Group synchronized completed closes into broker Monday keys. Require the
   immediately prior calendar week to contain exactly one close on each
   weekday Monday through Friday. Then select the six next-most-recent valid
   complete weeks, skipping incomplete older holiday weeks without changing
   their chronological order.
4. For each week compute the range of the five values
   `ln(XAU_close)-ln(XAG_close)`. Require the prior week's positive finite range
   to be strictly smaller than all six older ranges; equality is not NR7.
5. From Tuesday through Friday, compare only the latest synchronized completed
   current-week close ratio with the prior compressed week's strict extrema.
   BUY XAU/SELL XAG above the maximum and SELL XAU/BUY XAG below the minimum.
   Equality and non-breaks remain flat.
6. Once a strict break exists, persist the current broker Monday week key
   before history-independent spread, quote, ATR, sizing, news, or order gates.
   A rejected or failed attempt may not retry in the same week.
7. Target one-to-one absolute entry notional with at most 20 percent lot-step
   mismatch. Constrain combined broker-normalized stop risk to one
   `RISK_FIXED=1000` package; confidence never scales risk.
8. Attach one frozen `3.0 * ATR(20,D1)` stop per leg, no target, and require
   each spread at or below 1,500 points.
9. Keep both news axes OFF and framework Friday close enabled at broker 21.
   Close the package Friday, on a later broker week, or after eight calendar
   days. Never retry, trail, partially close, scale in, grid, martingale, or
   pyramid.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_PORT_RISK`: named-author/publisher trading-book
  lineage plus CME exchange research, with the untested ratio port disclosed.
- R2 `PASS`: exact grouping, strict NR7 state, break, side, attempt, risk,
  spread, and lifecycle are locked.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native XAU and
  XAG D1 histories supply all runtime data; Q02 owns alignment and basis risk.
- R4 `PASS`: deterministic native arithmetic and V5 state only; no banned
  indicator, ML, external runtime data, adaptive fit, grid, martingale,
  scale-in, or pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,547 registry rows and 625 root cards and
returned `CLEAN`. Manual review distinguishes the continuous 120-D1 ratio
channel in `QM5_12724`, the 60-D1 failed-break fade in `QM5_20265`, the monthly
variance-ratio memory state in `QM5_20249`, and the weekly flow fades in
`QM5_41040` / `QM5_41057`. None requires a strict completed-week ratio NR7 and
then follows only a next-week completed-close break with a Friday-flat package.
`QM5_12533` is only the two-leg implementation recipe.

Verdict: `CLEAN_WEEKLY_RATIO_NR7_EXPANSION_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is five to ten completed packages per full post-warm-up year.
Q02 must retire below five per year, at zero trades or nonpositive governed
economics, or on any week, synchronization, range, strictness, break, attempt,
basket, risk, lifecycle, or determinism defect.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after fresh exact-path tester and host-CPU checks are below their ceilings. At
the ceiling, stop before queue mutation and record a non-live handoff.
