[CmdletBinding()]
param(
    [string]$TaskName = 'QM_QUA95_TaskHealth_15min',
    [string]$RepoRoot = 'C:\QM\repo',
    [int]$EveryMinutes = 15,
    [int]$MaxAgeMinutes = 125,
    [string]$TransitionPayloadCheckScript = '',
    [switch]$PreviewOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($EveryMinutes -lt 5) {
    throw "EveryMinutes must be >= 5."
}

$checkScript = Join-Path $RepoRoot 'infra\monitoring\Test-QUA95BlockerTaskHealth.ps1'
if (-not (Test-Path -LiteralPath $checkScript)) {
    throw "Health check script missing: $checkScript"
}

if ([string]::IsNullOrWhiteSpace($TransitionPayloadCheckScript)) {
    $TransitionPayloadCheckScript = Join-Path $RepoRoot 'infra\scripts\Test-QUA95IssueTransitionPayload.ps1'
}
if (-not (Test-Path -LiteralPath $TransitionPayloadCheckScript)) {
    throw "Transition payload check script missing: $TransitionPayloadCheckScript"
}

$args = "-NoProfile -ExecutionPolicy Bypass -File `"$checkScript`" -MaxAgeMinutes $MaxAgeMinutes -TransitionPayloadCheckScript `"$TransitionPayloadCheckScript`""
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $args
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date.AddMinutes(2) `
    -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

if ($PreviewOnly) {
    Write-Host ("preview_task_name={0}" -f $TaskName)
    Write-Host ("preview_interval_minutes={0}" -f $EveryMinutes)
    Write-Host ("preview_max_age_minutes={0}" -f $MaxAgeMinutes)
    Write-Host ("preview_transition_payload_check_script={0}" -f $TransitionPayloadCheckScript)
    Write-Host ("preview_action=PowerShell {0}" -f $args)
    exit 0
}

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Write-Host ("installed_task={0}" -f $TaskName)
