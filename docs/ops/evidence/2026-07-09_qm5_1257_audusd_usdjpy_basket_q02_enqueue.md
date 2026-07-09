# QM5_1257 AUDUSD/USDJPY Basket Q02 Enqueue

Date: 2026-07-09
Actor: codex-headless-board-advisor
Branch: agents/board-advisor

## Context

- `QM5_12532` and `QM5_12533` were checked first and are not Q02-blocked; both have logical Q02 PASS rows.
- The 66-pair FX scan has no remaining unbuilt strict survivor with allocated `ea_id`.
- Fallback path used: advance existing allocated forex cointegration card `QM5_1257_lemishko-fx-cointpair`.
- Concrete pair selected: slot 12, `AUDUSD.DWX` versus `USDJPY.DWX`.

## Changes

- Added `framework/EAs/QM5_1257_lemishko-fx-cointpair/basket_manifest.json`.
- Added logical RISK_FIXED backtest setfile:
  `framework/EAs/QM5_1257_lemishko-fx-cointpair/sets/QM5_1257_lemishko-fx-cointpair_QM5_1257_AUDUSD_USDJPY_COINTEGRATION_H1_H1_backtest.set`.
- Removed bespoke month-end `iTime` cadence from the EA and replaced it with `QM_CalendarPeriodKey(PERIOD_MN1, ...)`.
- Moved z-score exit refresh behind the EA's existing `QM_IsNewBar()` gate.
- Added missing `symbol` headers to the `QM5_1257` live setfiles so `build_check` no longer rejects the EA metadata.

## Validation

- `powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_1257_lemishko-fx-cointpair -RepoRoot C:/QM/repo -SkipCompile`
  - PASS, 0 failures, 0 warnings
- `powershell -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EALabel QM5_1257_lemishko-fx-cointpair -Strict`
  - PASS, 0 errors, 0 warnings
- `python -m pytest tools/strategy_farm/tests/test_fx_basket_manifests.py tools/strategy_farm/tests/test_basket_work_items.py -q`
  - 27 passed
- `powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_1257_lemishko-fx-cointpair -RepoRoot C:/QM/repo -Strict`
  - PASS, 0 failures, 0 warnings

## Queue Action

Active DB backup:

- `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_1257_audusd_usdjpy_basket_q02_20260709_1227.sqlite`

Command:

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --review-task-id a0571cb2-8ad3-4187-9434-5e8b545d71f7 --phase Q02
```

Result:

- Backtest task: `c329386b-3cce-4002-b08c-b71ccdfc4642`
- Work item: `3e600d24-7536-463e-9c8d-9a57140dbaa1`
- Symbol: `QM5_1257_AUDUSD_USDJPY_COINTEGRATION_H1`
- Setfile: `C:/QM/repo/framework/EAs/QM5_1257_lemishko-fx-cointpair/sets/QM5_1257_lemishko-fx-cointpair_QM5_1257_AUDUSD_USDJPY_COINTEGRATION_H1_H1_backtest.set`
- Payload scope: `portfolio_scope=basket`, `host_symbol=AUDUSD.DWX`, `host_timeframe=H1`, `tester_currency=USD`, `tester_deposit=100000`, Q02 window `2017.01.01` to `2022.12.31`

## Guardrails

- No `T_Live` files or manifest touched.
- No AutoTrading changes.
- No portfolio admission gate files touched.
- No MT5 dispatch was launched; farm was already at CPU ceiling with 7 active workers, so the new item was left pending for the normal dispatcher.
