# QM5_41048 — XNG Standard-Thursday Event / Slow-Trend Agreement

Status: `G0 APPROVED; Q01 PASS; Q02 ENQUEUED`

## Identity

- EA ID: `QM5_41048`
- slug: `xng-thu-trend-agree`
- strategy ID: `EIA-MOP-XNG-THUTRENDAGREE-2026_S01`
- host: exact `XNGUSD.DWX`, D1
- slot: `0`
- registered magic: `410480000`
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

The directory was established before magic allocation, then the canonical
resolver kept 17,297 rows and dropped zero. The source and binary are present
with one fixed-risk backtest preset, a synchronized approved-card copy, and an
independent 15-case reference suite.

Q01 evidence:

- strict compile PASS, zero errors and zero warnings:
  `framework/build/compile/20260817_165733/QM5_41048_xng-thu-trend-agree.compile.log`
- targeted build check PASS, zero failures and zero warnings:
  `D:/QM/reports/framework/21/build_check_20260817_165858.json`
- static P1 artifact validation PASS:
  `D:/QM/reports/pipeline/QM5_41048/P1/P1_QM5_41048_result.json`
- factory symbol-scope validation: `SINGLE_SYMBOL_OK`, zero violations
- MQ5 SHA-256:
  `D0CAFFFFEECC293285430AA5B9324E60EC83CA0FFF8230AB537F5124191F9315`
- EX5 SHA-256:
  `19D2C37E91752AEB12540FAC07BE855E6585EB25394A785CB79A0B8B2B340A9C`
- setfile normalized-content build hash:
  `80974e1c67e39ad4fecf5698b9c8f14e38881bb551f47f080a04b792354c8b7a`

## Q02 Handoff

The target-only dry run selected one fresh Q02 item and no recovery item. At
the capacity gate, five exact-path research terminals were active against the
seven-terminal ceiling; five host-CPU samples averaged `94.80%` and peaked at
`96.93%`, below the `97%` hard stop. The paced launch limit was `1`.

The apply created exactly one work item,
`6d4dbb7f-736b-4255-965a-b12e7333f24e`, for exact `XNGUSD.DWX`, D1. It was
initially `pending` with attempt count 0; the scheduled fleet later claimed it
on T7 without operator terminal control. A post-apply target-only dry run
selected zero additional rows. Full evidence is in
`docs/ops/evidence/2026-08-17_qm5_41048_xng_thursday_trend_agreement_q01_q02_enqueue.md`.
