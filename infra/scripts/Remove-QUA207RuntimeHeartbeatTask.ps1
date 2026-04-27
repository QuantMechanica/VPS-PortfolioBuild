[CmdletBinding()]
param(
    [string]$TaskName = 'QM_QUA207_RuntimeHeartbeat_30min',
    [switch]$PreviewOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($null -eq $existing) {
    Write-Host ("status=ok task_absent={0}" -f $TaskName)
    exit 0
}

if ($PreviewOnly) {
    Write-Host ("preview_remove_task={0}" -f $TaskName)
    exit 0
}

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
Write-Host ("removed_task={0}" -f $TaskName)
exit 0
