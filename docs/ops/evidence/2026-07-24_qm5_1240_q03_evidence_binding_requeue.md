# QM5_1240 AUDUSD Q03 evidence-binding recovery

`QM5_1240_bandy-prank-mr` was stuck at Q03 because the worker enabled
`run_smoke/v2` evidence binding while persisting null `expected_from_date` and
`expected_to_date` values. Q03 intentionally omits explicit dates and
`run_smoke.ps1 -Year 2024` resolves that request to `2024.01.01` through
`2024.12.31`. The binding validator therefore rejected every otherwise valid
summary before verdict derivation.

## Diagnosis

- Claimed farm row: `de5749bd-956c-409d-a330-0b753fe30696`
- EA / symbol / phase: `QM5_1240` / `AUDUSD.DWX` / `Q03`
- Collision guard: zero other pending or active `QM5_1240` Q03 rows at claim
  and requeue.
- Valid discarded summary:
  `D:/QM/reports/work_items/de5749bd-956c-409d-a330-0b753fe30696/QM5_1240/20260724_061503/summary.json`
- The summary contains two deterministic Model-4 runs, stable EX5/MQ5/setfile
  identity, `oninit_failure_detected=false`, and the resolved 2024 window.
- The worker rejected that summary only because the expected dates were null,
  then classified a terminal-log history-lock token and exhausted seven
  transient retries.

## Repair

`terminal_worker._resolved_evidence_window` now binds a date-less Q03 launch to
the same full-year window resolved by `run_smoke.ps1`. Explicit Q02/Q03 windows
remain unchanged. Unit coverage verifies both cases.

The existing failed row was reopened in place with its transient runtime state
cleared. No duplicate Q03 work item was inserted. The paced farm owns execution;
this recovery did not launch MT5 manually and did not touch T_Live,
AutoTrading, portfolio gates, or deploy manifests.

## Verification

```text
python -m unittest tools.strategy_farm.tests.test_terminal_worker_history_lock_storm
Ran 13 tests in 0.353s
OK
```
