# QUA-649 Blocked Gate Handoff (2026-05-01)

## Status
QM5_1003 and QM5_1004 compile clean, `.ex5` artifacts exist, registry rows are active, but Stage A cannot be closed due framework-gate and smoke-harness blockers outside EA source scope.

## Verified for target EAs
- `QM5_1003_davey_baseline_3bar`: compile PASS (`0 errors`, `0 warnings`)
- `QM5_1004_davey_es_breakout`: compile PASS (`0 errors`, `0 warnings`)

Primary logs:
- `C:\QM\repo\framework\build\compile\20260501_073529\QM5_1003_davey_baseline_3bar.compile.log`
- `C:\QM\repo\framework\build\compile\20260501_073532\QM5_1004_davey_es_breakout.compile.log`

## Gate defects / infra blockers
1. `build_check.ps1` input-group gate false positives.
   - Repro report: `D:\QM\reports\framework\21\qua649_scoped\build_check_20260501_092806.json`
   - Non-EA files (`.md`, `.json`, `.signal`) are being flagged as missing EA input groups.
   - Failures also label targets as `.ex5` in this gate path, inconsistent with expected `.mq5` source scanning.

2. Smoke harness failure on multiple terminals.
   - T1 summary: `D:\QM\reports\smoke\QM5_1001\20260501_073619\summary.json`
   - T2 summary: `D:\QM\reports\smoke\QM5_1001\20260501_090737\summary.json`
   - Reason classes: `TIMEOUT`, `METATESTER_HUNG`, `INCOMPLETE_RUNS`, `MODEL4_MARKER_REQUIRED`
   - `Terminal=any` path currently rejects smoke job shape (`BACKTEST_REJECTED_NO_SETFILE`) and `run_smoke.ps1` dereferences missing `.terminal`.

## Unblock owner and action
- Owner: CTO / Framework Operations.
- Required action:
  1. Fix `build_check.ps1` input-group file filtering to EA `.mq5` only.
  2. Fix smoke harness/runtime (T1/T2) and `Terminal=any` dispatch contract for smoke jobs.
  3. After fixes, rerun Stage A gates and handoff baseline backtests to Pipeline-Operator.
