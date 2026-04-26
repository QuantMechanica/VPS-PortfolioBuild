# Infra (DevOps)

Idempotent infrastructure scripts for QuantMechanica V5. Re-running these scripts must converge to the same desired state.

## Day-1 assets (QUA-11)

- `scripts/Invoke-DwxHourlyCheck.ps1`
  - Hourly DWX orchestrator heartbeat.
  - Uses lock-file + stale-lock cleanup to avoid overlap.
  - WS30 gate + per-symbol check-then-act staging.
  - Writes run logs and `dwx_hourly_state.json`.
- `scripts/dwx_hourly_check.py`
  - Canonical DWX Python orchestrator used by `QM_DWX_HourlyCheck`.
  - Includes source-symbol pre-flight (`tick_value > 0`, currencies present) before staging.
  - Readiness verdict is strict: missing symbols, pending queue, stale service heartbeat, bad symbol spec, or missing commission file => `OVERALL=NOT_READY`.
- `scripts/Install-DwxHourlyTask.ps1`
  - Registers Task Scheduler job `QM_DWX_HourlyCheck` as `SYSTEM` (works when no user is logged in).
  - Safe to re-run (`Register-ScheduledTask -Force`).
  - Uses `MultipleInstances=IgnoreNew` to prevent concurrent overlap.
- `scripts/Invoke-InfraAudit.ps1`
  - Audits core infra health checks:
    - disk free thresholds
    - T1-T5 terminal liveness
    - T6 live/demo isolation signal
    - Paperclip daemon process health
    - aggregator freshness
    - Google Drive sync freshness
    - stale `.git/index.lock` detection
  - Writes machine-readable JSON report to `infra/reports/infra_audit_latest.json`.
- `monitoring/Test-DwxHeartbeat.ps1`
  - Validates DWX service heartbeat freshness from content.
  - Requires `wall_clock_utc` field for strict `ok`; missing field is `warn`.
- `monitoring/Test-DriveGitExclusion.ps1`
  - Verifies repo path is outside known Google Drive sync roots (PC1-00 guard).
- `monitoring/Test-BackupSmoke.ps1`
  - Runs backup workflow in an isolated temp workspace and asserts manifest/artifacts.
- `tasks/Test-HourlyTaskTick.ps1`
  - Verifies `QM_DWX_HourlyCheck` is hourly (`PT1H`) and has at least one observed completed tick.

## Recommended scheduler wiring

DWX heartbeat (hourly HH:07 baseline):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-DwxHourlyTask.ps1 -MinuteOffset 7
```

Infra audit (hourly, can run at HH:12 or similar):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Invoke-InfraAudit.ps1 -FailOnCritical
```

## Non-goals

- No EA strategy code changes.
- No T6 live automation mutations.
- No secret material in repo.
