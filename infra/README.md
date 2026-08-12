# QuantMechanica Infrastructure

This directory contains local, deterministic VPS infrastructure. It has no external
agent-company, role-hierarchy, or issue-system dependency.

## Active components

- `backup.ps1` — daily backup and retention workflow.
- `monitoring/Invoke-InfraHealthCheck.ps1` — disk, MT5, DWX, Drive, aggregator,
  and Git-lock checks.
- `monitoring/Invoke-GitIndexLockMonitor.ps1` — canonical-repository lock monitor.
- `monitoring/Test-DriveGitExclusion.ps1` — repository/sync-root isolation check.
- `scripts/Invoke-DwxHourlyCheck.ps1` — hourly DWX import and verification.
- `tasks/Register-QMInfraTasks.ps1` — idempotent Windows Task Scheduler setup.

Run a non-mutating task-registration preflight with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File C:\QM\repo\infra\tasks\Register-QMInfraTasks.ps1 `
  -PreviewOnly
```

Only OWNER instructions plus deterministic evidence and the active pipeline
contracts authorize changes. T6/live and AutoTrading remain outside generic infra
automation.
