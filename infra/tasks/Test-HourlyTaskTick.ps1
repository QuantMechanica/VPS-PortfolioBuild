[CmdletBinding()]
param(
    [string]$TaskName = "QM_DWX_HourlyCheck",
    [int]$LookbackHours = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$result = [ordered]@{
    check = "hourly_task_tick"
    generated_at_utc = [datetime]::UtcNow.ToString("o")
    task_name = $TaskName
    task_exists = $false
    repetition_interval = $null
    last_run_time = $null
    next_run_time = $null
    observed_tick_count = 0
    status = "unknown"
    message = ""
}

$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if (-not $task) {
    $result.status = "critical"
    $result.message = "Scheduled task not found."
    $result | ConvertTo-Json -Depth 6
    exit 2
}

$result.task_exists = $true
$trigger = $task.Triggers | Select-Object -First 1
if ($trigger -and $trigger.Repetition) {
    $result.repetition_interval = $trigger.Repetition.Interval
}

$taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
$result.last_run_time = if ($taskInfo.LastRunTime -and $taskInfo.LastRunTime.Year -gt 1900) { $taskInfo.LastRunTime.ToUniversalTime().ToString("o") } else { $null }
$result.next_run_time = if ($taskInfo.NextRunTime -and $taskInfo.NextRunTime.Year -gt 1900) { $taskInfo.NextRunTime.ToUniversalTime().ToString("o") } else { $null }

$start = (Get-Date).AddHours(-1 * $LookbackHours)
$filter = @{
    LogName = "Microsoft-Windows-TaskScheduler/Operational"
    Id = 201
    StartTime = $start
}
$events = @(Get-WinEvent -FilterHashtable $filter -ErrorAction SilentlyContinue | Where-Object { $_.Message -like "*\\$TaskName*" })
$result.observed_tick_count = $events.Count

$isHourly = $false
if ($result.repetition_interval -and $result.repetition_interval -eq "PT1H") {
    $isHourly = $true
}

if (-not $isHourly) {
    $result.status = "critical"
    $result.message = "Task exists but repetition interval is not hourly (PT1H)."
    $result | ConvertTo-Json -Depth 6
    exit 2
}

if ($result.observed_tick_count -lt 1) {
    $result.status = "warn"
    $result.message = "Task is hourly but no completed tick observed in lookback window."
    $result | ConvertTo-Json -Depth 6
    exit 1
}

$result.status = "ok"
$result.message = "Hourly cadence verified with observed completed tick(s)."
$result | ConvertTo-Json -Depth 6
exit 0
