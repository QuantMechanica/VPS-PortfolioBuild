# QM5_1056 Filter-Variant Rerun

Date: 2026-05-22
Status: REVIEW_READY
Router task: `af7c5668-a15d-4bb8-af93-80ab999e9f7f`
Input triage: `docs/ops/FAILED_EA_FILTER_TRIAGE_2026-05-22.md`

## Scope

The triage task identified exactly one qualifying failed EA:

- `QM5_1056` / `moskowitz-tsmom-multiasset`
- Declared filter: crisis regime/volatility filter
- Thesis: flatten TSMOM exposure during bear-regime plus volatility-expansion crisis states to target Q08 crisis-slice failure.

No other failed EAs qualified; no blanket filter rerun was started.

## Built Variant

Updated EA:

- `framework/EAs/QM5_1056_moskowitz-tsmom-multiasset/QM5_1056_moskowitz-tsmom-multiasset.mq5`

Variant setfile:

- `framework/EAs/QM5_1056_moskowitz-tsmom-multiasset/sets/QM5_1056_moskowitz-tsmom-multiasset_NDX.DWX_D1_backtest_filter_crisis.set`

The filter is off by default in code. The `_filter_crisis` setfile is the only rerun variant with:

- `qm_filter_regime_enabled=true`
- `qm_filter_regime_lookback_bars=63`
- `qm_filter_regime_bull_return_pct=8.0`
- `qm_filter_regime_bear_return_pct=8.0`
- `qm_filter_volatility_enabled=true`
- `qm_filter_volatility_atr_period=20`
- `qm_filter_volatility_lookback_bars=63`
- `qm_filter_volatility_compression_ratio=0.75`
- `qm_filter_volatility_expansion_ratio=1.50`

## Pipeline Rerun

Enqueued one Q02/P2 work item for the declared filter variant:

- Parent task: `30593d06-a6c7-4260-a7ef-74657de46429`
- Work item: `427d85b9-20a0-4733-b1dc-ba6894b1552e`
- EA: `QM5_1056`
- Symbol: `NDX.DWX`
- Status at verification: `pending`
- Setfile: `C:\QM\repo\framework\EAs\QM5_1056_moskowitz-tsmom-multiasset\sets\QM5_1056_moskowitz-tsmom-multiasset_NDX.DWX_D1_backtest_filter_crisis.set`

## Verification

- `compile_one.ps1 -EALabel QM5_1056_moskowitz-tsmom-multiasset` -> PASS, 0 errors, 0 warnings.
- Deployed compiled `.ex5` to T1-T10 factory terminals only; all destination hashes matched.
- Deployment evidence: `D:\QM\strategy_farm\artifacts\deploy\QM5_1056_filter_crisis_deploy_20260522T1125Z.json`
- `python -m py_compile tools/strategy_farm/farmctl.py tools/strategy_farm/agent_router.py` -> PASS.
- DB verification confirmed Q02/P2 work item `427d85b9-20a0-4733-b1dc-ba6894b1552e` exists and is pending.

## Guardrails

- Model=4 policy unchanged.
- No T_Live or AutoTrading changes.
- No manual `terminal64.exe` start.
- No gate or verdict semantics changed.
- No extra filters or parameter sweep were added.
