# QUA-95 Blocked Heartbeat Task Smoke (2026-04-27)

Task (smoke): `QM_QUA95_BlockedHeartbeat_Smoke`

## Preview

```text
preview_task_name=QM_QUA95_BlockedHeartbeat_60min
preview_interval_minutes=60
preview_action=PowerShell -NoProfile -ExecutionPolicy Bypass -File "C:\QM\repo\infra\scripts\Invoke-QUA95BlockedHeartbeat.ps1" -RepoRoot "C:\QM\repo"
```

## Install

```text
installed_task=QM_QUA95_BlockedHeartbeat_Smoke
```

## Query highlights

```text
TaskName: \QM_QUA95_BlockedHeartbeat_Smoke
Scheduled Task State: Enabled
Run As User: SYSTEM
Task To Run: powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\QM\repo\infra\scripts\Invoke-QUA95BlockedHeartbeat.ps1" -RepoRoot "C:\QM\repo"
Repeat: Every: 1 Hour(s), 0 Minute(s)
```

## Cleanup

```text
SUCCESS: The scheduled task "QM_QUA95_BlockedHeartbeat_Smoke" was successfully deleted.
```
