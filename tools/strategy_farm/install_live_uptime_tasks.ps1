<#
.SYNOPSIS
  Install both live MT5 logon tasks, resident session supervisor, and SYSTEM watchdog.

.DESCRIPTION
  The terminals are GUI applications and therefore run with an InteractiveToken
  in the qm-admin autologon session. A resident user-session supervisor recovers
  individual crashes even while RDP is disconnected. The watchdog runs as SYSTEM
  every minute, checks both exact image paths, and provides total-session recovery.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$InteractiveUser = 'qm-admin',
    [ValidateRange(1, 5)][int]$WatchdogMinutes = 1,
    [switch]$RunNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$dxzScript = Join-Path $RepoRoot 'tools\strategy_farm\T_Live_ON.ps1'
$ftmoScript = Join-Path $RepoRoot 'tools\strategy_farm\FTMO_ON.ps1'
$watchdogScript = Join-Path $RepoRoot 'tools\strategy_farm\T_Live_Watchdog.ps1'
$dxzProfileScript = Join-Path $RepoRoot 'tools\strategy_farm\prepare_dxz_v2_liveops_profile.ps1'
$sessionSupervisorScript = Join-Path $RepoRoot 'tools\strategy_farm\Live_MT5_SessionSupervisor.ps1'
$sessionSupervisorStarter = Join-Path $RepoRoot 'tools\strategy_farm\Start_Live_SessionSupervisor.ps1'
foreach ($path in @($dxzScript, $ftmoScript, $watchdogScript, $dxzProfileScript, $sessionSupervisorScript, $sessionSupervisorStarter)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required script missing: $path" }
    $tokens = $null
    $parseErrors = $null
    [Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$parseErrors) | Out-Null
    if ($parseErrors.Count -gt 0) {
        throw "PowerShell parse failed for $path : $(($parseErrors.Message) -join '; ')"
    }
}

$localUser = Get-LocalUser -Name $InteractiveUser -ErrorAction Stop
if (-not $localUser.Enabled) { throw "Interactive user is disabled: $InteractiveUser" }
$interactiveIdentity = "$env:COMPUTERNAME\$InteractiveUser"

# A reboot is only a recovery action if Windows can recreate the interactive
# desktop without human input. The password itself is an LSA secret and is
# deliberately verified later by the watchdog running as SYSTEM.
$winlogon = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction Stop
if ($winlogon.AutoAdminLogon -ne '1') { throw 'AutoAdminLogon is not enabled; refusing to arm reboot recovery' }
if (-not [string]::Equals([string]$winlogon.DefaultUserName, $InteractiveUser, [StringComparison]::OrdinalIgnoreCase)) {
    throw "DefaultUserName is '$($winlogon.DefaultUserName)', expected '$InteractiveUser'"
}
if (-not [string]::Equals([string]$winlogon.DefaultDomainName, $env:COMPUTERNAME, [StringComparison]::OrdinalIgnoreCase)) {
    throw "DefaultDomainName is '$($winlogon.DefaultDomainName)', expected '$env:COMPUTERNAME'"
}

$interactivePrincipal = New-ScheduledTaskPrincipal `
    -UserId $interactiveIdentity `
    -LogonType Interactive `
    -RunLevel Highest

$systemPrincipal = New-ScheduledTaskPrincipal `
    -UserId 'SYSTEM' `
    -LogonType ServiceAccount `
    -RunLevel Highest

$interactiveSettings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -DontStopOnIdleEnd `
    -DisallowDemandStart `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

$watchdogSettings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 2) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1)

$sessionSupervisorSettings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -DontStopOnIdleEnd `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 255 `
    -RestartInterval (New-TimeSpan -Minutes 1)

