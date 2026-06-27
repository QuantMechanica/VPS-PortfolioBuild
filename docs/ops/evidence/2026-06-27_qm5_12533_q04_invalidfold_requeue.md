# QM5_12533 Q04 Invalid-Fold Classification Fix + Requeue - 2026-06-27

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate or T_Live manifest changes.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` is still the controlling
66-pair FX cointegration scan. It lists only two strict-threshold FX
cointegration survivors:

- `QM5_12533` EURJPY/GBPJPY D1, the strongest survivor.
- `QM5_12532` AUDUSD/NZDUSD D1.

Both are already built and both cleared logical-basket Q02. No third unbuilt
strict-threshold cointegration pair was available from that scan, so this pass
advanced the existing stronger FX basket instead of creating a weaker duplicate.

## Failure State

Prior Q04 work item:

- Work item: `7b8a32f6-0daa-4b55-8a48-b8815ba20550`
- EA/symbol: `QM5_12533` /
  `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`
- Status/verdict in DB: `done` / `INFRA_FAIL`
- Evidence:
  `D:/QM/reports/work_items/7b8a32f6-0daa-4b55-8a48-b8815ba20550/QM5_12533/Q04/QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1/aggregate.json`

The aggregate artifact contained mixed evidence: F1 and F3 had real fold
results, while F2 wrote a `run_smoke` failure summary with
`REPORT_MISSING`, `METATESTER_HUNG`, and `INCOMPLETE_RUNS`. The runner was
able to serialize that into an aggregate `FAIL` because
`q04_walkforward.py` treated any existing summary file as a completed fold,
even when the summary described malformed or missing tester evidence.

## Code Repair

`framework/scripts/q04_walkforward.py` now:

- Parses `run_smoke` fold summaries for infra/data invalidation markers.
- Marks report-missing, no-history, invalid-report, incomplete-run, timeout,
  and OnInit-style fold summaries as invalid evidence.
- Blocks low-frequency pooled rescue when any strict fold is invalid.
- Keeps real completed zero-trade or low-PF folds classified as strategy
  failures.

Regression coverage was added in
`framework/scripts/tests/test_q04_walkforward.py`.

Validation:

- `python -m unittest -v framework.scripts.tests.test_q04_walkforward`: PASS
- `python -m unittest -v tools.strategy_farm.tests.test_cascade_real_phase_runners`: PASS

## Queue Mutation

SQLite backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12533_q04_invalidfold_fix_requeue_20260627_122024.sqlite`

Inserted one replacement Q04 work item:

- Work item: `ff2cb183-8269-4e63-abaf-27ba79afdb62`
- EA: `QM5_12533`
- Symbol: `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`
- Setfile:
  `C:/QM/repo/framework/EAs/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration/sets/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration_QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1_D1_backtest.set`
- Source Q02 PASS: `76cb11ee-7e9d-4d75-be9d-626c205bca62`
- Supersedes Q04: `7b8a32f6-0daa-4b55-8a48-b8815ba20550`
- Status at verification: `pending`
- Duplicate guard after insert: exactly one pending/active Q04 row for
  `QM5_12533`

No manual MT5 backtest was launched. Execution is left to the paced terminal
workers under the CPU-ceiling constraint.
