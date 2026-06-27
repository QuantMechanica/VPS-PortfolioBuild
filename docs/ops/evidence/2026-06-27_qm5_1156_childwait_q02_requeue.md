# QM5_1156 Logical Basket Q02 Requeue - 2026-06-27

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no portfolio-gate edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling 66-pair
FX cointegration scan artifact. It documents only two strict-threshold FX cointegration
survivors:

- `QM5_12533` EURJPY.DWX / GBPJPY.DWX D1 market-neutral cointegration basket.
- `QM5_12532` AUDUSD.DWX / NZDUSD.DWX D1 market-neutral cointegration basket.

Current farm state before this action:

- `QM5_12532` logical-basket Q02: `PASS`; later Q04: `FAIL`.
- `QM5_12533` logical-basket Q02: real-tick run, no `ONINIT` or `NO_HISTORY`; latest verdict
  `FAIL` / `MIN_TRADES_NOT_MET` with 0 trades after the JPY fixed-risk repair.

No third unbuilt FX cointegration pair from the scan meets the documented build threshold,
so this action advances an existing reputable-source FX cointegration card instead of creating
a weak duplicate.

## Target

Existing card/EA:

- EA: `QM5_1156_caldeira-cointegration-pairs-fx`.
- Source: Caldeira/Moura cointegration pairs research, already built and packaged with
  `basket_manifest.json`.
- Concrete pair: `EURUSD.DWX` / `GBPUSD.DWX`.
- Logical symbol: `QM5_1156_EURUSD_GBPUSD_COINTEGRATION_M30`.
- Host: `EURUSD.DWX`, `M30`.

Previous logical basket Q02 row:

| Field | Value |
|---|---|
| Work item | `9d58e7a6-b62a-4fd1-9aaa-0b479cc631a0` |
| Status/verdict | `failed` / `INFRA_FAIL` |
| Final failure | `summary_missing_retries_exhausted` |
| Evidence path | none |
| Report root | empty |
| Claimed by | `T6` |

That failure predated the later `run_smoke.ps1` child-terminal wait and real-tick report
evidence fixes used to unblock `QM5_12533`, so it was treated as an infra retry candidate,
not a strategy verdict.

## Validation

- `powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_1156_caldeira-cointegration-pairs-fx -SkipCompile`
  - Result: `PASS`, 0 failures, 16 existing framework include advisory warnings.
  - Report: `D:/QM/reports/framework/21/build_check_20260627_030410.json`.
- `powershell -ExecutionPolicy Bypass -File framework/scripts/tests/Test-RunSmokeWaitsForChildTerminal.ps1`
  - Result: `PASS`.
- `powershell -ExecutionPolicy Bypass -File framework/scripts/tests/Test-RunSmokeRealTicksReportEvidence.ps1`
  - Result: `PASS`.

## Queue Action

Database: `D:/QM/strategy_farm/state/farm_state.sqlite`

Backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_1156_childwait_q02_requeue_20260627_030453.sqlite`

Inserted review provenance task:

`qm5-1156-logical-basket-review-20260627_030453-17479a20`

Enqueued Q02 through `farmctl enqueue-backtest`:

| Field | Value |
|---|---|
| Parent task | `5b5480b1-543e-490d-9453-f9878687b882` |
| Work item | `a89aef71-5373-4622-8ae3-ee3664624042` |
| EA | `QM5_1156` |
| Symbol | `QM5_1156_EURUSD_GBPUSD_COINTEGRATION_M30` |
| Host | `EURUSD.DWX`, `M30` |
| Setfile | `framework/EAs/QM5_1156_caldeira-cointegration-pairs-fx/sets/QM5_1156_caldeira-cointegration-pairs-fx_QM5_1156_EURUSD_GBPUSD_COINTEGRATION_M30_M30_backtest.set` |
| Payload | `portfolio_scope=basket`, `basket_symbol_count=2`, `basket_manifest=.../basket_manifest.json` |
| Status after enqueue check | `pending` |

Duplicate guard confirmed exactly one `pending` / `active` / `claimed` / `running` row for this
EA/logical symbol after enqueue.

## CPU Ceiling

No manual MT5 backtest was launched. At the post-enqueue slot check, T1-T7 all had active
`terminal64.exe` work-item processes, so this cycle stopped at the paced-factory Q02 handoff.
