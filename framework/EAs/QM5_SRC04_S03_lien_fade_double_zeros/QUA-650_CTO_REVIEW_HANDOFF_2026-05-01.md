# QUA-650 CTO Review Handoff ? SRC04_S03 lien-fade-double-zeros

Date: 2026-05-01
Issue: QUA-650
Card: `strategy-seeds/cards/lien-fade-double-zeros_card.md` (`strategy_id: SRC04_S03`, `ea_id: 1009`, `status: APPROVED`)
EA: `framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/QM5_SRC04_S03_lien_fade_double_zeros.mq5`

## Implementation Commits
- `ec81a1d8` ? initial EA add
- `a61fccd9` ? align `qm_ea_id=1009`, strict warning fix
- `9326785a` ? align card header + registry evidence for `ea_id=1009`

## Card/Registry Evidence
- Card header synced: `strategy-seeds/cards/lien-fade-double-zeros_card.md` (`ea_id: 1009`, `status: APPROVED`, `last_updated: 2026-05-01`)
- Registry row: `framework/registry/ea_id_registry.csv`
  - `1009,lien-fade-double-zeros,SRC04_S03,active,Development,2026-05-01`

## Code Line Citations
- EA id input: `...mq5:10`
- Magic via schema: `...mq5:47`
- Risk dual inputs: `...mq5:21`, `...mq5:22`
- Risk mode -> framework init: `...mq5:336-349`
- Friday close input/hook: `...mq5:29`, `...mq5:370`
- No-trade gates: `...mq5:366`, `...mq5:368`, `...mq5:370`
- Entry module: `...mq5:169` (`SRC04_S03_LONG_STOP` @ `...mq5:220`, `SRC04_S03_SHORT_STOP` @ `...mq5:231`)
- Management module: `...mq5:238` (partial at `...mq5:268`, `...mq5:292`)
- Exit module: `...mq5:317`
- Entry execution API: `...mq5:326`

## Compile Evidence (Strict)
Command:
`powershell -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/QM5_SRC04_S03_lien_fade_double_zeros.mq5 -Strict`

Artifacts:
- Log: `C:\QM\repo\framework\build\compile\20260501_074533\QM5_SRC04_S03_lien_fade_double_zeros.compile.log`
- Summary: `D:\QM\reports\compile\20260501_074533\summary.csv`
- EX5: `C:\QM\repo\framework\EAs\QM5_SRC04_S03_lien_fade_double_zeros\QM5_SRC04_S03_lien_fade_double_zeros.ex5`

Excerpt:
`Result: 0 errors, 0 warnings, 2122 ms elapsed, cpu='X64 Regular'`

## Policy
- No pipeline dispatch performed by Development.
- Next action: CTO review-only gate.
