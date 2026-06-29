# QM5_12804 XNG TSMOM12M ATR Build And Q02 Enqueue

Date: 2026-06-29
Branch: `agents/board-advisor`

## Edge Selected

Built `QM5_12804_xng-tsmom12m-atr`: a structural low-frequency natural-gas
time-series-momentum sleeve on `XNGUSD.DWX`.

Source lineage is `MOP-TSMOM-2012`, the Moskowitz, Ooi, and Pedersen Journal of
Financial Economics/AQR time-series-momentum paper. Runtime data is limited to
Darwinex MT5 D1 OHLC and broker calendar state.

## Duplicate Review

- XAU/XAG ratio candidates already exist as `QM5_12577_cme-xauxag-ratio` and
  `QM5_12724_cme-xauxag-brk`.
- Existing XNG sleeves include RSI/pullback, four-week reversal, storage,
  inventory, weather, seasonal, LNG/event, and weekend-gap concepts.
- This build is a monthly 12-month own-return sign package with an ATR%
  participation corridor. It has no RSI, no reversal fade, no weather/event
  input, no seasonality, no basket leg, and no metals/index exposure.

## Artifacts

- Card: `strategy-seeds/cards/approved/QM5_12804_xng-tsmom12m-atr_card.md`
- EA: `framework/EAs/QM5_12804_xng-tsmom12m-atr/QM5_12804_xng-tsmom12m-atr.mq5`
- SPEC: `framework/EAs/QM5_12804_xng-tsmom12m-atr/SPEC.md`
- Setfile: `framework/EAs/QM5_12804_xng-tsmom12m-atr/sets/QM5_12804_xng-tsmom12m-atr_XNGUSD.DWX_D1_backtest.set`
- Build result: `artifacts/qm5_12804_build_result.json`

## Validation

- `python framework\scripts\skill_card_schema_lint.py --card strategy-seeds\cards\approved\QM5_12804_xng-tsmom12m-atr_card.md`
  - PASS: status ok, no ML hits, no missing sections.
- `python framework\scripts\validate_spec_doc.py framework\EAs\QM5_12804_xng-tsmom12m-atr`
  - PASS: 1 PASS, 0 FAIL.
- `python tools\strategy_farm\validate_symbol_scope.py --ea-label QM5_12804_xng-tsmom12m-atr --verbose --fail-on-leak`
  - PASS: SINGLE_SYMBOL_OK, n_violations=0.
- `powershell -ExecutionPolicy Bypass -File framework\scripts\compile_one.ps1 -EALabel QM5_12804_xng-tsmom12m-atr -Strict`
  - PASS: 0 errors, 0 warnings, `.ex5` produced.
- `powershell -ExecutionPolicy Bypass -File framework\scripts\build_check.ps1 -EALabel QM5_12804_xng-tsmom12m-atr -Strict -SkipCompile`
  - PASS: 0 failures. Warnings were existing shared-framework lazy-indicator
    advisory findings under `framework/include/QM/`.

## Q02 Enqueue

Command:

```powershell
python tools\strategy_farm\sweep_enqueue_built_eas.py --apply --ea QM5_12804 --queue-ceiling 10000 --max-part2-per-run 0
```

Result:

- `part1 never_tested: enqueued=1 skipped=0`
- Work item: `fa20a750-2e74-4101-bf61-648f5f8b2054`
- Phase: `Q02`
- EA: `QM5_12804`
- Symbol: `XNGUSD.DWX`
- Status: `pending`
- Created: `2026-06-29T19:11:23+00:00`

No backtest was run in this build turn.

## Live Scope

No `T_Live` manifest, AutoTrading setting, deploy manifest, or portfolio gate
file was touched.
