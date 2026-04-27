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
  - Parses `verify_import.py` output and emits diagnostics when FAIL rows show a systemic pattern (`bars expected>0` with `got=0` across many symbols), preventing false symbol-level triage.
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
- `scripts/Install-AggregatorStateTask.ps1`
  - Registers Task Scheduler job `QM_AggregatorState_1min` as `SYSTEM`.
  - Runs `scripts/aggregator/standalone_aggregator_loop.py --once` every minute.
  - Safe to re-run (`Register-ScheduledTask -Force`) and overlap-safe (`MultipleInstances=IgnoreNew`).
- `scripts/Install-PaperclipStaleLockWatchdogTask.ps1`
  - Registers Task Scheduler job `QM_PaperclipStaleLockWatchdog_15min` as `SYSTEM`.
  - Runs `monitoring/Invoke-PaperclipStaleLockWatchdog.ps1 -StaleAfterMinutes 15 -FailOnFinding` every 15 minutes (monitor-only).
  - Safe to re-run (`Register-ScheduledTask -Force`) and overlap-safe (`MultipleInstances=IgnoreNew`).
- `scripts/Install-DwxSpecPatchRunner.ps1`
  - Converges a non-interactive MT5 startup INI from one patch version to another (default: `v2 -> v3`).
  - Check-then-act writes: updates target only when content differs.
  - Enforces `ShutdownTerminal=1` and refuses T6 paths by default.
- `scripts/Remove-RecoveryOrphans.ps1`
  - Cleans `D:\QM\_recovery_orphans_*` directories after the 24h hold window.
  - Idempotent check-then-act delete flow with retries for transient remove failures.
  - Writes JSON run logs to `D:\QM\reports\infra\recovery_orphans\`.
- `scripts/Fix_DWX_Spec_v3.mq5`
  - Corrected DWX custom-symbol spec patch (`tvp/tvl` excluded from writable/settable fields).
  - Enforces `spec_ok := custom.tv > 0 and rel_err(custom.tv, broker.tv) < 0.05`.
  - Includes batch throttling (`5` symbols + `Sleep(200)`).
- `monitoring/Test-DwxHeartbeat.ps1`
  - Validates DWX service heartbeat freshness from content.
  - Requires `wall_clock_utc` field for strict `ok`; missing field is `warn`.
- `monitoring/Test-DriveGitExclusion.ps1`
  - Verifies repo path is outside known Google Drive sync roots (PC1-00 guard).
- `monitoring/Test-BackupSmoke.ps1`
  - Runs backup workflow in an isolated temp workspace and asserts manifest/artifacts.
- `monitoring/Invoke-PaperclipStaleLockWatchdog.ps1`
  - Detects stale Paperclip execution locks (`executionLockedAt` stale while `activeRun=null`) on targeted assignees/issues.
  - Default mode is monitor-only (no mutations); optional `-AutoRecover` performs PATCH-only assignee-cycle recovery.
  - Adds `X-Paperclip-Run-Id` header on all mutating PATCH calls.
- `tasks/Test-HourlyTaskTick.ps1`
  - Verifies `QM_DWX_HourlyCheck` is hourly (`PT1H`) and has at least one observed completed tick.
- `paperclip-stale-lock-runbook.md`
  - Manual and platform recovery flow for stale `checkoutRunId` / `executionRunId` lock conflicts (QUA-24).
  - Documents the comment-side-effect and PATCH-only assignee-cycle workaround.
  - Includes stale-run watchdog duplicate-suppression patch notes for source-derived issues (QUA-67 / DEVOPS-008).

## Recommended scheduler wiring

DWX heartbeat (hourly HH:07 baseline):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-DwxHourlyTask.ps1 -MinuteOffset 7
```

Infra audit (hourly, can run at HH:12 or similar):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Invoke-InfraAudit.ps1 -FailOnCritical
```

Paperclip stale-lock watchdog (every 10-15 minutes, monitor-only):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\monitoring\Invoke-PaperclipStaleLockWatchdog.ps1 -StaleAfterMinutes 15
```

Install the scheduler task (idempotent):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-PaperclipStaleLockWatchdogTask.ps1
```

Aggregator state writer (every minute):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-AggregatorStateTask.ps1
```

Recovery orphan cleanup (daily schedule is managed by `tasks/Register-QMInfraTasks.ps1`):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Remove-RecoveryOrphans.ps1
```

## Non-goals

- No EA strategy code changes.
- No T6 live automation mutations.
- No secret material in repo.

## T1 DWX spec patch runner (operational)

Converge current patch launcher (`v3` baseline) from prior known-good launcher (`v2`):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-DwxSpecPatchRunner.ps1 -TerminalRoot D:\QM\mt5\T1 -FromVersion v2 -ToVersion v3
```

Run after convergence:

```powershell
D:\QM\mt5\T1\terminal64.exe /portable /config:D:\QM\mt5\T1\run_fix_dwx_spec_v3.ini
```

Use only on T1; do not point this flow at T6 paths.
