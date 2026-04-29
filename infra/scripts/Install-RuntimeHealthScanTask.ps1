[CmdletBinding()]
param(
    [string]$TaskName = "QM_RuntimeHealthScan_15min",
    [string]$RepoRoot = "C:\QM\repo",
    [string]$ScriptRelativePath = "infra\scripts\Run-RuntimeHealthScan.ps1",
    [string]$OutputPath = "C:\QM\logs\infra\health\runtime_health_scan_latest.json",
    [string]$PostgresUrl = $(if ($env:PAPERCLIP_POSTGRES_URL) { $env:PAPERCLIP_POSTGRES_URL } else { "" }),
    [string]$PostgresUrlEnvVarName = "PAPERCLIP_POSTGRES_URL",
    [switch]$UseMachineEnvPostgresUrl,
    [switch]$AllowApiFallback,
    [int]$MinuteOffset = 1,
    [int]$EveryMinutes = 15,
    [switch]$FailOnFinding,
    [switch]$DryRun,
    [switch]$PreviewOnly,
    [switch]$RunNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($EveryMinutes -lt 1) {
    throw "EveryMinutes must be >= 1."
}

$scriptPath = Join-Path $RepoRoot $ScriptRelativePath
if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Runtime health scan script not found: $scriptPath"
}
if ([string]::IsNullOrWhiteSpace($PostgresUrl) -and -not $UseMachineEnvPostgresUrl -and -not $AllowApiFallback) {
    throw "PostgresUrl is required for scheduled execution unless -AllowApiFallback is explicitly set."
}

$minuteOffset = [Math]::Max(0, [Math]::Min(59, $MinuteOffset))
$startBoundary = (Get-Date).Date.AddHours((Get-Date).Hour).AddMinutes($minuteOffset)
if ($startBoundary -le (Get-Date)) {
    $startBoundary = $startBoundary.AddMinutes($EveryMinutes)
}

if ($UseMachineEnvPostgresUrl.IsPresent) {
    $allowArg = if ($AllowApiFallback.IsPresent) { " -AllowApiFallback" } else { "" }
    $failArg = if ($FailOnFinding.IsPresent) { " -FailOnFinding" } else { "" }
    $dryArg = if ($DryRun.IsPresent) { " -DryRun" } else { "" }
    $cmd = "`$pg=[Environment]::GetEnvironmentVariable('$PostgresUrlEnvVarName','Machine'); if([string]::IsNullOrWhiteSpace(`$pg)) { throw '$PostgresUrlEnvVarName not set in Machine env.' }; & `"$scriptPath`" -OutputPath `"$OutputPath`" -PostgresUrl `$pg$allowArg$failArg$dryArg"
    $args = "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
} else {
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -OutputPath `"$OutputPath`""
    if (-not [string]::IsNullOrWhiteSpace($PostgresUrl)) { $args += " -PostgresUrl `"$PostgresUrl`"" }
    if ($AllowApiFallback.IsPresent) { $args += " -AllowApiFallback" }
    if ($FailOnFinding.IsPresent) { $args += " -FailOnFinding" }
    if ($DryRun.IsPresent) { $args += " -DryRun" }
}

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $args -WorkingDirectory $RepoRoot
$trigger = New-ScheduledTaskTrigger -Once -At $startBoundary -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest -LogonType ServiceAccount
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

$task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings
if ($PreviewOnly.IsPresent) {
    [pscustomobject]@{
        task_name = $TaskName
        script_path = $scriptPath
        args = $args
        repo_root = $RepoRoot
        every_minutes = $EveryMinutes
        start_boundary = $startBoundary.ToString('o')
        principal = 'SYSTEM'
        run_now = [bool]$RunNow
    } | ConvertTo-Json -Depth 6
    exit 0
}
Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force | Out-Null

$taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
Write-Host "Task '$TaskName' is configured. Next run: $($taskInfo.NextRunTime)"
Write-Host "Action: powershell.exe $args"
Write-Host "Principal: SYSTEM, MultipleInstances=IgnoreNew, Repetition=$($EveryMinutes)m"

if ($RunNow.IsPresent) {
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "Task '$TaskName' started on demand."
}
