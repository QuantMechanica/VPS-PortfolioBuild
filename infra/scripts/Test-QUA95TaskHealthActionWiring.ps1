[CmdletBinding()]
param(
    [string]$TaskName = 'QM_QUA95_TaskHealth_15min',
    [string[]]$RequiredFragments = @(
        '-TransitionPayloadCheckScript',
        '-UnblockReadinessCheckScript',
        '-AuditSignalCheckScript',
        '-CanonicalSnapshotCheckScript',
        '-CustomVisibilityProofCheckScript'
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

$args = ''
if ($task.Actions -and $task.Actions.Count -gt 0) {
    $args = [string]$task.Actions[0].Arguments
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

Write-Host ("status=ok task={0}" -f $TaskName)
exit 0
