# QM5_41053 - WTI Post-Wednesday Counter-Gap Fade

Status: `G0 APPROVED; Q01 PASS; Q02 READY`

## Identity

- EA ID: `QM5_41053`
- slug: `wti-postwed-gap-fade`
- strategy ID: `EIA-WILLIAMS-YANG-WTI-POSTWEDGAPFADE-2026_S01`
- source ID: `EIA-WILLIAMS-YANG-WTI-POSTWEDGAPFADE-2026`
- source packet:
  `strategy-seeds/sources/EIA-WILLIAMS-YANG-WTI-POSTWEDGAPFADE-2026/source.md`
- source approval:
  `decisions/2026-08-18_wti_post_wednesday_countergap_fade_source_approval.md`
- source approval commit: `afdedce04`
- deterministic EA-ID reservation commit: `2cd8ff7a9`
- deterministic magic allocation commit: `b702a0069`
- approved card:
  `strategy-seeds/cards/approved/QM5_41053_wti-postwed-gap-fade_card.md`
- host: exact `XTIUSD.DWX`, D1
- intended slot: `0`
- intended magic: `410530000`

## Locked Candidate Boundary

At the first executable tick of a genuine broker Thursday, within 180 minutes
of the D1 session open, require exact completed Monday, Tuesday, and Wednesday
sessions under one uniform native or `+1` energy-label convention. Consume
the Thursday attempt before every fallible gate. Compute only the completed
Wednesday open-to-close event-session flow and the frozen Wednesday-close-to-
Thursday-open gap.

Trade only when those components are finite, nonzero, strictly opposed, and
the event-session component is strictly larger in absolute magnitude. Their
sum must reconcile to the Wednesday-open/Thursday-open path. Trade in the
event-session sign, which fades the later counter-gap while preserving the
still-dominant completed Wednesday displacement.

The planned non-live build uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, one
frozen `3.0 * ATR(20,D1)` hard stop, no target, a 1,500-point spread ceiling,
first-later-D1 exit, three-day stale repair, and framework Friday close at
broker hour 21 as a fail-safe. It has no inventory value, forecast, external
runtime source, retry, scale-in, grid, martingale, hedge, or pyramid.

## Duplicate Boundary

The canonical checker scanned 4,540 EA rows and 625 root cards and returned
`CLEAN`. Formula search found the event-session/post-event-gap endpoint pair
only in the strict-agreement carriers `QM5_41050` and `QM5_41052`. This
candidate admits the disjoint strict-opposition plus event-dominance state.
Manual review separates it from internal-Wednesday flow fade/agreement/
dominance (`QM5_41041`, `QM5_41042`, `QM5_41049`), magnitude/body/mean WPSR
systems, exact-clock M30 systems, and the incumbent cumulative-RSI commodity
pullback (`QM5_12567`).

## Build State

The approved card, durable G0 decision, EA registry row, and active slot-0
magic authorize this exact non-live implementation. The resolver contains
`410530000`; no alternate carrier, signal endpoint, direction, or lifecycle is
authorized.

Artifacts:

- `QM5_41053_wti-postwed-gap-fade.mq5`
- `docs/strategy_card.md` (byte-identical governed card mirror)
- `docs/test_post_wednesday_countergap_fade_reference.py`
- `sets/QM5_41053_wti-postwed-gap-fade_XTIUSD.DWX_D1_backtest.set`

Strict compile, targeted build checks, independent fixtures, static P1, card
lint, and single-symbol scope all pass. A target-only Q02 enqueue remains
subject to the governed tester/CPU ceiling.
