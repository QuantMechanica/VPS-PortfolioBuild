[CmdletBinding()]
param(
    [string]$TaskName = 'QM_QUA95_RuntimeRestore_15min',
    [string]$RepoRoot = 'C:\QM\repo',
    [int]$EveryMinutes = 15,
    [string]$PythonExe = '',
    [string]$TerminalRoot = 'D:\QM\mt5\T1',
    [string]$TargetSymbol = 'XTIUSD.DWX',
    [int]$MaxRestartAttempts = 2,
    [int]$PostStartWaitSeconds = 20,
    [int]$InterAttemptWaitSeconds = 10,
    [switch]$PreviewOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($EveryMinutes -lt 5) {
    throw "EveryMinutes must be >= 5."
}
if ($TerminalRoot -match 'T6') {
    throw "Refusing T6 terminal scope: $TerminalRoot"
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

$runner = Join-Path $RepoRoot 'infra\scripts\Restore-QUA95RuntimeBars.ps1'
if (-not (Test-Path -LiteralPath $runner)) {
    throw "Runtime-restore runner missing: $runner"
}

$args = @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', ('"{0}"' -f $runner),
    '-IssueId', 'QUA-207',
    '-RepoRoot', ('"{0}"' -f $RepoRoot),
    '-TargetSymbol', ('"{0}"' -f $TargetSymbol),
    '-TerminalRoot', ('"{0}"' -f $TerminalRoot),
    '-PythonExe', ('"{0}"' -f $PythonExe),
    '-MaxRestartAttempts', $MaxRestartAttempts,
    '-PostStartWaitSeconds', $PostStartWaitSeconds,
    '-InterAttemptWaitSeconds', $InterAttemptWaitSeconds
) -join ' '

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $args
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date.AddMinutes(2) `
    -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

if ($PreviewOnly) {
    Write-Host ("preview_task_name={0}" -f $TaskName)
    Write-Host ("preview_interval_minutes={0}" -f $EveryMinutes)
    Write-Host ("preview_python_exe={0}" -f $PythonExe)
    Write-Host ("preview_action=PowerShell {0}" -f $args)
    exit 0
}

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Write-Host ("installed_task={0}" -f $TaskName)
exit 0
