# QUA-743 Logic Variant 4 Results (Half-Step Trigger Grid)

- timestamp_utc: 2026-05-05T23:46:50Z
- source changes: use_half_step_levels=true to use denser round-grid for trigger construction.

## EURUSD Variant4
- result: FAIL
- reason_classes: MIN_TRADES_NOT_MET
- summary: D:\QM\reports\pipeline\QM5_SRC04_S03\P2_variant4_eurusd\QM5_1009\20260505_234554\summary.json

## XAUUSD Variant4
- result: FAIL
- reason_classes: MIN_TRADES_NOT_MET
- summary: D:\QM\reports\pipeline\QM5_SRC04_S03\P2_variant4_xauusd\QM5_1009\20260505_234616\summary.json

## Conclusion
- Variant4 trigger-thesis change did not resolve low-trade behavior on either probe symbol.

## Unblock Owner / Action
1. R-and-D: escalate to structural strategy redesign (entry thesis mismatch), not incremental trigger tuning.
2. Pipeline-Operator: maintain P2 remediation-required state with variant1..4 failure evidence.
