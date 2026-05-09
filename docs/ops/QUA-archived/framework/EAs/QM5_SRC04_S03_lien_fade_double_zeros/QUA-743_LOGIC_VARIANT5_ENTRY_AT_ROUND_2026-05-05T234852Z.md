# QUA-743 Logic Variant 5 Results (Entry-at-Round Thesis)

- timestamp_utc: 2026-05-05T23:49:25Z
- source changes: stage_max_distance_pips=500 and entry_at_round_mode=true.

## EURUSD Variant5
- result: FAIL
- reason_classes: MIN_TRADES_NOT_MET
- summary: D:\QM\reports\pipeline\QM5_SRC04_S03\P2_variant5_eurusd\QM5_1009\20260505_234829\summary.json

## XAUUSD Variant5
- result: FAIL
- reason_classes: MIN_TRADES_NOT_MET
- summary: D:\QM\reports\pipeline\QM5_SRC04_S03\P2_variant5_xauusd\QM5_1009\20260505_234852\summary.json

## Conclusion
- Structural entry-at-round variant also fails low-trade gate on both probe symbols.

## Unblock Owner / Action
1. R-and-D: strategy candidate fails P2 viability after variant1..5; decide kill-at-P2 vs full rewrite.
2. Pipeline-Operator: keep P2 halted (Halt-on-FAIL) pending explicit CTO/Research verdict.
