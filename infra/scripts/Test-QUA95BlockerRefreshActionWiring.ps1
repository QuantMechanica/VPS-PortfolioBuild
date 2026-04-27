[CmdletBinding()]
param(
    [string]$TaskName = 'QM_QUA95_BlockerRefresh',
    [string[]]$RequiredFragments = @(
        'Run-QUA95BlockerRefresh.ps1',
        '-RepoRoot',
        '-LogPath',
        '-TaskName',
        '-PythonExe'
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
}
catch {
    Write-Host ("status=critical task={0} reason=task_not_found error={1}" -f $TaskName, $_.Exception.Message)
    exit 2
}

$execute = ''
$args = ''
if ($task.Actions -and $task.Actions.Count -gt 0) {
    $execute = [string]$task.Actions[0].Execute
    $args = [string]$task.Actions[0].Arguments
}

if ([string]::IsNullOrWhiteSpace($execute)) {
    Write-Host ("status=critical task={0} reason=action_execute_missing" -f $TaskName)
    exit 2
}

if ($execute -notmatch 'powershell(\.exe)?$') {
    Write-Host ("status=critical task={0} reason=unexpected_execute value={1}" -f $TaskName, $execute)
    exit 2
}

$missing = @()
foreach ($fragment in $RequiredFragments) {
    if ($args -notlike "*$fragment*") {
        $missing += $fragment
    }
}

if ($missing.Count -gt 0) {
    Write-Host ("status=critical task={0} missing_fragments={1}" -f $TaskName, ($missing -join ','))
    exit 2
}

$pythonMatch = [regex]::Match($args, '-PythonExe\s+"([^"]+)"')
if (-not $pythonMatch.Success) {
    Write-Host ("status=critical task={0} reason=python_exe_value_missing" -f $TaskName)
    exit 2
}

$pythonExe = $pythonMatch.Groups[1].Value
if (-not [IO.Path]::IsPathRooted($pythonExe)) {
    Write-Host ("status=critical task={0} reason=python_exe_not_absolute value={1}" -f $TaskName, $pythonExe)
    exit 2
}
if (-not (Test-Path -LiteralPath $pythonExe)) {
    Write-Host ("status=critical task={0} reason=python_exe_not_found value={1}" -f $TaskName, $pythonExe)
    exit 2
}

Write-Host ("status=ok task={0}" -f $TaskName)
exit 0
