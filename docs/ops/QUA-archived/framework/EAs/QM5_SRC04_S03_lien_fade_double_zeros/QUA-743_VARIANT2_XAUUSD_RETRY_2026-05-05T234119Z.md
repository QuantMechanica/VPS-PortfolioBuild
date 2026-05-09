# QUA-743 Variant2 XAUUSD Retry

- timestamp_utc: 2026-05-05T23:41:46Z
- command: run_smoke.ps1 (EAId=1009, XAUUSD.DWX, M15, MinTrades=1, variant2 code)
- result: FAIL
- reason_classes: MIN_TRADES_NOT_MET
- summary: D:\QM\reports\pipeline\QM5_SRC04_S03\P2_variant2_xauusd\QM5_1009\20260505_234119\summary.json
- report_dir: D:\QM\reports\pipeline\QM5_SRC04_S03\P2_variant2_xauusd\QM5_1009\20260505_234119
- evidence: D:\QM\reports\framework\22\20260505_234119_QM5_1009_run_smoke.md

## Delta vs prior variant2 XAUUSD run
- Prior: REPORT_MISSING;INCOMPLETE_RUNS
- Current: MIN_TRADES_NOT_MET
- Interpretation: infra/export instability cleared on retry; remaining blocker is strategy low-trade behavior.

## Unblock Owner / Action
1. R-and-D: deeper strategy redesign required (entry model/trigger thesis), not infra fix.
2. Pipeline-Operator: maintain remediation-required status with clean reproducible low-trade evidence.
