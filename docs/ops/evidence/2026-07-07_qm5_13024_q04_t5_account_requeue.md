# QM5_13024 Q04 T5 Account-Missing Requeue

Date: 2026-07-07

Scope:
- Advanced the existing forex cointegration basket `QM5_13024` (`AUDCAD~GBPAUD`) after `QM5_12532` and `QM5_12533` were not Q02-blocked.
- Did not touch portfolio admission gates or `T_Live`.

Diagnosis:
- `QM5_13024` Q02 already passed on T3:
  - `D:/QM/reports/work_items/a69aaccd-4227-4129-9854-a789598cd2b8/QM5_13024/20260707_044025/summary.json`
- Q04 failed as infra on T5 with missing reports:
  - `D:/QM/reports/work_items/0334f308-2519-4c3c-8d80-2f7e96e8c126/QM5_13024/Q04/QM5_13024_AUDCAD_GBPAUD_COINTEGRATION_D1/aggregate.json`
- The T5 tester logs showed:
  - `tester not started because the account is not specified`
- Source run summaries:
  - `D:/QM/reports/work_items/0334f308-2519-4c3c-8d80-2f7e96e8c126.requeued_20260707T0626470000/QM5_13024/20260707_051814/summary.json`
  - `D:/QM/reports/work_items/0334f308-2519-4c3c-8d80-2f7e96e8c126.requeued_20260707T0626470000/QM5_13024/20260707_053037/summary.json`

Actions:
- Added `ACCOUNT_NOT_SPECIFIED` classification for report-missing smoke failures and Q04 invalid-summary handling.
- Added `avoid_terminals` / `skip_terminals` enforcement to terminal worker claiming.
- Disabled T5 in `D:/QM/strategy_farm/state/disabled_terminals.txt`.
- Stopped the orphaned T5 `QM5_12712` Q07 child process and released work item `1b9fa7a5-48a7-4e57-a699-9e55dfb0cb19`; it was subsequently claimed by T4.
- Requeued `QM5_13024` Q04 work item `0334f308-2519-4c3c-8d80-2f7e96e8c126`.
- Tagged that Q04 payload with:
  - `priority_track=true`
  - `avoid_terminals=["T5"]`
  - account-missing evidence path above

Backups:
- `D:/QM/strategy_farm/state/disabled_terminals.txt.bak_before_t5_account_missing_20260707T0622Z`
- `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_13024_q04_t5_requeue_20260707T062723Z.sqlite`

Validation:
- `powershell -ExecutionPolicy Bypass -File framework/scripts/tests/Test-RunSmokeAccountNotSpecified.ps1`
- `powershell -ExecutionPolicy Bypass -File framework/scripts/tests/Test-RunSmokeNoHistoryScope.ps1`
- `python -m pytest framework/scripts/tests/test_q04_walkforward.py tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py -q`
- `powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_13024_audcad-gbpaud-coint -RepoRoot C:/QM/repo -SkipCompile`

Queue state after requeue:
- `QM5_13024` Q04 work item `0334f308-2519-4c3c-8d80-2f7e96e8c126` was pending, with `avoid_terminals=["T5"]`.
