# QM5_41047 — XNG Thursday Counter-Move / Slow-Trend Re-entry

Status: `G0 APPROVED; Q01 PASS; Q02 NOT ENQUEUED — CPU CEILING`

## Identity

- EA ID: `QM5_41047`
- slug: `xng-thu-trend-pb`
- strategy ID: `EIA-MOP-XNG-THUTRENDPB-2026_S01`
- host: exact `XNGUSD.DWX`, D1
- slot: `0`
- registered magic: `410470000`
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

## Build State

The directory was established before magic allocation, then the canonical
resolver kept 17,296 rows and dropped zero. The source and binary are present
with one fixed-risk backtest preset, a synchronized approved-card copy, and an
independent 15-case reference suite.

Q01 evidence:

- strict compile PASS, zero errors and zero warnings:
  `framework/build/compile/20260817_150047/QM5_41047_xng-thu-trend-pb.compile.log`
- targeted build check PASS, zero failures and zero warnings:
  `D:/QM/reports/framework/21/build_check_20260817_150150.json`
- static P1 artifact validation PASS:
  `D:/QM/reports/pipeline/QM5_41047/P1/P1_QM5_41047_result.json`
- factory symbol-scope validation: `SINGLE_SYMBOL_OK`, zero violations

The target-only Q02 dry run selected exactly one new row. The pre-apply census
then found seven active exact-path research terminals and the five-sample host
reading averaged 99.62% CPU, so the apply command was not run. A read-only
post-check found zero `QM5_41047` work items. The only next mutation authorized
by the card remains one paced target-only Q02 enqueue after the governed tester
and host-CPU ceilings clear. Evidence:
`docs/ops/evidence/2026-08-17_qm5_41047_xng_thursday_trend_pullback_q01_q02_capacity_stop.md`.
