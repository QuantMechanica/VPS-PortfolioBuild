param(
    [int]$Minutes = 30,
    [switch]$ForceRebuild,
    [switch]$EnableLegacyProcessesScheduler
)

if (-not $EnableLegacyProcessesScheduler) {
    throw "Legacy processes scheduler disabled for V5. This script would recreate QM_ProcessesHtml_Build and cause periodic PowerShell/Python popups. Re-run with -EnableLegacyProcessesScheduler only if you intentionally want to restore the old local process dashboard rebuild task."
}

if ($Minutes -lt 5) {
    throw "Minutes must be >= 5."
}

$root = "G:\Meine Ablage\QuantMechanica"
$taskName = "QM_ProcessesHtml_Build"
$builderPs1 = Join-Path $root "Company\scripts\build_processes_html.ps1"
$builderModeArg = if ($ForceRebuild) { "" } else { " -Guardrail" }
$builderModeLabel = if ($ForceRebuild) { "force rebuild" } else { "guardrail rebuild" }

if (-not (Test-Path $builderPs1)) {
    throw "Missing script: $builderPs1"
}

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -File `"$builderPs1`"$builderModeArg" `
    -WorkingDirectory $root

$trigger = New-ScheduledTaskTrigger `
    -Once -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes $Minutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -MultipleInstances IgnoreNew

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "Rebuild QuantMechanica Processes/processes.html every $Minutes minutes ($builderModeLabel)." `
    -Force | Out-Null

Write-Host "Done: $taskName scheduled every $Minutes minutes ($builderModeLabel)." -ForegroundColor Green
