# Installs QM_StrategyFarm_MailboxSourceIntake_Daily — daily 06:00 mailbox source-intake:
# reads info@quantmechanica.com forwards (read-only), then dispatches a doctrine-bound, injection-safe
# Codex analyst to judge each source and feed qualifying ones into the G0 funnel (add-source + draft card).
# Mirrors the SourcingIntakeSweep / CodexOrchestration pattern: SYSTEM principal, RunLevel Highest,
# pythonw.exe DIRECT (no cmd/powershell wrapper — avoids the PS5.1 stderr-trap task-killer class).
$ErrorActionPreference = 'Stop'

$TaskName = 'QM_StrategyFarm_MailboxSourceIntake_Daily'
$Pythonw  = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe'
$Script   = 'C:\QM\repo\tools\strategy_farm\mailbox_source_intake.py'

if (-not (Test-Path $Pythonw)) { throw "pythonw not found: $Pythonw" }
if (-not (Test-Path $Script))  { throw "script not found: $Script" }

$action    = New-ScheduledTaskAction -Execute $Pythonw -Argument "`"$Script`"" -WorkingDirectory 'C:\QM\repo'
$trigger   = New-ScheduledTaskTrigger -Daily -At 06:00
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
             -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 1)

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal `
    -Settings $settings -Description 'Daily 06:00: read info@ forwards, analyze sources, feed qualifying ones into the G0 funnel (add-source + draft cards). Injection-safe, drafts-only — no approve/build/deploy.' -Force | Out-Null

$t = Get-ScheduledTask -TaskName $TaskName
"installed: {0} | state={1} | trigger={2} | principal={3}" -f $TaskName, $t.State, ($t.Triggers[0].StartBoundary), $t.Principal.UserId
