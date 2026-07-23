[CmdletBinding()]
param(
    [string]$TaskName = 'QM_MultiEAScheduler_30s',
    [ValidateRange(1, 60)]
    [int]$IntervalMinutes = 1,
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$PythonExe,
    [switch]$PreviewOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-PythonExe {
    param([string]$Candidate)
    if ($Candidate) {
        if (-not (Test-Path -LiteralPath $Candidate -PathType Leaf)) {
            throw "Python executable not found: $Candidate"
        }
        return (Resolve-Path -LiteralPath $Candidate).Path
    }
    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if (-not $cmd) {
        throw 'python not found on PATH; provide -PythonExe <fullpath>'
    }
    return $cmd.Source
}

$repo = (Resolve-Path -LiteralPath $RepoRoot).Path
$python = Resolve-PythonExe -Candidate $PythonExe
$schedulerScript = Join-Path $repo 'framework\scripts\multi_ea_scheduler.py'
if (-not (Test-Path -LiteralPath $schedulerScript -PathType Leaf)) {
    throw "Scheduler script not found: $schedulerScript"
}

$actionArgs = "-m framework.scripts.multi_ea_scheduler --sleep-seconds 30"
$taskRun = ('"{0}" {1}' -f $python, $actionArgs)

$summary = [ordered]@{
    task_name = $TaskName
    repo_root = $repo
    python = $python
    scheduler_script = $schedulerScript
    interval_minutes = $IntervalMinutes
    action_execute = 'schtasks.exe'
    action_args = "/Create /TN `"$TaskName`" /TR `"$taskRun`" /SC MINUTE /MO $IntervalMinutes /RU SYSTEM /RL HIGHEST /F"
    preview_only = [bool]$PreviewOnly
}

if ($PreviewOnly) {
    $summary | ConvertTo-Json -Depth 5
    exit 0
}

$null = & schtasks.exe /Create /TN "$TaskName" /TR "$taskRun" /SC MINUTE /MO $IntervalMinutes /RU SYSTEM /RL HIGHEST /F
$summary['registered'] = $true
$summary | ConvertTo-Json -Depth 5
