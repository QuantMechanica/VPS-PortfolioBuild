param(
    [string]$TaskName = 'QM_QUA774_BlockedHeartbeat_60min',
    [int]$IntervalMinutes = 60,
    [string]$RepoRoot = 'C:\QM\repo',
    [switch]$PreviewOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($IntervalMinutes -lt 5) {
    throw "IntervalMinutes must be >= 5"
}

$scriptPath = Join-Path $RepoRoot 'infra\scripts\Invoke-QUA774BlockedHeartbeat.ps1'
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "Heartbeat script missing: $scriptPath"
}

$taskDir = 'C:\QM\tasks'
if (-not (Test-Path -LiteralPath $taskDir)) {
    New-Item -ItemType Directory -Path $taskDir -Force | Out-Null
}

$launcherPath = Join-Path $taskDir 'run_qua774_blocked_heartbeat.ps1'
$launcher = @"
`$ErrorActionPreference = 'Stop'
powershell -NoProfile -ExecutionPolicy Bypass -File "$scriptPath" *> "C:\QM\logs\qua774_blocked_heartbeat.log"
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
    -RepetitionDuration ([TimeSpan]::MaxValue)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

$null = Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description 'Runs QUA-774 blocked heartbeat refresh + payload + validation.'

[pscustomobject]@{
    preview = $false
    task_name = $TaskName
    interval_minutes = $IntervalMinutes
    launcher_path = $launcherPath
    invoke_script = $scriptPath
}
