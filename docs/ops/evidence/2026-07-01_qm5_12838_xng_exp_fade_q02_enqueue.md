# QM5_12838 xng-exp-fade Q02 enqueue evidence

Date: 2026-07-01 Europe/Berlin
Branch: `agents/board-advisor`
EA: `QM5_12838_xng-exp-fade`
Build task: `5eb2250b-fdd0-4609-ab2c-7d989b5c91cb`
Q02 work item: `69195601-83fc-4613-bfc2-07d62ed2b380`

## Edge selected

Built a structural low-frequency `XNGUSD.DWX` D1 Henry Hub natural-gas
expiry-window failed-breakout fade. It uses the existing official CME Henry Hub
source packet and is intentionally different from:

- `QM5_12830_xng-exp-brk`: breakout-following expiry-window logic.
- `QM5_12567_cum-rsi2-commodity`: RSI pullback commodity logic.

The card is approved at:
`strategy-seeds/cards/approved/QM5_12838_xng-exp-fade_card.md`.

## Validation

- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_12838_xng-exp-fade`
  - PASS.
- `python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_12838_xng-exp-fade --json`
  - `SINGLE_SYMBOL_OK`.
- `python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_12838_xng-exp-fade`
  - PASS.
- `python tools/strategy_farm/compile_ea.py --ea-label QM5_12838_xng-exp-fade --force --json --fail-on-error`
  - COMPILED, 0 errors, 0 warnings.
  - Compile log: `C:\QM\repo\framework\build\compile\20260630_223821\QM5_12838_xng-exp-fade.compile.log`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12838_xng-exp-fade -Strict -SkipCompile`
  - PASS, 0 failures, 16 shared-framework DWX advisory warnings.
  - Report: `D:\QM\reports\framework\21\build_check_20260630_223838.json`.

## Q02 enqueue

`farmctl build-ea` created build task
`5eb2250b-fdd0-4609-ab2c-7d989b5c91cb`.

`farmctl record-build` recorded
`D:\QM\strategy_farm\artifacts\builds\5eb2250b-fdd0-4609-ab2c-7d989b5c91cb.json`
with `smoke_result=deferred_p2_smoke`, marked the build `done`, and
auto-enqueued Q02:

- Work item: `69195601-83fc-4613-bfc2-07d62ed2b380`
- Phase: `Q02`
- Status: `pending`
- Symbol: `XNGUSD.DWX`
- Timeframe: `D1`
- Setfile: `C:\QM\repo\framework\EAs\QM5_12838_xng-exp-fade\sets\QM5_12838_xng-exp-fade_XNGUSD.DWX_D1_backtest.set`

## Safety boundary

No manual MT5 backtest was launched. No `T_Live`, AutoTrading, T_Live manifest,
portfolio gate, portfolio admission, or portfolio KPI files were touched.
