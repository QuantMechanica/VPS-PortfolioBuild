# QM5_41050 — WTI Post-Wednesday Gap-Agreement Continuation

Status: `G0 APPROVED; BUILD IMPLEMENTED; Q01 PENDING`

## Identity

- EA ID: `QM5_41050`
- slug: `wti-postwed-gap-agree`
- strategy ID: `EIA-WILLIAMS-MOP-WTI-POSTWEDGAP-2026_S01`
- source approval:
  `decisions/2026-08-17_wti_post_wednesday_gap_agreement_source_approval.md`
- source approval commit: `8ee045854`
- host: exact `XTIUSD.DWX`, D1
- slot: `0`
- registered magic: `410500000`
- approved card:
  `strategy-seeds/cards/approved/QM5_41050_wti-postwed-gap-agree_card.md`
- G0 decision:
  `decisions/2026-08-17_wti_post_wednesday_gap_agreement_g0.md`

## Locked Mechanic

At the first executable broker-Thursday D1 boundary after exact completed
Monday, Tuesday, and standard Wednesday sessions, compute:

```text
event_session_flow = ln(WednesdayClose / WednesdayOpen)
post_event_gap      = ln(ThursdayOpen / WednesdayClose)
confirmed_path      = ln(ThursdayOpen / WednesdayOpen)
total_flow          = event_session_flow + post_event_gap
```

Trade only when both finite nonzero components share one strict sign and
`total_flow` reconciles to `confirmed_path` within `1e-10`. Follow the shared
sign, freeze a `3.0 * ATR(20,D1)` hard stop, use no target, and close at the
first later D1 boundary. The Thursday open is frozen; no later current-bar
field enters the signal.

## Risk And Runtime Boundary

- backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`
- both news axes OFF
- framework Friday close ON at broker hour 21 as a fail-safe
- entry spread ceiling: 1,500 points
- one durable Thursday attempt before every fallible gate
- no external runtime data, inventory value, calendar file, live preset, demo,
  shadow, stress, optimization, AutoTrading, `T_Live`, deploy/T_Live manifest,
  portfolio-gate change, portfolio admission, or correlation waiver

## Build State

The approved card, durable G0 decision, EA registry row, and active slot-0
magic authorize this exact non-live implementation. The resolver contains
`410500000`; no alternate carrier, signal endpoint, direction, or lifecycle is
authorized.

Artifacts:

- `QM5_41050_wti-postwed-gap-agree.mq5`
- `docs/strategy_card.md` (byte-identical governed card mirror)
- `docs/test_post_wednesday_gap_agreement_reference.py`
- `sets/QM5_41050_wti-postwed-gap-agree_XTIUSD.DWX_D1_backtest.set`

Strict compile, build checks, and static Q01 remain required before the
target-only Q02 queue may be mutated.
