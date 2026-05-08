param(
    [string]$TaskName = 'QM_QUA774_ExternalUnblockStatus_60min',
    [string]$ExpectedLauncherPath = 'C:\QM\tasks\run_qua774_external_unblock_status.ps1'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$task = $null
try {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
}
catch {
    throw "Scheduled task not found: $TaskName"
}

$info = Get-ScheduledTaskInfo -TaskName $TaskName
$action = $task.Actions | Select-Object -First 1
$arg = [string]$action.Arguments
$expectedFragment = "-File `"$ExpectedLauncherPath`""

$errors = @()
if ([string]::IsNullOrWhiteSpace($arg)) {
    $errors += 'action_arguments_empty'
}
elseif ($arg -notlike "*$expectedFragment*") {
    $errors += 'action_launcher_path_mismatch'
}

if ($info.LastTaskResult -ne 0) {
    $errors += "last_task_result_nonzero:$($info.LastTaskResult)"
}

$status = if ($errors.Count -eq 0) { 'ok' } else { 'fail' }

[pscustomobject]@{
    issue_id = 'QUA-774'
    status = $status
    task_name = $TaskName
    task_state = $task.State.ToString()
    execute = $action.Execute
    arguments = $arg
    expected_launcher_path = $ExpectedLauncherPath
    last_run_time = $info.LastRunTime
    next_run_time = $info.NextRunTime
    last_task_result = $info.LastTaskResult
    errors = $errors
}

if ($status -ne 'ok') {
    exit 2
}
