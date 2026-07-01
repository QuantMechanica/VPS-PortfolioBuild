# QM5_12617 Calendar Gate Rework - 2026-07-02

## Scope

Repaired the blocked `QM5_12617_tsmom-12m-fx-usdjpy` build task:

- EA: `QM5_12617`
- Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12617_tsmom-12m-fx-usdjpy.md`
- Task: `a9e19c50-85c0-4d07-bc70-11809fc24c0e`
- Instrument: `USDJPY.DWX`
- Phase target: `Q02`

## Fix

Codex review had blocked the build because monthly rebalance logic used raw
`iTime()` gates. The EA now uses the framework calendar helper:

- `QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0)`
- `QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1)`

Strategy logic, symbol universe, risk mode, and setfile parameters were not
otherwise changed.

## Verification

- `rg -n "iTime\\(|Strategy_MonthKey" framework/EAs/QM5_12617_tsmom-12m-fx-usdjpy/QM5_12617_tsmom-12m-fx-usdjpy.mq5` returned no matches.
- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_12617_tsmom-12m-fx-usdjpy` PASS.
- `pwsh -File framework/scripts/build_check.ps1 -EALabel QM5_12617_tsmom-12m-fx-usdjpy` PASS.
  - Compile: 0 errors, 0 warnings.
  - Build-check report: `D:/QM/reports/framework/21/build_check_20260701_234705.json`.

## Farm State

`farmctl record-build` accepted the refreshed build result:

- Build task status: `done`
- Auto Q02 enqueue: skipped duplicate because existing Q02 row is pending
- Existing Q02 work item: `2f371e85-e807-48e9-ae5a-84cacd4b417e`
- Work item state: `Q02_pending` for `USDJPY.DWX`

No manual MT5 backtest was launched. No `T_Live`, AutoTrading, portfolio gate,
or live manifest files were touched.
