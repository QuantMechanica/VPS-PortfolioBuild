# QM5_13043 XTI Residual Fuel Momentum Q02 Enqueue Evidence

Date: 2026-07-07

## Build

- EA: `QM5_13043_xti-resfuel-mom`
- Source ID: `EIA-XTI-RESFUEL-MOM-2026`
- Symbol/timeframe: `XTIUSD.DWX` / D1
- Setfile: `framework/EAs/QM5_13043_xti-resfuel-mom/sets/QM5_13043_xti-resfuel-mom_XTIUSD.DWX_D1_backtest.set`
- Risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`

## Source Boundary

The card uses EIA residual fuel oil sources as structural lineage:

- EIA WPSR table/figure family includes residual fuel oil stocks by PAD District.
- EIA residual fuel oil stocks table is the official data family.
- EIA glossary identifies No. 6/bunker fuel uses including vessel bunkering, electric power, space heating, and industrial uses.
- EIA Today in Energy documents late-2021 residual fuel demand pressure tied mainly to bunker fuel.

This is a distinct product-line sleeve from `QM5_13042` distillate pressure,
`QM5_13039` gasoline pressure, crude inventory, Cushing/DPR/SPR,
days-of-supply, import/export, refinery, COT, rig-count, XAU/XAG, XNG, and
index logic.

## Checks

- `python framework\scripts\skill_card_schema_lint.py --card strategy-seeds\cards\approved\QM5_13043_xti-resfuel-mom_card.md`: PASS
- `python framework\scripts\skill_g0_card_lint.py --card strategy-seeds\cards\approved\QM5_13043_xti-resfuel-mom_card.md`: PASS
- `python framework\scripts\validate_spec_doc.py framework\EAs\QM5_13043_xti-resfuel-mom`: PASS
- `python tools\strategy_farm\validate_symbol_scope.py --ea-label QM5_13043_xti-resfuel-mom --json`: `SINGLE_SYMBOL_OK`
- `python tools\strategy_farm\validate_build_guardrails.py framework\EAs\QM5_13043_xti-resfuel-mom`: PASS
- `python tools\strategy_farm\compile_ea.py --ea-label QM5_13043_xti-resfuel-mom --force --json --fail-on-error`: COMPILED, 0 errors, 0 warnings
- `powershell -ExecutionPolicy Bypass -File framework\scripts\build_check.ps1 -EALabel QM5_13043_xti-resfuel-mom -Strict -SkipCompile`: PASS, 0 failures, 0 warnings

`framework\scripts\update_magic_resolver.py` regenerated the resolver and only
reported pre-existing missing-dir warnings for old magic rows `1001`, `1015`,
and `1016`.

## Q02

Command:

```powershell
python tools\strategy_farm\sweep_enqueue_built_eas.py --apply --ea QM5_13043 --queue-ceiling 10000 --max-part2-per-run 0
```

Result:

- Q02 work item: `d0357a89-8a07-41d1-ae6d-5aa3c41526f7`
- Status: `pending`
- Symbol: `XTIUSD.DWX`
- Created: `2026-07-07T17:25:40+00:00`

## Guardrails

No local backtest/smoke run was executed. No `T_Live`, AutoTrading, deploy
manifest, or portfolio gate files were touched.
