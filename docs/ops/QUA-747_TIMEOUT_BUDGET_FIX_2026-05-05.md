# QUA-747 Timeout Budget Fix (2026-05-05)

## Problem

`p2_baseline.py` wrapped `run_smoke.ps1` with subprocess timeout = `timeout_sec + 60`.
With `--runs 2`, this could terminate wrapper execution before run_smoke finished both runs,
causing false `INVALID` outcomes not representative of tester results.

## Fix

File: `framework/scripts/p2_baseline.py`

- Wrapper timeout now scales with run count:
  - `wrapper_timeout = (timeout_sec * max(1, runs)) + 60`

## Regression Test

File: `framework/scripts/tests/test_p2_baseline.py`

- Added `test_invoke_run_smoke_timeout_scales_with_runs`.
- Verifies `runs=2`, `timeout_sec=120` calls subprocess with timeout `300`.

## Verification

- `python -m unittest framework.scripts.tests.test_p2_baseline framework.scripts.tests.test_resolve_backtest_target` -> PASS
- Live probe:
  - `python framework/scripts/p2_baseline.py --ea QM5_1004 --symbols AUDCAD.DWX --year 2024 --runs 2 --min-trades 20 --timeout 120`
  - Result: no wrapper timeout invalid; execution completed with classified run outcome (`FAIL run_smoke_fail:REPORT_MISSING;INCOMPLETE_RUNS`) after retry.

This confirms timeout-budget false-invalid path is removed.