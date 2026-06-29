# QM5_12712 Q05 Host-Keyed Aggregate Classification

Date: 2026-06-29

## Scope

Mission fallback path: no remaining unbuilt FX cointegration pair was found in
the current 66-pair scan-derived card/EA set, and `QM5_12532` / `QM5_12533`
already have logical-basket Q02 PASS records. This pass advanced an existing
forex basket by clearing a Q05 queue wedge for `QM5_12712`
EURGBP/EURAUD cointegration.

No `T_Live`, AutoTrading, portfolio admission, portfolio KPI, Q08 contribution,
or live manifest files were touched.

## Finding

`QM5_12712` had already reached Q05:

| Phase | Work item | Verdict |
|---|---|---|
| Q02 | `dcc9e3f9-0639-4423-b6e2-ddd03c0188a6` | PASS |
| Q03 | `a60a9de9-1637-4250-aca8-db1e7ae58f71` | PASS |
| Q04 | `06e86ebb-4f8d-4763-ac11-1966a890cf22` | PASS |

The Q05 row `f064eb24-9f7e-4d80-8180-88b1b0165b52` repeatedly fast-exited and
was returned to `pending` as `launch_fault` despite a durable phase aggregate:

`D:/QM/reports/work_items/f064eb24-9f7e-4d80-8180-88b1b0165b52/QM5_12712/Q05/EURGBP_DWX/aggregate.json`

Root cause: the worker looked for a real-phase aggregate under the work-item
logical symbol path, but Q05 basket runners write host-keyed phase evidence
under `EURGBP_DWX`. The fast-exit guard therefore failed to see evidence and
kept cooling down/retrying the row.

## Fix

Patched `tools/strategy_farm/terminal_worker.py` so real phase evidence
discovery falls back to scanning the isolated work-item phase directory for
`aggregate.json` files. This preserves the existing verdict derivation path and
does not change launch-fault behavior when no evidence exists.

Regression added:

`tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py::TerminalWorkerAtomicClaimTests::test_fast_phase_runner_with_host_keyed_aggregate_finishes_item`

## Queue Action

SQLite backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12712_q05_host_aggregate_classify_20260629T023440Z.sqlite`

Both recorded child PIDs (`4740`, `17976`) were not running. The existing Q05
aggregate was then classified through the worker finish path without launching
MT5.

Final Q05 row:

| Field | Value |
|---|---|
| Work item | `f064eb24-9f7e-4d80-8180-88b1b0165b52` |
| EA | `QM5_12712` |
| Symbol | `QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1` |
| Status | `done` |
| Verdict | `INFRA_FAIL` |
| Evidence | `D:/QM/reports/work_items/f064eb24-9f7e-4d80-8180-88b1b0165b52/QM5_12712/Q05/EURGBP_DWX/aggregate.json` |
| Reason | `invalid_summary:BARS_ZERO,EMPTY_EXPERT,EMPTY_SYMBOL,HISTORY_CONTEXT_INVALID,INCOMPLETE_RUNS,M0_1970_PERIOD,NO_HISTORY,REPORT_MISSING,RUN_STATUS_INVALID` |

Duplicate/open guard after classification: `0` pending/active Q05 rows for
`QM5_12712`.

## Verification

```powershell
python -m pytest tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py -q
python -m pytest framework/scripts/tests/test_q05_q07_verdicts.py -q
```

Results: `23 passed`; `9 passed`.
