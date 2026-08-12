# FX cointegration frontier Q04 / CPU-ceiling stop — 2026-07-23

## Mission decision

The OWNER-requested 66-pair FX cointegration scan does not contain a
source-qualified unbuilt pair. The two original survivors and every later
strict sign-aware survivor already have a card, compiled EA, RISK_FIXED
backtest setfile, and `basket_manifest.json`. Creating another scan-derived
card would either duplicate an existing sleeve or weaken the documented
selection threshold.

The preferred anchors are not blocked at Q02:

- `QM5_12532` AUDUSD/NZDUSD has logical-basket Q02 PASS and Q04 PASS; it later
  failed Q05.
- `QM5_12533` EURJPY/GBPJPY has logical-basket Q02 PASS; it later failed Q04.

No anchor Q02 repair or duplicate enqueue is justified.

## Existing-sleeve fallback

The highest-ranked existing strict survivor,
`QM5_12978` GBPUSD/USDCAD, was advanced through a repaired Q03 PASS on
2026-07-21 and a repaired logical-basket Q04 run completed on 2026-07-22.

Canonical evidence:

`D:/QM/reports/work_items/bf98a2c5-0ed2-4410-abbe-7e66fe97e843/QM5_12978/Q04/QM5_12978_GBPUSD_USDCAD_COINTEGRATION_D1/aggregate.json`

The Q04 verdict is a strategy `FAIL`, not an infrastructure blocker:

- F1: 0 trades.
- F2: PF net 0.790 over 22 trades.
- F3: PF net 2.636 over 2 trades.
- Low-frequency pool: PF net 0.804, 24 trades, 2/3 active years.
- Gate reason: `lowfreq_pooled_pf_below_floor`.

The farm row `bf98a2c5-0ed2-4410-abbe-7e66fe97e843` is `done/FAIL`.
Advancing this sleeve beyond Q04 would violate the deterministic gate.

## CPU-ceiling observation

At the 2026-07-23 stop check,
`framework/scripts/mt5_queue_status.py` reported nine active work items across
T1, T2, T3, T4, T6, T7, T8, T9, and T10, with 2,503 pending rows. This is the
paced-fleet backtest CPU ceiling specified by the mission.

No backtest was launched, no duplicate queue row was created, and no terminal
was started, stopped, or reconfigured. T_Live and AutoTrading were not touched.
No portfolio-admission, KPI, Q08-contribution, or live-manifest artifact was
read or modified.

## Deterministic next action

Do not replay Q02 for either anchor and do not enqueue `QM5_12978` past its Q04
FAIL. Resume only after fleet capacity clears and a currently non-terminal
forex sleeve is identified, or after an OWNER-approved new source/scan contract
produces a genuinely unbuilt pair.
