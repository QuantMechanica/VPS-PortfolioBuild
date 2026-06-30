# QM5_12781 Q04 Parser Fix and Requeue - 2026-06-30

Scope: branch `agents/board-advisor`; no `T_Live`, AutoTrading, portfolio
admission, portfolio KPI, or Q08 contribution artifacts touched.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
66-pair FX cointegration scan. The only strict-threshold survivors are
`QM5_12533` and `QM5_12532`; both are already past Q02, so there was no Q02
ONINIT / NO_HISTORY fix to prefer.

All current EdgeLab cointegration card slugs found in `strategy-seeds/cards`
already have matching `framework/EAs` folders. Per the mission fallback, I
advanced an existing built forex basket: `QM5_12781` USDJPY/AUDJPY.

## Root Cause

`QM5_12781` had Q02 PASS, then Q04 `INFRA_FAIL` on work item
`f8e8a8d4-48c8-4c30-a7f0-2eace7bb8ccb`.

The Q04 aggregate marked fold F1 invalid even though its
`20260629_173839/summary.json` had top-level `result: PASS` and a later OK run
with 34 trades. The parser scanned all retry attempts and treated the earlier
blank M0/1970 attempt as fold-invalid evidence.

## Code Fix

Changed `framework/scripts/q04_walkforward.py` so
`summary_invalid_reason()` returns cleanly when the `run_smoke` summary is a
top-level PASS and contains at least one `OK` run. Failed retry attempts still
invalidate summaries that never reach a successful run.

Regression test added:

```text
framework/scripts/tests/test_q04_walkforward.py::Q04WalkForwardTests::test_pass_summary_ignores_failed_retry_attempts
```

## Queue Action

Requeued the existing Q04 work item in place:

| Field | Value |
|---|---|
| EA | `QM5_12781` |
| Pair | `USDJPY.DWX` / `AUDJPY.DWX` |
| Work item | `f8e8a8d4-48c8-4c30-a7f0-2eace7bb8ccb` |
| Phase | `Q04` |
| Status before | `done` / `INFRA_FAIL` |
| Status after | `pending` |
| Duplicate row inserted | `false` |
| Pending/active duplicate count after | `1` |
| DB backup | `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12781_q04_parserfix_requeue_20260630T063550Z.sqlite` |

The pending payload was sanitized to remove stale claim/runtime/verdict fields
from the previous T4 run while preserving prior evidence in
`prior_runtime_payload_fields`.

## Validation

```text
python -m py_compile framework/scripts/q04_walkforward.py
PASS

python -m pytest framework/scripts/tests/test_q04_walkforward.py
19 passed
```

No manual MT5 backtest was launched. `mt5-slots` showed active factory runs on
T1, T3, T4, and T5; the Q04 retry is left pending for paced workers.
