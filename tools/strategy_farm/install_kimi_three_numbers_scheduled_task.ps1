# Installs QM_TMP_KimiThreeNumbers_15min — refreshes the factory three-numbers
# health read-model (D:/QM/reports/state/factory_three_numbers.json) every
# 15 minutes.
#
# PRINCIPAL = qm-admin InteractiveToken, per the Kimi interim OWNER brief
# (2026-09-16). Known trade-off (docs/ops/evidence/2026-07-27_interactive_task_
# selfheal_fix.md): an Interactive-token task queues (event 325, LastTaskResult
# 0x800710E0) whenever qm-admin has no connected session. The task is
# deliberately QM_TMP_: if the read-model must outlive session loss, reinstall
# with -TaskUser SYSTEM (the pruner pattern). factory_three_numbers.py itself
# needs no desktop/DPAPI/G: — plain D:-local JSON write — so SYSTEM works; the
# Interactive principal was chosen to run in the owner's logged-on context.
#
# The script is read-only on farm_state.sqlite (mode=ro + query_only) and
# writes only the JSON output; pythonw keeps it off the desktop.
#
# Rollback:
#   Unregister-ScheduledTask -TaskName 'QM_TMP_KimiThreeNumbers_15min' -Confirm:$false
param(
    [string]$TaskUser = 'qm-admin'
)
$ErrorActionPreference = 'Stop'

$TaskName = 'QM_TMP_KimiThreeNumbers_15min'
$Pythonw  = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe'
$Script   = 'C:\QM\repo\tools\strategy_farm\factory_three_numbers.py'
$WorkDir  = 'C:\QM\repo'

if (-not (Test-Path $Pythonw)) { throw "pythonw not found: $Pythonw" }
if (-not (Test-Path $Script)) { throw "script not found: $Script" }

$action    = New-ScheduledTaskAction -Execute $Pythonw -Argument "`"$Script`"" -WorkingDirectory $WorkDir
$trigger   = New-ScheduledTaskTrigger -Once -At ([datetime]::Now.AddMinutes(1)) `
             -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration ([TimeSpan]::FromDays(3650))
$principal = New-ScheduledTaskPrincipal -UserId $TaskUser -LogonType Interactive -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew `
             -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal `
    -Settings $settings -Force `
    -Description 'Every 15 min (pythonw, qm-admin Interactive): refresh qm.factory-three-numbers/v1 read-model (active/true-claimable/blocked-recoverable + health RUNNING/IDLE_WITH_WORK/NO_RUNNABLE_WORK/IDLE_RED). Read-only on farm_state.sqlite; writes only D:\QM\reports\state\factory_three_numbers.json. QM_TMP_ per Kimi interim OWNER brief 2026-09-16.' | Out-Null

$t = Get-ScheduledTask -TaskName $TaskName
if ([string]$t.Principal.LogonType -ne 'Interactive') { throw "unexpected LogonType: $($t.Principal.LogonType)" }
if ([string]$t.Principal.UserId -ne $TaskUser) { throw "unexpected principal: $($t.Principal.UserId)" }
"installed: {0} | state={1} | user={2} | logon={3}" -f $TaskName, $t.State, $t.Principal.UserId, $t.Principal.LogonType
