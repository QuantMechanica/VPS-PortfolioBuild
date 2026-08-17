# QM5_41041 WTI Standard-Wednesday Session-Dominant Flow Fade

## Identity

- EA ID: `QM5_41041`
- Slug: `wti-wed-flow-fade`
- Strategy ID: `EIA-WILLIAMS-YANG-WTI-WEDFLOWFADE-2026_S01`
- Card: `strategy-seeds/cards/approved/QM5_41041_wti-wed-flow-fade_card.md`
- G0: `APPROVED`
- Carrier: exact `XTIUSD.DWX`, D1, magic slot 0
- Environment: non-live build and deterministic pipeline only

## Locked Mechanic

On the first executable broker-Thursday D1 tick, reconstruct exact completed
Monday, Tuesday, and Wednesday sessions under the governed native or uniform
`+1` energy-label convention. Decompose Wednesday into:

```text
overnight_flow = ln(WednesdayOpen / TuesdayClose)
session_flow   = ln(WednesdayClose / WednesdayOpen)
day_return     = ln(WednesdayClose / TuesdayClose)
```

Trade only when the components strictly oppose, the session component has
strictly larger absolute magnitude, and their sum reconciles to `day_return`
within `1e-10`. Fade the completed total: positive sells WTI and negative buys
WTI. Exact zero, agreement, equality, broken dates, invalid endpoints, or
failed reconciliation consumes Thursday flat.

The ordinary exit is the first D1 boundary after entry. Framework Friday
close at broker hour 21 and a three-day stale guard are fail-safes.

## Locked Inputs

| Input | Value |
|---|---:|
| `qm_ea_id` | 41041 |
| `qm_magic_slot_offset` | 0 |
| `RISK_PERCENT` | 0 |
| `RISK_FIXED` | 1000 |
| `PORTFOLIO_WEIGHT` | 1 |
| both news axes | OFF / NONE |
| `qm_friday_close_enabled` | true |
| `qm_friday_close_hour_broker` | 21 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.0 |
| `strategy_max_hold_days` | 3 |
| `strategy_max_spread_points` | 1500 |
| `strategy_reconcile_tolerance` | 1e-10 |

The baseline has no optimization surface, take-profit, magnitude filter,
volatility signal gate, moving mean, oscillator, range/tail rule, inventory
input, retry, scale-in, grid, martingale, or pyramid.

## Source And Duplicate Boundary

The source approval is
`decisions/2026-08-17_wti_wednesday_flow_fade_source_approval.md`; the G0
authorization is
`decisions/2026-08-17_wti_wednesday_flow_fade_g0.md`.

The canonical checker scanned 4,528 registry rows and 625 cards and returned
`CLEAN`. The load-bearing identity differs from the existing D1 WPSR fade by
using internal overnight/session opposition plus dominance, no range/body/
tail/SMA state, and a next-D1 exit. It differs from the weekly WTI flow family
by using one Wednesday, a Thursday entry, contrarian direction, and a one-D1
hold rather than a completed week and Monday-Friday lifecycle.

## Risk And Safety

- Backtest preset only: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Frozen hard stop: `3.0 * ATR(20,D1)`.
- One position, one durable Thursday attempt, no same-day retry.
- Expected cadence: approximately 8-18 completed positions/year; Q02 retires
  below five/year or on nonpositive governed economics.
- Q09 alone may establish realized correlation with the certified book.
- No live/demo/shadow/stress/optimization setfile, manual backtest, terminal
  control, AutoTrading action, `T_Live` access, deploy/T_Live manifest,
  portfolio-gate edit, portfolio admission, or correlation waiver.

## Build Status

- G0: `APPROVED`
- EA ID registry: `41041 / wti-wed-flow-fade / active`
- EA directory identity: established before magic allocation
- Magic slot 0: `XTIUSD.DWX / 410410000 / active`
- Q01: PASS (14 fixtures; strict compile and targeted build check clean;
  static P1 artifact validation PASS)
- Q02: not enqueued

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-17 | approved build directory identity | source/G0/card and EA-ID registry complete |
| v1-build | 2026-08-17 | deterministic implementation | strict compile, targeted build check, independent fixtures, and static P1 PASS |

## Q01 Evidence

- independent Wednesday flow-fade reference suite: 14 tests PASS
- strict compile: 0 errors, 0 warnings
- targeted V5 build check: 0 failures, 0 warnings
- card copies: byte-identical; schema/ML and G0 lint PASS
- static P1 artifact validation: PASS
- compile log:
  `framework/build/compile/20260817_085806/QM5_41041_wti-wed-flow-fade.compile.log`
- build report:
  `D:/QM/reports/framework/21/build_check_20260817_085805.json`
- P1 report:
  `D:/QM/reports/pipeline/QM5_41041/P1/P1_QM5_41041_result.json`
