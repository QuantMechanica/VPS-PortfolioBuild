# QUA-743 Logic-Adjusted Variant Rerun (EURUSD + XAUUSD)

- timestamp_utc: 2026-05-05T23:38:25Z
- source_variant: QM5_SRC04_S03_lien_fade_double_zeros.mq5 updated with elaxed_entry_logic=true and stage_max_distance_pips=120 default.

## EURUSD Variant Probe
- result: FAIL
- reason_classes: MIN_TRADES_NOT_MET
- summary: D:\QM\reports\pipeline\QM5_SRC04_S03\P2_variant_eurusd\QM5_1009\20260505_233736\summary.json
- report_dir: D:\QM\reports\pipeline\QM5_SRC04_S03\P2_variant_eurusd\QM5_1009\20260505_233736

## XAUUSD Variant Probe
- result: FAIL
- reason_classes: MIN_TRADES_NOT_MET
- summary: D:\QM\reports\pipeline\QM5_SRC04_S03\P2_variant_xauusd\QM5_1009\20260505_233758\summary.json
- report_dir: D:\QM\reports\pipeline\QM5_SRC04_S03\P2_variant_xauusd\QM5_1009\20260505_233758

## Conclusion
- Entry/session gate relaxation alone did not clear the low/no-trade condition in either probe symbol.

## Unblock Owner / Action
1. R-and-D: move to deeper strategy logic remediation (trigger construction / level-selection mechanics).
2. Pipeline-Operator: keep P2 classified remediation-required after variant test failure.
