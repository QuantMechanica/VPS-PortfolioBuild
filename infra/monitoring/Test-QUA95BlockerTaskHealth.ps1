[CmdletBinding()]
param(
    [string]$TaskName = 'QM_QUA95_BlockerRefresh',
    [int]$MaxAgeMinutes = 125
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
    $info = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction Stop
} catch {
    Write-Host ("status=critical task={0} message=not_found" -f $TaskName)
    exit 2
}

$issues = @()
if ($task.State -eq 'Disabled') {
    $issues += 'disabled'
}
if ([int]$info.LastTaskResult -ne 0) {
    $issues += ("last_result={0}" -f [int]$info.LastTaskResult)
}

$ageMinutes = $null
if ($info.LastRunTime -and $info.LastRunTime.Year -gt 2000) {
    $ageMinutes = [math]::Round(((Get-Date) - $info.LastRunTime).TotalMinutes, 2)
    if ($ageMinutes -gt $MaxAgeMinutes) {
        $issues += ("stale_minutes={0}" -f $ageMinutes)
    }
} else {
    $issues += 'never_ran'
}

if ($issues.Count -gt 0) {
    Write-Host ("status=critical task={0} issues={1}" -f $TaskName, ($issues -join ','))
    exit 2
}

Write-Host ("status=ok task={0} last_run={1:o} age_minutes={2}" -f $TaskName, $info.LastRunTime, $ageMinutes)
exit 0
