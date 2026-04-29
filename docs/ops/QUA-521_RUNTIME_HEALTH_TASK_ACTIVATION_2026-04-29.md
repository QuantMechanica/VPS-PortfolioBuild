# QUA-521 RuntimeHealthScan Task Activation (Blocked on Machine Env)

Date: 2026-04-29
Owner to unblock: CTO/Platform Ops
Blocker: `PAPERCLIP_POSTGRES_URL` not present as Machine environment variable on target host.

## 1) Set machine environment variable (elevated PowerShell)

```powershell
[Environment]::SetEnvironmentVariable('PAPERCLIP_POSTGRES_URL', '<postgres-connection-string>', 'Machine')
```

## 2) Install scheduled task (SYSTEM, every 15 min)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-RuntimeHealthScanTask.ps1 -UseMachineEnvPostgresUrl
```

## 3) Verify task registration

```powershell
Get-ScheduledTask -TaskName QM_RuntimeHealthScan_15min | Format-List TaskName,State
Get-ScheduledTaskInfo -TaskName QM_RuntimeHealthScan_15min | Format-List LastRunTime,LastTaskResult,NextRunTime
```

## 4) Force one run and inspect output

```powershell
Start-ScheduledTask -TaskName QM_RuntimeHealthScan_15min
Start-Sleep -Seconds 15
Get-Content C:\QM\logs\infra\health\runtime_health_scan_latest.json
```

## 5) Expected

- Task exists as `QM_RuntimeHealthScan_15min`
- Output JSON is present at `C:\QM\logs\infra\health\runtime_health_scan_latest.json`
- Scanner runs via PowerShell + `psql` path (no AI at execution time)
