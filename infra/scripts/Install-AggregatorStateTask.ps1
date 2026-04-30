[CmdletBinding()]
param(
    [string]$TaskName = 'QM_AggregatorState_1min',
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$PythonExe = 'python',
    [string]$ScriptRelativePath = 'scripts\aggregator\standalone_aggregator_loop.py',
    [int]$SecondOffset = 20,
    [switch]$PreviewOnly,
    [switch]$RunNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $RepoRoot $ScriptRelativePath
if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Aggregator script not found: $scriptPath"
}

$resolvedPythonExe = $PythonExe
if (-not [System.IO.Path]::IsPathRooted($resolvedPythonExe)) {
    $pythonCmd = Get-Command -Name $resolvedPythonExe -CommandType Application -ErrorAction SilentlyContinue
    if ($null -eq $pythonCmd -or [string]::IsNullOrWhiteSpace($pythonCmd.Source)) {
        throw "Python executable '$PythonExe' is not resolvable to an absolute path. Pass -PythonExe with a full path."
    }
    $resolvedPythonExe = $pythonCmd.Source
}
if (-not (Test-Path -LiteralPath $resolvedPythonExe -PathType Leaf)) {
    throw "Python executable not found: $resolvedPythonExe"
}

$offset = [Math]::Max(0, [Math]::Min(59, $SecondOffset))
$now = Get-Date
$startBoundary = Get-Date -Date $now.ToString('yyyy-MM-dd HH:mm:00')
$startBoundary = $startBoundary.AddSeconds($offset)
if ($startBoundary -le $now) {
    $startBoundary = $startBoundary.AddMinutes(1)
}

$args = "`"$scriptPath`" --once"
$action = New-ScheduledTaskAction -Execute $resolvedPythonExe -Argument $args -WorkingDirectory $RepoRoot
$trigger = New-ScheduledTaskTrigger -Once -At $startBoundary -RepetitionInterval (New-TimeSpan -Minutes 1)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest -LogonType ServiceAccount
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Seconds 45)

$task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings
if ($PreviewOnly.IsPresent) {
    [pscustomobject]@{
        preview = $true
        task_name = $TaskName
        execute = $resolvedPythonExe
        arguments = $args
        working_directory = $RepoRoot
        start_boundary_local = $startBoundary.ToString("o")
        repetition_minutes = 1
        principal = "SYSTEM"
        run_level = "Highest"
    } | ConvertTo-Json -Depth 5
    exit 0
}
Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force | Out-Null

$taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
Write-Host "Task '$TaskName' is configured. Next run: $($taskInfo.NextRunTime)"
Write-Host "Action: $resolvedPythonExe $args"
Write-Host "Principal: SYSTEM, MultipleInstances=IgnoreNew, Repetition=1m"

if ($RunNow.IsPresent) {
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "Task '$TaskName' started on demand."
}
