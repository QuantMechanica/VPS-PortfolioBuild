# QUA-615 Installer Preview Coverage (2026-05-01)

- total_installers: 17
- preview_only_supported: 14
- preview_only_missing: 3

| installer | preview_only |
|---|---|
| Install-AggregatorStateTask.ps1 | True |
| Install-Class2ExecutionPolicySentinelTask.ps1 | True |
| Install-DriveGitExclusionTask.ps1 | True |
| Install-DwxHourlyRoutine.ps1 | False |
| Install-DwxHourlyTask.ps1 | True |
| Install-DwxSpecPatchRunner.ps1 | False |
| Install-GitIndexLockMonitorTask.ps1 | True |
| Install-MainArtifactPreCommitHook.ps1 | False |
| Install-PaperclipStaleLockWatchdogTask.ps1 | True |
| Install-QUA207RuntimeHeartbeatTask.ps1 | True |
| Install-QUA93BlockerRefreshTask.ps1 | True |
| Install-QUA95BlockedHeartbeatTask.ps1 | True |
| Install-QUA95BlockerRefreshTask.ps1 | True |
| Install-QUA95RuntimeRestoreTask.ps1 | True |
| Install-QUA95TaskHealthTask.ps1 | True |
| Install-RuntimeHealthScanTask.ps1 | True |
| Install-TokenCostObservabilityTasks.ps1 | True |

## Missing PreviewOnly
- Install-DwxHourlyRoutine.ps1
- Install-DwxSpecPatchRunner.ps1
- Install-MainArtifactPreCommitHook.ps1
