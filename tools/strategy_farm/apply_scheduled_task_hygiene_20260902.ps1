[CmdletBinding(DefaultParameterSetName = 'Plan')]
param(
    [Parameter(ParameterSetName = 'Apply')]
    [switch]$Apply,
    [Parameter(ParameterSetName = 'Rollback', Mandatory = $true)]
    [switch]$Rollback,
    [Parameter(ParameterSetName = 'Rollback', Mandatory = $true)]
    [string]$BackupDir = '',
    [string]$OutputPath = 'D:\QM\reports\state\scheduled_task_hygiene_20260902.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$limits = [ordered]@{
    'QM_StrategyFarm_PumpMaintenance_Hourly' = 'PT2H'
    'QM_StrategyFarm_Dashboard_Hourly' = 'PT1H'
    'QM_StrategyFarm_HourlyMonitor_60min' = 'PT1H'
    'QM_StrategyFarm_UnbuiltCardsDisposition_Hourly' = 'PT1H'
    'QM_StrategyFarm_ContinuousRetention_45min' = 'PT2H'
}
$oneOffs = @(
    'QM_Balke_Diagnostic',
    'QM_Balke_Manual_NB3',
    'QM_Balke_Walkforward',
    'QM_FTMO_Round26_Prep_Sunday',
    'QM_NDX_Convert',
    'QM_PreSunday_Prep_Saturday',
    'QM_Q08_Neighborhood',
    'QM_QM10834_AUDIT_74482231bd60c80a5518fc4a',
    'QM_QM10834_AUDIT_c9dd675e92f10d1f726cd54c',
    'QM_QM13210_XAU_AUDIT_2ec4ba1e251eaf13ee140c8b',
    'QM_QM20002_G2_AUDIT_1e59619fcaab480110a79f90',
    'QM_Rebuild_Wave',
    'QM_TMP_SpawnWorkers_Once'
)

function Get-SafeFileName([string]$Name) {
    return ($Name -replace '[^A-Za-z0-9_.-]', '_') + '.xml'
}

if ($Rollback) {
    $resolved = [IO.Path]::GetFullPath($BackupDir)
    if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
        throw "Rollback backup directory missing: $resolved"
    }
    $restored = @()
    foreach ($xmlFile in Get-ChildItem -LiteralPath $resolved -Filter '*.xml' -File) {
        $xml = Get-Content -LiteralPath $xmlFile.FullName -Raw
        $name = [IO.Path]::GetFileNameWithoutExtension($xmlFile.Name)
        Register-ScheduledTask -TaskName $name -Xml $xml -Force | Out-Null
        $restored += $name
    }
    [ordered]@{ schema='qm.scheduled-task-hygiene/v1'; mode='rollback'; backup_dir=$resolved; restored=$restored } |
        ConvertTo-Json -Depth 5
    return
}

$allNames = @($limits.Keys) + $oneOffs
$inventory = @()
foreach ($name in $allNames) {
    $task = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
    if ($null -eq $task) {
        $inventory += [ordered]@{ name=$name; exists=$false }
        continue
    }
    $info = Get-ScheduledTaskInfo -TaskName $name
    $inventory += [ordered]@{
        name=$name
        exists=$true
        execution_time_limit=[string]$task.Settings.ExecutionTimeLimit
        last_result=[int64]$info.LastTaskResult
        last_run=$info.LastRunTime.ToUniversalTime().ToString('o')
        action=@($task.Actions | ForEach-Object { "$(($_.Execute)) $(($_.Arguments))" }) -join ' || '
    }
}

$receipt = [ordered]@{
    schema='qm.scheduled-task-hygiene/v1'
    mode=if ($Apply) { 'apply' } else { 'plan' }
    at_utc=[datetime]::UtcNow.ToString('o')
    inventory=$inventory
    requested_limits=$limits
    requested_unregistrations=$oneOffs
    backup_dir=$null
    updated=@()
    unregistered=@()
}

if ($Apply) {
    $stamp = [datetime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
    $backup = Join-Path 'D:\QM\reports\state' "scheduled_task_hygiene_20260902_before_$stamp"
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    foreach ($name in $allNames) {
        $task = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
        if ($null -ne $task) {
            Export-ScheduledTask -TaskName $name |
                Set-Content -LiteralPath (Join-Path $backup (Get-SafeFileName $name)) -Encoding UTF8
        }
    }
    foreach ($entry in $limits.GetEnumerator()) {
        $task = Get-ScheduledTask -TaskName $entry.Key -ErrorAction SilentlyContinue
        if ($null -eq $task) { throw "Required recurring task missing: $($entry.Key)" }
        $settings = $task.Settings
        $settings.ExecutionTimeLimit = $entry.Value
        Set-ScheduledTask -TaskName $entry.Key -Settings $settings | Out-Null
        $receipt.updated += [ordered]@{ name=$entry.Key; execution_time_limit=$entry.Value }
    }
    foreach ($name in $oneOffs) {
        if ($null -ne (Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue)) {
            Unregister-ScheduledTask -TaskName $name -Confirm:$false
            $receipt.unregistered += $name
        }
    }
    $receipt.backup_dir = $backup
}

$json = $receipt | ConvertTo-Json -Depth 8
if ($Apply) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
    Set-Content -LiteralPath $OutputPath -Value $json -Encoding UTF8
}
$json
