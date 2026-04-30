# QUA-615 Progress Ledger (2026-05-01)

## Scheduler Hardening Commits
- ccc64e62 - normalize repeating trigger start boundaries
- 535ad8f6 - ensure runtime health task starts in future slot
- 2f2da48d - add git index-lock monitor task installer
- 8e824a87 - harden class2 sentinel scheduler boundary
- a156f677 - harden token-cost task start boundary
- c5cb6c8a - harden 15-min task installer start boundaries
- 49eb624e - fix now-relative start for QUA-95 schedulers
- 1bf19aef - fix midnight-relative boundaries in ops installers
- 81c224d3 - fix QUA-93 blocker refresh start boundary
- 3ef704fb - normalize DWX hourly task start boundary

## Preview-Mode Standardization Commits
- 4dda3650 - add PreviewOnly to Install-AggregatorStateTask
- f2c815c9 - add PreviewOnly to Install-GitIndexLockMonitorTask
- f1146ef6 - add PreviewOnly to Install-DwxHourlyTask
- 71a47aac - add PreviewOnly to Install-TokenCostObservabilityTasks
- e2c5c904 - add PreviewOnly to Install-MainArtifactPreCommitHook
- 1c9fc7e3 - add PreviewOnly to Install-DwxSpecPatchRunner
- 1c54e291 - add explicit PreviewOnly to Install-DwxHourlyRoutine
- 5d0b2493 - refresh coverage report to PreviewOnly 17/17

## Tracking and Evidence Commits
- a98f4f0b - add `infra/monitoring/Invoke-GitIndexLockMonitor.ps1`
- 7c4fba71 - add `infra/scripts/Commit-HeartbeatCheckpoint.ps1`
- ec2754fd - add QUA-346 blocked-heartbeat helper suite
- 18e09386 - add scheduler boundary hardening evidence report
- 0b4621f5 - add installer boundary audit report
- 562620a0 - add artifact scope status report
- f5fa3d91 - track commodity inventory markdown
- 77b6747a - refresh bond inventory markdown timestamp
- c5032b60 - document main-branch artifact guard workflow

## Current State
- Installer PreviewOnly coverage: 17/17
- Main-branch artifact policy: `artifacts/*` commits may be blocked (`main_artifact_policy_violation`)
- Evidence fallback path for blocked artifact commits: `infra/reports/*`
