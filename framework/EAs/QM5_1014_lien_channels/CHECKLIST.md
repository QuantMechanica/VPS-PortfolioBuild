# QM5_1014 CTO Checklist

- [x] Strategy Card ID in header: `SRC04_S08`
- [x] EA ID allocated in registry: `1014,lien-channels,SRC04_S08,active,CTO,2026-05-01`
- [x] V5 framework include present: `<QM/QM_Common.mqh>`
- [x] Magic resolver used: `QM_Magic(qm_ea_id, qm_magic_slot_offset)`
- [x] Required input groups present: Framework, Risk, News, Friday Close, Strategy
- [x] Required strategy functions present:
  - `Strategy_EntrySignal`
  - `Strategy_ManageOpenPosition`
  - `Strategy_ExitSignal`
- [x] Card-cited comments included for key rules
- [x] Friday close enabled by default
- [x] Compile result: PASS, 0 errors, 0 warnings (`compile_one`, run tag `20260509_104204`)

## Artifacts

- `QM5_1014_lien_channels.mq5`
- `QM5_1014_lien_channels.ex5`
- `REVIEW_INPUT.json`
- `CHECKLIST.md`
