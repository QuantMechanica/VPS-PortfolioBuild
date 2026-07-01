# QM5_12781 JPY Account Q02 Requeue Evidence

Date: 2026-07-01
Branch: `agents/board-advisor`
EA: `QM5_12781_edgelab-usdjpy-audjpy-cointegration`

## Selection

- The 2026-06-09 FX cointegration scan left no unbuilt positive-hedge candidate from the ranked 66-pair rerun; all 29 positive-hedge scan pairs were already represented by built `QM5_*` basket EAs.
- `QM5_12532` and `QM5_12533` were checked first and were not Q02-blocked: both already had Q02 PASS rows.
- Fallback target selected: `QM5_12781`, the most advanced existing FX cointegration basket with Q02/Q04/Q05/Q06 evidence and a latest Q07 `INFRA_FAIL`.

## Root Cause

Latest Q07 work item:

- `38226031-b41f-4f03-ab86-d1697ca5e203`
- aggregate: `D:/QM/reports/work_items/38226031-b41f-4f03-ab86-d1697ca5e203/QM5_12781/Q07/QM5_12781_USDJPY_AUDJPY_COINTEGRATION_D1/aggregate.json`
- verdict reason: `seeds_invalid_evidence:[(99, 'invalid_summary:INCOMPLETE_RUNS,REPORT_MISSING'), (7, 'invalid_summary:INCOMPLETE_RUNS,REPORT_MISSING')]`

Seed summaries for 99 and 7 showed MT5 fetching bare `USDJPY` conversion history and then failing history synchronization before report completion. The basket itself trades `USDJPY.DWX` and `AUDJPY.DWX`; under USD tester accounting MT5 still needed bare `USDJPY` for conversion. Since both traded legs are JPY-quoted, switching the tester account to JPY removes that conversion-history dependency.

## Change

- `basket_manifest.json`: `tester_currency=JPY`, `tester_deposit=15000000`.
- All `QM5_12781` backtest/Q05/Q06 setfiles: `RISK_FIXED=150000`, `RISK_PERCENT=0`.
- Strategy card and SPEC copies updated to document JPY tester accounting and the repaired Q02 handoff.
- Added a manifest regression test for `QM5_12781`.

No EA strategy logic, portfolio gate code, T_Live manifest, or AutoTrading state was touched.

## Validation

- `python -m pytest tools/strategy_farm/tests/test_fx_basket_manifests.py -q`
  - PASS: `5 passed in 0.06s`
- `python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_12781_edgelab-usdjpy-audjpy-cointegration --verbose`
  - PASS: `BASKET_OK`, `n_violations=0`
- `powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12781_edgelab-usdjpy-audjpy-cointegration -RepoRoot C:/QM/repo -SkipCompile`
  - PASS: `build_check.result=PASS`, `failures=0`, `warnings=16`
  - report: `D:/QM/reports/framework/21/build_check_20260701_125834.json`

## Queue Action

Farm DB backup before enqueue:

- `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12781_jpy_account_q02_requeue_20260701T145510Z.sqlite`

The cascade enqueue command rejects Q02 by design, so Q02 was enqueued through the existing supported `APPROVE_FOR_BACKTEST` review-task path:

- review task: `b92031f7-23eb-4b49-b71d-62ee20607184`
- Q02 task: `ccd2d5bd-1d18-4c42-a888-63dadfe9b6a3`
- Q02 work item: `54c04ac1-e5f7-4060-ae60-6814cb930fd5`
- status: `pending`
- symbol: `QM5_12781_USDJPY_AUDJPY_COINTEGRATION_D1`
- payload tester account: `tester_currency=JPY`, `tester_deposit=15000000`

No manual MT5 backtest was launched from this session.
