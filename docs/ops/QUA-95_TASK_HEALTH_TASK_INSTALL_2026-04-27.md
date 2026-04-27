# QUA-95 Task Health Monitor Install Record (2026-04-27)

Task: `QM_QUA95_TaskHealth_15min`  
Host: `WIN-B95G5LPSJ1O`

## Install command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-QUA95TaskHealthTask.ps1 -EveryMinutes 15 -MaxAgeMinutes 125
```

Install output:

```text
installed_task=QM_QUA95_TaskHealth_15min
```

## Verification command

```powershell
schtasks /Query /TN "QM_QUA95_TaskHealth_15min" /V /FO LIST
```

Verified highlights:
- `TaskName: \QM_QUA95_TaskHealth_15min`
- `Scheduled Task State: Enabled`
- `Run As User: SYSTEM`
- `Repeat: Every: 0 Hour(s), 15 Minute(s)`
- Task action:
  - `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\QM\repo\infra\monitoring\Test-QUA95BlockerTaskHealth.ps1" -MaxAgeMinutes 125`
  - Script now also enforces `Test-QUA95IssueTransitionPayload.ps1` success as part of health status.

## Runtime proof

Manual trigger:

```powershell
schtasks /Run /TN "QM_QUA95_TaskHealth_15min"
```

Post-run scheduler fields:
- `Last Run Time: 4/27/2026 10:07:17 AM`
- `Last Result: 0`

## Negative-path monitor proof

Controlled check:
1. Temporarily disable `QM_QUA95_BlockerRefresh`.
2. Run `Test-QUA95BlockerTaskHealth.ps1` (expect critical).
3. Re-enable `QM_QUA95_BlockerRefresh`.
4. Run `Test-QUA95BlockerTaskHealth.ps1` again (expect ok).

Observed outputs:

```text
disabled_check_exit=2
status=critical task=QM_QUA95_BlockerRefresh issues=disabled
reenabled_check_exit=0
status=ok task=QM_QUA95_BlockerRefresh last_run=2026-04-27T10:13:13.0000000+02:00 age_minutes=1.92
```
