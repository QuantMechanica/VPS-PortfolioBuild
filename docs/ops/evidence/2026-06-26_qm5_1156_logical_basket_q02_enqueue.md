# QM5_1156 Logical Basket Q02 Enqueue - 2026-06-26

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no portfolio-gate edits.

## Context

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` shows no third strict survivor from the
66-pair FX cointegration scan beyond `QM5_12533` and `QM5_12532`, and both logical basket Q02 rows
were already pending. To advance an existing reputable-source FX cointegration card instead, this
work used `QM5_1156_caldeira-cointegration-pairs-fx`, sourced from Caldeira/Moura cointegration
pairs research.

`QM5_1156` had prior terminal Q02 attempts as component-symbol rows. Those rows tested pair-slot
setfiles as ordinary single-symbol items and ended as `INFRA_FAIL` / summary-missing retries. The
slot-00 EURUSD.DWX / GBPUSD.DWX spread now has a logical basket target:

`QM5_1156_EURUSD_GBPUSD_COINTEGRATION_M30`

## Repo Action

- Used the existing `basket_manifest.json` logical symbol route for slot 00.
- Added/refreshed the logical RISK_FIXED backtest setfile:
  `framework/EAs/QM5_1156_caldeira-cointegration-pairs-fx/sets/QM5_1156_caldeira-cointegration-pairs-fx_QM5_1156_EURUSD_GBPUSD_COINTEGRATION_M30_M30_backtest.set`
- Added strict-build `perf-allowed` markers for the EA's D1 formation-history and closed-bar timestamp calls.
- Recompiled `QM5_1156_caldeira-cointegration-pairs-fx.ex5`.

## Validation

- `compile_one.ps1 -Strict`: PASS, 0 errors, 0 warnings.
- `build_check.ps1 -EALabel QM5_1156_caldeira-cointegration-pairs-fx -SkipCompile`: PASS, 0 failures, 16 existing framework include advisory warnings.
- `python -m unittest tools.strategy_farm.tests.test_basket_work_items`: PASS.

## Farm Queue Action

Database: `D:/QM/strategy_farm/state/farm_state.sqlite`

Backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_1156_logical_basket_enqueue_20260626_114856.sqlite`

Inserted review provenance task:

`qm5-1156-logical-basket-review-796a6303`

Enqueued Q02 through `farmctl enqueue-backtest`:

| EA | Logical symbol | Work item | Parent task | Host | Status |
|---|---|---:|---:|---|---|
| `QM5_1156` | `QM5_1156_EURUSD_GBPUSD_COINTEGRATION_M30` | `9d58e7a6` | `9d4d47f1` | `EURUSD.DWX` | `pending` |

No backtest was launched; the work item is queued for the paced factory.
