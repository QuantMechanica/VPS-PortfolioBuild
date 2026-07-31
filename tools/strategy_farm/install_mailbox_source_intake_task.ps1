# Installs QM_StrategyFarm_MailboxSourceIntake_Daily — daily 06:07 mailbox source-intake:
# reads info@quantmechanica.com forwards (read-only), then dispatches a doctrine-bound, injection-safe
# Codex analyst to judge each source and feed qualifying ones into the G0 funnel (add-source + draft card).
# The analyst uses Codex plus agy. Both credentials are bound to the qm-admin
# operator profile. The task root runs as SYSTEM and the approved console-
# session helper launches the child with the logged-on qm-admin token.
[CmdletBinding()]
param(
    [string]$UserId = 'qm-admin'
)

$ErrorActionPreference = 'Stop'

$TaskName = 'QM_StrategyFarm_MailboxSourceIntake_Daily'
$Pythonw  = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe'
$Script   = 'C:\QM\repo\tools\strategy_farm\mailbox_source_intake.py'
$RepoRoot = 'C:\QM\repo'
$Helper   = 'C:\QM\repo\tools\strategy_farm\run_in_console_session.ps1'
$PowerShellExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

if (-not (Test-Path $Pythonw)) { throw "pythonw not found: $Pythonw" }
if (-not (Test-Path $Script))  { throw "script not found: $Script" }
if (-not (Test-Path $Helper))  { throw "console-session helper not found: $Helper" }

$sidType = [System.Security.Principal.SecurityIdentifier]
$canonicalUser = 'qm-admin'
$canonicalSid = ([System.Security.Principal.NTAccount]::new($canonicalUser)).Translate($sidType).Value
$requestedSid = ([System.Security.Principal.NTAccount]::new($UserId)).Translate($sidType).Value
if ($requestedSid -ne $canonicalSid) {
    throw "Mailbox intake must run as canonical $canonicalUser [$canonicalSid], not $UserId [$requestedSid]"
}

$actionArguments = (
    '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -Exe "{1}" -Arguments "{2}" -WorkDir "{3}" -TargetUser "{4}" -WaitSeconds 2640' -f `
        $Helper, $Pythonw, $Script, $RepoRoot, $canonicalUser
)
if ($actionArguments.Contains("'")) {
    throw 'MNT-003 v2 action must not contain literal apostrophe wrappers.'
}
$action    = New-ScheduledTaskAction -Execute $PowerShellExe -Argument $actionArguments -WorkingDirectory $RepoRoot
$trigger   = New-ScheduledTaskTrigger -Daily -At 06:07
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
             -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 45) `
             -RestartCount 4 -RestartInterval (New-TimeSpan -Minutes 15)

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal `
    -Settings $settings -Description 'Daily 06:07: SYSTEM root bridges to logged-on qm-admin for Codex/agy auth, reads info@ forwards, analyzes sources, and feeds qualifying ones into G0. Nonzero runs get 4 scheduler restarts at 15-minute intervals. Drafts-only, no approve/build/deploy.' -Force | Out-Null

$t = Get-ScheduledTask -TaskName $TaskName
$i = Get-ScheduledTaskInfo -TaskName $TaskName
if ([string]$t.Principal.LogonType -ne 'ServiceAccount') { throw "unexpected LogonType: $($t.Principal.LogonType)" }
$systemSid = 'S-1-5-18'
$actualSid = ([System.Security.Principal.NTAccount]::new([string]$t.Principal.UserId)).Translate($sidType).Value
if ($actualSid -ne $systemSid) { throw "unexpected principal: $($t.Principal.UserId) [$actualSid]" }
if ([int]$t.Settings.RestartCount -ne 4) { throw "unexpected RestartCount: $($t.Settings.RestartCount)" }
"installed: {0} | state={1} | trigger={2} | principal={3} | logon={4} | retries={5} | next={6}" -f `
    $TaskName, $t.State, ($t.Triggers[0].StartBoundary), $t.Principal.UserId, `
    $t.Principal.LogonType, $t.Settings.RestartCount, $i.NextRunTime
