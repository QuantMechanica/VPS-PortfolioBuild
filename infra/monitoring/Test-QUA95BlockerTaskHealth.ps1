[CmdletBinding()]
param(
    [string]$TaskName = 'QM_QUA95_BlockerRefresh',
    [int]$MaxAgeMinutes = 125,
    [string]$TransitionPayloadCheckScript = 'C:\QM\repo\infra\scripts\Test-QUA95IssueTransitionPayload.ps1'
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

if (-not (Test-Path -LiteralPath $TransitionPayloadCheckScript)) {
    Write-Host ("status=critical task={0} issues=transition_check_missing path={1}" -f $TaskName, $TransitionPayloadCheckScript)
    exit 2
}

$transitionOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $TransitionPayloadCheckScript 2>&1
$transitionCode = $LASTEXITCODE
if ($transitionCode -ne 0) {
    $transitionText = ($transitionOut | ForEach-Object { $_.ToString() }) -join '; '
    Write-Host ("status=critical task={0} issues=transition_payload_check_failed exit_code={1} output={2}" -f $TaskName, $transitionCode, $transitionText)
    exit 2
}

Write-Host ("status=ok task={0} last_run={1:o} age_minutes={2}" -f $TaskName, $info.LastRunTime, $ageMinutes)
exit 0
