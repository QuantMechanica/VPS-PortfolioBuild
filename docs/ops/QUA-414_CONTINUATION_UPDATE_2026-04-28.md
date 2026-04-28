# QUA-414 Continuation Update — 2026-04-28

## Delta Implemented
Extended dispatcher integration from validation-only to executable matrix flow + matrix verdict state.

### Code
- `framework/scripts/pipeline_dispatcher.py`
  - Added phase-matrix schema bucket support under state key `phase_matrix_index`:
    - key: `<ea_id>_<version>_<phase>`
    - value: `{ matrix: [...], phase_verdict, next_strategy_unblocked }`
  - Added helpers:
    - `matrix_bucket_key()`
    - `_ensure_matrix_bucket()`
    - `_upsert_matrix_row()`
    - `_refresh_phase_verdict()`
  - `dispatch_job()` now records/updates matrix row assignment (`symbol`, `terminal`, `verdict:null`, `evidence:null`).
  - `release_job()` now accepts `verdict`, `evidence`, `pass_threshold`, `fail_phase_label`, `next_strategy_unblocked` and recomputes phase verdict.

- `framework/scripts/resolve_backtest_target.py`
  - Wired matrix intake: when payload contains `symbols`, script calls `build_matrix_jobs()` and dispatches all rows.
  - Added completion flags:
    - `--verdict`
    - `--evidence`
    - `--pass-threshold`
    - `--fail-phase-label`
    - `--next-strategy-unblocked`
  - Emits matrix summary counts (`scheduled`, `duplicate`, `no_capacity`).

- `framework/scripts/tests/test_pipeline_dispatcher.py`
  - Added tests for:
    - phase matrix update + PASS verdict propagation
    - fail-phase verdict (`FAIL_PHASE_P2`) + unblock pointer persistence

## Verification
- `python -m unittest framework/scripts/tests/test_pipeline_dispatcher.py`
- Result: `Ran 19 tests ... OK`

## Worked Example (3 symbols x 1 EA)
1. **Fail-fast schema proof**
   - Input matrix payload with 3 symbols in `symbols` array.
   - Command: `resolve_backtest_target.py --event start`
   - Result: hard reject with `ValueError: matrix.symbols must contain exactly 36 entries`

2. **Fail-fast unblock path proof (reduced 3-job run)**
   - Dispatched and completed 3 single-symbol jobs for same `(ea_id,version,phase)` with completion `--verdict FAIL --fail-phase-label P2 --pass-threshold 1`.
   - Final completion passed `--next-strategy-unblocked SRC04_S2`.
   - State snapshot confirms:
     - `phase_matrix_index.QM5_1001_v1_P2.matrix` has 3 rows
     - `phase_verdict = FAIL_PHASE_P2`
     - `next_strategy_unblocked = SRC04_S2`

## Next Action
- Add a dedicated CLI mode to explicitly ingest full 36-symbol matrix payload + completion payloads from runner outputs, then publish a single operator runbook snippet under `framework/scripts/README.md` for standard use.
