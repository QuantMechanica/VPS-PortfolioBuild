# QUA-521 Runtime Health Scan Task Proof (2026-04-29)

## Commits

- `8af831a9` - initial task + wiring + docs
- `9eab9d78` - runtime execution fix (`ArgumentException` path removed)
- `08726513` - scheduler/install and execution-path hardening
- `8352a945` - detector/action flow adjustments
- `74df4615` - closeout evidence sync
- `bf7ec8e5` - review-requested fixes (P0-only bottleneck + commit-list alignment)

## Scheduler state

Task: `QM_RuntimeHealthScan_15min`

- Action:
  - `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\QM\repo\infra\scripts\Run-RuntimeHealthScan.ps1" -OutputPath "C:\QM\logs\infra\health\runtime_health_scan_latest.json"`
- Principal: `SYSTEM`
- Repetition: `15 minutes`
- Multiple instances: `IgnoreNew`

## Live run proof

Manual trigger timestamp (local): `2026-04-29 22:41:41 +02:00`

`Get-ScheduledTaskInfo` snapshot:

- `LastRunTime`: `2026-04-29T22:41:41+02:00`
- `LastTaskResult`: `1` (alert state from active detector findings)
- `NextRunTime`: `2026-04-29T22:46:46+02:00`

Artifact output:

- Path: `C:\QM\logs\infra\health\runtime_health_scan_latest.json`
- `LastWriteTime`: `2026-04-29T22:41:18+02:00`
- `Length`: `4171` bytes

## Notes

- Task is installed in execution mode (no `-DryRun` in scheduled action).
- Script dry-run path was validated after runtime fix; non-dry-run path is active under scheduler.
