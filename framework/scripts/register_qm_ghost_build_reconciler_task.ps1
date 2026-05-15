[CmdletBinding()]
param(
    [string]$TaskName = 'QM_GhostBuildReconciler_6h',
    [string]$PythonExe = 'python',
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$DispatchStatePath = 'D:\QM\Reports\pipeline\dispatch_state.json',
    [string]$OutDir = 'D:\QM\reports\pipeline\ghost_build_reconciler',
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $RepoRoot 'framework\scripts\ghost_build_reconciler.py'
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "ghost_build_reconciler.py not found at '$scriptPath'"
}

$pythonCmd = (Get-Command $PythonExe -ErrorAction Stop).Source
$arguments = @(
    $scriptPath,
    '--dispatch-state', $DispatchStatePath,
    '--out-dir', $OutDir,
    '--json'
) -join ' '

$action = New-ScheduledTaskAction -Execute $pythonCmd -Argument $arguments -WorkingDirectory $RepoRoot
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 6) -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType S4U -RunLevel Highest

if ($DryRun) {
    [pscustomobject]@{
        dry_run = $true
        task_name = $TaskName
        execute = $pythonCmd
        arguments = $arguments
        working_directory = $RepoRoot
        repetition_hours = 6
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
