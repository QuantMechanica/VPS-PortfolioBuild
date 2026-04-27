# Drive/Git Hard-Fence Runbook (PC1-00)

Purpose: verify and continuously enforce that repository roots and git metadata (`.git` directory or worktree `gitdir`) never enter Google Drive sync scope.

## Hard Rules

- `.git` must never be inside a Drive-synced root.
- Any repo in Drive scope is a `critical` incident class (V4 mass-delete risk).
- Reparse-point `.git` entries are not allowed for fence verification.

## Manual Verification

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\monitoring\Test-DriveGitExclusion.ps1
```

Exit codes:

- `0` = `ok` (hard fence intact)
- `1` = `warn` (limited check scope or non-required repo missing)
- `2` = `critical` (hard fence violated)

## Recurring Scheduler Check (Idempotent)

Install/converge task:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-DriveGitExclusionTask.ps1 -EveryMinutes 15
```

Task name:

- `QM_DriveGitExclusion_15min`

Quick validation:

```powershell
Get-ScheduledTask -TaskName QM_DriveGitExclusion_15min | Format-List TaskName,State
Get-ScheduledTaskInfo -TaskName QM_DriveGitExclusion_15min | Format-List LastRunTime,LastTaskResult,NextRunTime
```

## Incident Response (Critical)

1. Stop any git automation touching affected repo(s).
2. Move repo out of Drive sync roots (or fix Drive exclusions) before resuming writes.
3. Re-run `Test-DriveGitExclusion.ps1` until status is `ok`.
4. Confirm stale lock monitoring and per-repo mutex controls remain active:
   - `QM_GitIndexLockMonitor_10min`
   - `infra\scripts\Invoke-GitWithMutex.ps1`

## Related Controls

- `infra\monitoring\Invoke-GitIndexLockMonitor.ps1`
- `infra\scripts\Install-GitIndexLockMonitorTask.ps1`
- `infra\scripts\Ensure-AgentWorktree.ps1`
- `infra\tasks\Register-QMInfraTasks.ps1`
