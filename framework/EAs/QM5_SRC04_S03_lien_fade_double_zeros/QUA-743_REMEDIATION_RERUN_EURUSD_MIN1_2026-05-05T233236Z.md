# QUA-743 Remediation Rerun (EURUSD, MinTrades=1)

- timestamp_utc: 2026-05-05T23:33:00Z
- command: run_smoke.ps1 (EAId=1009, EURUSD.DWX, M15, Runs=2, MinTrades=1)
- result: FAIL
- reason_classes: MIN_TRADES_NOT_MET
- summary: D:\QM\reports\pipeline\QM5_SRC04_S03\P2\QM5_1009\20260505_233236\summary.json
- report_dir: D:\QM\reports\pipeline\QM5_SRC04_S03\P2\QM5_1009\20260505_233236
- evidence: D:\QM\reports\framework\22\20260505_233236_QM5_1009_run_smoke.md

## Interpretation
- Lowering threshold from 5 to 1 did not clear gate; low/no-trade behavior persists.

## Unblock Owner / Action
1. R-and-D: move from threshold tuning to strategy/entry-logic remediation path.
2. Pipeline-Operator: classify as remediation-required (not threshold-only) for P2 decisioning.
