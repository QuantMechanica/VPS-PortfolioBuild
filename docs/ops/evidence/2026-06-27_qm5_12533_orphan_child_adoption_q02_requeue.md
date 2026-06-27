# QM5_12533 Orphan-Child Adoption Q02 Requeue - 2026-06-27

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no portfolio-gate changes.

## Decision

The controlling FX scan remains `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`.
It documents only two strict-threshold FX cointegration survivors from the 66-pair scan:

- `QM5_12533` EURJPY/GBPJPY D1, the strongest survivor.
- `QM5_12532` AUDUSD/NZDUSD D1, already logical-basket Q02 `PASS` and later Q04 `FAIL`
  for low pooled fold trades.

There is no third unbuilt strict-threshold FX cointegration pair in that scan. The
non-duplicate action was to repair and requeue the existing approved `QM5_12533`
logical-basket Q02 lane.

## Failure State

Latest completed logical-basket Q02 before this repair:

- Work item: `12165577-fb9d-40c3-a527-f41c57cb8c45`
- Parent task: `qm5-12533-jpy-deposit-q02-requeue-20260627_035634-12165577`
- Status/verdict: `done` / `INFRA_FAIL`
- Payload reason: `run_smoke_fail:NO_HISTORY;INCOMPLETE_RUNS`
- Report summary:
  `D:/QM/reports/work_items/12165577-fb9d-40c3-a527-f41c57cb8c45/QM5_12533/20260627_054136/summary.json`
- Report invalid reasons: `BARS_ZERO`, `HISTORY_CONTEXT_INVALID`
- OnInit failure detected: `false`

The T4 terminal log showed two starts for the same work item: an earlier run from
`20260627_043010` and a later zero-bar report from `20260627_054136`. The old worker
path released a still-running child when the supervising worker pid disappeared, stopped
the terminal, and allowed the same logical item to be rerun into a misleading zero-bar
`NO_HISTORY` artifact.

## Code Repair

`tools/strategy_farm/terminal_worker.py` now:

- Adopts an active work item when `claimed_by_worker_pid` is gone but the recorded child
  process tree still exists.
- Records `orphan_worker_pid`, `orphan_child_adopted_at_iso`, and updates
  `claimed_by_worker_pid` instead of stopping the child and terminal.
- Reuses the existing monitor loop for fresh and adopted children.
- Preserves the original timeout budget for adopted children using `started_at_iso` or
  `claimed_at_iso`, so adoption does not expand CPU time.

Added focused regression coverage in
`tools/strategy_farm/tests/test_terminal_worker_adoption.py`.

## Validation

- `python -m unittest -v tools.strategy_farm.tests.test_terminal_worker_adoption`: PASS
- `python -m unittest tools.strategy_farm.tests.test_basket_work_items`: PASS
- `python -m unittest tools.strategy_farm.tests.test_index_symbol_dispatch_serialization`: PASS

An earlier adoption-test invocation timed out while the new timeout-budget test was being
adjusted; the orphaned unittest process was stopped. The corrected test passed.

## Queue Mutation

SQLite backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12533_orphan_adopt_q02_requeue_20260627_064625.sqlite`

Inserted one replacement logical-basket Q02 item after a duplicate guard confirmed zero
pending/active rows for the logical symbol:

- Work item: `433bf1fd-c82f-4d3f-934c-21b772eea5fc`
- Parent task: `qm5-12533-orphan-adopt-q02-requeue-20260627_064625-433bf1fd`
- EA: `QM5_12533`
- Symbol: `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`
- Host: `EURJPY.DWX`, `D1`
- Setfile:
  `C:/QM/repo/framework/EAs/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration/sets/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration_QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1_D1_backtest.set`
- Basket manifest:
  `C:/QM/repo/framework/EAs/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration/basket_manifest.json`
- Risk payload: `tester_currency=JPY`, `tester_deposit=15000000`, `risk_fixed=150000`
- Timeout: `120` minutes
- Supersedes: `12165577-fb9d-40c3-a527-f41c57cb8c45`

Post-insert worker activity:

- `T4` claimed the item at `2026-06-27T06:46:34Z`.
- The first child launch exited in `0.05` seconds and was classified by the worker as a
  transient `launch_fault`, not as a strategy/history result.
- The item was returned to `pending` at `2026-06-27T06:48:05Z`.
- Backoff: `launch_not_before_utc=2026-06-27T06:53:05+00:00`.
- `launch_fault_count=1`; no replacement duplicate was inserted.

No manual MT5 backtest was launched from this agent. The item was left to the paced farm
worker under the mission CPU-ceiling constraint.
