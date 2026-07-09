# QM5_9184 Logical Basket Q02 Enqueue - 2026-07-09

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate or live-manifest edits.

## Decision

The strict 66-pair FX cointegration scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` still has only two
formal survivors:

| EA | Pair | Current state |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS, Q04 FAIL |

No unbuilt strict-scan survivor remains. Per the mission fallback, this pass
advanced an existing forex cointegration card rather than creating a duplicate
card/build.

## Target

`QM5_9184_jstm-pair-cointegration-fx`

- Logical basket: `QM5_9184_AUDUSD_NZDUSD_COINTEGRATION_D1`
- Host/timeframe: `AUDUSD.DWX`, `D1`
- Basket legs: `AUDUSD.DWX`, `NZDUSD.DWX`
- Manifest: `framework/EAs/QM5_9184_jstm-pair-cointegration-fx/basket_manifest.json`

Prior state was mis-keyed:

- Physical-leg Q02 PASS: `3bb02373-5f50-496e-9558-8590a25837db`, symbol `AUDUSD.DWX`.
- Physical-leg Q04 FAIL: `c5499375-84ca-49e4-9ff2-095e0ede7c7e`, symbol `AUDUSD.DWX`.

The EA had a basket manifest, but no canonical logical basket setfile. That let
the pipeline continue promoting the physical AUDUSD host row instead of the
logical basket row.

## Repo Work

Added:

`framework/EAs/QM5_9184_jstm-pair-cointegration-fx/sets/QM5_9184_jstm-pair-cointegration-fx_QM5_9184_AUDUSD_NZDUSD_COINTEGRATION_D1_D1_backtest.set`

Updated:

- `framework/EAs/QM5_9184_jstm-pair-cointegration-fx/SPEC.md`
- `tools/strategy_farm/tests/test_fx_basket_manifests.py`
- Existing `AUDUSD.DWX` and `NZDUSD.DWX` setfile `build_hash` headers normalized by `build_check`.

## Validation

```powershell
python -m pytest tools/strategy_farm/tests/test_fx_basket_manifests.py -q
python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_9184_jstm-pair-cointegration-fx --verbose
powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_9184_jstm-pair-cointegration-fx -RepoRoot C:/QM/repo -SkipCompile
python framework/scripts/validate_spec_doc.py framework/EAs/QM5_9184_jstm-pair-cointegration-fx
```

Results:

- Manifest tests: PASS, 14 tests.
- Symbol scope: `BASKET_OK`, 0 violations.
- Build check: PASS, 0 failures, 0 warnings.
- Build-check report: `D:/QM/reports/framework/21/build_check_20260709_180439.json`.
- SPEC validation: PASS.

## Queue Action

DB backup before queue mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_9184_logical_q02_20260709T180508Z.sqlite`

Official enqueue path:

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm record-build --task-id 7fd5a807-876a-4d6e-8cf8-68c9b2bfa43f --result-file D:/QM/strategy_farm/artifacts/builds/7fd5a807-876a-4d6e-8cf8-68c9b2bfa43f.attempt_1.json
```

Result:

- Created one Q02 work item: `f10fcf97-b4fb-4286-9188-d51415c8fb60`.
- Symbol: `QM5_9184_AUDUSD_NZDUSD_COINTEGRATION_D1`.
- Status: `pending`.
- Setfile: canonical logical basket setfile above.
- Payload: `portfolio_scope=basket`, host `AUDUSD.DWX`, basket symbols
  `AUDUSD.DWX` and `NZDUSD.DWX`, tester currency `USD`, tester deposit `100000`,
  timeout `450`.
- Skipped both physical leg setfiles with
  `basket_manifest_logical_setfile_preferred`.

No manual MT5 backtest or dispatch tick was launched. Farm health showed 4,881
pending work items and 7 active workers, so execution is left to the paced
worker fleet under the CPU-ceiling discipline.

Machine-readable companion:
`artifacts/qm5_9184_logical_q02_enqueue_20260709T180516Z.json`.

## Guardrails

- No duplicate card or EA was created.
- No duplicate logical Q02 work item was created.
- No `portfolio_admission`, portfolio KPI, or Q08 contribution artifact/code was touched.
- No `T_Live`, deploy manifest, or AutoTrading state was touched.
