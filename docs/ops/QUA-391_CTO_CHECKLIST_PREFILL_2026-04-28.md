# QUA-391 CTO Checklist Prefill (2026-04-28)

EA: `QM5_1007_lien_dbb_pick_tops`  
Card: `SRC04_S02a` (`lien-dbb-pick-tops`)

## Hard-Gate Checks

- [x] EA path exists: `framework/EAs/QM5_1007_lien_dbb_pick_tops/QM5_1007_lien_dbb_pick_tops.mq5`
- [x] Header Strategy Card ID present (`SRC04_S02a`) and framework include present (`#include <QM/QM_Common.mqh`) at lines 4-7.
- [x] Required input groups present:
  - `QuantMechanica V5 Framework` (lines 9-11)
  - `Risk` with `RISK_PERCENT` + `RISK_FIXED` (lines 13-16)
  - `News` (lines 18-19)
  - `Friday Close` default ON (lines 21-23)
  - `Strategy` (lines 25-32)
- [x] No hardcoded symbol; strategy uses `_Symbol` only.
- [x] No ML imports/libraries; no external market APIs.
- [x] 4-module separation present:
  - No-Trade: `Strategy_NoTradeFilter` (line 178)
  - Entry: `Strategy_EntrySignal` (line 191)
  - Management: `Strategy_ManageOpenPosition` (line 314)
  - Close: `Strategy_ExitSignal` (line 325)
- [x] Friday Close handled via framework gate (`QM_FrameworkHandleFridayClose`) in `OnTick` line 392.
- [x] Model-4 compatibility: no timer-driven execution assumptions; bar-driven logic with `IsNewBar` (line 39) and framework lifecycle.

## Card-to-Code Trace (key rules)

- Entry reclaim conditions (Card §4, PDF pp.103-104): lines 220-256.
- Dwell-zone precondition (Card §4): lines 152-176 + 220-241.
- Asymmetric stop defaults 50/30 pips (Card §4/§8): inputs lines 30-31; stop calc lines 227 and 246.
- TP1 half-close + BE move (Card §5 rule 5): lines 299-312.
- TP2 fixed 2R default (Card §5 rule 6): lines 32, 234, 253.
- No pyramiding/stacking filter (Card §6/§7): lines 184-186.

## Registry / Magic Evidence

- [x] Card header `ea_id` updated to `1007`: `strategy-seeds/cards/lien-dbb-pick-tops_card.md` line 10.
- [x] Card status set `APPROVED`: `strategy-seeds/cards/lien-dbb-pick-tops_card.md` line 12.
- [x] `ea_id` row present in `framework/registry/ea_id_registry.csv` (CTO unblock update).
- [x] Magic row present in `framework/registry/magic_numbers.csv`: `10070000`.
- [x] Collision check evidence:
  - `NO_DUPLICATE_MAGICS`
  - `EA1007_MAGIC=10070000,slot=0,symbol=EURUSD.DWX`

## Compile Evidence

- Non-strict compile PASS (0 errors / 0 warnings):
  - command: `framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_1007_lien_dbb_pick_tops/QM5_1007_lien_dbb_pick_tops.mq5`
  - log: `C:\QM\worktrees\development\framework\build\compile\20260428_104206\QM5_1007_lien_dbb_pick_tops.compile.log`
- Strict compile wrapper returned nonzero, but compile log reports `Result: 0 errors, 0 warnings`:
  - command: `framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_1007_lien_dbb_pick_tops/QM5_1007_lien_dbb_pick_tops.mq5 -Strict`
  - log: `C:\QM\worktrees\development\framework\build\compile\20260428_104215\QM5_1007_lien_dbb_pick_tops.compile.log`

## Review Note

`strategy_enable_tp2_fixed_2r=false` currently disables hard TP placement (`req.tp=0.0`) but no trailing variant is implemented yet; default remains `true` per card default fixed-2R behavior.
