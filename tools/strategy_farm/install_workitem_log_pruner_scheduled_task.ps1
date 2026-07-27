# Installs QM_WorkItemLogPruner_Daily_0310 — prunes redundant raw MT5 backtest
# journals (*.log) from durable report surfaces every 3 hours.
#
# PRINCIPAL = SYSTEM (ServiceAccount), deliberately.
# prune_workitem_logs.py only touches local D: paths (the farm_state.sqlite DB and
# D:\QM\reports work_item / pipeline* .log files). It spawns no terminal64, reads no
# per-user DPAPI credential, and needs no G: (Google Drive) mount or interactive
# desktop. It was historically registered LogonType=Interactive purely by copy-paste
# inheritance; after the 2026-07-26 session handover left qm-admin's only session
# Disconnected, every InteractiveToken trigger queued (event 325) and never started
# (LastTaskResult 0x800710E0). SYSTEM runs in session 0 regardless of interactive
# session state, so the task is reliable (evidence:
# docs/ops/evidence/2026-07-27_interactive_task_selfheal_fix.md).
#
# Rollback (restore the prior Interactive principal):
#   $p = New-ScheduledTaskPrincipal -UserId 'qm-admin' -LogonType Interactive -RunLevel Highest
#   Set-ScheduledTask -TaskName 'QM_WorkItemLogPruner_Daily_0310' -Principal $p
$ErrorActionPreference = 'Stop'

$TaskName = 'QM_WorkItemLogPruner_Daily_0310'
$Python   = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe'
$Script   = 'C:\QM\repo\tools\strategy_farm\prune_workitem_logs.py'

if (-not (Test-Path $Python)) { throw "python not found: $Python" }
if (-not (Test-Path $Script)) { throw "script not found: $Script" }

$action    = New-ScheduledTaskAction -Execute $Python -Argument "`"$Script`" --older-than-days 0"
$trigger   = New-ScheduledTaskTrigger -Once -At ([datetime]'03:10') `
             -RepetitionInterval (New-TimeSpan -Hours 3) -RepetitionDuration ([TimeSpan]::FromDays(3650))
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew `
             -ExecutionTimeLimit (New-TimeSpan -Minutes 30)

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal `
    -Settings $settings -Description 'Every 3h: prune redundant raw MT5 *.log journals from D:\QM\reports. Runs as SYSTEM (headless, local-D-only; no desktop/DPAPI/G: dependency).' -Force | Out-Null

$t = Get-ScheduledTask -TaskName $TaskName
if ([string]$t.Principal.LogonType -ne 'ServiceAccount') { throw "unexpected LogonType: $($t.Principal.LogonType)" }
if ([string]$t.Principal.UserId -notmatch 'SYSTEM') { throw "unexpected principal: $($t.Principal.UserId)" }
"installed: {0} | state={1} | user={2} | logon={3}" -f $TaskName, $t.State, $t.Principal.UserId, $t.Principal.LogonType
