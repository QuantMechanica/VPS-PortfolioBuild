# XBR/CADCHF Relative-Spread Q02 Handoff

**Date:** 2026-07-22

**Branch:** `agents/board-advisor`

**EA:** `QM5_13086_xbr-cadchf-rspr`

**Card:** `strategy-seeds/cards/approved/QM5_13086_xbr-cadchf-rspr_card.md`

## Outcome

The ranked 66-pair cointegration cohort contains no unbuilt approved pair: its
approved candidates already have EA directories and prior pipeline work. The
mission fallback was therefore used to advance an existing, unadvanced forex
relative-value card. QM5_13086 was the approved built FX basket with no prior
work item.

The XBRUSD/CADCHF D1 return-spread basket passed structural pre-flight: its
`.ex5`, two-leg `basket_manifest.json`, active registry rows, and logical
backtest setfile are present. The setfile uses `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The sleeve was enqueued for Q02 in
`D:/QM/reports/pipeline/mt5_queue.db` as queue row `3`:

```text
ea_id: QM5_13086
phase: Q02
symbol: XBRUSD.DWX
sub_gate_config_hash: q02_xbr_cadchf_rspr_13086_s20260709_001
target_terminal: any
priority: 80
status: queued
```

`XBRUSD.DWX` is the manifest host and `CADCHF.DWX` is the second traded leg.
This is one logical basket job, not two standalone symbol jobs.

## Selection And Safety

QM5_12532 and QM5_12533 already have Q02 PASS evidence, so neither required an
ONINIT or NO_HISTORY repair. The enqueue path checked for an active duplicate
with the same EA, phase, and configuration hash before inserting the row.

Four factory `terminal64` processes were active at enqueue time (T1, T3, T8,
and T10), below the seven-job CPU ceiling. Enqueueing did not launch MT5. The
T_Live and FTMO terminals were excluded from the factory count. No T_Live
setting, AutoTrading control, deploy manifest, portfolio admission gate, KPI,
or Q08 contribution artifact was touched.
