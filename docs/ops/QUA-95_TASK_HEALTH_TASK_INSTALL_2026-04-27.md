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
  - `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\QM\repo\infra\monitoring\Test-QUA95BlockerTaskHealth.ps1" -MaxAgeMinutes 125 -TransitionPayloadCheckScript "C:\QM\repo\infra\scripts\Test-QUA95IssueTransitionPayload.ps1" -UnblockReadinessCheckScript "C:\QM\repo\infra\scripts\Test-QUA95UnblockReadiness.ps1" -AuditSignalCheckScript "C:\QM\repo\infra\scripts\Test-QUA95AuditSignal.ps1"`
  - Script now enforces transition-payload, unblock-readiness, and audit-signal consistency as part of health status.

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

## Post-hardening runtime proof

Manual trigger after adding transition-payload enforcement:

```powershell
schtasks /Run /TN "QM_QUA95_TaskHealth_15min"
schtasks /Query /TN "QM_QUA95_TaskHealth_15min" /V /FO LIST
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\monitoring\Test-QUA95BlockerTaskHealth.ps1 -MaxAgeMinutes 125
```

Observed fields:
- `Last Run Time: 4/27/2026 10:28:41 AM`
- `Last Result: 0`
- direct check output: `status=ok task=QM_QUA95_BlockerRefresh ...`

## Live readiness-wiring proof

Executed:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-QUA95TaskHealthTask.ps1 -EveryMinutes 15 -MaxAgeMinutes 125
schtasks /Run /TN "QM_QUA95_TaskHealth_15min"
schtasks /Query /TN "QM_QUA95_TaskHealth_15min" /V /FO LIST
```

Observed:
- installer output: `installed_task=QM_QUA95_TaskHealth_15min`
- scheduler run attempt: `SUCCESS`
- post-run `Last Run Time: 4/27/2026 11:39:13 AM`
- post-run `Last Result: 0`

Full action argument (PowerShell API):

```text
-NoProfile -ExecutionPolicy Bypass -File "C:\QM\repo\infra\monitoring\Test-QUA95BlockerTaskHealth.ps1" -MaxAgeMinutes 125 -TransitionPayloadCheckScript "C:\QM\repo\infra\scripts\Test-QUA95IssueTransitionPayload.ps1" -UnblockReadinessCheckScript "C:\QM\repo\infra\scripts\Test-QUA95UnblockReadiness.ps1" -AuditSignalCheckScript "C:\QM\repo\infra\scripts\Test-QUA95AuditSignal.ps1"
```

## Audit-signal wiring proof

Executed:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-QUA95TaskHealthTask.ps1 -PreviewOnly
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-QUA95TaskHealthTask.ps1 -EveryMinutes 15 -MaxAgeMinutes 125
schtasks /Run /TN "QM_QUA95_TaskHealth_15min"
```

Observed:
- `preview_audit_signal_check_script=C:\QM\repo\infra\scripts\Test-QUA95AuditSignal.ps1`
- preview action contains `-AuditSignalCheckScript "C:\QM\repo\infra\scripts\Test-QUA95AuditSignal.ps1"`
- scheduler post-run `Last Result: 0`
