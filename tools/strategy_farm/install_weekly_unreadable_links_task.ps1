# Installs the explicitly OWNER-authorized Friday source-access backlog mail.
# This is independent from the disabled PIPELINE FAIL/OK mail channel.
[CmdletBinding()]
param(
    [string]$UserId = 'qm-admin',
    [string]$At = '06:30'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$TaskName = 'QM_StrategyFarm_UnreadableLinks_Friday'
$RepoRoot = 'C:\QM\repo'
$Pythonw = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe'
$Wrapper = Join-Path $RepoRoot 'tools\strategy_farm\run_weekly_unreadable_links_task.py'

if (-not (Test-Path -LiteralPath $Pythonw)) {
    throw "pythonw.exe not found: $Pythonw"
}
if (-not (Test-Path -LiteralPath $Wrapper)) {
    throw "wrapper not found: $Wrapper"
}

# G: is a per-user Google Drive mount.  Resolve the requested account by SID
# so aliases cannot silently move the task to a different profile.
$sidType = [System.Security.Principal.SecurityIdentifier]
$canonicalUser = 'qm-admin'
$canonicalSid = (
    [System.Security.Principal.NTAccount]::new($canonicalUser)
).Translate($sidType).Value
$requestedSid = (
    [System.Security.Principal.NTAccount]::new($UserId)
).Translate($sidType).Value
if ($requestedSid -ne $canonicalSid) {
    throw (
        "Weekly unreadable-links mail must run as canonical " +
        "$canonicalUser [$canonicalSid], not $UserId [$requestedSid]"
    )
}

$action = New-ScheduledTaskAction `
    -Execute $Pythonw `
    -Argument "`"$Wrapper`"" `
    -WorkingDirectory $RepoRoot
$trigger = New-ScheduledTaskTrigger `
    -Weekly `
    -DaysOfWeek Friday `
    -At $At
$principal = New-ScheduledTaskPrincipal `
    -UserId $UserId `
    -LogonType Interactive `
    -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10) `
    -RestartCount 4 `
    -RestartInterval (New-TimeSpan -Minutes 15)

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description (
        'Friday 06:30 OWNER report: unchecked manually unreadable source links ' +
        'from the Vault plus access-related DEFERRED mailbox leads. Reuses the ' +
        'canonical Gmail SMTP helper; atomic week claim prevents duplicate ' +
        'delivery; independent from disabled PIPELINE alerts.'
    ) `
    -Force | Out-Null

$task = Get-ScheduledTask -TaskName $TaskName
$info = Get-ScheduledTaskInfo -TaskName $TaskName
$xml = [xml](Export-ScheduledTask -TaskName $TaskName)
$actualSid = (
    [System.Security.Principal.NTAccount]::new(
        [string]$task.Principal.UserId
    )
).Translate($sidType).Value

if ($actualSid -ne $canonicalSid) {
    throw "unexpected principal: $($task.Principal.UserId) [$actualSid]"
}
if ([string]$task.Principal.LogonType -ne 'Interactive') {
    throw "unexpected LogonType: $($task.Principal.LogonType)"
}
if ([int]$task.Settings.RestartCount -ne 4) {
    throw "unexpected RestartCount: $($task.Settings.RestartCount)"
}
if ([string]$task.Settings.MultipleInstances -ne 'IgnoreNew') {
    throw "unexpected MultipleInstances: $($task.Settings.MultipleInstances)"
}
if ([string]$task.State -eq 'Disabled') {
    throw "task unexpectedly disabled"
}
if ($null -eq $xml.Task.Triggers.CalendarTrigger.ScheduleByWeek) {
    throw "registered trigger is not weekly"
}
if ($null -eq $xml.Task.Triggers.CalendarTrigger.ScheduleByWeek.DaysOfWeek.Friday) {
    throw "registered trigger is not Friday"
}
$expectedTime = [TimeSpan]::Parse(
    $At,
    [System.Globalization.CultureInfo]::InvariantCulture
)
$actualBoundary = [DateTimeOffset]::Parse(
    [string]$xml.Task.Triggers.CalendarTrigger.StartBoundary,
    [System.Globalization.CultureInfo]::InvariantCulture
)
if ($actualBoundary.TimeOfDay -ne $expectedTime) {
    throw (
        "unexpected trigger time: $($actualBoundary.TimeOfDay); " +
        "expected $expectedTime"
    )
}
if ([string]$xml.Task.Actions.Exec.Command -ne $Pythonw) {
    throw "unexpected action command: $($xml.Task.Actions.Exec.Command)"
}
if ([string]$xml.Task.Actions.Exec.WorkingDirectory -ne $RepoRoot) {
    throw (
        "unexpected action working directory: " +
        "$($xml.Task.Actions.Exec.WorkingDirectory)"
    )
}

(
    "installed: {0} | state={1} | trigger={2} | principal={3} | logon={4} | " +
    "retries={5} | next={6}"
) -f `
    $TaskName, `
    $task.State, `
    $task.Triggers[0].StartBoundary, `
    $task.Principal.UserId, `
    $task.Principal.LogonType, `
    $task.Settings.RestartCount, `
    $info.NextRunTime
