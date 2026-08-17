# QM5_41047 — XNG Thursday Counter-Move / Slow-Trend Re-entry

Status: `G0 APPROVED; DIRECTORY IDENTITY ESTABLISHED; BUILD PENDING`

## Identity

- EA ID: `QM5_41047`
- slug: `xng-thu-trend-pb`
- strategy ID: `EIA-MOP-XNG-THUTRENDPB-2026_S01`
- host: exact `XNGUSD.DWX`, D1
- slot: `0`
- planned magic: `410470000` (registry allocation pending)
- approved card:
  `strategy-seeds/cards/approved/QM5_41047_xng-thu-trend-pb_card.md`
- G0 decision:
  `decisions/2026-08-17_xng_thursday_trend_pullback_g0.md`

## Locked Mechanic

At the first executable broker-Friday D1 boundary after an exact standard
Thursday, compute:

```text
event_return = ln(ThursdayClose / WednesdayClose)
slow_trend   = ln(WednesdayClose / Close252SessionsBeforeWednesday)
```

Trade only when the two finite nonzero returns strictly oppose. Enter in the
slow-trend direction, freeze a `3.5 * ATR(20,D1)` hard stop, use no target, and
close at the first later D1 boundary. Friday close is disabled because the
normal one-D1 lifecycle spans the weekend.

## Risk And Runtime Boundary

- backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`
- both news axes OFF
- entry spread ceiling: 3,000 points
- one durable Friday attempt before every fallible gate
- no external runtime data, storage value, calendar file, live preset, demo,
  shadow, stress, optimization, AutoTrading, `T_Live`, deploy/T_Live manifest,
  portfolio-gate change, portfolio admission, or correlation waiver

## Build Order

This file establishes the exact EA directory before magic allocation, as
required by the canonical resolver generator. Development may next append the
single active `(41047, 0, XNGUSD.DWX)` row, regenerate the resolver with zero
dropped rows, then implement and strictly validate the approved card.
