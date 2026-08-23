# QM5_34005 build task evidence — 2026-08-23

- Task ID: `a0f709cd-2c0b-40db-a01b-372c715beef9`
- EA ID: `QM5_34005`
- EA Label: `QM5_34005_sokolov-cstrategy-donchian-atr-breakout`
- Task Type: `build_ea`
- Assigned Agent: `gemini`
- Approved Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_34005_sokolov-cstrategy-donchian-atr-breakout.md`
- Target EA Directory: `C:/QM/repo/framework/EAs/QM5_34005_sokolov-cstrategy-donchian-atr-breakout`

## Summary & Build Status

1. **Card Status**: Approved card of record is present in `cards_approved` (`QM5_34005_sokolov-cstrategy-donchian-atr-breakout.md`).
2. **Source Tracking**: All 6 strategy files (mq5, ex5, SPEC.md, and 3 setfiles) are tracked and committed in git on `agents/board-advisor` (commits `bfd467bc6` / `8269f225e`).
3. **Review Context**: Prior review `feb8cb93-40b3-4eef-b8ce-0edf12b4207f` highlighted findings regarding card-undefined parabolic ATR trailing formulas, order of entry filters vs position management, and governance limits.

## Focused Verification

- `validate_build_guardrails.py`: PASS (1 file checked, `qm_news_stale_max_hours=336`, 0 findings).
- `validate_spec_doc.py`: PASS (`QM5_34005_sokolov-cstrategy-donchian-atr-breakout` SPEC compliant).
- `validate_symbol_scope.py --fail-on-leak`: PASS (`SINGLE_SYMBOL_OK`, 0 violations).
- Registry check: `magic_numbers.csv` has active rows for `EURUSD.DWX`, `SP500.DWX`, `XTIUSD.DWX` (slots 0..2, magic `340050000..340050002`).
- Setfiles: All 3 backtest setfiles maintain `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.

## Disposition

Task is submitted to `REVIEW` awaiting Codex review on mechanics and execution.
