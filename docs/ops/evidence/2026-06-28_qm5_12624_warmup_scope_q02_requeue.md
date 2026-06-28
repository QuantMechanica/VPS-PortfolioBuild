# QM5_12624 Warmup-Scope Q02 Requeue

Date: 2026-06-28
Branch: agents/board-advisor
EA: QM5_12624_edgelab-eurjpy-audjpy-cointegration
Instrument class: FX market-neutral basket (`EURJPY.DWX` plus `AUDJPY.DWX`)

## Diagnosis

The latest logical-basket Q02 work item
`f346f9e9-7dc9-4cff-be60-4dec96784e77` failed as infrastructure:

- verdict: `INFRA_FAIL`
- reason classes: `REPORT_MISSING`, `METATESTER_HUNG`, `NO_HISTORY`, `INCOMPLETE_RUNS`
- OnInit failure: false
- evidence: `D:\QM\reports\work_items\f346f9e9-7dc9-4cff-be60-4dec96784e77\QM5_12624\20260628_154905\summary.json`

The run reached real EURJPY/AUDJPY order execution. The raw tester tail then
showed repeated USDJPY tick preprocessing followed by `64 Mb not available`,
`not enough available memory`, and a zero-bar report. This pointed to tester
memory pressure from unused conversion-symbol warmup rather than strategy logic
or an EA init defect.

## Fix

`Strategy_EnsureBasketScope()` now warms and guards only:

- `EURJPY.DWX`
- `AUDJPY.DWX`

The prior scope also selected `EURUSD.DWX`, `AUDUSD.DWX`, and `USDJPY.DWX`.
Those symbols are not strategy inputs under the JPY tester account pinned by the
basket manifest, and USDJPY preprocessing was the memory hot spot in the failed
Q02 evidence.

## Validation

- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_12624_edgelab-eurjpy-audjpy-cointegration`
  - PASS
- `powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12624_edgelab-eurjpy-audjpy-cointegration`
  - compile PASS
  - errors 0
  - warnings 0
  - build_check PASS
  - failures 0
  - framework advisory warnings 16
  - report: `D:\QM\reports\framework\21\build_check_20260628_204932.json`

Fresh `.ex5` SHA256:

`1bf16657ab20c951a179190692be56c4872d52b8fd24c991d322da360b50d46e`

## Q02 Requeue

Farm DB backup before mutation:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12624_warmup_scope_q02_requeue_20260628_205039Z.sqlite`

Inserted pending Q02 work item:

- ID: `5cac7445-76ce-4933-aec7-042064105f2f`
- phase: `Q02`
- status: `pending`
- symbol: `QM5_12624_EURJPY_AUDJPY_COINTEGRATION_D1`
- host symbol: `EURJPY.DWX`
- host timeframe: `D1`
- setfile: `framework/EAs/QM5_12624_edgelab-eurjpy-audjpy-cointegration/sets/QM5_12624_edgelab-eurjpy-audjpy-cointegration_QM5_12624_EURJPY_AUDJPY_COINTEGRATION_D1_D1_backtest.set`
- supersedes: `f346f9e9-7dc9-4cff-be60-4dec96784e77`
- reason: `warmup_scope_narrowed_after_usdjpy_tick_memory_exhaustion`

No manual MT5 backtest was launched. No `T_Live` files, AutoTrading settings,
deploy manifests, or portfolio gate files were touched.
