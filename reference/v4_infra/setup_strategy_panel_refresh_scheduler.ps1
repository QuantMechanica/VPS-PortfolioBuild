[CmdletBinding()]
param(
    [string]$TaskName = "QM_FullDashboard_Refresh15m",
    [string]$RootPath = "G:/Meine Ablage/QuantMechanica",
    [string]$PythonExe = "C:/Users/fabia/anaconda3/python.exe",
    [string]$ScriptRelativePath = "Company/scripts/full_dashboard_refresh_15min.py",
    [int]$IntervalMinutes = 15,
    [int]$ExecutionTimeLimitMinutes = 10,
    [int]$RestartCount = 3,
    [int]$RestartIntervalMinutes = 5,
    [string]$ExportXmlRelativePath = "Company/scripts/infra/task_scheduler/QM_FullDashboard_Refresh15m.xml",
    [switch]$SkipStartupTrigger,
    [switch]$EnableLegacyDashboardScheduler
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $EnableLegacyDashboardScheduler) {
    throw "Legacy scheduler disabled for V5. This script would recreate QM_FullDashboard_Refresh15m and cause periodic Anaconda/Python popups. Re-run with -EnableLegacyDashboardScheduler only if you intentionally want to restore the old local dashboard refresh task."
}

function Resolve-AbsolutePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$BasePath
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $Path))
}

if ($IntervalMinutes -lt 1) {
    throw "IntervalMinutes must be >= 1."
}
if ($ExecutionTimeLimitMinutes -lt 1) {
    throw "ExecutionTimeLimitMinutes must be >= 1."
}
if ($RestartCount -lt 0) {
    throw "RestartCount must be >= 0."
}
if ($RestartIntervalMinutes -lt 1) {
    throw "RestartIntervalMinutes must be >= 1."
}

$rootAbsolute = Resolve-AbsolutePath -Path $RootPath -BasePath (Get-Location).Path
$pythonAbsolute = Resolve-AbsolutePath -Path $PythonExe -BasePath $rootAbsolute
$scriptAbsolute = Resolve-AbsolutePath -Path $ScriptRelativePath -BasePath $rootAbsolute
$exportXmlAbsolute = Resolve-AbsolutePath -Path $ExportXmlRelativePath -BasePath $rootAbsolute

if (-not (Test-Path -LiteralPath $rootAbsolute -PathType Container)) {
    throw "Root path not found: $rootAbsolute"
}
if (-not (Test-Path -LiteralPath $pythonAbsolute -PathType Leaf)) {
    throw "Python interpreter not found: $pythonAbsolute"
}
if (-not (Test-Path -LiteralPath $scriptAbsolute -PathType Leaf)) {
    throw "Target script not found: $scriptAbsolute"
}

$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
if ([string]::IsNullOrWhiteSpace($currentUser)) {
    $currentUser = "$env:USERDOMAIN\$env:USERNAME"
}

$startupLabel = if ($SkipStartupTrigger) { "startup trigger skipped" } else { "includes startup trigger" }
$taskDescription = "Run strategy panel refresh every $IntervalMinutes minutes ($startupLabel, QUAA-235)."
$actionArgs = "`"$scriptAbsolute`""

$action = New-ScheduledTaskAction `
    -Execute $pythonAbsolute `
    -Argument $actionArgs `
    -WorkingDirectory $rootAbsolute

$repeatTrigger = New-ScheduledTaskTrigger `
    -Once -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$triggers = @($repeatTrigger)
if (-not $SkipStartupTrigger) {
    $startupTrigger = New-ScheduledTaskTrigger -AtStartup
    $triggers += $startupTrigger
}

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes $ExecutionTimeLimitMinutes) `
    -MultipleInstances IgnoreNew `
    -RestartCount $RestartCount `
    -RestartInterval (New-TimeSpan -Minutes $RestartIntervalMinutes)

try {
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $triggers `
        -Settings $settings `
        -Description $taskDescription `
        -Force | Out-Null
} catch {
    if (
        -not $SkipStartupTrigger -and
        $_.Exception.Message -like "*Zugriff verweigert*"
    ) {
        throw "Access denied while adding startup trigger. Re-run in elevated PowerShell for full mode, or use -SkipStartupTrigger for interim 15-min + retry mode."
    }
    throw
}

$exportDir = Split-Path -Path $exportXmlAbsolute -Parent
if (-not (Test-Path -LiteralPath $exportDir -PathType Container)) {
    New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
}

Export-ScheduledTask -TaskName $TaskName | Set-Content -LiteralPath $exportXmlAbsolute -Encoding utf8

$task = Get-ScheduledTask -TaskName $TaskName
$taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName

$result = [ordered]@{
    task_name = $TaskName
    task_path = $task.TaskPath
    user_id = $currentUser
    execute = $pythonAbsolute
    argument = $actionArgs
    working_directory = $rootAbsolute
    export_xml_path = $exportXmlAbsolute
    next_run_time = $taskInfo.NextRunTime
    last_run_time = $taskInfo.LastRunTime
    last_task_result = $taskInfo.LastTaskResult
    schedule_minutes = $IntervalMinutes
    restart_count = $RestartCount
    restart_interval_minutes = $RestartIntervalMinutes
    startup_trigger_enabled = (-not $SkipStartupTrigger)
}

$result | ConvertTo-Json -Depth 4
