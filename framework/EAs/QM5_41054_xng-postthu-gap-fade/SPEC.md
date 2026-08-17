# QM5_41054 - XNG Post-Thursday Counter-Gap Fade

Status: `G0 APPROVED; IMPLEMENTED; Q01 PENDING; Q02 NOT QUEUED`

## Identity

- EA ID: `QM5_41054`
- slug: `xng-postthu-gap-fade`
- strategy ID: `EIA-WILLIAMS-YANG-XNG-POSTTHUGAPFADE-2026_S01`
- source ID: `EIA-WILLIAMS-YANG-XNG-POSTTHUGAPFADE-2026`
- source packet:
  `strategy-seeds/sources/EIA-WILLIAMS-YANG-XNG-POSTTHUGAPFADE-2026/source.md`
- source approval:
  `decisions/2026-08-18_xng_post_thursday_countergap_fade_source_approval.md`
- source approval commit: `860798f0a`
- deterministic EA-ID reservation commit: `bd394ac36`
- deterministic magic allocation commit: `061ebd1a4`
- approved card:
  `strategy-seeds/cards/approved/QM5_41054_xng-postthu-gap-fade_card.md`
- G0 decision:
  `decisions/2026-08-18_xng_post_thursday_countergap_fade_g0.md`
- host: exact `XNGUSD.DWX`, D1
- slot: `0`
- registered magic: `410540000`

## Locked Candidate Boundary

At the first executable tick of a genuine broker Friday, within 180 minutes
of the D1 session open, require exact completed Tuesday, Wednesday, and
standard-Thursday sessions under one uniform native or `+1` energy-label
convention. Consume the Friday attempt before every fallible gate. Compute
only the completed Thursday open-to-close event-session flow and the frozen
Thursday-close-to-Friday-open gap.

Trade only when those components are finite, nonzero, strictly opposed, and
the event-session component is strictly larger in absolute magnitude. Their
sum must reconcile to the Thursday-open/Friday-open path. Trade in the event-
session sign, which fades the later counter-gap while preserving the still-
dominant completed Thursday displacement.

The planned non-live build uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, one
frozen `3.5 * ATR(20,D1)` hard stop, no target, a 3,000-point spread ceiling,
framework Friday close at broker hour 21, first-later-D1 survivor repair, and
a four-day stale guard. It has no storage value, forecast, external runtime
source, retry, scale-in, grid, martingale, hedge, or pyramid.

## Duplicate Boundary

The canonical checker scanned 4,541 EA rows and 625 root cards and returned
`CLEAN`. Formula review found the event-session/post-event-gap endpoint pair
only in `QM5_41050`, `QM5_41052`, and `QM5_41053`. This candidate admits the
disjoint strict-opposition plus event-dominance XNG state. Manual review
separates it from the agreement/continuation XNG sibling (`QM5_41052`), the
earlier internal-Thursday flow fade (`QM5_41044`), M30 storage-event systems,
multiday drift, and the incumbent cumulative-RSI commodity pullback
(`QM5_12567`).

## Build State

The approved card, durable G0 decision, EA registry row, and active slot-0
magic authorize this exact non-live implementation. The resolver contains
`410540000`; no alternate carrier, signal endpoint, direction, or lifecycle is
authorized.

Artifacts:

- `QM5_41054_xng-postthu-gap-fade.mq5`
- `docs/strategy_card.md` (byte-identical governed card mirror)
- `docs/test_post_thursday_countergap_fade_reference.py`
- `sets/QM5_41054_xng-postthu-gap-fade_XNGUSD.DWX_D1_backtest.set`

Strict compile, build checks, and static Q01 remain required before the
target-only Q02 queue may be mutated.

No live artifact, tester dispatch, terminal control, portfolio mutation, or
performance claim is authorized.
