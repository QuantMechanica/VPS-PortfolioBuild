# WTI Completed-Week NR7 Expansion - Source Approval

Date: 2026-08-18

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and host-CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission requires one new non-duplicate,
structural, low-frequency commodity edge with reputable sources and
`RISK_FIXED` backtests; identifies outright WTI trend/seasonality as an allowed
sleeve; and forbids live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `wti-week-nr7-brk`
- proposed strategy ID: `CRABEL-WTI-WEEKNR7-2026_S01`
- proposed source ID: `CRABEL-WTI-WEEKNR7-2026`
- carrier: exact `XTIUSD.DWX`, D1, single slot
- state: immediately prior complete normalized broker week is strict NR7 by
  full D1 high-low range
- trigger: next-week first completed D1 close outside that range
- lifecycle: one attempt per broker week, continuation side, Friday flat

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The bounded governed records below were read completely before approval:

1. `strategy-seeds/sources/CRABEL-WTI-NR7-BRK-2026/source.md`, recording Toby
   Crabel's 1990 Traders Press book and the NR7 contraction/expansion lineage.
2. `strategy-seeds/sources/CRABEL-WTI-WEEK-ORB-2026/source.md`, recording the
   existing governed translation of Crabel-style range states to complete WTI
   broker weeks.
3. `strategy-seeds/sources/CRABEL-WTI-WEEKNR7-2026/source.md`, joining those
   lineages and locking the exact candidate plus adverse boundaries.

Crabel does not test this normalized complete-week rule on a Darwinex
continuous WTI CFD. No result, density, cost, CFD-equivalence, or portfolio-
correlation claim transfers.

## Locked Mechanic

1. Require exact `XTIUSD.DWX`, D1, EA slot zero, fixed-risk backtest inputs,
   both news axes OFF, and Friday close enabled at broker 21.
2. Normalize all D1 dates with one uniform offset: raw dates either match the
   broker date or are exactly one day behind and receive `+1` day. Reject every
   other, mixed, or ambiguous convention.
3. Require the immediately prior normalized broker Monday-Friday week to have
   exactly one completed bar per weekday. Select the six next-most-recent valid
   complete weeks, skipping only incomplete older holiday weeks.
4. Compute each complete week's maximum D1 high minus minimum D1 low. Require
   the prior week's positive finite range to be strictly smaller than every
   older comparison range; equality is not NR7.
5. From Tuesday through Friday of the next broker week, compare only the latest
   completed normalized D1 close with the compressed-week extrema. Buy above
   its high, sell below its low, and remain flat on equality or no break.
6. Persist the current broker Monday week key before every fallible downstream
   entry gate after a strict break; a rejected or failed attempt may not retry.
7. Size one position to `RISK_FIXED=1000` against a frozen
   `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.
8. Close Friday at broker 21, on a later broker week, or after eight calendar
   days. Never retry, trail, partially close, scale in, grid, martingale, or
   pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,548 registry rows and 625 root cards. It found
no exact identity and surfaced only the expected fuzzy family match to the
weekly opening-range EA. Manual review separates:

- the single-D1 NR7 setup in `QM5_13096`;
- the current-week first-D1 opening box in `QM5_12965`;
- the parent/inside-week relation in `QM5_13075`;
- the synchronized two-metal close-ratio basket in `QM5_41060`; and
- the XNG cumulative-RSI pullback in `QM5_12567`.

None computes outright WTI full high-low ranges for seven valid complete weeks
and follows only the next week's first completed-close escape with one weekly
attempt and Friday-flat lifecycle. Verdict:
`CLEAN_WTI_COMPLETE_WEEK_NR7_NEXT_WEEK_EXPANSION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_TIME_AGGREGATION_RISK`: named-author/publisher systematic
  trading-book lineage; untested weekly CFD translation disclosed.
- R2 `PASS`: exact clock, normalization, week sample, strict comparison,
  breakout, side, attempt, risk, and lifecycle are locked.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native WTI D1
  history supplies all runtime data; Q02 owns data and basis falsification.
- R4 `PASS`: deterministic native arithmetic and V5 state only; no banned
  indicator, ML, external runtime data, adaptive fit, grid, martingale,
  scale-in, or pyramid.

## Kill And Safety Boundary

Expected cadence is five to ten completed positions per full post-warm-up year.
Q02 must retire below five per year, at zero trades or nonpositive governed
economics, or on any label, week, range, strictness, breakout, attempt, risk,
lifecycle, or determinism defect.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after fresh exact-path tester and host-CPU checks are below their ceilings. At
the ceiling, stop before queue mutation and record a non-live handoff.
