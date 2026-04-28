# QUA-303 CTO Review Checklist (Prefill)

Issue: QUA-303  
EA: `QM5_1006_davey_eu_day`  
Card: `SRC01_S02`

## Identity
- [x] EA path exists: `framework/EAs/QM5_1006_davey_eu_day/QM5_1006_davey_eu_day.mq5`
- [x] Card path exists: `strategy-seeds/cards/davey-eu-day_card.md`
- [x] Registry row exists: `1006,davey-eu-day,SRC01_S02`

## Hard Rules
- [x] Includes `#include <QM/QM_Common.mqh>`
- [x] Required input groups present
- [x] `RISK_FIXED` and `RISK_PERCENT` present
- [x] Friday close enabled by default
- [x] No hardcoded symbol dependency
- [x] No ML imports
- [x] No external API usage
- [x] Magic through framework (`QM_FrameworkMagic` resolver path)

## Modularity
- [x] `Strategy_EntrySignal(...)`
- [x] `Strategy_ManageOpenPosition(...)`
- [x] `Strategy_ExitSignal(...)`

## Card Traceability
- [x] Header Strategy Card ID included (`SRC01_S02`)
- [x] Inline comments include section/page citations for implemented rules

## Compile Evidence
- [x] Compile log shows `0 errors, 0 warnings`
- [x] Evidence log path recorded:
  - `C:\QM\worktrees\development\framework\build\compile\20260428_103123\QM5_1006_davey_eu_day.compile.log`

## Final CTO Gate
- [ ] Approve Card-vs-EA compliance
- [ ] Dispatch Pipeline-Operator continuation from parent `QUA-278`

