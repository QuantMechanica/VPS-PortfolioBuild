# QUA-11 Acceptance Evidence - 2026-04-26

## Scope

Issue: QUA-11 DevOps Day-1 - DWX heartbeat-script fix + infra audit.

## Evidence

1. DWX service heartbeat now includes wall-clock UTC field.
- Patched and rebuilt `D:\QM\mt5\T1\MQL5\Services\Import_DWX_Queue_Service.mq5`.
- Added explicit heartbeat-semantics comment block at the top of `Import_DWX_Queue_Service.mq5` documenting `alive`, `broker_time`, `wall_clock_utc`, and `utc_epoch` plus weekend semantics.
- Compile result: `0 errors, 0 warnings` in `Import_DWX_Queue_Service.compile.log`.
- After controlled T1 terminal restart, heartbeat content:

```text
alive=1777074899
broker_time=2026.04.24 23:54
wall_clock_utc=2026-04-26T19:04:58Z
utc_epoch=1777230298
processed_this_loop=0
```

- Validator run (`infra/monitoring/Test-DwxHeartbeat.ps1`) returned `status=ok` at `2026-04-26T19:05:20Z`.

2. Drive-sync `.git/` exclusion verification.
- Validator run (`infra/monitoring/Test-DriveGitExclusion.ps1`) returned:
  - `repo_root=C:\QM\repo`
  - `in_drive_sync_root=false`
  - `status=ok`

3. Daily backup smoke complete.
- Smoke run (`infra/monitoring/Test-BackupSmoke.ps1`) returned `status=ok`.
- Verified artifacts include:
  - `backup_manifest.json`
  - copied `last_check_state.json`
  - copied `paperclip.sqlite`

4. Hourly cadence lock + observed tick.
- Converged `QM_DWX_HourlyCheck` via `infra/scripts/Install-DwxHourlyTask.ps1`.
- `Test-HourlyTaskTick.ps1` result:
  - `repetition_interval=PT1H`
  - `last_run_time=2026-04-26T19:00:00Z`
  - `status=ok`

## Notes

- `alive` and `broker_time` remain broker-time-driven and can appear static during weekend market close.
- Monitoring now uses `wall_clock_utc` or `utc_epoch` for freshness to avoid weekend false positives.
