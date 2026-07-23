[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$PythonExe = 'python',
    [switch]$PreviewOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-RepeatingTriggerFromToday {
    param(
        [Parameter(Mandatory = $true)] [datetime]$AtTime,
        [Parameter(Mandatory = $true)] [timespan]$Interval
    )

    $now = Get-Date
    $start = $now.Date.AddHours($AtTime.Hour).AddMinutes($AtTime.Minute)
    while ($start -le $now) {
        $start = $start.Add($Interval)
    }
    New-ScheduledTaskTrigger `
        -Once `
        -At $start `
        -RepetitionInterval $Interval `
        -RepetitionDuration (New-TimeSpan -Days 3650)
}

function Register-DesiredTask {
    param(
        [Parameter(Mandatory = $true)] [hashtable]$Spec,
        [Parameter(Mandatory = $true)] [Microsoft.Management.Infrastructure.CimInstance]$Trigger
    )

    $target = [string]$Spec.target
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        throw "Scheduled-task target missing: $target"
    }

    $action = New-ScheduledTaskAction `
        -Execute ([string]$Spec.execute) `
        -Argument ([string]$Spec.arguments) `
        -WorkingDirectory $RepoRoot
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -MultipleInstances IgnoreNew
    $principal = New-ScheduledTaskPrincipal `
        -UserId 'SYSTEM' `
        -LogonType ServiceAccount `
        -RunLevel Highest
    $task = New-ScheduledTask `
        -Action $action `
        -Trigger $Trigger `
        -Settings $settings `
        -Principal $principal `
        -Description ([string]$Spec.description)
    Register-ScheduledTask -TaskName ([string]$Spec.name) -InputObject $task -Force | Out-Null
    Write-Host "Converged task: $($Spec.name)"
}

$specs = @(
    @{
        name = 'QM_PublicSnapshot_Export_Hourly'
        target = (Join-Path $RepoRoot 'scripts\export_public_snapshot.ps1')
        execute = 'powershell.exe'
        arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $RepoRoot 'scripts\export_public_snapshot.ps1')`""
        cadence = 'hourly'
        minute = 7
        description = 'Exports the public strategy-farm snapshot.'
    },
    @{
        name = 'QM_DWX_HourlyCheck'
        target = (Join-Path $RepoRoot 'infra\scripts\Invoke-DwxHourlyCheck.ps1')
        execute = 'powershell.exe'
        arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $RepoRoot 'infra\scripts\Invoke-DwxHourlyCheck.ps1')`""
        cadence = 'hourly'
        minute = 7
        description = 'Runs the deterministic DWX import and verification workflow.'
    },
    @{
        name = 'QM_AggregatorState_1min'
        target = (Join-Path $RepoRoot 'scripts\aggregator\standalone_aggregator_loop.py')
        execute = $PythonExe
        arguments = "`"$(Join-Path $RepoRoot 'scripts\aggregator\standalone_aggregator_loop.py')`" --once"
        cadence = 'minutes'
        every = 1
        minute = 0
        description = 'Refreshes deterministic local pipeline state.'
    },
    @{
        name = 'QM_InfraHealthCheck_5min'
        target = (Join-Path $RepoRoot 'infra\monitoring\Invoke-InfraHealthCheck.ps1')
        execute = 'powershell.exe'
        arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $RepoRoot 'infra\monitoring\Invoke-InfraHealthCheck.ps1')`""
        cadence = 'minutes'
        every = 5
        minute = 0
        description = 'Checks disk, MT5, DWX, Drive, aggregator, and repository health.'
    },
    @{
        name = 'QM_GitIndexLockMonitor_10min'
        target = (Join-Path $RepoRoot 'infra\monitoring\Invoke-GitIndexLockMonitor.ps1')
        execute = 'powershell.exe'
        arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $RepoRoot 'infra\monitoring\Invoke-GitIndexLockMonitor.ps1')`" -StaleAfterMinutes 20 -FailOnFinding"
        cadence = 'minutes'
        every = 10
        minute = 2
        description = 'Detects stale Git index locks in the canonical repository.'
    },
    @{
        name = 'QM_DriveGitExclusion_15min'
        target = (Join-Path $RepoRoot 'infra\monitoring\Test-DriveGitExclusion.ps1')
        execute = 'powershell.exe'
        arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $RepoRoot 'infra\monitoring\Test-DriveGitExclusion.ps1')`" -PrimaryRepoForWorktrees `"$RepoRoot`" -IncludeGitWorktrees"
        cadence = 'minutes'
        every = 15
        minute = 6
        description = 'Verifies that repositories and worktrees remain outside sync roots.'
    },
    @{
        name = 'QM_MainArtifactEnforcer_15min'
        target = (Join-Path $RepoRoot 'infra\monitoring\Test-MainArtifactEnforcer.ps1')
        execute = 'powershell.exe'
        arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $RepoRoot 'infra\monitoring\Test-MainArtifactEnforcer.ps1')`" -RepoRoot `"$RepoRoot`" -ProtectedBranch main"
        cadence = 'minutes'
        every = 15
        minute = 13
        description = 'Detects forbidden transient artifacts on the protected branch.'
    },
    @{
        name = 'QM_Backup_Daily_0215'
        target = (Join-Path $RepoRoot 'infra\backup.ps1')
        execute = 'powershell.exe'
        arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $RepoRoot 'infra\backup.ps1')`""
        cadence = 'daily'
        at = '02:15'
        description = 'Runs the daily repository and report backup workflow.'
    },
    @{
        name = 'QM_RecoveryOrphans_Cleanup_Daily_0310'
        target = (Join-Path $RepoRoot 'infra\scripts\Remove-RecoveryOrphans.ps1')
        execute = 'powershell.exe'
        arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $RepoRoot 'infra\scripts\Remove-RecoveryOrphans.ps1')`""
        cadence = 'daily'
        at = '03:10'
        description = 'Removes recovery-orphan directories after the configured minimum age.'
    }
)

$missing = @($specs | Where-Object { -not (Test-Path -LiteralPath ([string]$_.target) -PathType Leaf) })
if ($missing.Count -gt 0) {
    $paths = $missing | ForEach-Object { [string]$_.target }
    throw "Cannot register infrastructure tasks; target(s) missing: $($paths -join ', ')"
}

if ($PreviewOnly.IsPresent) {
    @($specs | ForEach-Object { [pscustomobject]$_ }) | ConvertTo-Json -Depth 5
    exit 0
}

foreach ($spec in $specs) {
    if ($spec.cadence -eq 'daily') {
        $trigger = New-ScheduledTaskTrigger -Daily -At ([string]$spec.at)
    }
    elseif ($spec.cadence -eq 'hourly') {
        $trigger = New-RepeatingTriggerFromToday `
            -AtTime (Get-Date ("00:{0:D2}" -f [int]$spec.minute)) `
            -Interval (New-TimeSpan -Hours 1)
    }
    else {
        $trigger = New-RepeatingTriggerFromToday `
            -AtTime (Get-Date ("00:{0:D2}" -f [int]$spec.minute)) `
            -Interval (New-TimeSpan -Minutes ([int]$spec.every))
    }
    Register-DesiredTask -Spec $spec -Trigger $trigger
}
