param(
    [string]$TaskName = 'QM_QUA774_ExternalUnblockOpsSuite_60min',
    [int]$IntervalMinutes = 60,
    [string]$RepoRoot = 'C:\QM\repo',
    [switch]$PreviewOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($IntervalMinutes -lt 5) {
    throw 'IntervalMinutes must be >= 5'
}

$scriptPath = Join-Path $RepoRoot 'infra\scripts\Test-QUA774ExternalUnblockOpsSuite.ps1'
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "Ops suite script missing: $scriptPath"
}

$taskDir = 'C:\QM\tasks'
if (-not (Test-Path -LiteralPath $taskDir -PathType Container)) {
    New-Item -ItemType Directory -Path $taskDir -Force | Out-Null
}

$logDir = 'C:\QM\logs'
if (-not (Test-Path -LiteralPath $logDir -PathType Container)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

$launcherPath = Join-Path $taskDir 'run_qua774_external_unblock_ops_suite.ps1'
$launcher = @"
`$ErrorActionPreference = 'Stop'
powershell -NoProfile -ExecutionPolicy Bypass -File "$scriptPath" *> "C:\QM\logs\qua774_external_unblock_ops_suite.log"
"@
Set-Content -LiteralPath $launcherPath -Value $launcher -Encoding UTF8

if ($PreviewOnly) {
    [pscustomobject]@{
        preview = $true
        task_name = $TaskName
        interval_minutes = $IntervalMinutes
        launcher_path = $launcherPath
        invoke_script = $scriptPath
    }
    exit 0
}

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$launcherPath`""
$trigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

$null = Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description 'Runs QUA-774 external unblock ops suite.'

[pscustomobject]@{
    preview = $false
    task_name = $TaskName
    interval_minutes = $IntervalMinutes
    launcher_path = $launcherPath
    invoke_script = $scriptPath
}
