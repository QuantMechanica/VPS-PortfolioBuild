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
    - QUA-95 blocker refresh task health (`QM_QUA95_BlockerRefresh`)
    - QUA-95 issue-transition payload consistency (`Test-QUA95IssueTransitionPayload.ps1`)
    - QUA-95 blocked invariant enforcement (`Test-QUA95BlockedInvariant.ps1`)
    - QUA-95 handoff integrity (`Test-QUA95HandoffIntegrity.ps1`)
    - QUA-95 blocked assertion freshness (`QUA-95_BLOCKED_STATE_ASSERTION_2026-04-27.md`)
    - QUA-95 unblock-readiness freshness (`QUA-95_UNBLOCK_READINESS_2026-04-27.json`)
    - QUA-95 ops bundle manifest integrity (`Test-QUA95OpsBundleManifest.ps1`)
    - QUA-95 blocked-heartbeat wrapper validation (`Test-QUA95BlockedHeartbeatWrapper.ps1`)
  - Writes machine-readable JSON report to `infra/reports/infra_audit_latest.json`.
- `scripts/Install-AggregatorStateTask.ps1`
  - Registers Task Scheduler job `QM_AggregatorState_1min` as `SYSTEM`.
  - Runs `scripts/aggregator/standalone_aggregator_loop.py --once` every minute.
  - Safe to re-run (`Register-ScheduledTask -Force`) and overlap-safe (`MultipleInstances=IgnoreNew`).
- `scripts/Install-PaperclipStaleLockWatchdogTask.ps1`
  - Registers Task Scheduler job `QM_PaperclipStaleLockWatchdog_15min` as `SYSTEM`.
  - Runs `monitoring/Invoke-PaperclipStaleLockWatchdog.ps1 -StaleAfterMinutes 15 -FailOnFinding` every 15 minutes (monitor-only).
  - Safe to re-run (`Register-ScheduledTask -Force`) and overlap-safe (`MultipleInstances=IgnoreNew`).
- `scripts/Install-QUA95BlockerRefreshTask.ps1`
  - Registers Task Scheduler job `QM_QUA95_BlockerRefresh` as `SYSTEM` (hourly by default).
  - Action chain: verifier rerun -> blocker sync -> blocked summary -> handoff integrity check.
  - Safe to re-run (`Register-ScheduledTask -Force`).
- `scripts/Install-QUA95TaskHealthTask.ps1`
  - Registers Task Scheduler job `QM_QUA95_TaskHealth_15min` as `SYSTEM`.
  - Runs `monitoring/Test-QUA95BlockerTaskHealth.ps1` on a 15-minute cadence.
  - Passes explicit `-TransitionPayloadCheckScript` and `-UnblockReadinessCheckScript` paths to avoid hidden default/path drift.
  - Safe to re-run (`Register-ScheduledTask -Force`).
- `scripts/Run-QUA95BlockerRefresh.ps1`
  - Scheduled runner used by `QM_QUA95_BlockerRefresh`.
  - Logs to `infra\smoke\qua95_blocker_refresh_task.log`.
  - Refreshes handoff SHA manifest before integrity validation.
  - Enforces blocked invariant (`scripts/Test-QUA95BlockedInvariant.ps1`) in-run.
  - Auto-refreshes both unblock-readiness JSON and markdown summary artifacts.
- `scripts/Invoke-QUA95BlockedHeartbeat.ps1`
  - One-command heartbeat wrapper for blocked QUA-95 operations.
  - Runs blocker refresh + infra audit + blocked assertion sync + blocked-invariant check + unblock-readiness snapshot + unblock-readiness summary + ops-suite snapshot + ops-bundle manifest, then writes consolidated status JSON.
- `scripts/Update-QUA95BlockedAssertion.ps1`
  - Regenerates blocked-state assertion markdown from canonical gate + blocker JSON.
- `scripts/Install-QUA95BlockedHeartbeatTask.ps1`
  - Registers a dedicated `SYSTEM` scheduler task for the blocked-heartbeat wrapper.
  - Safe to re-run (`Register-ScheduledTask -Force`).
- `scripts/Install-DwxSpecPatchRunner.ps1`
  - Converges a non-interactive MT5 startup INI from one patch version to another (default: `v2 -> v3`).
  - Check-then-act writes: updates target only when content differs.
  - Enforces `ShutdownTerminal=1` and refuses T6 paths by default.
