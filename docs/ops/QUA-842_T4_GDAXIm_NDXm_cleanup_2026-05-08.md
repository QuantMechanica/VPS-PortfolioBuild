# QUA-842 T4 GDAXIm/NDXm cleanup verification (2026-05-08)

Issue: QUA-842
Terminal: T4
Scope: post-DL-059 legacy folder cleanup verification with canonical symbols NDX.DWX and GDAXI.DWX.

## Preconditions
- Legacy folders removed: history/ticks NDXm.DWX + GDAXIm.DWX
- Canonical folders present: history/ticks NDX.DWX + GDAXI.DWX

## Smoke executions (sequential)
- Symbol: GDAXI.DWX
- rc: 1
- result: FAIL
- reason_classes: REPORT_MISSING;INCOMPLETE_RUNS
- summary: D:\QM\reports\smoke\qua842\QM5_1001\20260508_115406\summary.json
- report_dir: D:\QM\reports\smoke\qua842\QM5_1001\20260508_115406
- run_evidence: D:\QM\reports\framework\22\20260508_115406_QM5_1001_run_smoke.md
- raw report.htm count: 0 (no exported report)

- Symbol: NDX.DWX
- rc: 1
- result: FAIL
- reason_classes: REPORT_MISSING;INCOMPLETE_RUNS
- summary: D:\QM\reports\smoke\qua842\QM5_1001\20260508_115054\summary.json
- report_dir: D:\QM\reports\smoke\qua842\QM5_1001\20260508_115054
- run_evidence: D:\QM\reports\framework\22\20260508_115054_QM5_1001_run_smoke.md
- raw report.htm count: 0 (no exported report)

## Classification
All runs returned FAIL with REPORT_MISSING;INCOMPLETE_RUNS and report.htm count=0.
Per V5 NO_REPORT rule: this is infrastructure/harness failure, not EA weakness.

## Next action
Block QUA-842 on CTO + DevOps to restore report export path on T4 (terminal tester/report pipeline) and request rerun after fix.
