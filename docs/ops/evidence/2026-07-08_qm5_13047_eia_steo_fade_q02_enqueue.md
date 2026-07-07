# QM5_13047 EIA STEO Fade Q02 Enqueue Evidence

Date: 2026-07-08

## Build

- EA: `QM5_13047_eia-steo-fade`
- Source ID: `EIA-STEO-XTI-FADE-2026`
- Symbol/timeframe: `XTIUSD.DWX` / D1
- Setfile: `framework/EAs/QM5_13047_eia-steo-fade/sets/QM5_13047_eia-steo-fade_XTIUSD.DWX_D1_backtest.set`
- Risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`

## Source Boundary

The card uses official EIA Short-Term Energy Outlook sources as structural
lineage:

- EIA STEO report hub.
- EIA STEO release schedule.
- EIA STEO global oil-market context.

The EA reads no EIA data, report contents, CSV, API, futures curve, inventory
feed, analyst forecast, or external data at runtime. It is a Darwinex-native
`XTIUSD.DWX` D1 OHLC proxy for failed range probes around the deterministic
monthly STEO release window.

This is distinct from `QM5_12992_eia-steo-brk`: that EA follows STEO proxy
closing breakouts; this EA fades failed outside probes that close back inside
the prior D1 context range.

## Checks

- `python framework\scripts\skill_card_schema_lint.py --card strategy-seeds\cards\eia-steo-fade_card.md`: PASS
- `python framework\scripts\skill_g0_card_lint.py --card strategy-seeds\cards\eia-steo-fade_card.md`: PASS
- `python framework\scripts\skill_card_schema_lint.py --card strategy-seeds\cards\approved\QM5_13047_eia-steo-fade_card.md`: PASS
- `python framework\scripts\skill_g0_card_lint.py --card strategy-seeds\cards\approved\QM5_13047_eia-steo-fade_card.md`: PASS
- `python framework\scripts\validate_spec_doc.py framework\EAs\QM5_13047_eia-steo-fade`: PASS
- `python tools\strategy_farm\validate_symbol_scope.py --ea-label QM5_13047_eia-steo-fade --json`: `SINGLE_SYMBOL_OK`
- `python tools\strategy_farm\validate_build_guardrails.py framework\EAs\QM5_13047_eia-steo-fade`: PASS
- `python tools\strategy_farm\compile_ea.py --ea-label QM5_13047_eia-steo-fade --force --json --fail-on-error`: COMPILED, 0 errors, 0 warnings
- `powershell -ExecutionPolicy Bypass -File framework\scripts\build_check.ps1 -EALabel QM5_13047_eia-steo-fade -SkipCompile`: PASS, 0 failures, 0 warnings

`framework\scripts\update_magic_resolver.py` regenerated the resolver and only
reported pre-existing missing-dir warnings for old magic rows `1001`, `1015`,
and `1016`.

## Q02

Command:

```powershell
python tools\strategy_farm\sweep_enqueue_built_eas.py --apply --ea QM5_13047 --queue-ceiling 10000 --max-part2-per-run 0
```

Result:

- Q02 work item: `0b20c287-1481-4783-94c1-b3ff23c37bbf`
- Status: `pending`
- Symbol: `XTIUSD.DWX`
- Created: `2026-07-07T22:25:58+00:00`

## Guardrails

No local backtest/smoke run was executed. No `T_Live`, AutoTrading, deploy
manifest, or portfolio gate files were touched.
