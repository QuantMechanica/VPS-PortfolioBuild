# QM5_12599 WTI February Premium Q02 Enqueue

Date: 2026-06-27
Agent: Codex
Branch: `agents/board-advisor`

## Scope

Built a new structural commodity/energy sleeve:

- EA: `QM5_12599_wti-feb-prem`
- Card: `strategy-seeds/cards/approved/QM5_12599_wti-feb-prem_card.md`
- Source packet: `strategy-seeds/sources/GORSKA-WTI-CAL-2015/source.md`
- Symbol/timeframe: `XTIUSD.DWX` / D1
- Logic: broker-calendar February-only long WTI exposure; one D1 bar hold,
  ATR hard stop, month-end/time exits.
- Risk: Q02 backtest setfile uses `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Non-Duplicate Check

This is not a duplicate of the current WTI/XNG/commodity shelf:

- Not the generic weekday sleeves (`QM5_12596`, `QM5_12597`): this is
  February month-of-year logic.
- Not broad EIA WTI demand seasonality (`QM5_12576`): February is neutral
  there and this card has no SMA/ROC monthly-hold confirmation.
- Not WPSR before/after/fade logic (`QM5_12579`, `QM5_12590`, `QM5_12592`).
- Not hurricane, refinery, OPEC, or return-reversal WTI logic
  (`QM5_12591`, `QM5_12593`, `QM5_12598`, `QM5_12594`).
- Not the short-horizon RSI commodity sleeve (`QM5_12567`).

## Build Evidence

- SPEC validation: PASS
  - command: `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_12599_wti-feb-prem`
- Strict compile: PASS
  - command: `powershell -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12599_wti-feb-prem/QM5_12599_wti-feb-prem.mq5 -Strict`
  - errors: 0
  - warnings: 0
  - log: `C:\QM\repo\framework\build\compile\20260627_060752\QM5_12599_wti-feb-prem.compile.log`
- EA-local build check: PASS
  - command: `powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12599_wti-feb-prem -Strict -SkipCompile`
  - failures: 0
  - warnings: 16 existing framework-include DWX advisories
  - report: `D:\QM\reports\framework\21\build_check_20260627_060812.json`

## Q02 Enqueue Evidence

Farm build task:

- `eba2ee32-da67-477d-9cb7-7131b40c01ad`

`farmctl.py record-build` auto-enqueued Q02:

- work item: `c95aa425-2e4a-4141-8b97-931d4acc2089`
- EA: `QM5_12599`
- symbol: `XTIUSD.DWX`
- timeframe: D1
- setfile: `framework/EAs/QM5_12599_wti-feb-prem/sets/QM5_12599_wti-feb-prem_XTIUSD.DWX_D1_backtest.set`
- status after enqueue check: `pending`

No backtest was launched manually. No `T_Live`, AutoTrading, live manifest, or
portfolio gate artifact was touched.
