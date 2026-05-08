# QUA-743 Variant3 EURUSD Retry

- timestamp_utc: 2026-05-05T23:45:15Z
- command: run_smoke.ps1 (EAId=1009, EURUSD.DWX, M15, MinTrades=1, variant3 code)
- result: FAIL
- reason_classes: MIN_TRADES_NOT_MET
- summary: D:\QM\reports\pipeline\QM5_SRC04_S03\P2_variant3_eurusd\QM5_1009\20260505_234449\summary.json
- report_dir: D:\QM\reports\pipeline\QM5_SRC04_S03\P2_variant3_eurusd\QM5_1009\20260505_234449
- evidence: D:\QM\reports\framework\22\20260505_234449_QM5_1009_run_smoke.md

## Delta vs prior variant3 EURUSD run
- Prior: REPORT_MISSING;INCOMPLETE_RUNS
- Current: MIN_TRADES_NOT_MET
- Interpretation: infra instability cleared; low-trade behavior remains.

## Unblock Owner / Action
1. R-and-D: continue next trigger-thesis redesign iteration (beyond directional-round variant).
2. Pipeline-Operator: maintain remediation-required status for P2.
