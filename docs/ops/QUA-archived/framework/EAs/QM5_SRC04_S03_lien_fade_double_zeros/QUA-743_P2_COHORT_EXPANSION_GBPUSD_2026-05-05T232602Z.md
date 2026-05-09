# QUA-743 P2 Cohort Expansion Probe (GBPUSD)

- timestamp_utc: 2026-05-05T23:28:08Z
- command: run_smoke.ps1 (EAId=1009, GBPUSD.DWX, M15, Runs=2, MinTrades=5)
- result: FAIL
- reason_classes: REPORT_MISSING;INCOMPLETE_RUNS
- summary: D:\QM\reports\pipeline\QM5_SRC04_S03\P2\QM5_1009\20260505_232602\summary.json
- report_dir: D:\QM\reports\pipeline\QM5_SRC04_S03\P2\QM5_1009\20260505_232602
- evidence: D:\QM\reports\framework\22\20260505_232602_QM5_1009_run_smoke.md

## Impact
- Cohort expansion surfaced infrastructure/reporting stability issues in addition to low-trade behavior.

## Unblock Owner / Action
1. Infra/Tooling: fix REPORT_MISSING / INCOMPLETE_RUNS export path or terminal/metatester stability for T1.
2. Pipeline-Operator: rerun GBPUSD probe after infra fix and reclassify P2 readiness.
3. R-and-D: continue low-trade remediation path in parallel for EURUSD probes.
