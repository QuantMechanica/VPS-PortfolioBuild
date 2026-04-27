# QUA-187 Closeout Evidence (2026-04-27)

## Scope
Integrate `infra/monitoring/Invoke-GitIndexLockMonitor.ps1` into canonical health surfaces.

## Integrated surfaces
- `infra/scripts/Invoke-InfraAudit.ps1`
  - check: `stale_git_index_lock`
  - delegates to monitor script via `-RepoRoots` + `-StaleAfterMinutes`
- `infra/monitoring/Invoke-InfraHealthCheck.ps1`
  - check: `git_index_lock`
  - delegates to monitor script via `-RepoRoots` + `-StaleAfterMinutes`

## Verification run
- UTC: 2026-04-27T14:25:36.1369800Z
- Command 1:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Invoke-InfraAudit.ps1 -OutJson C:\QM\repo\artifacts\qua-187\infra_audit_qua187_verify.json`
  - `audit_exit_code=0`, `audit_overall=critical`, `stale_git_index_lock=ok`
- Command 2:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\monitoring\Invoke-InfraHealthCheck.ps1`
  - `health_exit_code=2`, `health_overall=critical`, `git_index_lock=ok`

## Artifacts
- `artifacts/qua-187/infra_audit_qua187_verify.json`
- `artifacts/qua-187/verification_summary.json`
- `C:\QM\logs\infra\health\infra_health_latest.json`

## Related commits
- `2636012` `infra: route stale index.lock audit check through monitor script`
- `d5efef3` `infra(pc1-00): add worktree-aware drive fence evidence and alert routing`
