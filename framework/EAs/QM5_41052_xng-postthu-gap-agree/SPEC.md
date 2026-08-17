# QM5_41052 - XNG Post-Thursday Gap-Agreement Friday Continuation

Status: `G0 APPROVED; MAGIC ALLOCATED; Q01 PASS; Q02 NOT ENQUEUED - CPU CEILING`

## Identity

- EA ID: `QM5_41052`
- slug: `xng-postthu-gap-agree`
- strategy ID: `EIA-WILLIAMS-MOP-XNG-POSTTHUGAP-2026_S01`
- source ID: `EIA-WILLIAMS-MOP-XNG-POSTTHUGAP-2026`
- source packet:
  `strategy-seeds/sources/EIA-WILLIAMS-MOP-XNG-POSTTHUGAP-2026/source.md`
- source approval:
  `decisions/2026-08-17_xng_post_thursday_gap_agreement_source_approval.md`
- source approval commit: `2b8178970`
- deterministic EA-ID reservation commit: `d33a6d11f`
- host: exact `XNGUSD.DWX`, D1
- slot: `0`
- registered magic: `410520000`
- magic allocation commit: `0e149bab7`

## Locked Candidate Boundary

At the first executable tick of a genuine broker Friday, within 180 minutes
of the D1 session open, require exact completed Tuesday, Wednesday, and
Thursday sessions under one uniform native or `+1` energy-label convention.
Consume the Friday attempt before every fallible gate. Compute only the
completed Thursday open-to-close event-session flow and the frozen Thursday-
close-to-Friday-open gap. Trade only when they are both nonzero and strictly
same-sign, reconcile their sum to the Thursday-open/Friday-open path, and
follow the common sign through Friday.

The planned non-live build uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, one
frozen `3.5 * ATR(20,D1)` hard stop, no target, a 3,000-point spread ceiling,
framework Friday close at broker hour 21, and first-later-D1/four-day stale
repair. It has no storage value, forecast, external runtime source, retry,
scale-in, grid, martingale, hedge, or pyramid.

## Duplicate Boundary

The canonical checker scanned 4,539 EA rows and 625 root cards and returned
`CLEAN`. Manual review separates the candidate from completed-Thursday
internal-flow agreement/fade (`QM5_41043`, `QM5_41044`), Thursday/252-D1
trend conjunctions (`QM5_41047`, `QM5_41048`), magnitude/body/trend multiday
storage drift (`QM5_12898`), M30 release-window systems, Friday slow-trend
short (`QM5_20160`), and the incumbent cumulative-RSI pullback (`QM5_12567`).

## Build State

The branch implementation now contains the card-exact `.mq5`, one canonical
`RISK_FIXED` D1 backtest preset, an exact approved-card copy, and 15 independent
reference fixtures. The fixtures cover both governed energy-label conventions,
exact Tuesday-through-Friday identity, frozen endpoints, all sign pairings,
reconciliation, grace, intrabar non-leakage, Friday cutoff, later-D1 repair,
and stable attempt identity.

Strict MetaEditor compile (0 errors, 0 warnings), generated setfile build hash,
targeted V5 build check, static P1 artifact validation, card lint, all 15
reference fixtures, and single-symbol scope validation pass. The compiled EX5
is a Q01 artifact only. The target-only Q02 dry run selected one fresh row,
but the governed five-sample CPU check reached 97.51% against the 97% hard
ceiling, so no queue mutation occurred. No manual tester dispatch, terminal
control, live artifact, portfolio mutation, or performance claim is
authorized.
