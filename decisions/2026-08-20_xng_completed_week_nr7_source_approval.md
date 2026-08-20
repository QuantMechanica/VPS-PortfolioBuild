# XNG Completed-Week NR7 Expansion - Source Approval

Date: 2026-08-20

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and host-CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission requires one new non-duplicate,
structural, low-frequency commodity edge with reputable-source criteria and
`RISK_FIXED` backtests; explicitly permits a second `XNGUSD` edge when its
logic differs from `QM5_12567`; and forbids live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `xng-week-nr7-brk`
- proposed strategy ID: `CRABEL-XNG-WEEKNR7-2026_S01`
- source ID: `CRABEL-XNG-WEEKNR7-2026`
- carrier: exact `XNGUSD.DWX`, D1, single slot
- state: immediately prior complete normalized broker week is strict NR7 by
  full D1 high-low range
- trigger: next-week first completed D1 close outside that range
- lifecycle: one attempt per broker week, continuation side, Friday flat

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The bounded governed records below were read completely before approval:

1. `strategy-seeds/sources/CRABEL-WTI-NR7-BRK-2026/source.md`, recording Toby
   Crabel's 1990 Traders Press book and NR7 contraction/expansion lineage.
2. `strategy-seeds/sources/CRABEL-WTI-WEEK-ORB-2026/source.md`, recording the
   governed translation of range states to complete broker weeks.
3. `strategy-seeds/sources/CRABEL-WTI-WEEKNR7-2026/source.md`, locking the
   strict seven-complete-week estimator and completed-close chronology.
4. `strategy-seeds/sources/CRABEL-XNG-WEEKNR7-2026/source.md`, bounding the
   XNG carrier test and its adverse duplicate and claim boundaries.

The primary citation is Toby Crabel, *Day Trading with Short-Term Price
Patterns and Opening Range Breakout*, Traders Press, 1990. Crabel does not test
this normalized complete-week rule on a Darwinex continuous natural-gas CFD.
No source or WTI-sibling result, density, cost, CFD-equivalence, or portfolio-
correlation claim transfers.

## Locked Mechanic

1. Require exact `XNGUSD.DWX`, D1, slot zero, fixed-risk backtest inputs, both
   news axes OFF, and Friday close enabled at broker 21.
2. Normalize all D1 dates with one uniform offset: raw dates either match the
   broker date or are exactly one day behind and receive `+1` day. Reject every
   other, mixed, or ambiguous convention.
3. Require the immediately prior normalized Monday-Friday broker week to have
   exactly one completed bar per weekday. Select the six next-most-recent
   valid complete weeks, skipping only incomplete older holiday weeks.
4. Compute each complete week's maximum D1 high minus minimum D1 low. Require
   the prior week's positive finite range to be strictly smaller than every
   older range; equality is not NR7.
5. From Tuesday through Friday of the next broker week, compare only the latest
   completed normalized D1 close with the compressed-week extrema. Buy above
   its high, sell below its low, and remain flat otherwise.
6. Persist the current broker-Monday week key before every fallible downstream
   gate after a strict break; a rejected or failed attempt may not retry.
7. Size one position to `RISK_FIXED=1000` against a frozen
   `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.
8. Close Friday at broker 21, on a later broker week, or after eight calendar
   days. Never retry, trail, partially close, scale in, grid, martingale, or
   pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,550 registry rows and 625 root cards, found no
exact identity, and raised one lexical family match. Manual review separates
the two-day long-only cumulative-RSI2 pullback in `QM5_12567`, the thresholded
five-D1 return/reversal rules in `QM5_13101` and `QM5_13102`, the D1 inside-
day/narrow-four pattern in `QM5_13105`, and the month opening range in
`QM5_12812`.

`QM5_41061` is the same predeclared estimator on outright WTI, while
`QM5_41060` is a synchronized two-metal close-ratio basket. Neither already
builds an outright XNG weekly range-rank stream. Carrier difference does not
prove decorrelation and no sibling evidence transfers. Verdict:
`CLEAN_XNG_COMPLETE_WEEK_NR7_CARRIER_EXTENSION_AFTER_MANUAL_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_TIME_AGGREGATION_AND_CARRIER_RISK`: named-author/publisher
  systematic trading-book lineage; untested weekly XNG CFD translation
  disclosed.
- R2 `PASS`: exact clock, normalization, week sample, strict comparison,
  breakout, side, attempt, risk, and lifecycle are locked.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native XNG D1
  history supplies all runtime data; Q02 owns data and basis falsification.
- R4 `PASS`: deterministic native arithmetic and V5 state only; no banned
  signal, ML, external runtime data, adaptive fit, grid, martingale, scale-in,
  or pyramid.

## Kill And Safety Boundary

Expected cadence is five to ten completed positions per full post-warm-up
year. Q02 must retire below five per year, at zero trades or nonpositive
governed economics, or on any label, week, range, strictness, breakout,
attempt, risk, lifecycle, or determinism defect.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after fresh exact-path tester and host-CPU checks are below their ceilings. At
the ceiling, stop before queue mutation and record a non-live handoff.
