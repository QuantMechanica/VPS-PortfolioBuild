# PC1-00 Drive/Git Mitigation Plan (2026-04-27)

## Scope

Issue: `QUA-181`  
Goal: close the V4 mass-delete incident class by converging three controls:

1. Per-repo git writer mutex.
2. Stale `.git/index.lock` monitor on scheduler cadence.
3. Agent CWD isolation through git worktrees.

## Deliverables

- `infra/scripts/Invoke-GitWithMutex.ps1`
  - Wraps git operations in a repo-specific named mutex.
- `infra/monitoring/Invoke-GitIndexLockMonitor.ps1`
  - Detects stale locks and emits machine-readable status.
- `infra/scripts/Install-GitIndexLockMonitorTask.ps1`
  - Idempotent scheduler installer (`QM_GitIndexLockMonitor_10min`).
- `infra/scripts/Ensure-AgentWorktree.ps1`
  - Idempotent per-agent worktree convergence under `C:\QM\worktrees\`.
- `infra/tasks/Register-QMInfraTasks.ps1`
  - Includes `QM_GitIndexLockMonitor_10min` convergence.

## Install / Converge Commands

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-GitIndexLockMonitorTask.ps1 -EveryMinutes 10 -StaleAfterMinutes 20 -FailOnFinding
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Ensure-AgentWorktree.ps1 -AgentKey devops -CreateBranchIfMissing
```

## Operational Rules

- All automation that performs `git add/commit/push` should execute via:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Invoke-GitWithMutex.ps1 -RepoRoot C:\QM\repo -GitCommand commit -GitArguments "-m","message"
```

- Do not keep `.git/` inside Drive sync scope (PC1-00 hard rule remains unchanged).
- Do not remove `index.lock` unless it is stale and no active git process references the repo.

## Verification

- Monitor output:
  - `C:\QM\logs\infra\health\git_index_lock_monitor_latest.json`
- Task registration:
  - `Get-ScheduledTask -TaskName QM_GitIndexLockMonitor_10min`
- Worktree proof artifact:
  - `docs/ops/PC1-00_WORKTREE_PROOF_2026-04-27.md`