function Register-LiveLogonTask {
    param(
        [string]$TaskName,
        [string]$ScriptPath,
        [int]$DelaySeconds,
        [string]$Description
    )
    $action = New-ScheduledTaskAction `
        -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"" `
        -WorkingDirectory $RepoRoot
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $interactiveIdentity
    $trigger.Delay = "PT${DelaySeconds}S"
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $interactiveSettings `
        -Principal $interactivePrincipal `
        -Description $Description `
        -Force | Out-Null
    Enable-ScheduledTask -TaskName $TaskName | Out-Null
}

Register-LiveLogonTask `
    -TaskName 'QM_T_Live_AtLogon' `
    -ScriptPath $dxzScript `
    -DelaySeconds 15 `
    -Description 'Start DXZ Darwinex live MT5 in the qm-admin interactive session; idempotent; recovery profile DarwinexZero_V2_LiveOps.'

Register-LiveLogonTask `
    -TaskName 'QM_FTMO_AtLogon' `
    -ScriptPath $ftmoScript `
    -DelaySeconds 30 `
    -Description 'Start FTMO trial MT5 in the qm-admin interactive session; idempotent; explicit Administrator profile data directory.'

$sessionSupervisorAction = New-ScheduledTaskAction `
    -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -Argument "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$sessionSupervisorScript`" -IntervalSeconds 10" `
    -WorkingDirectory $RepoRoot
$sessionSupervisorTrigger = New-ScheduledTaskTrigger -AtLogOn -User $interactiveIdentity
$sessionSupervisorTrigger.Delay = 'PT45S'
$existingSupervisor = Get-ScheduledTask -TaskName 'QM_Live_MT5_SessionSupervisor' -ErrorAction SilentlyContinue
if ($existingSupervisor -and $existingSupervisor.State -eq 'Running') {
    Write-Warning 'Preserving the running live session supervisor task instance; task definition was not overwritten.'
} else {
    Register-ScheduledTask `
        -TaskName 'QM_Live_MT5_SessionSupervisor' `
        -Action $sessionSupervisorAction `
        -Trigger $sessionSupervisorTrigger `
        -Settings $sessionSupervisorSettings `
        -Principal $interactivePrincipal `
        -Description 'Resident qm-admin session supervisor: exact-path recovery for DXZ and FTMO while RDP is disconnected.' `
        -Force | Out-Null
}
Enable-ScheduledTask -TaskName 'QM_Live_MT5_SessionSupervisor' | Out-Null

$watchdogAction = New-ScheduledTaskAction `
    -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$watchdogScript`" -NoReboot" `
    -WorkingDirectory $RepoRoot
$watchdogTrigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes $WatchdogMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

Register-ScheduledTask `
    -TaskName 'QM_T_Live_Watchdog' `
    -Action $watchdogAction `
    -Trigger $watchdogTrigger `
    -Settings $watchdogSettings `
    -Principal $systemPrincipal `
    -Description 'Live uptime watchdog every minute (SYSTEM): path-checks DXZ + FTMO, relaunches through interactive tasks, and reboot-heals confirmed total session loss only when both terminals are already down.' `
    -Force | Out-Null
Enable-ScheduledTask -TaskName 'QM_T_Live_Watchdog' | Out-Null

function Assert-TaskContract {
    param(
        [string]$TaskName,
        [string]$ExpectedUser,
        [string]$ExpectedLogonType,
        [string]$ExpectedScript,
        [string]$ExpectedTriggerClass
    )
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
    try {
        $actualSid = ([Security.Principal.NTAccount]([string]$task.Principal.UserId)).Translate([Security.Principal.SecurityIdentifier]).Value
        $expectedSid = ([Security.Principal.NTAccount]$ExpectedUser).Translate([Security.Principal.SecurityIdentifier]).Value
        $samePrincipal = ($actualSid -eq $expectedSid)
    } catch { $samePrincipal = $false }
    if (-not $samePrincipal) {
        throw "$TaskName principal drift: '$($task.Principal.UserId)' != '$ExpectedUser'"
    }
    if ([string]$task.Principal.LogonType -ne $ExpectedLogonType) {
        throw "$TaskName LogonType drift: '$($task.Principal.LogonType)' != '$ExpectedLogonType'"
    }
    if (@($task.Actions).Count -ne 1 -or $task.Actions[0].Arguments -notlike "*$ExpectedScript*") {
        throw "$TaskName action drift: expected script '$ExpectedScript'"
    }
    if (@($task.Triggers).Count -ne 1 -or $task.Triggers[0].CimClass.CimClassName -ne $ExpectedTriggerClass) {
        throw "$TaskName trigger drift: expected '$ExpectedTriggerClass'"
    }
    return $task
}

$null = Assert-TaskContract -TaskName 'QM_T_Live_AtLogon' -ExpectedUser $interactiveIdentity `
    -ExpectedLogonType 'Interactive' -ExpectedScript $dxzScript -ExpectedTriggerClass 'MSFT_TaskLogonTrigger'
$null = Assert-TaskContract -TaskName 'QM_FTMO_AtLogon' -ExpectedUser $interactiveIdentity `
    -ExpectedLogonType 'Interactive' -ExpectedScript $ftmoScript -ExpectedTriggerClass 'MSFT_TaskLogonTrigger'
$verifiedSupervisor = Assert-TaskContract -TaskName 'QM_Live_MT5_SessionSupervisor' -ExpectedUser $interactiveIdentity `
    -ExpectedLogonType 'Interactive' -ExpectedScript $sessionSupervisorScript -ExpectedTriggerClass 'MSFT_TaskLogonTrigger'
if ([string]$verifiedSupervisor.Settings.ExecutionTimeLimit -ne 'PT0S' -or
    [string]$verifiedSupervisor.Settings.MultipleInstances -ne 'IgnoreNew' -or
    $verifiedSupervisor.Settings.AllowDemandStart -ne $true -or
    [int]$verifiedSupervisor.Settings.RestartCount -ne 255 -or
    [string]$verifiedSupervisor.Settings.RestartInterval -ne 'PT1M' -or
    [string]$verifiedSupervisor.Triggers[0].Delay -ne 'PT45S') {
    throw 'QM_Live_MT5_SessionSupervisor RunEx/restart/execution-time contract drift'
}
foreach ($oneShot in @('QM_T_Live_AtLogon', 'QM_FTMO_AtLogon')) {
    if ((Get-ScheduledTask -TaskName $oneShot).Settings.AllowDemandStart -ne $false) {
        throw "$oneShot must be logon-only; demand starts queue in disconnected RDP sessions"
    }
}
$verifiedWatchdog = Assert-TaskContract -TaskName 'QM_T_Live_Watchdog' -ExpectedUser 'SYSTEM' `
    -ExpectedLogonType 'ServiceAccount' -ExpectedScript $watchdogScript -ExpectedTriggerClass 'MSFT_TaskTimeTrigger'
if ($verifiedWatchdog.Triggers[0].Repetition.Interval -ne "PT${WatchdogMinutes}M") {
    throw "QM_T_Live_Watchdog cadence drift: '$($verifiedWatchdog.Triggers[0].Repetition.Interval)'"
}

# Superseded and unsafe: event-triggered tscon caused session arbitration races
# and session destruction on 2026-07-21. Preserve it for forensics, but keep OFF.
$tscon = Get-ScheduledTask -TaskName 'QM_TSCon_Console_OnDisconnect' -ErrorAction SilentlyContinue
if ($tscon) {
    Stop-ScheduledTask -TaskName $tscon.TaskName -ErrorAction SilentlyContinue | Out-Null
    Disable-ScheduledTask -TaskName $tscon.TaskName | Out-Null
}

# The legacy hygiene task can force-stop healthy live MT5 processes before a
# reboot. It is outside the new dual-live recovery contract and must remain
# disabled until it has equivalent maintenance, process, task, and Autologon
# guards of its own.
$hygiene = Get-ScheduledTask -TaskName 'QM_StrategyFarm_HygieneReboot' -ErrorAction SilentlyContinue
if ($hygiene) {
    Disable-ScheduledTask -TaskName $hygiene.TaskName -ErrorAction Stop | Out-Null
}

if ($RunNow.IsPresent) {
    $verificationStartedUtc = [DateTime]::UtcNow
    Start-ScheduledTask -TaskName 'QM_T_Live_Watchdog'
    $deadline = (Get-Date).AddSeconds(45)
    $verifiedState = $null
    do {
        Start-Sleep -Seconds 2
        $taskInfo = Get-ScheduledTaskInfo -TaskName 'QM_T_Live_Watchdog'
        $statePath = 'D:\QM\reports\state\live_uptime_watchdog.json'
        if (Test-Path -LiteralPath $statePath -PathType Leaf) {
            try {
                $candidate = Get-Content -LiteralPath $statePath -Raw -ErrorAction Stop | ConvertFrom-Json
                $checked = [DateTime]::Parse([string]$candidate.last_checked_utc).ToUniversalTime()
                if ($checked -ge $verificationStartedUtc.AddSeconds(-1)) { $verifiedState = $candidate }
            } catch { }
        }
    } until ($verifiedState -or (Get-Date) -ge $deadline)
    if (-not $verifiedState) { throw 'Watchdog smoke run did not produce fresh state within 45 seconds' }
    if ($verifiedState.autologon_ready -ne $true -or $verifiedState.autologon_secret_probe -ne 'present') {
        throw "SYSTEM watchdog could not verify Autologon LSA secret: ready=$($verifiedState.autologon_ready), probe=$($verifiedState.autologon_secret_probe)"
    }
    if ($verifiedState.process_probe_ok -ne $true) { throw 'SYSTEM watchdog process probe failed during smoke run' }
    if ($verifiedState.recovery_task_contract_ready -ne $true) {
        throw "SYSTEM watchdog rejected the recovery-task contract: $($verifiedState.recovery_task_contract_errors -join '|')"
    }
    if ($verifiedState.session_supervisor_ready -ne $true -or
        $verifiedState.session_supervisor_scheduler_owned -ne $true) {
        throw "Session supervisor is not Scheduler-owned/ready: ready=$($verifiedState.session_supervisor_ready), owned=$($verifiedState.session_supervisor_scheduler_owned), reason=$($verifiedState.session_supervisor_reason)"
    }
} else {
    Write-Warning 'RunNow was not supplied; SYSTEM-only Autologon LSA verification remains pending.'
}

foreach ($name in @('QM_T_Live_AtLogon', 'QM_FTMO_AtLogon', 'QM_Live_MT5_SessionSupervisor', 'QM_T_Live_Watchdog', 'QM_TSCon_Console_OnDisconnect', 'QM_StrategyFarm_HygieneReboot')) {
    $task = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
    if (-not $task) { continue }
    $info = Get-ScheduledTaskInfo -TaskName $name
    [pscustomobject]@{
        TaskName = $name
        State = $task.State
        Principal = $task.Principal.UserId
        LogonType = $task.Principal.LogonType
        LastResult = $info.LastTaskResult
        NextRunTime = $info.NextRunTime
    }
}
