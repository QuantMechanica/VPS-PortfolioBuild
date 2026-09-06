# M14 on-box backup guard and retention lock fix

- Task: `974f4953-a479-43d2-9c6d-dc84330eec2e`
- Date: 2026-09-06
- State requested: REVIEW
- Code branch: `agents/codex-m14-backup-guard-20260906`
- Code commit: `405d2529e7` (`fix(ops): distinguish hourly backups and skip locked logs`)
- Scope: on-box scheduled farm-state snapshot cadence detection and retention-runner handling of locked log files only. No retention-policy, off-box-bundle, database-row, terminal, T_Live, or AutoTrading change.

## Result

The code fix is complete and focused verification passes. It is intentionally left on the isolated branch for review; no merge or deployment was performed by this task.

1. `farmctl._hourly_db_backup_paths` now recognizes only producer-native names matching `farm_state_YYYYMMDD_HHMM.sqlite` (`farmctl.py:17897-17908`). `_hourly_db_backup` uses that exact set for the 50-minute cadence guard (`farmctl.py:17920-17924`). The established 24-hour cleanup remains on the whole `farm_state_*.sqlite` family, so retention policy is unchanged.
2. `chk_db_backup_fresh` uses the same exact scheduled-snapshot classifier and explicitly reports hourly snapshot counts (`health.py:1293-1332`). A fresh `farm_state_before_*` file can no longer mask a stalled scheduled copy.
3. `safe_delete_batch` has an opt-in `skip_locked` mode used only by `LOG_DELETE` (`continuous_retention_runner.py:294-364,425`). On Windows sharing violation 32 it preserves the file, records path/bytes/status=`SKIPPED_LOCKED`/winerror in the receipt and compact telemetry, and continues with later files. Other errors remain fail-closed. Backup deletion does not enable this mode.

## Before measurement

Read-only production measurement at approximately 2026-09-06 03:22Z:

- Broad family: 107 files; newest `farm_state_before_first_q02_intake_20260906T024954_852465Z.sqlite`.
- Actual scheduled family: 5 files; newest `farm_state_20260905_1800.sqlite`.
- Old production health logic reported the broad family healthy at about 27 minutes old.
- Patched scoped health reports `FAIL`, scheduled snapshot age 562 minutes, threshold 150 minutes, and `5 hourly snapshots`. This exposes the real stall.
- Retention telemetry baseline: 3 `FAIL_CLOSED` of 8 runs in the preceding 6 hours; 16 of 32 in 24 hours; latest failure at 2026-09-06T03:06:00Z.

## Verification

- `python -m pytest tools/strategy_farm/tests/test_hourly_db_backup.py tools/strategy_farm/tests/test_continuous_retention_runner.py -q` -> `12 passed`.
- `python -m compileall -q tools/strategy_farm/farmctl.py tools/strategy_farm/health.py tools/strategy_farm/continuous_retention_runner.py` -> exit 0.
- `git diff --check` and `git show --check 405d2529e7` -> exit 0.
- Production-data retention dry-run from the isolated branch, limited to ten evidence candidates -> `PASS`; live DB `quick_check=ok`; 107 backups retained/planned; 168 old logs identified; zero files deleted. Scratch receipt/telemetry root: `C:/QM/tmp/m14-retention-dryrun-974f4953/`.
- Regression coverage proves that a fresh pre-mutation snapshot does not suppress a due scheduled snapshot, scoped health rejects both stale-hourly-plus-fresh-before and before-only cases, and a simulated WinError 32 log is retained and logged while the following deletable log is removed.

## Post-deploy acceptance still required

The task acceptance requires elapsed production observation and therefore cannot be asserted before review/integration:

- Confirm the scheduled snapshot mtime advances on each of three consecutive hourly runs after deployment.
- Confirm zero retention-runner `FAIL_CLOSED` runs during a six-hour post-deploy window; any locked log should instead appear as `SKIPPED_LOCKED` while the run remains `PASS`.

These are review/deployment follow-ups, not pipeline verdicts. No production writer or scheduled task was manually started, stopped, or altered during this task.
