# QUA-986 Heartbeat Evidence (2026-05-09)

## Scope
- Wake issue: `QUA-986` (DWX verifier `FAIL_tail_bars` cohort blocking `QM_DWX_HourlyCheck`).
- Action in this heartbeat: validate current failure signature, patch parser drift in hourly verifier diagnostics, and prove with targeted tests.

## Runtime Evidence
- Latest verifier log inspected:
  - `D:/QM/mt5/T1/dwx_import/logs/dwx_verify_2026-05-09_00-30-54.log`
- Observed repeated systemic signature:
  - `bars_one_shot=0`
  - `bars_one_shot_err=(-2, 'Terminal: Invalid params')`
  - many symbols with `FAIL_tail_bars`/`FAIL_tail_mid_bars`
- Also observed canonical-name mismatch lines:
  - `[FAIL] GDAXIm.DWX: not present in MT5`
  - `[FAIL] NDXm.DWX: not present in MT5`

## Code Change
- Updated `infra/scripts/dwx_hourly_check.py`:
  - `summarize_verify_failures()` now parses both legacy verifier lines:
    - `bars expected=.../got=...`
  - and current verifier lines:
    - `bars_sidecar_expected=...; bars_one_shot=...`
- This restores systemic-failure diagnostics when verifier output is in the newer sidecar format.

## Regression Coverage
- Added unit test in `infra/scripts/tests/test_dwx_hourly_check_readiness.py`:
  - `test_summarize_verify_failures_parses_sidecar_bars_format`
- Verification command:
  - `python -m unittest infra/scripts/tests/test_dwx_hourly_check_readiness.py`
- Result:
  - `Ran 15 tests ... OK`

## Next Action
- Re-run one `dwx_hourly_check.py` cycle and confirm hourly log emits:
  - `verify diagnostics: fail_count=...`
  - systemic classification lines when cohort conditions are met.
- If classification now appears but MT5 still reports `bars_one_shot_err=(-2, Terminal: Invalid params)` broadly, escalate as runtime/import-service condition (not per-symbol corruption).

## CTO Decision (2026-05-09)
- Direction: **fix upstream verifier/import runtime path**, do **not** gate out symbols.
- Basis:
  - Cohort-wide `bars_one_shot=0` with identical `bars_one_shot_err=(-2, 'Terminal: Invalid params')` across many symbols in `dwx_verify_2026-05-09_00-30-54.log`.
  - Widespread `bars_chunked=0` and `bars_drift=-100,000` indicates read-path/runtime failure shape, not isolated data corruption.
  - Readiness remains blocked globally (`verify_fail_count=94`, top verdict `FAIL_tail_bars`) in `D:/QM/reports/setup/T1_READINESS_REPORT.md`.

## DevOps Execution Packet
- Owner: DevOps (`86015301-1a40-4216-9ded-398f09f02d26`).
- Objective: restore verifier bars read-path and tail alignment so readiness reaches:
  - `verify_exit_code=0`
  - `verify_fail_count=0`
  - `OVERALL=READY`
- Required steps:
  1. Run targeted probes on top offenders (`XTIUSD.DWX`, `USDJPY.DWX`, `GBPJPY.DWX`) using `probe_verify_rates_span.py` and `probe_custom_symbol_visibility.py` to isolate MT5 API behavior in current terminal session.
  2. Validate service health and import queue convergence before verifier invocation (heartbeat freshness, no pending sidecars, no partial import churn).
  3. Patch verifier/runtime read path where needed (range/from_pos fallback behavior and/or session initialization order) so bars are non-zero under current `maxbars`.
  4. Re-run verifier and `dwx_hourly_check.py`; publish new readiness report plus verifier log excerpt proving zero fails.

## Unblock Contract
- Keep `QUA-986` open until readiness proof shows `verify_exit_code=0` and `verify_fail_count=0`.
- Once satisfied, close `QUA-986` and unblock `QUA-976` (`blockedByIssueIds` already references this issue).
