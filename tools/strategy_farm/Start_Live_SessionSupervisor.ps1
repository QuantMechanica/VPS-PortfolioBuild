<#
.SYNOPSIS
  Start the resident live MT5 supervisor in an existing qm-admin session.

.DESCRIPTION
  A normal InteractiveToken demand start can remain queued when its RDP session
  is disconnected. This bootstrapper uses IRegisteredTask.RunEx with
  TASK_RUN_USE_SESSION_ID so Task Scheduler binds the already registered task to
  the exact existing desktop session. It never starts either MT5 terminal itself.

  Success requires all three ownership signals to agree:
    * Task Scheduler reports one running instance and its engine PID;
    * that PID is in the requested Windows session; and
    * the supervisor heartbeat reports the same PID, session, user SID, and a
      fresh timestamp.
#>
[CmdletBinding()]
param(
    [string]$TaskName = 'QM_Live_MT5_SessionSupervisor',
    [string]$TargetUser = 'qm-admin',
    [int]$SessionId = -1,
    [string]$ExpectedScriptPath = 'C:\QM\repo\tools\strategy_farm\Live_MT5_SessionSupervisor.ps1',
    [string]$StateFile = 'D:\QM\reports\state\live_session_supervisor.json',
    [ValidateRange(5, 60)][int]$VerifySeconds = 30,
    [switch]$ProbeOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$taskRunUseSessionId = 4
$expectedPowerShell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$expectedRepoRoot = 'C:\QM\repo'
$expectedArguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ExpectedScriptPath`" -IntervalSeconds 10"

function Resolve-AccountSid {
    param([string]$Account)
    return ([Security.Principal.NTAccount]$Account).Translate(
        [Security.Principal.SecurityIdentifier]
    ).Value
}

function Get-ExactTargetSession {
    param(
        [string]$UserName,
        [int]$RequestedSessionId
    )
    $rows = [Collections.Generic.List[object]]::new()
    $escapedUser = [regex]::Escape($UserName)
    $raw = @(& "$env:SystemRoot\System32\qwinsta.exe" 2>$null)
    if ($LASTEXITCODE -ne 0) { throw "qwinsta failed with exit code $LASTEXITCODE" }
    foreach ($line in $raw) {
        if ($line -match "(?i)(?:^|\s)$escapedUser\s+(?<id>\d+)\s+(?<state>Active|Disc|Conn)\b") {
            $rows.Add([pscustomobject]@{
                id = [int]$matches.id
                state = [string]$matches.state
            })
        }
    }
    if ($RequestedSessionId -eq 0 -or $RequestedSessionId -lt -1) {
        throw "SessionId must identify an interactive session greater than zero: $RequestedSessionId"
    }
    if ($RequestedSessionId -gt 0) {
        $rows = @($rows | Where-Object { $_.id -eq $RequestedSessionId })
    }
    if (@($rows).Count -ne 1) {
        throw "Expected exactly one existing session for $UserName; matched $(@($rows).Count)"
    }
    return @($rows)[0]
}

function Assert-SupervisorTaskContract {
    param(
        [string]$Name,
        [string]$TargetAccount,
        [string]$TargetSid
    )
    if ($Name -notmatch '^[A-Za-z0-9_.-]+$') { throw "Unsafe task name: $Name" }
    $task = Get-ScheduledTask -TaskPath '\' -TaskName $Name -ErrorAction Stop
    if ($task.State -eq 'Disabled') { throw "$Name is disabled" }

    $principalSid = Resolve-AccountSid ([string]$task.Principal.UserId)
    if ($principalSid -ne $TargetSid) {
        throw "$Name principal drift: '$($task.Principal.UserId)' != '$TargetAccount'"
    }
    if ([string]$task.Principal.LogonType -ne 'Interactive') {
        throw "$Name LogonType drift: '$($task.Principal.LogonType)' != 'Interactive'"
    }
    if (@($task.Actions).Count -ne 1) { throw "$Name must have exactly one action" }
    $action = @($task.Actions)[0]
    if (-not [string]::Equals([string]$action.Execute, $expectedPowerShell, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Name executable drift: '$($action.Execute)'"
    }
    if (-not [string]::Equals(([string]$action.Arguments).Trim(), $expectedArguments, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Name arguments drift"
    }
    if (-not [string]::Equals(([string]$action.WorkingDirectory).TrimEnd('\'), $expectedRepoRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Name working-directory drift: '$($action.WorkingDirectory)'"
    }

    if (@($task.Triggers).Count -ne 1 -or
        $task.Triggers[0].CimClass.CimClassName -ne 'MSFT_TaskLogonTrigger') {
        throw "$Name must have exactly one logon trigger"
    }
    $triggerSid = Resolve-AccountSid ([string]$task.Triggers[0].UserId)
    if ($triggerSid -ne $TargetSid) { throw "$Name logon-trigger user drift" }
    if ([string]$task.Triggers[0].Delay -ne 'PT45S') { throw "$Name logon-trigger delay drift" }

    if ($task.Settings.AllowDemandStart -ne $true) {
        throw "$Name must allow demand start for RunEx session binding"
    }
    if ([string]$task.Settings.ExecutionTimeLimit -ne 'PT0S' -or
        [string]$task.Settings.MultipleInstances -ne 'IgnoreNew' -or
        [int]$task.Settings.RestartCount -ne 255 -or
        [string]$task.Settings.RestartInterval -ne 'PT1M') {
        throw "$Name resident/restart settings drift"
    }
}

function Get-RegisteredTaskInstances {
    param($RegisteredTask)
    $collection = $null
    $records = [Collections.Generic.List[object]]::new()
    try {
        $collection = $RegisteredTask.GetInstances(0)
        for ($index = 1; $index -le [int]$collection.Count; $index++) {
            $instance = $null
            try {
                $instance = $collection.Item($index)
                $enginePid = [int]$instance.EnginePID
                $engineSession = $null
                if ($enginePid -gt 0) {
                    try { $engineSession = [int](Get-Process -Id $enginePid -ErrorAction Stop).SessionId }
                    catch { $engineSession = $null }
                }
                $records.Add([pscustomobject]@{
                    instance_guid = [string]$instance.InstanceGuid
                    engine_pid = $enginePid
                    session_id = $engineSession
                    state = [int]$instance.State
                })
            } finally {
                if ($null -ne $instance) {
                    [Runtime.InteropServices.Marshal]::FinalReleaseComObject($instance) | Out-Null
                }
            }
        }
    } finally {
        if ($null -ne $collection) {
            [Runtime.InteropServices.Marshal]::FinalReleaseComObject($collection) | Out-Null
        }
    }
    return @($records)
}

function Get-FreshMatchingHeartbeat {
    param(
        [int]$EnginePid,
        [int]$ExpectedSessionId,
        [string]$ExpectedSid
    )
    if (-not (Test-Path -LiteralPath $StateFile -PathType Leaf)) { return $null }
    try {
        $heartbeat = Get-Content -LiteralPath $StateFile -Raw -ErrorAction Stop | ConvertFrom-Json
        $checked = [DateTime]::Parse([string]$heartbeat.last_checked_utc).ToUniversalTime()
        $age = ([DateTime]::UtcNow - $checked).TotalSeconds
        if ($age -lt -5 -or $age -gt 60) { return $null }
        if ([int]$heartbeat.supervisor_pid -ne $EnginePid -or
            [int]$heartbeat.session_id -ne $ExpectedSessionId -or
            [string]$heartbeat.identity_sid -ne $ExpectedSid) {
            return $null
        }
        return [pscustomobject]@{ value = $heartbeat; age_seconds = [math]::Round($age, 1) }
    } catch { return $null }
}

function Wait-SchedulerOwnership {
    param(
        $RegisteredTask,
        [int]$ExpectedSessionId,
        [string]$ExpectedSid,
        [int]$TimeoutSeconds
    )
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $instances = @(Get-RegisteredTaskInstances -RegisteredTask $RegisteredTask)
        $targetInstances = @($instances | Where-Object { $_.session_id -eq $ExpectedSessionId })
        if ($instances.Count -gt 1) {
            throw "$TaskName has multiple running Task Scheduler instances"
        }
        if ($targetInstances.Count -eq 1) {
            $item = $targetInstances[0]
            $heartbeat = Get-FreshMatchingHeartbeat `
                -EnginePid $item.engine_pid `
                -ExpectedSessionId $ExpectedSessionId `
                -ExpectedSid $ExpectedSid
            if ($null -ne $heartbeat) {
                return [pscustomobject]@{
                    task_name = $TaskName
                    scheduler_owned = $true
                    started = $false
                    session_id = $ExpectedSessionId
                    engine_pid = $item.engine_pid
                    instance_guid = $item.instance_guid
                    heartbeat_age_seconds = $heartbeat.age_seconds
                }
            }
        }
        if ($ProbeOnly.IsPresent) { return $null }
        if ([DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 500 }
    } while ([DateTime]::UtcNow -lt $deadline)
    return $null
}

