# QM5_12728 Q04 Launch-Fault Retry Requeue - 2026-07-02

Branch: `agents/board-advisor`

## Scope

Mission: grow the certified V5 portfolio book with market-neutral FX
cointegration baskets. The controlling source remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`.

No unbuilt strict 66-pair survivor remains. `QM5_12532` and `QM5_12533` are
already built and not Q02-blocked:

| EA | Current state |
|---|---|
| `QM5_12532` | logical Q02 `PASS`, Q04 `PASS`, Q05 already `pending` |
| `QM5_12533` | logical Q02 `PASS`, latest Q04 completed as strategy `FAIL` with pooled PF net `0.432` |

The fallback path was used: advance an existing forex basket through the
funnel without duplicating an active/pending row.

## Target

`QM5_12728_edgelab-nzdusd-gbpjpy-cointegration`

- Logical basket: `QM5_12728_NZDUSD_GBPJPY_COINTEGRATION_D1`
- Host/timeframe: `NZDUSD.DWX`, `D1`
- Declared basket/history symbols: `NZDUSD.DWX`, `GBPJPY.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`
- Q02 state: `PASS`
- Latest Q04 state before action: `INFRA_FAIL`

## Reason

Latest Q04 work item `6a1a390b-7380-407e-a75d-6c64cec9a63f` completed before
the later launch-fault retry wrapper was in place. Its aggregate showed both
folds failing with Windows exit code `3221225794` and no `summary.json`:

`D:/QM/reports/work_items/6a1a390b-7380-407e-a75d-6c64cec9a63f/QM5_12728/Q04/QM5_12728_NZDUSD_GBPJPY_COINTEGRATION_D1/aggregate.json`

That matches the `0xC0000142` process/DLL initialization failure class now
handled by `framework/scripts/_phase_utils.py::run_with_launch_fault_retry`.

## Queue Action

Duplicate guard before enqueue: `0` pending/active `QM5_12728` Q04 rows.

Farm DB backup:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12728_q04_launchfault_retry_requeue_20260702T184752Z.sqlite`

Command:

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_12728 --phase Q04
```

Result:

- `enqueued`: `true`
- created rows: `0`
- requeued row: `6a1a390b-7380-407e-a75d-6c64cec9a63f`
- post-action status: `pending`
- post-action verdict: `null`
- payload scope: `portfolio_scope=basket`
- payload history clamp: `q04_latest_full_year=2024`

## Validation

```powershell
python -m py_compile framework/scripts/_phase_utils.py framework/scripts/q04_walkforward.py framework/scripts/q05_stress_medium.py framework/scripts/q06_stress_harsh.py framework/scripts/q07_multiseed.py
python -m pytest framework/scripts/tests/test_q05_q07_verdicts.py framework/scripts/tests/test_q04_walkforward.py tools/strategy_farm/tests/test_fx_basket_manifests.py -q
python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_12728_edgelab-nzdusd-gbpjpy-cointegration --verbose
powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12728_edgelab-nzdusd-gbpjpy-cointegration -RepoRoot C:/QM/repo -SkipCompile
```

Results:

- Py compile: `PASS`
- Tests: `48 passed`
- Symbol scope: `BASKET_OK`, 0 violations
- Build check: `PASS`, 0 failures, 16 existing shared-framework advisory warnings
- Build-check report: `D:/QM/reports/framework/21/build_check_20260702_184829.json`
- Build check refreshed the logical basket backtest setfile hash to
  `5cfdae14f9a76fe9fa54931b9f7e60f4bdf608d6823a0a8dbfca2acbde573515`

## Guardrails

No manual MT5 tester run was launched. `T_Live`, AutoTrading, portfolio gate
files, portfolio admission/KPI files, Q08 contribution files, and live deploy
manifests were not touched.
