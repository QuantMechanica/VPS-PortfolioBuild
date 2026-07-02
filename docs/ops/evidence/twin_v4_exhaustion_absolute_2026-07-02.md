# T-WIN v4 Exhaustion Absolute Gate Evidence

Date: 2026-07-02
EA: `QM5_12821_twin-csm-basket`
Task: `QM5_12821`

## Change

The CSM module now exposes the pre-normalization aggregate explicitly:

- `QM_CSMReading.raw_strength[]`
- `QM_CSM_RawStrength(reading, currency_idx)`
- `QM_CSM_IsExhaustedAbsolute(reading, currency_idx, threshold_abs_pct)`

Existing normalized outputs are unchanged. `strength[]` remains the existing raw aggregate used by current probability and ranking logic, and `normalized[]` still min-max scales to +/-100. The new absolute exhaustion helper compares `MathAbs(raw_strength[currency]) >= threshold_abs_pct`.

The EA has the input-gated exhaustion mode:

- `strategy_exhaustion_mode=0`: legacy normalized gate via `strategy_exhaustion_norm`
- `strategy_exhaustion_mode=1`: absolute raw aggregate percent gate via `strategy_exhaustion_abs_pct`

The v4 setfile is present at:

`framework/EAs/QM5_12821_twin-csm-basket/sets/QM5_12821_twin-csm-basket_FX8_TWIN_CSM_BASKET_H1_H1_backtest_v4exh.set`

with:

```text
strategy_exhaustion_mode=1
strategy_exhaustion_abs_pct=0.60
```

No entry sessions, pullback, probability, cluster, sizing, DL-081 stop, news gate, or `OnTick` ordering were changed.

## Include Consumers

Direct `QM_CurrencyStrength.mqh` EA consumers found by grep:

- `framework/EAs/QM5_12821_twin-csm-basket/QM5_12821_twin-csm-basket.mq5`
- `framework/EAs/_tests/QM_TWIN_Module_tests/QM_TWIN_Module_tests.mq5`

Indirect CSM include paths through `QM_MTFCoherence.mqh` and `QM_BasketBuilder.mqh` resolve to the same two EA consumers in this repo.

## Validation

Main EA compile:

```powershell
python tools/strategy_farm/compile_ea.py --ea-label QM5_12821_twin-csm-basket --force --json --fail-on-error
```

Result:

- verdict: `COMPILED`
- errors: `0`
- warnings: `0`
- symbol scope: `BASKET_OK`
- ex5: `C:\QM\repo\framework\EAs\QM5_12821_twin-csm-basket\QM5_12821_twin-csm-basket.ex5`
- log: `C:\QM\repo\framework\build\compile\20260702_143101\QM5_12821_twin-csm-basket.compile.log`

Compile log tail:

```text
Result: 0 errors, 0 warnings, 3334 ms elapsed, cpu='X64 Regular'
```

Build guardrails:

```powershell
python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_12821_twin-csm-basket
```

Result:

- verdict: `PASS`
- files checked: `33`
- findings: `[]`

Additional strict compile for another direct include consumer:

```powershell
pwsh.exe -NoProfile -File framework\scripts\compile_one.ps1 -EAPath framework\EAs\_tests\QM_TWIN_Module_tests\QM_TWIN_Module_tests.mq5 -EALabel QM_TWIN_Module_tests -Strict
```

Result:

- result: `PASS`
- reason: `OK`
- strict: `True`
- errors: `0`
- warnings: `0`
- log: `C:\QM\repo\framework\build\compile\20260702_143116\QM_TWIN_Module_tests.compile.log`

Strict compile log tail:

```text
Result: 0 errors, 0 warnings, 938 ms elapsed, cpu='X64 Regular'
```

## Operational Constraint

Validation used compile-only tooling. No `terminal64.exe` backtest, factory run, queue enqueue, or T5 process interaction was performed.
