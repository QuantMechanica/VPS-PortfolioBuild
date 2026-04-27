# QUA-95 Blocker Refresh Task Smoke Test (2026-04-27)

Goal: validate `Install-QUA95BlockerRefreshTask.ps1` can register a periodic task with expected action chain.

## Commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-QUA95BlockerRefreshTask.ps1 -TaskName QM_QUA95_BlockerRefresh_Smoke -EveryMinutes 60
schtasks /Query /TN "QM_QUA95_BlockerRefresh_Smoke" /V /FO LIST
schtasks /Delete /TN "QM_QUA95_BlockerRefresh_Smoke" /F
```

## Result

- Install script reported:
  - `installed_task=QM_QUA95_BlockerRefresh_Smoke`
- `schtasks /Query` confirmed:
  - task exists in root folder
  - `Run As User: SYSTEM`
  - hourly repetition
  - action chain includes:
    - `Invoke-VerifyDisposition.ps1`
    - `Update-QUA95BlockerStatus.ps1`
    - `Write-QUA95BlockedSummary.ps1`
    - `Test-QUA95HandoffIntegrity.ps1`
- Cleanup succeeded:
  - `SUCCESS: The scheduled task "QM_QUA95_BlockerRefresh_Smoke" was successfully deleted.`

## Notes

- Initial installer implementation used `TimeSpan::MaxValue` for repetition duration, which Task Scheduler rejected.
- Patched to `New-TimeSpan -Days 3650` and smoke passed.
