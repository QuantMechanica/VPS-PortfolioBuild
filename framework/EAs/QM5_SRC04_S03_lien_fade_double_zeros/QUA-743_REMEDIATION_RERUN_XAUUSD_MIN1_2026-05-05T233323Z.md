# QUA-743 Remediation Rerun (XAUUSD, MinTrades=1)

- timestamp_utc: 2026-05-05T23:33:48Z
- command: run_smoke.ps1 (EAId=1009, XAUUSD.DWX, M15, Runs=2, MinTrades=1)
- result: FAIL
- reason_classes: MIN_TRADES_NOT_MET
- summary: D:\QM\reports\pipeline\QM5_SRC04_S03\P2\QM5_1009\20260505_233323\summary.json
- report_dir: D:\QM\reports\pipeline\QM5_SRC04_S03\P2\QM5_1009\20260505_233323
- evidence: D:\QM\reports\framework\22\20260505_233323_QM5_1009_run_smoke.md

## Cross-Asset Confirmation
- EURUSD (FX) with MinTrades=1: FAIL / MIN_TRADES_NOT_MET
- XAUUSD (non-FX) with MinTrades=1: FAIL / MIN_TRADES_NOT_MET
- This confirms cross-asset persistence and rules out threshold-only gating.

## Unblock Owner / Action
1. R-and-D: proceed with entry-logic/session-filter remediation branch.
2. Pipeline-Operator: classify P2 as remediation-required; defer promotion pending logic change evidence.
