# QUA-743 Remediation Rerun (EURUSD, Year=2023, MinTrades=1)

- timestamp_utc: 2026-05-05T23:34:45Z
- command: run_smoke.ps1 (EAId=1009, EURUSD.DWX, Year=2023, M15, Runs=2, MinTrades=1)
- result: FAIL
- reason_classes: MIN_TRADES_NOT_MET
- summary: D:\QM\reports\pipeline\QM5_SRC04_S03\P2\QM5_1009\20260505_233415\summary.json
- report_dir: D:\QM\reports\pipeline\QM5_SRC04_S03\P2\QM5_1009\20260505_233415
- evidence: D:\QM\reports\framework\22\20260505_233415_QM5_1009_run_smoke.md

## Interpretation
- Failure persists with alternate year window (2023), indicating low/no-trade behavior is not isolated to 2024 window.

## Unblock Owner / Action
1. R-and-D: prioritize entry-condition/session-gate logic remediation over further window/threshold probing.
2. Pipeline-Operator: mark current P2 status as remediation-required with cross-window persistence evidence.
