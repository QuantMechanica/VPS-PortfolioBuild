# QM5_12752 EIA WTI WPSR Inside-Breakout Q02 Enqueue Evidence

Date: 2026-06-28
Branch: `agents/board-advisor`

## Scope

- New commodity/energy sleeve: `QM5_12752_eia-wti-wpsr-idbrk`
- Symbol: `XTIUSD.DWX`
- Logic: low-frequency WTI post-EIA Weekly Petroleum Status Report inside-bar breakout
- Source lineage: `strategy-seeds/sources/EIA-WTI-WPSR-IDBRK-2026/source.md`
- Card: `strategy-seeds/cards/approved/QM5_12752_eia-wti-wpsr-idbrk_card.md`
- Risk setfile: `framework/EAs/QM5_12752_eia-wti-wpsr-idbrk/sets/QM5_12752_eia-wti-wpsr-idbrk_XTIUSD.DWX_D1_backtest.set`

## Build Artifacts

- EA: `framework/EAs/QM5_12752_eia-wti-wpsr-idbrk/QM5_12752_eia-wti-wpsr-idbrk.mq5`
- Compiled artifact: `framework/EAs/QM5_12752_eia-wti-wpsr-idbrk/QM5_12752_eia-wti-wpsr-idbrk.ex5`
- Build result: `artifacts/qm5_12752_build_result.json`
- Farm build task: `e2619f5d-e627-4d40-93f3-1902d695b28e`

## Validation

- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_12752_eia-wti-wpsr-idbrk` - PASS
- `python framework/scripts/skill_card_schema_lint.py --card strategy-seeds/cards/approved/QM5_12752_eia-wti-wpsr-idbrk_card.md` - PASS
- `python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_12752_eia-wti-wpsr-idbrk --json --fail-on-leak` - PASS
- `powershell -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12752_eia-wti-wpsr-idbrk/QM5_12752_eia-wti-wpsr-idbrk.mq5 -Strict` - PASS, 0 errors, 0 warnings
- `powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12752_eia-wti-wpsr-idbrk -SkipCompile` - PASS

## Q02 Enqueue

`farmctl record-build` accepted the build result and auto-enqueued Q02:

- Work item: `15391ed9-e3a3-42ba-b4df-5fe10fd9ec7a`
- Phase: `Q02`
- Status: `pending`
- Symbol: `XTIUSD.DWX`
- Setfile: `QM5_12752_eia-wti-wpsr-idbrk_XTIUSD.DWX_D1_backtest.set`

No manual backtest was launched by this operator. No `T_Live`, AutoTrading, live manifest, or portfolio gate file was touched.
