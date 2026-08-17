# QM5_41043 XNG Standard-Thursday Strict Flow-Agreement Continuation

## Identity

- EA ID: `QM5_41043`
- Slug: `xng-thu-flow-agree`
- Strategy ID: `EIA-WILLIAMS-MOP-XNG-THUFLOWAGREE-2026_S01`
- Card: `strategy-seeds/cards/approved/QM5_41043_xng-thu-flow-agree_card.md`
- G0: `APPROVED`
- Carrier: exact `XNGUSD.DWX`, D1, magic slot 0
- Environment: non-live build and deterministic pipeline only

## Locked Mechanic

On the first executable broker-Friday D1 tick, reconstruct exact completed
Tuesday, Wednesday, and Thursday sessions under the governed native or uniform
`+1` energy-label convention. Decompose Thursday into:

```text
overnight_flow = ln(ThursdayOpen / WednesdayClose)
session_flow   = ln(ThursdayClose / ThursdayOpen)
day_return     = ln(ThursdayClose / WednesdayClose)
```

Trade only when both components are nonzero, have the same strict sign, and
their sum reconciles to `day_return` within `1e-10`. Follow the completed total:
positive buys XNG and negative sells XNG. Exact zero, opposition, broken dates,
invalid endpoints, or failed reconciliation consumes Friday flat.

The ordinary exit is the first D1 boundary after entry, normally Monday open.
Framework Friday close is disabled so it cannot truncate that lifecycle; a
four-day stale guard remains.

## Locked Inputs

| Input | Value |
|---|---:|
| `qm_ea_id` | 41043 |
| `qm_magic_slot_offset` | 0 |
| `RISK_PERCENT` | 0 |
| `RISK_FIXED` | 1000 |
| `PORTFOLIO_WEIGHT` | 1 |
| both news axes | OFF / NONE |
| `qm_friday_close_enabled` | false |
| `qm_friday_close_hour_broker` | 21 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_max_hold_days` | 4 |
| `strategy_max_spread_points` | 3000 |
| `strategy_reconcile_tolerance` | 1e-10 |

The baseline has no optimization surface, take-profit, magnitude filter,
volatility signal gate, moving mean, oscillator, range/tail rule, storage
value, retry, scale-in, grid, martingale, or pyramid.

## Source And Duplicate Boundary

The source approval is
`decisions/2026-08-17_xng_thursday_flow_agreement_source_approval.md`; the G0
authorization is
`decisions/2026-08-17_xng_thursday_flow_agreement_g0.md`.

The canonical checker found no exact identity and surfaced weekly/monthly WTI
flow-agreement relatives. This identity uses XNG's standard Thursday storage
clock, a Friday decision, and a weekend-bearing next-D1 lifecycle. Existing XNG
Thursday systems are unconditional calendar or slow-trend entries; exact-clock
storage systems use M30 release-window objects; `QM5_12567` is a long-only
cumulative-RSI pullback.

## Risk And Safety

- Backtest preset only: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Frozen hard stop: `3.5 * ATR(20,D1)`.
- One position, one durable Friday attempt, no same-day retry.
- Expected cadence: approximately 18-32 completed positions/year; Q02 retires
  below five/year or on nonpositive governed economics.
- Weekend XNG gaps and financing are explicit kill risks.
- Q09 alone may establish realized correlation with the certified book.
- No live/demo/shadow/stress/optimization setfile, manual backtest, terminal
  control, AutoTrading action, `T_Live` access, deploy/T_Live manifest,
  portfolio-gate edit, portfolio admission, or correlation waiver.

## Build Status

- G0: `APPROVED`
- EA ID registry: `41043 / xng-thu-flow-agree / active`
- EA directory identity: established before magic allocation
- Magic slot 0: `XNGUSD.DWX / 410430000 / active`
- Q01: pending
- Q02: not enqueued

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-17 | approved build directory identity | source/G0/card and EA-ID registry complete |
