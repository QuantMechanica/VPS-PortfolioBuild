# QUA-743 Logic Variant 2 (Trigger Construction) Results

- timestamp_utc: 2026-05-05T23:40:56Z
- source changes: tightened trigger construction (	rigger_offset_scale=0.25), longer order lifetime (order_expiration_minutes=240).

## EURUSD Variant2 Probe
- result: FAIL
- reason_classes: MIN_TRADES_NOT_MET
- summary: D:\QM\reports\pipeline\QM5_SRC04_S03\P2_variant2_eurusd\QM5_1009\20260505_233905\summary.json

## XAUUSD Variant2 Probe
- result: FAIL
- reason_classes: REPORT_MISSING;INCOMPLETE_RUNS
- summary: D:\QM\reports\pipeline\QM5_SRC04_S03\P2_variant2_xauusd\QM5_1009\20260505_233905\summary.json

## Unblock Owner / Action
1. R-and-D: trigger-construction variant did not clear EURUSD low-trade state; deeper strategy redesign required.
2. Infra/Tooling: resolve XAUUSD REPORT_MISSING/INCOMPLETE_RUNS in variant2 lane.
3. Pipeline-Operator: hold P2 promotion; classify as remediation-in-progress.
