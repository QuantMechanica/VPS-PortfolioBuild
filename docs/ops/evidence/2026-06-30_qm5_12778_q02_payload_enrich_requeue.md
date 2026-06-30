# QM5_12778 Q02 Basket Payload Enrichment - 2026-06-30

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate or T_Live manifest edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
66-pair FX cointegration scan. It documents only two strict-threshold survivors:
`QM5_12533` EURJPY/GBPJPY and `QM5_12532` AUDUSD/NZDUSD. Current farm state shows
both have logical-basket Q02 PASS rows, so there was no active Q02 ONINIT or
NO_HISTORY repair to prefer.

No unbuilt strict-threshold FX cointegration pair was found. The selected
fallback action was to advance the existing forex basket `QM5_12778`
AUDUSD/EURJPY by repairing its pending replacement Q02 row.

## Prior State

`QM5_12778` prior Q02 row `8f0e511f-0f93-42eb-b2c5-b07e1f7a6f1e` finished
`INFRA_FAIL` with `NO_HISTORY` and `INCOMPLETE_RUNS`. The EA/manifest conversion
history repair was already recorded in
`docs/ops/evidence/2026-06-29_qm5_12778_audusd_eurjpy_conversion_repair_q02_requeue.md`,
which created replacement Q02 row `7f04ff6a-35ca-45bd-a702-afc37b310f97`.

That replacement row was still `pending`, but its auto-enqueue payload was thin:
it had manifest identity and tester currency, but not the basket symbols,
conversion symbols, fixed-risk audit fields, tester deposit, explicit 120-minute
basket timeout, or priority flag carried by the previous repaired basket rows.

## Code Fix

Added `farmctl._basket_q02_payload(...)` and wired it into both basket Q02
enqueue paths:

- `enqueue_backtest` / `_create_backtest_work_items`
- `record-build` / `_auto_enqueue_q02_for_build`

The helper keeps basket Q02 rows consistent with the runtime metadata expected
by workers and phase promotion:

- manifest path, logical symbol, host symbol/timeframe, portfolio scope
- declared basket symbols, including conversion-history symbols
- traded symbols from build results when available
- tester currency/deposit from the basket manifest
- `RISK_FIXED`, `RISK_PERCENT`, and `PORTFOLIO_WEIGHT` from build results
- `timeout_min=120` for basket Q02 rows
- scan ranking metadata when available

Strategy logic, card content, EA source, and EA binaries were not changed.
`build_check.ps1 -SkipCompile` refreshed only the selected backtest setfile's
`build_hash` header for `QM5_12778`.

## Queue Mutation

SQLite backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12778_q02_payload_enrich_20260630T023610Z.sqlite`

Updated pending work item:

| Field | Value |
|---|---|
| work_item_id | `7f04ff6a-35ca-45bd-a702-afc37b310f97` |
| ea_id | `QM5_12778` |
| phase | `Q02` |
| symbol | `QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1` |
| status after update | `pending` |
| claimed_by after update | `NULL` |
| host/timeframe | `AUDUSD.DWX`, `D1` |
| traded symbols | `AUDUSD.DWX`, `EURJPY.DWX` |
| conversion symbols | `EURUSD.DWX`, `USDJPY.DWX` |
| tester | `USD`, deposit `100000` |
| risk | `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` |
| timeout | `120` minutes |

Duplicate guard after update: exactly one pending/active Q02 row exists for
`QM5_12778`.

## Validation

- `python -m py_compile tools/strategy_farm/farmctl.py`: PASS
- `python -m pytest tools/strategy_farm/tests/test_basket_work_items.py`: PASS, 11 tests
- `python -m pytest tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py::TerminalWorkerAtomicClaimTests::test_fast_phase_runner_with_host_keyed_aggregate_finishes_item`: PASS, 1 test
- `python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_12778_edgelab-audusd-eurjpy-cointegration --verbose`: `BASKET_OK`, 0 violations
- `powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12778_edgelab-audusd-eurjpy-cointegration -RepoRoot C:\QM\repo -SkipCompile`: PASS, failures 0, warnings 16 existing shared-framework DWX advisories; report `D:/QM/reports/framework/21/build_check_20260630_023647.json`

## CPU Ceiling

`QM5_12532` was checked first as a proven survivor. It is past Q02 and Q04, but
its latest Q05 run hit the paced backtest ceiling (`TIMEOUT`,
`METATESTER_HUNG`, `INCOMPLETE_RUNS`) after a 1800-second MT5 run. No manual
backtest was launched or requeued from this session.

## Safety

- No manual MT5 backtest launched; Q02 remains delegated to paced farm workers.
- No `T_Live` files edited.
- AutoTrading was not touched.
- No `portfolio_admission`, `portfolio_kpi`, or `q08_contribution` artifacts edited.
