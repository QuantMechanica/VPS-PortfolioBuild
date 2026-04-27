[CmdletBinding()]
param(
    [string]$RefreshTaskName = 'QM_QUA95_BlockerRefresh',
    [int]$RefreshMaxAgeMinutes = 125,
    [string]$TaskHealthTaskName = 'QM_QUA95_TaskHealth_15min',
    [int]$TaskHealthMaxAgeMinutes = 45,
    [string]$OutPath = 'C:\QM\repo\docs\ops\QUA-95_AUTOMATION_HEALTH_2026-04-27.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-TaskSnapshot {
    param(
        [string]$TaskName,
        [int]$MaxAgeMinutes
    )

    try {
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
        $info = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction Stop
    } catch {
        return [pscustomobject]@{
            task_name = $TaskName
            status = 'critical'
            reason = 'not_found'
        }
    }

    $issues = @()
    if ($task.State -eq 'Disabled') {
        $issues += 'disabled'
    }
    if ([int]$info.LastTaskResult -ne 0) {
        $issues += ("last_result={0}" -f [int]$info.LastTaskResult)
    }

    $age = $null
    if ($info.LastRunTime -and $info.LastRunTime.Year -gt 2000) {
        $age = [math]::Round(((Get-Date) - $info.LastRunTime).TotalMinutes, 2)
        if ($age -gt $MaxAgeMinutes) {
            $issues += ("stale_minutes={0}" -f $age)
        }
    } else {
        $issues += 'never_ran'
    }

    return [pscustomobject]@{
        task_name = $TaskName
        status = if ($issues.Count -eq 0) { 'ok' } else { 'critical' }
        max_age_minutes = $MaxAgeMinutes
        last_run_local = if ($info.LastRunTime) { $info.LastRunTime.ToString('o') } else { $null }
        last_result = [int]$info.LastTaskResult
        age_minutes = $age
        issues = @($issues)
    }
}

$refresh = Get-TaskSnapshot -TaskName $RefreshTaskName -MaxAgeMinutes $RefreshMaxAgeMinutes
$taskHealth = Get-TaskSnapshot -TaskName $TaskHealthTaskName -MaxAgeMinutes $TaskHealthMaxAgeMinutes

$overall = if ($refresh.status -eq 'ok' -and $taskHealth.status -eq 'ok') { 'ok' } else { 'critical' }

$summary = [ordered]@{
    issue = 'QUA-95'
    generated_at_local = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
    overall_status = $overall
    checks = @($refresh, $taskHealth)
}

$outDir = Split-Path -Parent $OutPath
if ($outDir) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutPath -Encoding UTF8

Write-Host ("status={0} refresh_task={1} task_health={2}" -f $overall, $refresh.status, $taskHealth.status)
Write-Host ("wrote={0}" -f $OutPath)
if ($overall -ne 'ok') {
    exit 2
}
exit 0
