[CmdletBinding()]
param(
    [string]$TaskName = 'QM_QUA95_BlockerRefresh',
    [string]$RepoRoot = 'C:\QM\repo',
    [int]$EveryMinutes = 60,
    [string]$LogPath = 'C:\QM\repo\infra\smoke\qua95_blocker_refresh_task.log',
    [string]$PythonExe = '',
    [switch]$PreviewOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($EveryMinutes -lt 5) {
    throw "EveryMinutes must be >= 5."
}

if ([string]::IsNullOrWhiteSpace($PythonExe)) {
    try {
        $PythonExe = (Get-Command python -ErrorAction Stop).Source
    } catch {
        throw "Python executable not provided and not found on PATH for installer context. Pass -PythonExe <fullpath>."
    }
}
if (-not (Test-Path -LiteralPath $PythonExe)) {
    throw "Python executable path does not exist: $PythonExe"
}

$invoke = Join-Path $RepoRoot 'infra\scripts\Invoke-VerifyDisposition.ps1'
$sync = Join-Path $RepoRoot 'infra\scripts\Update-QUA95BlockerStatus.ps1'
$summary = Join-Path $RepoRoot 'infra\scripts\Write-QUA95BlockedSummary.ps1'
$integrity = Join-Path $RepoRoot 'infra\scripts\Test-QUA95HandoffIntegrity.ps1'
$runner = Join-Path $RepoRoot 'infra\scripts\Run-QUA95BlockerRefresh.ps1'

$required = @($invoke, $sync, $summary, $integrity, $runner)
foreach ($f in $required) {
    if (-not (Test-Path -LiteralPath $f)) {
        throw "Required script missing: $f"
    }
}

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$runner`" -RepoRoot `"$RepoRoot`" -LogPath `"$LogPath`" -TaskName `"$TaskName`" -PythonExe `"$PythonExe`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date.AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

if ($PreviewOnly) {
    Write-Host ("preview_task_name={0}" -f $TaskName)
    Write-Host ("preview_interval_minutes={0}" -f $EveryMinutes)
    Write-Host ("preview_log_path={0}" -f $LogPath)
    Write-Host ("preview_python_exe={0}" -f $PythonExe)
    Write-Host ("preview_action=PowerShell {0}" -f $action.Arguments)
    exit 0
}

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Write-Host ("installed_task={0}" -f $TaskName)
