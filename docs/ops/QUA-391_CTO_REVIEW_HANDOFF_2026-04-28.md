# QUA-391 CTO Review Handoff (2026-04-28)

Issue: `QUA-391`  
EA: `QM5_1007_lien_dbb_pick_tops`  
Strategy Card: `SRC04_S02a` (`lien-dbb-pick-tops`)  
Execution policy: Development implementation complete; CTO review required before any pipeline/backtest activity.

## Deliverables

- `framework/EAs/QM5_1007_lien_dbb_pick_tops/QM5_1007_lien_dbb_pick_tops.mq5`
- `strategy-seeds/cards/lien-dbb-pick-tops_card.md` (`ea_id=1007`, `status=APPROVED`)
- `docs/ops/QUA-391_CTO_CHECKLIST_PREFILL_2026-04-28.md`

## Implementation Summary

- V5 framework-compliant EA created with:
  - `#include <QM/QM_Common.mqh>`
  - required input groups including dual risk inputs and Friday-close default ON
  - 4-module strategy split:
    - `Strategy_NoTradeFilter`
    - `Strategy_EntrySignal`
    - `Strategy_ManageOpenPosition`
    - `Strategy_ExitSignal`
- Card-driven logic implemented:
  - DBB(20,1σ/2σ) dwell-zone reclaim entries (long/short)
  - asymmetric stop defaults (long 50 pips, short 30 pips)
  - TP1: close half at 1R + move SL to BE
  - TP2: fixed 2R target by default

## Compile Evidence

- Non-strict compile PASS (`0 errors`, `0 warnings`):
  - log: `C:\QM\worktrees\development\framework\build\compile\20260428_104206\QM5_1007_lien_dbb_pick_tops.compile.log`
- Strict wrapper anomaly persists (MetaEditor nonzero exit despite clean log):
  - log reports `Result: 0 errors, 0 warnings`
  - log path: `C:\QM\worktrees\development\framework\build\compile\20260428_104215\QM5_1007_lien_dbb_pick_tops.compile.log`

## Registry Evidence

- Magic reservation present: `10070000` (`ea_id=1007`, slot `0`, symbol `EURUSD.DWX`)
- Collision check output: `NO_DUPLICATE_MAGICS`

## CTO Review Focus

- Confirm card-to-code fidelity for reclaim trigger and dwell-window interpretation.
- Confirm TP2 optional-trail behavior handling is acceptable for v1 (default fixed-2R path is implemented; non-default trail path deferred).
- Confirm strict-wrapper anomaly classification as tooling/runtime issue, not EA compile defect, since strict log itself is clean.
