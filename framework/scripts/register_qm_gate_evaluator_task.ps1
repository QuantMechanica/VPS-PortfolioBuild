[CmdletBinding()]
param(
    [string]$TaskName = 'QM_GateEvaluator_5min',
    [string]$PythonExe = 'python',
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$QueueDbPath = 'D:\QM\reports\pipeline\mt5_queue.db',
    [string]$PaperclipBase = 'http://127.0.0.1:3100',
    [string]$CompanyId = '03d4dcc8-4cea-4133-9f68-90c0d99628fb',
    [string]$ProjectId = '71b6d994-70ba-4a28-bd62-732b42a9ea58',
    [int]$MaxRetries = 3,
    [int]$Limit = 200,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $RepoRoot 'framework\scripts\gate_evaluator.py'
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "gate_evaluator.py not found at '$scriptPath'"
}

$pythonCmd = (Get-Command $PythonExe -ErrorAction Stop).Source
$arguments = @(
    $scriptPath,
    '--sqlite', $QueueDbPath,
    '--max-retries', $MaxRetries,
    '--limit', $Limit,
    '--paperclip-base', $PaperclipBase,
    '--company-id', $CompanyId,
    '--project-id', $ProjectId
) -join ' '

$action = New-ScheduledTaskAction -Execute $pythonCmd -Argument $arguments -WorkingDirectory $RepoRoot
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType S4U -RunLevel Highest

if ($DryRun) {
    [pscustomobject]@{
        dry_run = $true
        task_name = $TaskName
        execute = $pythonCmd
        arguments = $arguments
        working_directory = $RepoRoot
        repetition_minutes = 5
        logon_type = 'S4U'
    } | ConvertTo-Json -Depth 4
    exit 0
}

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null

$task = Get-ScheduledTask -TaskName $TaskName
$info = Get-ScheduledTaskInfo -TaskName $TaskName

[pscustomobject]@{
    task_name = $TaskName
    state = $task.State.ToString()
    last_run_time = $info.LastRunTime.ToString('o')
    last_task_result = $info.LastTaskResult
    execute = $pythonCmd
    arguments = $arguments
} | ConvertTo-Json -Depth 4
