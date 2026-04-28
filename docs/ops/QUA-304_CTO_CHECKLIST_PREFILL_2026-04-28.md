# QUA-304 CTO Review Checklist (Prefill)

Issue: QUA-304
EA: `QM5_1003_davey_baseline_3bar`
Card: `SRC01_S03`

## Identity
- [x] EA path exists: `framework/EAs/QM5_1003_davey_baseline_3bar/QM5_1003_davey_baseline_3bar.mq5`
- [x] Card path exists: `strategy-seeds/cards/davey-baseline-3bar_card.md`
- [x] Registry row exists: `1003,davey-baseline-3bar,SRC01_S03`

## Hard Rules
- [x] Includes `#include <QM/QM_Common.mqh>`
- [x] Required input groups present
- [x] `RISK_FIXED` and `RISK_PERCENT` present
- [x] Friday close enabled by default
- [x] No hardcoded symbol dependency
- [x] No ML imports
- [x] No external API usage
- [x] Magic through framework (`QM_FrameworkMagic` / resolver path)

## Modularity
- [x] `Strategy_EntrySignal(...)`
- [x] `Strategy_ManageOpenPosition(...)`
- [x] `Strategy_ExitSignal(...)`

## Card Traceability
- [x] Header Strategy Card ID included (`SRC01_S03`)
- [x] Inline comments include section/page citations for implemented rules

## Compile Evidence
- [x] Compile log shows `0 errors, 0 warnings`
- [x] Evidence log path recorded in handoff docs
- [ ] CTO to decide disposition of wrapper `METAEDITOR_NONZERO_EXIT` anomaly

## Final CTO Gate
- [ ] Approve Card-vs-EA compliance
- [ ] Dispatch Pipeline-Operator (parent QUA-279 continuation)
