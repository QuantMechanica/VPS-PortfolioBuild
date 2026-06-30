# QM5_12839 wti-exp-fade Q02 enqueue evidence

Date: 2026-07-01 Europe/Berlin
Branch: `agents/board-advisor`
EA: `QM5_12839_wti-exp-fade`
Build task: `67e682a8-530f-488c-b7ea-44518b9f7f96`
Q02 work item: `2ecee84f-2e19-4f3e-9e2f-3cd4c3fece7e`

## Edge selected

Built a structural low-frequency `XTIUSD.DWX` D1 WTI CME expiry-window
failed-breakout fade. It uses the existing official CME WTI source packet and
is intentionally different from:

- `QM5_12600_cme-wti-exp-brk`: breakout-following expiry-window logic.
- `QM5_12743_wti-postroll-fade`: post-roll pressure-relief fade.
- `QM5_12567_cum-rsi2-commodity`: RSI pullback commodity logic.
- XAU/XAG, XNG, and cross-commodity basket sleeves.

The card is approved at:
`strategy-seeds/cards/approved/QM5_12839_wti-exp-fade_card.md`.

## Validation

- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_12839_wti-exp-fade`
  - PASS.
- `python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_12839_wti-exp-fade --json`
  - `SINGLE_SYMBOL_OK`.
- `python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_12839_wti-exp-fade`
  - PASS.
- `python tools/strategy_farm/compile_ea.py --ea-label QM5_12839_wti-exp-fade --force --json --fail-on-error`
  - COMPILED, 0 errors, 0 warnings.
  - Compile log: `C:\QM\repo\framework\build\compile\20260630_233803\QM5_12839_wti-exp-fade.compile.log`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12839_wti-exp-fade -Strict -SkipCompile`
  - PASS, 0 failures, 16 shared-framework DWX advisory warnings.
  - Report: `D:\QM\reports\framework\21\build_check_20260630_233817.json`.

## Q02 enqueue

`farmctl build-ea` created build task
`67e682a8-530f-488c-b7ea-44518b9f7f96`.

`farmctl record-build` recorded `artifacts/qm5_12839_build_result.json` with
`smoke_result=deferred_p2_smoke`, marked the build `done`, and auto-enqueued
Q02:

- Work item: `2ecee84f-2e19-4f3e-9e2f-3cd4c3fece7e`
- Phase: `Q02`
- Status: `pending`
- Symbol: `XTIUSD.DWX`
- Timeframe: `D1`
- Setfile: `C:\QM\repo\framework\EAs\QM5_12839_wti-exp-fade\sets\QM5_12839_wti-exp-fade_XTIUSD.DWX_D1_backtest.set`

## Safety boundary

No manual MT5 backtest was launched. No `T_Live`, AutoTrading, T_Live manifest,
portfolio gate, portfolio admission, or portfolio KPI files were touched.