- `scripts/Confirm-DwxRegistryMitigation.ps1`
  - Emits machine-readable QUA-69 evidence for registry-corruption mitigation confirmation.
  - Verifies >= 3 successful `Fix_DWX_Spec_v3` terminal-close events from latest T1 log, throttling markers (`BATCH|processed=5|sleep_ms=200`), and non-truncated `symbols.custom.dat` size.
  - Writes JSON output to `lessons-learned/evidence/qua69_registry_mitigation_confirmation.json`.
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
- `monitoring/Test-QUA95BlockerTaskHealth.ps1`
  - Validates task existence, enabled state, last result, and staleness window for `QM_QUA95_BlockerRefresh`.
  - Validates QUA-95 transition payload consistency via `scripts/Test-QUA95IssueTransitionPayload.ps1`.
  - Validates QUA-95 unblock readiness consistency via `scripts/Test-QUA95UnblockReadiness.ps1`.
  - Returns non-zero on critical task-health drift.
- `monitoring/Test-QUA95BlockedHeartbeatWrapper.ps1`
  - Runs `Invoke-QUA95BlockedHeartbeat.ps1` in non-recursive validation mode
    (`-SkipRefresh -SkipAudit`) and validates
    consolidated heartbeat JSON structure and key blocked-state fields.
  - Use `-RunRefresh` to include refresh execution in validation runs.
- `monitoring/Test-QUA95AutomationHealth.ps1`
  - Combined scheduler-health check for `QM_QUA95_BlockerRefresh` and `QM_QUA95_TaskHealth_15min`.
  - Writes machine-readable snapshot to `docs/ops/QUA-95_AUTOMATION_HEALTH_2026-04-27.json`.
- `scripts/Test-QUA95OpsSuite.ps1`
  - Runs core QUA-95 ops checks as one suite and emits JSON summary.
- `scripts/Test-QUA95OpsBundleManifest.ps1`
  - Verifies hash consistency for the QUA-95 blocked-ops bundle manifest.
- `scripts/Write-QUA95OpsSuiteSnapshot.ps1`
  - Runs the QUA-95 ops suite and persists the JSON snapshot artifact.
- `scripts/Update-QUA95OpsBundleManifest.ps1`
  - Regenerates SHA256 manifest for core QUA-95 blocked-ops artifact bundle.
- `scripts/Test-QUA95IssueTransitionPayload.ps1`
  - Validates that `docs/ops/QUA-95_ISSUE_TRANSITION_PAYLOAD_2026-04-27.json`
    is consistent with gate + blocker canonical JSON artifacts.
  - Returns non-zero on mismatch and is consumed by `Invoke-InfraAudit.ps1`.
- `scripts/Test-QUA95UnblockReadiness.ps1`
  - Validates unblock-readiness artifact freshness/consistency against blocker status.
  - Returns non-zero on drift.
- `scripts/Update-QUA95UnblockReadiness.ps1`
  - Writes machine-readable unblock readiness snapshot with `ready_to_unblock`, unmet criteria, and unblock owners/actions.
- `scripts/Write-QUA95UnblockReadinessSummary.ps1`
  - Writes a deterministic human-readable summary from the unblock-readiness JSON.
- `scripts/Test-QUA95UnblockReadinessSummary.ps1`
  - Validates that unblock-readiness markdown summary stays aligned with canonical readiness JSON.
- `scripts/Test-QUA95BlockedInvariant.ps1`
  - Enforces blocked/defer invariant when `bars_got <= 0` using gate + transition payload artifacts.
  - Returns non-zero if blocked-state policy drifts.
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

QUA-95 blocker refresh task (hourly):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-QUA95BlockerRefreshTask.ps1 -EveryMinutes 60
```

QUA-95 task-health monitor (every 15 minutes):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-QUA95TaskHealthTask.ps1 -EveryMinutes 15 -MaxAgeMinutes 125
```

QUA-95 blocked heartbeat wrapper task (hourly):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-QUA95BlockedHeartbeatTask.ps1 -EveryMinutes 60
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

Registry mitigation confirmation (`QUA-69` evidence):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Confirm-DwxRegistryMitigation.ps1 -FailOnInsufficientEvidence
```
