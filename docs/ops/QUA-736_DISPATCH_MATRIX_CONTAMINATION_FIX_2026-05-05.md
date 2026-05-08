# QUA-736 Dispatch Matrix Contamination Fix (2026-05-05)

Issue: `dispatch_state.json` phase bucket `QM5_1003_v1_P2` showed 21 phantom `PASS` rows.

## Root Cause

Matrix `start` dispatch reused existing `phase_matrix_index[ea_version_phase].matrix` rows without clearing prior verdicts.
When a new run could only schedule a subset (e.g., capacity-limited), unscheduled symbols retained stale verdict/evidence from prior runs.

## Fix Applied

1. Added `initialize_matrix_bucket_for_symbols(state, jobs)` in `framework/scripts/pipeline_dispatcher.py`.
2. On matrix `start` path in `framework/scripts/resolve_backtest_target.py`, call this initializer before scheduling.
3. Initializer behavior:
- bucket rows become exactly the current matrix symbol cohort
- `verdict`, `invalidation_reason`, `evidence` reset to `null`
- stale symbols not in current cohort are dropped
- `phase_verdict` and `next_strategy_unblocked` reset to `null`

## Verification

Command:

```powershell
python -m unittest framework.scripts.tests.test_pipeline_dispatcher
```

Result:
- `Ran 25 tests`
- `OK`

Regression test added:
- `test_initialize_matrix_bucket_for_symbols_clears_stale_verdicts`

## Operational Impact

Prevents phantom PASS carryover in future matrix starts for the same phase bucket (including `QM5_1003_v1_P2`) under partial scheduling conditions.
