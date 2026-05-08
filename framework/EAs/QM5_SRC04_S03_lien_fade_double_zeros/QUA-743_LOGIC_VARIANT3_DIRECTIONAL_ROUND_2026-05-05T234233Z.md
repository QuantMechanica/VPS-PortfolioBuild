# QUA-743 Logic Variant 3 Results (Directional Round Selection)

- timestamp_utc: 2026-05-05T23:44:24Z
- source changes: directional round selection enabled (long uses round above, short uses round below).

## EURUSD Variant3 Probe
- result: FAIL
- reason_classes: REPORT_MISSING;INCOMPLETE_RUNS
- summary: D:\QM\reports\pipeline\QM5_SRC04_S03\P2_variant3_eurusd\QM5_1009\20260505_234233\summary.json

## XAUUSD Variant3 Probe
- result: FAIL
- reason_classes: MIN_TRADES_NOT_MET
- summary: D:\QM\reports\pipeline\QM5_SRC04_S03\P2_variant3_xauusd\QM5_1009\20260505_234233\summary.json

## Unblock Owner / Action
1. Infra/Tooling: stabilize EURUSD variant3 run export path (REPORT_MISSING/INCOMPLETE_RUNS).
2. R-and-D: directional-round thesis did not clear XAUUSD low-trade behavior; refine trigger thesis further.
3. Pipeline-Operator: hold promotion pending clean EURUSD rerun + updated redesign evidence.
