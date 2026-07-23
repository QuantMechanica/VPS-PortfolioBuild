# Installs QM_StrategyFarm_MailboxSourceIntake_Daily — daily 06:07 mailbox source-intake:
# reads info@quantmechanica.com forwards (read-only), then dispatches a doctrine-bound, injection-safe
# Codex analyst to judge each source and feed qualifying ones into the G0 funnel (add-source + draft card).
# The analyst uses Codex plus agy. Both credentials are bound to the qm-admin
# operator profile, so this task must run Interactive (SYSTEM/S4U cannot decrypt
# agy's DPAPI-backed Credential Manager entry).
[CmdletBinding()]
param(
    [string]$UserId = 'qm-admin'
)

$ErrorActionPreference = 'Stop'

$TaskName = 'QM_StrategyFarm_MailboxSourceIntake_Daily'
$Pythonw  = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe'
$Script   = 'C:\QM\repo\tools\strategy_farm\mailbox_source_intake.py'

if (-not (Test-Path $Pythonw)) { throw "pythonw not found: $Pythonw" }
if (-not (Test-Path $Script))  { throw "script not found: $Script" }

$sidType = [System.Security.Principal.SecurityIdentifier]
$canonicalUser = 'qm-admin'
$canonicalSid = ([System.Security.Principal.NTAccount]::new($canonicalUser)).Translate($sidType).Value
$requestedSid = ([System.Security.Principal.NTAccount]::new($UserId)).Translate($sidType).Value
if ($requestedSid -ne $canonicalSid) {
    throw "Mailbox intake must run as canonical $canonicalUser [$canonicalSid], not $UserId [$requestedSid]"
}

$action    = New-ScheduledTaskAction -Execute $Pythonw -Argument "`"$Script`"" -WorkingDirectory 'C:\QM\repo'
$trigger   = New-ScheduledTaskTrigger -Daily -At 06:07
$principal = New-ScheduledTaskPrincipal -UserId $UserId -LogonType Interactive -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
             -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 45) `
             -RestartCount 4 -RestartInterval (New-TimeSpan -Minutes 15)

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal `
    -Settings $settings -Description 'Daily 06:07: read info@ forwards, analyze sources, feed qualifying ones into G0. Interactive qm-admin is required for Codex/agy auth. Codex is capped at 30 minutes; nonzero runs get 4 scheduler restarts at 15-minute intervals. Drafts-only, no approve/build/deploy.' -Force | Out-Null

$t = Get-ScheduledTask -TaskName $TaskName
$i = Get-ScheduledTaskInfo -TaskName $TaskName
if ([string]$t.Principal.LogonType -ne 'Interactive') { throw "unexpected LogonType: $($t.Principal.LogonType)" }
$actualSid = ([System.Security.Principal.NTAccount]::new([string]$t.Principal.UserId)).Translate($sidType).Value
if ($actualSid -ne $canonicalSid) { throw "unexpected principal: $($t.Principal.UserId) [$actualSid]" }
if ([int]$t.Settings.RestartCount -ne 4) { throw "unexpected RestartCount: $($t.Settings.RestartCount)" }
"installed: {0} | state={1} | trigger={2} | principal={3} | logon={4} | retries={5} | next={6}" -f `
    $TaskName, $t.State, ($t.Triggers[0].StartBoundary), $t.Principal.UserId, `
    $t.Principal.LogonType, $t.Settings.RestartCount, $i.NextRunTime
