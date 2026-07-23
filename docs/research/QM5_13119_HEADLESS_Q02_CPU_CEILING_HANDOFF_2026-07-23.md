# QM5_13119 Headless Q02 CPU-Ceiling Handoff

**Date:** 2026-07-23  
**Branch:** `agents/board-advisor`  
**EA:** `QM5_13119_usdjpy-euraud`  
**Pair:** `USDJPY.DWX` / `EURAUD.DWX`

## Queue continuation

The paced-fleet preflight was repeated after capacity dropped to five factory
terminals (T3, T4, T7, T8, and T10), below the seven-process CPU ceiling.
`T_Live` and the separate FTMO terminal were observed only to exclude them
from the factory count; neither was controlled or modified.

The duplicate guard still returned zero rows for the exact tuple
`(QM5_13119, Q02, q02_fx_coint_13119_s20260710_001)`. One logical basket job
was then enqueued through the canonical headless queue helper:

```text
queue_id: 4
ea_id: QM5_13119
phase: Q02
symbol: USDJPY.DWX
sub_gate_config_hash: q02_fx_coint_13119_s20260710_001
target_terminal: any
priority: 80
status: queued
```

`USDJPY.DWX` is the manifest host symbol. `EURAUD.DWX` is the second traded
leg, while `AUDUSD.DWX` and `EURUSD.DWX` are conversion-history dependencies;
they were not enqueued as duplicate jobs. Enqueueing did not launch MT5.

## Decision

The controlling positive-hedge 66-pair scan has no unbuilt survivor:
`QM5_12532` and `QM5_12533` both have logical-basket Q02 PASS evidence and
later genuine strategy failures. The sign-aware scan extension is also fully
built. Its final strict row, USDJPY/EURAUD, is the concrete fallback candidate
for the current headless paced fleet because `QM5_13119` was approved, built,
and absent from `D:/QM/reports/pipeline/mt5_queue.db` at initial preflight.

No new card or duplicate EA was created. The initial attempt stopped because
the factory had reached the mission's explicit backtest CPU ceiling; the
single Q02 row above was inserted only after capacity became available.

## Structural preflight

- Approved card:
  `strategy-seeds/cards/approved/QM5_13119_usdjpy-euraud_card.md`
- EA binary:
  `framework/EAs/QM5_13119_usdjpy-euraud/QM5_13119_usdjpy-euraud.ex5`
- Basket manifest:
  `framework/EAs/QM5_13119_usdjpy-euraud/basket_manifest.json`
- Logical setfile:
  `framework/EAs/QM5_13119_usdjpy-euraud/sets/QM5_13119_usdjpy-euraud_QM5_13119_USDJPY_EURAUD_COINTEGRATION_D1_D1_backtest.set`
- Risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`
- Build guard: PASS, zero failures and zero warnings
- Build report:
  `D:/QM/reports/framework/21/build_check_20260723_023229.json`
- Headless Q02 duplicate guard: zero rows for `QM5_13119` / `Q02`

The manifest declares USDJPY and EURAUD as the traded legs. AUDUSD and EURUSD
are conversion-history dependencies only. The fixed D1 z-score, fixed beta,
atomic package entry, and fixed-risk setfile remain structural and contain no
ML or banned indicator.

## Initial CPU stop condition

Seven factory terminals were running at preflight: T1, T2, T3, T6, T7, T8,
and T9. This equals the mission's seven-process CPU ceiling. The separate
`T_Live` process was observed only to exclude it from the factory count; it was
not controlled or modified.

Per the mission stop rule, no queue mutation and no MT5 launch occurred during
that initial attempt. The later continuation above satisfied the capacity and
duplicate guards and enqueued exactly one headless row with:

```text
ea_id: QM5_13119
version: v1
phase: Q02
symbol: USDJPY.DWX
sub_gate_config_hash: q02_fx_coint_13119_s20260710_001
setfile_path: framework/EAs/QM5_13119_usdjpy-euraud/sets/QM5_13119_usdjpy-euraud_QM5_13119_USDJPY_EURAUD_COINTEGRATION_D1_D1_backtest.set
target_terminal: any
priority: 80
```

Before insertion, repeat the duplicate guard on `(ea_id, phase,
sub_gate_config_hash)` and the CPU check. No `T_Live`, AutoTrading, deploy
manifest, portfolio admission gate, portfolio KPI, or Q08 contribution path is
part of this handoff.
