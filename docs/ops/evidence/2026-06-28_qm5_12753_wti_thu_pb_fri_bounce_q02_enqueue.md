# QM5_12753 WTI Thursday Pullback Friday Bounce Q02 Enqueue Evidence

Date: 2026-06-28
Branch: `agents/board-advisor`

## Scope

- New commodity/energy sleeve: `QM5_12753_wti-thu-pb-fri-bounce`
- Symbol: `XTIUSD.DWX`
- Logic: low-frequency WTI Friday bounce after a material Thursday D1 close-to-close decline
- Source lineage: `strategy-seeds/sources/MEEK-HOELSCHER-WTI-DOW-2023/source.md`
- Card: `strategy-seeds/cards/approved/QM5_12753_wti-thu-pb-fri-bounce_card.md`
- Risk setfile: `framework/EAs/QM5_12753_wti-thu-pb-fri-bounce/sets/QM5_12753_wti-thu-pb-fri-bounce_XTIUSD.DWX_D1_backtest.set`

## Build Artifacts

- EA: `framework/EAs/QM5_12753_wti-thu-pb-fri-bounce/QM5_12753_wti-thu-pb-fri-bounce.mq5`
- Compiled artifact: `framework/EAs/QM5_12753_wti-thu-pb-fri-bounce/QM5_12753_wti-thu-pb-fri-bounce.ex5`
- Build result: `artifacts/qm5_12753_build_result.json`
- Farm build task: `4f56c5dd-5ac4-494f-b225-94aaa8dd1341`
- EX5 SHA256: `CE13005CFFB3AAE758CD00D981E348A82A0F8EBEE430612265B947B2BF4A3C54`

## Validation

- `python framework/scripts/skill_card_schema_lint.py --card strategy-seeds/cards/approved/QM5_12753_wti-thu-pb-fri-bounce_card.md` - PASS
- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_12753_wti-thu-pb-fri-bounce` - PASS
- `python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_12753_wti-thu-pb-fri-bounce --json` - PASS, `SINGLE_SYMBOL_OK`
- `powershell -NoProfile -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12753_wti-thu-pb-fri-bounce -SkipCompile` - PASS, 0 failures
- `python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_12753_wti-thu-pb-fri-bounce` - PASS
- `python tools/strategy_farm/compile_ea.py --ea-label QM5_12753_wti-thu-pb-fri-bounce --force --json --fail-on-error` - COMPILED, 0 errors, 0 warnings

## Q02 Enqueue

`farmctl record-build` accepted the build result and auto-enqueued Q02:

- Work item: `39942434-4def-4363-bde4-eeb38bf81fc2`
- Phase: `Q02`
- Status: `pending`
- Symbol: `XTIUSD.DWX`
- Setfile: `QM5_12753_wti-thu-pb-fri-bounce_XTIUSD.DWX_D1_backtest.set`

No manual backtest was launched by this operator. No `T_Live`, AutoTrading, live manifest, or portfolio gate file was touched.
