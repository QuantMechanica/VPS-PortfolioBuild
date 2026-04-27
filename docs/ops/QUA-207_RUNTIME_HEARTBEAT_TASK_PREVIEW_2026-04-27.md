# QUA-207 Runtime Heartbeat Task Preview (2026-04-27)

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-QUA207RuntimeHeartbeatTask.ps1 -RepoRoot C:\QM\repo -EveryMinutes 30 -PreviewOnly
```

Output:

```text
preview_task_name=QM_QUA207_RuntimeHeartbeat_30min
preview_interval_minutes=30
preview_action=PowerShell -NoProfile -ExecutionPolicy Bypass -File "C:\QM\repo\infra\scripts\Run-QUA207RuntimeCompletionHeartbeat.ps1" -RepoRoot "C:\QM\repo"
```

Notes:

- Preview-only mode used intentionally; no scheduler mutation performed in this step.
- Action wiring resolves to the canonical QUA-207 runtime completion heartbeat runner.
