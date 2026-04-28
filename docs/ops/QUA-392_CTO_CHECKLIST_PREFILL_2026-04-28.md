# QUA-392 CTO Review Checklist (Prefill)

Issue: QUA-392  
EA: `QM5_1008_lien_dbb_trend_join`  
Card: `SRC04_S02b`

## Identity
- [x] EA path exists: `framework/EAs/QM5_1008_lien_dbb_trend_join/QM5_1008_lien_dbb_trend_join.mq5`
- [x] Card path exists: `strategy-seeds/cards/lien-dbb-trend-join_card.md`
- [x] Registry row exists: `1008,lien-dbb-trend-join,SRC04_S02b`
- [x] Magic row exists: `1008,lien-dbb-trend-join,0,EURUSD.DWX,10080000`

## Hard Rules
- [x] Includes `#include <QM/QM_Common.mqh>`
- [x] Required input groups present
- [x] `RISK_FIXED` and `RISK_PERCENT` present
- [x] Friday close enabled by default
- [x] No hardcoded symbol dependency
- [x] No ML imports
- [x] No external API usage
- [x] Magic via framework resolver path (`QM_FrameworkInit` + `qm_magic_slot_offset`)

## Modularity
- [x] `Strategy_EntrySignal()`
- [x] `Strategy_ManageOpenPosition()`
- [x] `Strategy_ExitSignal()`

## Card Traceability
- [x] Header Strategy Card ID included (`SRC04_S02b`)
- [x] Inline comments include section/page citations for implemented rules

## Compile Evidence
- [x] Compile log shows `Result: 0 errors, 0 warnings`
- [x] Compile log path: `artifacts/qua-392/QM5_1008_compile.log`

## Final CTO Gate
- [ ] Approve Card-vs-EA compliance
- [ ] Dispatch Pipeline-Operator (parent QUA-390 continuation)
