# QUA-95 Blocker Refresh Task Install Record (2026-04-27)

Task: `QM_QUA95_BlockerRefresh`  
Host: `WIN-B95G5LPSJ1O`

## Install command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-QUA95BlockerRefreshTask.ps1 -TaskName QM_QUA95_BlockerRefresh -EveryMinutes 60
```

Install output:

```text
installed_task=QM_QUA95_BlockerRefresh
```

## Verification command

```powershell
schtasks /Query /TN "QM_QUA95_BlockerRefresh" /V /FO LIST
```

Verified highlights:
- `TaskName: \QM_QUA95_BlockerRefresh`
- `Scheduled Task State: Enabled`
- `Run As User: SYSTEM`
- `Schedule Type: One Time Only, Hourly`
- `Repeat: Every: 1 Hour(s), 0 Minute(s)`
- Task action chain includes:
  - `Invoke-VerifyDisposition.ps1`
  - `Update-QUA95BlockerStatus.ps1`
  - `Write-QUA95BlockedSummary.ps1`
  - `Test-QUA95HandoffIntegrity.ps1`
