# QM5_12760 GBPUSD/GBPJPY Q02 CPU-Ceiling Hold

**Date:** 2026-07-22

**Branch:** `agents/board-advisor`

**EA:** `QM5_12760_edgelab-gbpusd-gbpjpy-cointegration`

## Outcome

No duplicate Q02 work item was created and no MT5 process was launched. The
approved, built GBPUSD/GBPJPY D1 basket remains the first genuinely
unadvanced scan-derived FX sleeve, and its existing canonical queue row is
still ready for paced execution:

```text
queue_db: D:/QM/reports/pipeline/mt5_queue.db
schema: legacy_saturation
row_id: 2
ea_id: QM5_12760
phase: Q02
symbol: GBPUSD.DWX
sub_gate_config_hash: q02_fx_coint_12760_s20260629_001
priority: 80
status: queued
```

`GBPUSD.DWX` is the basket-manifest host. `GBPJPY.DWX` is the second traded
leg and `USDJPY.DWX` is conversion history, so this is one logical test and
must not be expanded into component-leg jobs.

## Frontier And Anchor Check

- `QM5_12532` AUDUSD/NZDUSD already passed Q02 and Q04 before its Q05
  strategy failure. Historical component-leg `NO_HISTORY` rows are
  superseded.
- `QM5_12533` EURJPY/GBPJPY already passed repaired logical-basket Q02 and
  later reached a terminal strategy verdict. Historical `ONINIT` and history
  failures are superseded.
- The strict sign-aware extension of the OWNER-requested 66-pair scan is
  exhausted through `QM5_13119` USDJPY/EURAUD. Every strict row has a card
  and EA build; creating another card would duplicate a sleeve or weaken the
  documented screen.

The mission fallback therefore applies: retain the unique Q02 handoff for the
already-built `QM5_12760` rather than manufacture a duplicate candidate.

## CPU Ceiling

The read-only fleet scan reported `terminal64_running_count: 7`, equal to the
mission ceiling. Active test terminals included T3, T6, T8, T9, and T10; the
process list also contained the live and FTMO terminals, which were inspected
only for capacity accounting and were not touched. The canonical queue had
two queued rows and no dispatched row at inspection time.

Because the ceiling was reached, no dispatcher tick, worker launch, manual
smoke, or new enqueue was attempted. The safe next action is to let the
existing row `2` run when the paced worker pool has capacity.

## Reproduction

```powershell
python framework/scripts/mt5_queue_status.py `
  --sqlite D:/QM/reports/pipeline/mt5_queue.db `
  --limit 50

python tools/strategy_farm/farmctl.py `
  --root D:/QM/strategy_farm mt5-slots
```

## Safety Boundary

No `T_Live` or AutoTrading state was changed. No deploy manifest,
portfolio-admission gate, portfolio KPI, Q08 contribution path, or portfolio
gate file was modified.
