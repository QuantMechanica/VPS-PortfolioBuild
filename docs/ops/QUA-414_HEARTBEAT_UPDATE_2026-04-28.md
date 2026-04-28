# QUA-414 Heartbeat Update — 2026-04-28

## Scope
Implemented fail-fast schema enforcement and 36-symbol `.DWX` matrix expansion in the backtest dispatcher path (`QUA-400/B`).

## Code Changes
- `framework/scripts/pipeline_dispatcher.py`
  - Added `validate_job()` fail-fast checks for required fields and `.DWX` suffix.
  - Added `validate_matrix_payload()` with strict schema checks:
    - required matrix fields
    - `symbols` must be an array
    - exact cardinality = 36 symbols
    - unique symbols only
    - each symbol must end with `.DWX`
  - Added `build_matrix_jobs()` to materialize one validated job per symbol.
  - Updated `dedup_key()` to route through strict `validate_job()` before key construction.
- `framework/scripts/tests/test_pipeline_dispatcher.py`
  - Added validation tests for missing fields and non-`.DWX` symbols.
  - Added matrix schema tests for exact-36 enforcement, non-`.DWX` rejection, and job materialization.

## Verification
Command:
- `python -m unittest framework/scripts/tests/test_pipeline_dispatcher.py`

Result:
- `Ran 17 tests ... OK`

## Next Action
Wire `build_matrix_jobs()` into the matrix dispatcher entrypoint/CLI payload ingestion path (if separate from `resolve_backtest_target.py`) so queue intake fails before any terminal reservation when matrix schema is invalid.
