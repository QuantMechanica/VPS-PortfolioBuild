# QUA-406 Unblock Payload Template (CEO + CTO)

Issue: `QUA-406`  
Mapped strategy: `SRC04_S07`  
Slug: `lien-20day-breakout`

Purpose: one-shot unblock instructions so Development can start EA implementation immediately after governance updates land.

## 1) Card Header Update (CEO/Research Owner)
Target file:
- `strategy-seeds/cards/lien-20day-breakout_card.md`

Required edits in card header:
1. Set `status: APPROVED`
2. Replace `ea_id: TBD` with allocated numeric `ea_id`
3. Set/confirm `g0_issue` reference for approval trail

## 2) Registry Allocation Row (CTO)
Target file:
- `framework/registry/ea_id_registry.csv`

Append one row (values to finalize at allocation time):
```csv
<ea_id>,lien-20day-breakout,SRC04_S07,active,CTO,2026-04-28
```

Constraints:
1. `ea_id` must be unique in registry.
2. `ea_id` in card header and registry must match exactly.
3. Magic derivation will be framework-native via `QM_Magic(ea_id, slot)` in EA code.

## 3) Sync Into Development Checkout
Required in `C:\QM\worktrees\development` before coding:
1. Updated card file with `APPROVED` + concrete `ea_id`
2. Updated registry row for `SRC04_S07`

## 4) Immediate Development Action After Sync
Development will implement:
- `framework/EAs/QM5_<ea_id>_lien_20day_breakout/QM5_<ea_id>_lien_20day_breakout.mq5`

Implementation contract to be applied at once:
1. V5 framework include (`<QM/QM_Common.mqh>`)
2. 4-module boundary functions:
   - `Strategy_EntrySignal`
   - `Strategy_ManageOpenPosition`
   - `Strategy_ExitSignal`
3. Required input groups:
   - QuantMechanica V5 Framework
   - Risk
   - News
   - Friday Close
   - Strategy
4. Both risk modes exposed (`RISK_FIXED`, `RISK_PERCENT`)
5. Friday Close enabled by default unless card explicitly waives
6. No hardcoded symbols, no ML imports, no external API calls
7. Inline comments citing card sections for each implemented rule

## 5) CTO Gate Reminder
After implementation: CTO EA-vs-Card review must pass on `QUA-406` before any Pipeline-Operator dispatch.
