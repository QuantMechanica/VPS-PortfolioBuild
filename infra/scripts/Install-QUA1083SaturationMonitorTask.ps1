[CmdletBinding()]
param(
    [string]$TaskName = 'QM_QUA1083_SaturationMonitor_5min',
    [ValidateRange(1,60)]
    [int]$IntervalMinutes = 5,
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
    if (-not $cmd) { throw 'python not found on PATH; provide -PythonExe <fullpath>' }
    return $cmd.Source
}

$repo = (Resolve-Path -LiteralPath $RepoRoot).Path
$python = Resolve-PythonExe -Candidate $PythonExe
$statePath = 'D:\QM\Reports\pipeline\multi_ea_scheduler_state.json'
$outPath = Join-Path $repo 'artifacts\qua1083_monitor\latest_saturation_eval.json'

$args = "framework/scripts/monitor_saturation_window.py --state `"$statePath`" --duration-minutes 5 --min-ratio 0.5 --no-wait --out `"$outPath`""
$taskRun = ('"{0}" {1}' -f $python, $args)

$summary = [ordered]@{
    task_name = $TaskName
    repo_root = $repo
    python = $python
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
