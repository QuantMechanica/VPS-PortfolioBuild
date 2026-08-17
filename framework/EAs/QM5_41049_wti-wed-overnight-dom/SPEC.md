# QM5_41049 — WTI Standard-Wednesday Overnight-Dominant Flow

Status: `SOURCE APPROVED; EA ID RESERVED; MAGIC ALLOCATED; G0 PENDING`

## Identity

- EA ID: `QM5_41049`
- slug: `wti-wed-overnight-dom`
- strategy ID: `EIA-WILLIAMS-MOP-WTI-WEDOVERNIGHT-2026_S01`
- source approval:
  `decisions/2026-08-17_wti_wednesday_overnight_dominance_source_approval.md`
- host: exact `XTIUSD.DWX`, D1
- slot: `0`
- registered magic: `410490000`
- planned card:
  `strategy-seeds/cards/approved/QM5_41049_wti-wed-overnight-dom_card.md`
- planned G0 decision:
  `decisions/2026-08-17_wti_wednesday_overnight_dominance_g0.md`

## Locked Mechanic

At the first executable broker-Thursday D1 boundary after exact completed
Monday, Tuesday, and standard Wednesday sessions, compute:

```text
overnight_flow = ln(WednesdayOpen / TuesdayClose)
session_flow   = ln(WednesdayClose / WednesdayOpen)
day_return     = ln(WednesdayClose / TuesdayClose)
total_flow     = overnight_flow + session_flow
```

Trade only when the two components strictly oppose, the overnight component
is strictly larger in absolute value, and `total_flow` reconciles to
`day_return` within `1e-10`. Follow the total/overnight sign, freeze a
`3.0 * ATR(20,D1)` hard stop, use no target, and close at the first later D1
boundary.

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

This governed directory identity preceded the active slot-0 magic row, and
`update_magic_resolver.py` retained that allocation. Development remains
blocked until the approved card and G0 decision exist.
