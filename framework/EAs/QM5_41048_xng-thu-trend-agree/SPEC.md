# QM5_41048 — XNG Standard-Thursday Event / Slow-Trend Agreement

Status: `G0 APPROVED; BUILD PENDING MAGIC ALLOCATION`

## Identity

- EA ID: `QM5_41048`
- slug: `xng-thu-trend-agree`
- strategy ID: `EIA-MOP-XNG-THUTRENDAGREE-2026_S01`
- host: exact `XNGUSD.DWX`, D1
- slot: `0`
- planned magic: `410480000`
- approved card:
  `strategy-seeds/cards/approved/QM5_41048_xng-thu-trend-agree_card.md`
- G0 decision:
  `decisions/2026-08-17_xng_thursday_trend_agreement_g0.md`

## Locked Mechanic

At the first executable broker-Friday D1 boundary after an exact standard
Thursday, compute:

```text
event_return = ln(ThursdayClose / WednesdayClose)
slow_trend   = ln(WednesdayClose / Close252SessionsBeforeWednesday)
```

Trade only when the two finite nonzero returns strictly agree. Enter in their
common direction, freeze a `3.5 * ATR(20,D1)` hard stop, use no target, and
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

## Build State

The governed directory identity exists so slot-0 magic allocation can precede
source generation without being dropped by `update_magic_resolver.py`.
