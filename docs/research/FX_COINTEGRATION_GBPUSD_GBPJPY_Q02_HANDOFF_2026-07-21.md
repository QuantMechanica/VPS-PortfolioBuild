# GBPUSD/GBPJPY Cointegration Q02 Handoff

**Date:** 2026-07-21

**Branch:** `agents/board-advisor`

**EA:** `QM5_12760_edgelab-gbpusd-gbpjpy-cointegration`

**Card:** `strategy-seeds/cards/approved/QM5_12760_edgelab-gbpusd-gbpjpy-cointegration_card.md`

## Outcome

The approved GBPUSD/GBPJPY D1 cointegration basket was the first unadvanced
approved forex sleeve in the ranked 66-pair scan cohort. Its build already
existed and passed the structural pre-flight: `.ex5`, two-leg
`basket_manifest.json`, active registry rows, and a logical backtest setfile
with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The sleeve was enqueued for Q02 in
`D:/QM/reports/pipeline/mt5_queue.db` as queue row `2`:

```text
ea_id: QM5_12760
phase: Q02
symbol: GBPUSD.DWX
sub_gate_config_hash: q02_fx_coint_12760_s20260629_001
target_terminal: any
priority: 80
status: queued
```

`GBPUSD.DWX` is the manifest host symbol. `GBPJPY.DWX` is the second traded
leg and `USDJPY.DWX` is conversion history; the basket remains one logical
test, not three duplicate queue jobs.

## Selection And Safety

The two anchor sleeves did not need Q02 repair: repository evidence shows
QM5_12532 and QM5_12533 already passed Q02. All approved scan-derived forex
cards checked in this cohort already had EA builds, so the mission fallback
was used to advance an existing card rather than create duplicate research or
code.

At enqueue time two `terminal64` processes were active, below the mission's
seven-job CPU ceiling. Enqueueing did not launch MT5. No T_Live terminal,
AutoTrading setting, deploy manifest, portfolio admission gate, KPI, or Q08
contribution artifact was touched.
