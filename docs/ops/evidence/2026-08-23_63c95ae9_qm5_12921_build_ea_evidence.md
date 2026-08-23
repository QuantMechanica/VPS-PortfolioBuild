# QM5_12921 build task evidence — 2026-08-23

- Task ID: `63c95ae9-d593-403a-928b-c51ac9848a1b`
- EA ID: `QM5_12921`
- EA Label: `QM5_12921_qp-january-barometer-card`
- Task Type: `build_ea`
- Assigned Agent: `gemini`
- Located Card: `D:/QM/strategy_farm/artifacts/cards_rejected/QM5_12921_qp-january-barometer-card.md`
- Target EA Directory: `C:/QM/repo/framework/EAs/QM5_12921_qp-january-barometer-card`

## Summary & Card Status

1. **Card Status**: There is no approved strategy card of record for QM5_12921 in `cards_approved`. The only card found resides in `cards_rejected`.
2. Per company hard rules and orchestrator guidance, building or advancing an EA without an approved G0 card inverts pipeline sequence. The card must be approved upstream before build acceptance.
3. Prior orchestrator review `d38222fd-9878-4d72-b1cf-c56cc03cc369` placed this task in `RECYCLE` on 2026-08-21 noting the missing approved card.

## Focused Verification

- `validate_build_guardrails.py`: PASS (1 file checked, `qm_news_stale_max_hours=336`, 0 findings).
- `validate_spec_doc.py`: PASS (`QM5_12921_qp-january-barometer-card` SPEC compliant).
- `validate_symbol_scope.py --fail-on-leak`: PASS (`SINGLE_SYMBOL_OK`, 0 violations).
- Registry check: `magic_numbers.csv` has active rows for `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `UK100.DWX` (slots 0..4, magic `129210000..129210004`).
- Setfiles: All 5 backtest setfiles maintain `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.

## Disposition

Task is submitted to `REVIEW` awaiting Codex review and upstream resolution of G0 card status.