$targetAccount = "$env:COMPUTERNAME\$TargetUser"
$targetSid = Resolve-AccountSid $targetAccount
$targetSession = Get-ExactTargetSession -UserName $TargetUser -RequestedSessionId $SessionId
Assert-SupervisorTaskContract -Name $TaskName -TargetAccount $targetAccount -TargetSid $targetSid

$service = $null
$folder = $null
$registeredTask = $null
$runResult = $null
try {
    $service = New-Object -ComObject 'Schedule.Service'
    $service.Connect()
    $folder = $service.GetFolder('\')
    $registeredTask = $folder.GetTask($TaskName)
    if (-not [bool]$registeredTask.Enabled) { throw "$TaskName is disabled in Task Scheduler COM" }

    $owned = Wait-SchedulerOwnership `
        -RegisteredTask $registeredTask `
        -ExpectedSessionId $targetSession.id `
        -ExpectedSid $targetSid `
        -TimeoutSeconds 1
    if ($null -ne $owned) {
        $owned | ConvertTo-Json -Compress
        exit 0
    }
    if ($ProbeOnly.IsPresent) {
        [pscustomobject]@{
            task_name = $TaskName
            scheduler_owned = $false
            started = $false
            session_id = $targetSession.id
            reason = 'no_matching_scheduler_instance_and_heartbeat'
        } | ConvertTo-Json -Compress
        exit 2
    }

    $before = @(Get-RegisteredTaskInstances -RegisteredTask $registeredTask)
    if ($before.Count -gt 0) {
        throw "$TaskName already has a running instance outside session $($targetSession.id); RunEx refused"
    }

    # TASK_RUN_USE_SESSION_ID is the supported API for binding this
    # InteractiveToken task to an existing Active or disconnected session.
    $runResult = $registeredTask.RunEx($null, $taskRunUseSessionId, [int]$targetSession.id, $null)
    $owned = Wait-SchedulerOwnership `
        -RegisteredTask $registeredTask `
        -ExpectedSessionId $targetSession.id `
        -ExpectedSid $targetSid `
        -TimeoutSeconds $VerifySeconds
    if ($null -eq $owned) {
        throw "$TaskName did not establish scheduler-owned heartbeat in session $($targetSession.id) within $VerifySeconds seconds"
    }
    $owned.started = $true
    $owned | ConvertTo-Json -Compress
} finally {
    foreach ($comObject in @($runResult, $registeredTask, $folder, $service)) {
        if ($null -ne $comObject -and [Runtime.InteropServices.Marshal]::IsComObject($comObject)) {
            [Runtime.InteropServices.Marshal]::FinalReleaseComObject($comObject) | Out-Null
        }
    }
}
