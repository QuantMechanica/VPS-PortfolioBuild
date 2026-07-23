<#
.SYNOPSIS
  Live uptime watchdog for both interactive MT5 terminals.

.DESCRIPTION
  Runs as SYSTEM every minute. The two live MT5 GUI processes must run in the
  qm-admin interactive session; launching them directly from session 0 is not
  supported. If a terminal is missing while that session exists, the resident
  qm-admin session supervisor performs the interactive relaunch; the SYSTEM
  watchdog verifies the result without demand-starting an InteractiveToken task.

  If the desktop session itself has disappeared and BOTH live terminals are
  already down, the watchdog confirms the condition on consecutive runs,
  verifies Windows autologon (including the SYSTEM-only LSA secret), and asks
  Windows for a controlled reboot. The reboot path is independent of Factory
  ON/OFF. It never reboots while either live terminal is still running.

  Maintenance kill switch:
    D:\QM\reports\state\LIVE_UPTIME_MAINTENANCE.flag

  Evidence:
    D:\QM\reports\state\live_uptime_watchdog.json
    D:\QM\reports\state\live_uptime_watchdog.jsonl
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$NoReboot,
    [ValidateRange(2, 10)][int]$ConfirmCycles = 2,
    [ValidateRange(1, 60)][int]$StartupGraceMinutes = 5,
    [ValidateRange(0, 45)][int]$RelaunchWaitSeconds = 12,
    [ValidateRange(30, 1440)][int]$RebootCooldownMinutes = 360
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$targetUser = 'qm-admin'
$stateDir = 'D:\QM\reports\state'
$stateFile = Join-Path $stateDir 'live_uptime_watchdog.json'
$historyFile = Join-Path $stateDir 'live_uptime_watchdog.jsonl'
$sessionSupervisorStateFile = Join-Path $stateDir 'live_session_supervisor.json'
$maintenanceFlag = Join-Path $stateDir 'LIVE_UPTIME_MAINTENANCE.flag'
$unsafeTsconTask = 'QM_TSCon_Console_OnDisconnect'
$repoRoot = 'C:\QM\repo'
$windowsPowerShell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$dxzLauncher = Join-Path $repoRoot 'tools\strategy_farm\T_Live_ON.ps1'
$ftmoLauncher = Join-Path $repoRoot 'tools\strategy_farm\FTMO_ON.ps1'
$sessionSupervisorScript = Join-Path $repoRoot 'tools\strategy_farm\Live_MT5_SessionSupervisor.ps1'
$sessionSupervisorStarter = Join-Path $repoRoot 'tools\strategy_farm\Start_Live_SessionSupervisor.ps1'

$dxzPath = 'C:\QM\mt5\T_Live\MT5_Base\terminal64.exe'
$ftmoPath = 'C:\Program Files\FTMO Global Markets MT5 Terminal\terminal64.exe'
$dxzCommon = 'C:\QM\mt5\T_Live\MT5_Base\config\common.ini'
$ftmoCommon = 'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\config\common.ini'
$expectedDxzProfile = 'DarwinexZero_V2_LiveOps'
$expectedFtmoProfile = 'Default'

function Get-UtcStamp {
    return [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
}

function ConvertFrom-UtcStamp {
    param([AllowNull()][string]$Value)
    if (-not $Value) { return $null }
    try {
        return [DateTime]::ParseExact(
            $Value,
            'yyyy-MM-ddTHH:mm:ssZ',
            [Globalization.CultureInfo]::InvariantCulture,
            ([Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal)
        )
    } catch { return $null }
}

function Test-MaintenanceRequested {
    # A failed flag probe is UNKNOWN, so the destructive path must fail closed.
    try {
        return [bool](Test-Path -LiteralPath $maintenanceFlag -PathType Leaf -ErrorAction Stop)
    } catch {
        return $true
    }
}

function Get-ProfileLast {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try {
        $line = Get-Content -LiteralPath $Path -Encoding Unicode -ErrorAction Stop |
            Where-Object { $_ -match '^ProfileLast=' } |
            Select-Object -First 1
        if ($line -match '^ProfileLast=(.*)$') { return $matches[1].Trim() }
    } catch { }
    return $null
}

function Get-ExpertsEnabled {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try {
        $text = [IO.File]::ReadAllText($Path, [Text.Encoding]::Unicode)
        $section = [regex]::Match($text, '(?ms)^\[Experts\]\s*\r?\n.*?(?=^\[|\z)')
        if ($section.Success -and $section.Value -match '(?m)^Enabled=(\d+)\s*$') {
            return [int]$matches[1]
        }
    } catch { }
    return $null
}

function Get-LiveProcessState {
    try {
        $all = @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction Stop)
    } catch {
        return [pscustomobject]@{
            probe_ok = $false
            probe_error = $_.Exception.Message
            dxz = @()
            ftmo = @()
            dxz_running = $false
            ftmo_running = $false
        }
    }
    if (@($all | Where-Object { -not $_.ExecutablePath }).Count -gt 0) {
        return [pscustomobject]@{
            probe_ok = $false
            probe_error = 'one_or_more_terminal64_paths_unreadable'
            dxz = @()
            ftmo = @()
            dxz_running = $false
            ftmo_running = $false
        }
    }
    $dxz = @($all | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.Equals($dxzPath, [StringComparison]::OrdinalIgnoreCase) })
    $ftmo = @($all | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.Equals($ftmoPath, [StringComparison]::OrdinalIgnoreCase) })
    return [pscustomobject]@{
        probe_ok = $true
        probe_error = $null
        dxz = $dxz
        ftmo = $ftmo
        dxz_running = ($dxz.Count -gt 0)
        ftmo_running = ($ftmo.Count -gt 0)
    }
}

function Get-IndependentLivePresence {
    # A second API guards the destructive edge. If process paths cannot be
    # enumerated, the answer is unknown and the reboot must be cancelled.
    try {
        $items = @(Get-Process -Name 'terminal64' -ErrorAction SilentlyContinue)
        $pathProbeFailed = $false
        $paths = @($items | ForEach-Object {
            try {
                $path = $_.Path
                if (-not $path) { $pathProbeFailed = $true }
                $path
            } catch { $pathProbeFailed = $true; $null }
        })
        if ($pathProbeFailed) {
            return [pscustomobject]@{ probe_ok = $false; any_live = $false }
        }
        $any = @($paths | Where-Object {
            $_ -and ($_.Equals($dxzPath, [StringComparison]::OrdinalIgnoreCase) -or
                     $_.Equals($ftmoPath, [StringComparison]::OrdinalIgnoreCase))
        }).Count -gt 0
        return [pscustomobject]@{ probe_ok = $true; any_live = $any }
    } catch {
        return [pscustomobject]@{ probe_ok = $false; any_live = $false }
    }
}

function Get-TargetSession {
    $sid = $null
    $sessionState = $null
    $exitCode = $null
    $raw = @()
    try {
        $raw = @(& "$env:SystemRoot\System32\qwinsta.exe" 2>$null)
        $exitCode = $LASTEXITCODE
        foreach ($line in $raw) {
            if (($line -match "\b$([regex]::Escape($targetUser))\b") -and
                ($line -match '\s(\d+)\s+(Active|Disc|Conn)\b')) {
                $sid = [int]$matches[1]
                $sessionState = $matches[2]
                break
            }
        }
    } catch { $exitCode = -1 }
    return [pscustomobject]@{
        exists = ($null -ne $sid)
        id = $sid
        state = $sessionState
        qwinsta_exit = $exitCode
    }
}

function Get-AutologonState {
    $autoAdmin = $false
    $userMatches = $false
    $domainMatches = $false
    $accountEnabled = $false
    $secretPresent = $false
    $secretPayloadNonempty = $false
    $secretProbe = 'not_system'
    try {
        $wl = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction Stop
        $autoAdmin = ($wl.AutoAdminLogon -eq '1')
        $userMatches = [string]::Equals([string]$wl.DefaultUserName, $targetUser, [StringComparison]::OrdinalIgnoreCase)
        $domainMatches = [string]::Equals([string]$wl.DefaultDomainName, $env:COMPUTERNAME, [StringComparison]::OrdinalIgnoreCase)
    } catch { }
    try {
        $localAccounts = @(Get-CimInstance Win32_UserAccount -Filter "LocalAccount=True AND Name='$targetUser'" -ErrorAction Stop)
        $accountEnabled = ($localAccounts.Count -eq 1) -and ($localAccounts[0].Disabled -ne $true)
    } catch { }

    $isSystem = [Security.Principal.WindowsIdentity]::GetCurrent().IsSystem
    if ($isSystem) {
        $secretProbe = 'missing'
        $base = $null
        $key = $null
        $currVal = $null
        try {
            $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', 'Default')
            $key = $base.OpenSubKey('SECURITY\Policy\Secrets\DefaultPassword')
            if ($null -ne $key) {
                $secretPresent = $true
                $currVal = $key.OpenSubKey('CurrVal')
                if ($null -eq $currVal) {
                    $secretProbe = 'currval_missing'
                } else {
                    $payload = $currVal.GetValue(
                        '',
                        $null,
                        [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
                    )
                    if ($payload -is [byte[]]) {
                        $secretPayloadNonempty = ($payload.Length -gt 0)
                    } elseif ($null -ne $payload) {
                        $secretPayloadNonempty = ([string]$payload).Length -gt 0
                    }
                    $secretProbe = if ($secretPayloadNonempty) { 'present' } else { 'empty' }
                }
            }
        } catch {
            $secretProbe = 'probe_error'
        } finally {
            if ($null -ne $currVal) { $currVal.Dispose() }
            if ($null -ne $key) { $key.Dispose() }
            if ($null -ne $base) { $base.Dispose() }
        }
    }

    return [pscustomobject]@{
        is_system = $isSystem
        auto_admin = $autoAdmin
        user_matches = $userMatches
        domain_matches = $domainMatches
        account_enabled = $accountEnabled
        secret_present = $secretPresent
        secret_payload_nonempty = $secretPayloadNonempty
        secret_probe = $secretProbe
        ready = ($isSystem -and $autoAdmin -and $userMatches -and $domainMatches -and $accountEnabled -and $secretPresent -and $secretPayloadNonempty)
    }
}

function Resolve-IdentitySid {
    param([AllowNull()][string]$Identity)
    if (-not $Identity) { return $null }
    try {
        if ($Identity -match '^S-\d-') {
            return ([Security.Principal.SecurityIdentifier]$Identity).Value
        }
        return ([Security.Principal.NTAccount]$Identity).Translate([Security.Principal.SecurityIdentifier]).Value
    } catch {
        return $null
    }
}

function Get-RecoveryTaskContractState {
    $reasons = [Collections.Generic.List[string]]::new()
    $expectedIdentity = "$env:COMPUTERNAME\$targetUser"
    $expectedSid = Resolve-IdentitySid -Identity $expectedIdentity
    if (-not $expectedSid) {
        $reasons.Add('target_user_sid_unresolvable')
        return [pscustomobject]@{ ready = $false; reasons = @($reasons); expected_sid = $null }
    }
    if (-not (Test-Path -LiteralPath $windowsPowerShell -PathType Leaf)) { $reasons.Add('powershell_executable_missing') }
    foreach ($scriptPath in @($dxzLauncher, $ftmoLauncher, $sessionSupervisorScript, $sessionSupervisorStarter)) {
        if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
            $reasons.Add("recovery_script_missing:$scriptPath")
        }
    }

    # The two terminal launchers are logon-only. The resident supervisor also
    # has an AtLogon trigger, but demand start is deliberately enabled so the
    # SYSTEM watchdog can use Task Scheduler RunEx with an explicit session ID.
    $contracts = @(
        [pscustomobject]@{
            name = 'QM_T_Live_AtLogon'
            arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$dxzLauncher`""
            delay = 'PT15S'
            allow_demand = $false
            execution_limit = 'PT5M'
            supervisor = $false
        },
        [pscustomobject]@{
            name = 'QM_FTMO_AtLogon'
            arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$ftmoLauncher`""
            delay = 'PT30S'
            allow_demand = $false
            execution_limit = 'PT5M'
            supervisor = $false
        },
        [pscustomobject]@{
            name = 'QM_Live_MT5_SessionSupervisor'
            arguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$sessionSupervisorScript`" -IntervalSeconds 10"
            delay = 'PT45S'
            allow_demand = $true
            execution_limit = 'PT0S'
            supervisor = $true
        }
    )

    foreach ($contract in $contracts) {
        $task = $null
        try {
            $found = @(Get-ScheduledTask -TaskPath '\' -TaskName $contract.name -ErrorAction Stop)
            if ($found.Count -ne 1) {
                $reasons.Add("$($contract.name):task_count=$($found.Count)")
                continue
            }
            $task = $found[0]
        } catch {
            $reasons.Add("$($contract.name):missing_or_unreadable")
            continue
        }

        $principalSid = Resolve-IdentitySid -Identity ([string]$task.Principal.UserId)
        if ($principalSid -ne $expectedSid) { $reasons.Add("$($contract.name):principal_sid") }
        if ([string]$task.Principal.LogonType -ne 'Interactive') { $reasons.Add("$($contract.name):logon_type") }
        if ([string]$task.Principal.RunLevel -ne 'Highest') { $reasons.Add("$($contract.name):run_level") }
        if ($task.State -eq 'Disabled' -or $task.Settings.Enabled -ne $true) { $reasons.Add("$($contract.name):disabled") }

        $taskActions = @($task.Actions)
        if ($taskActions.Count -ne 1) {
            $reasons.Add("$($contract.name):action_count=$($taskActions.Count)")
        } else {
            $action = $taskActions[0]
            if (-not [string]::Equals(([string]$action.Execute).Trim(), $windowsPowerShell, [StringComparison]::OrdinalIgnoreCase)) {
                $reasons.Add("$($contract.name):action_executable")
            }
            if (-not [string]::Equals(([string]$action.Arguments).Trim(), $contract.arguments, [StringComparison]::Ordinal)) {
                $reasons.Add("$($contract.name):action_arguments")
            }
            if (-not [string]::Equals(([string]$action.WorkingDirectory).TrimEnd('\'), $repoRoot.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) {
                $reasons.Add("$($contract.name):working_directory")
            }
        }

        $taskTriggers = @($task.Triggers)
        if ($taskTriggers.Count -ne 1) {
            $reasons.Add("$($contract.name):trigger_count=$($taskTriggers.Count)")
        } else {
            $trigger = $taskTriggers[0]
            if ($trigger.CimClass.CimClassName -ne 'MSFT_TaskLogonTrigger') { $reasons.Add("$($contract.name):trigger_type") }
            if ($trigger.Enabled -ne $true) { $reasons.Add("$($contract.name):trigger_disabled") }
            if ((Resolve-IdentitySid -Identity ([string]$trigger.UserId)) -ne $expectedSid) { $reasons.Add("$($contract.name):trigger_user_sid") }
            if ([string]$trigger.Delay -ne [string]$contract.delay) { $reasons.Add("$($contract.name):trigger_delay") }
        }

        if ($task.Settings.AllowDemandStart -ne [bool]$contract.allow_demand) { $reasons.Add("$($contract.name):allow_demand_start") }
        if ([string]$task.Settings.MultipleInstances -ne 'IgnoreNew') { $reasons.Add("$($contract.name):multiple_instances") }
        if ([string]$task.Settings.ExecutionTimeLimit -ne [string]$contract.execution_limit) { $reasons.Add("$($contract.name):execution_time_limit") }
        if ($contract.supervisor) {
            if ([int]$task.Settings.RestartCount -ne 255) { $reasons.Add("$($contract.name):restart_count") }
            if ([string]$task.Settings.RestartInterval -ne 'PT1M') { $reasons.Add("$($contract.name):restart_interval") }
        }
    }

    return [pscustomobject]@{
        ready = ($reasons.Count -eq 0)
        reasons = @($reasons)
        expected_sid = $expectedSid
    }
}

function Get-SessionSupervisorState {
    param($TargetSession)
    if (-not $TargetSession.exists) {
        return [pscustomobject]@{ ready = $false; heartbeat_ready = $false; scheduler_owned = $false; engine_pid = $null; age_seconds = $null; reason = 'target_session_absent'; session_id = $null }
    }
    if (-not (Test-Path -LiteralPath $sessionSupervisorStateFile -PathType Leaf)) {
        return [pscustomobject]@{ ready = $false; heartbeat_ready = $false; scheduler_owned = $false; engine_pid = $null; age_seconds = $null; reason = 'state_missing'; session_id = $null }
    }
    try {
        $value = Get-Content -LiteralPath $sessionSupervisorStateFile -Raw -ErrorAction Stop | ConvertFrom-Json
        $checked = ConvertFrom-UtcStamp ([string]$value.last_checked_utc)
        if ($null -eq $checked) { throw 'invalid last_checked_utc' }
        $age = ([DateTime]::UtcNow - $checked).TotalSeconds
        $identityOk = ([string]$value.identity).Split('\')[-1] -ieq $targetUser
        $sessionOk = ([int]$value.session_id -eq [int]$TargetSession.id)
        $healthy = ($value.process_probe_ok -eq $true) -and
            ($value.dxz_running -eq $true) -and ($value.ftmo_running -eq $true)
        $fresh = ($age -ge -5 -and $age -le 60)
        $heartbeatReady = $fresh -and $identityOk -and $sessionOk
        $schedulerOwned = $false
        $enginePid = $null
        $ownershipReason = 'not_probed'
        if ($heartbeatReady -and (Test-Path -LiteralPath $sessionSupervisorStarter -PathType Leaf)) {
            $ownershipOutput = @(& $windowsPowerShell -NoProfile -NonInteractive -ExecutionPolicy Bypass `
                -File $sessionSupervisorStarter -SessionId ([int]$TargetSession.id) -ProbeOnly 2>$null)
            $ownershipExit = $LASTEXITCODE
            if ($ownershipExit -eq 0 -and $ownershipOutput.Count -gt 0) {
                try {
                    $ownership = $ownershipOutput[-1] | ConvertFrom-Json -ErrorAction Stop
                    $schedulerOwned = ($ownership.scheduler_owned -eq $true) -and
                        ([int]$ownership.engine_pid -eq [int]$value.supervisor_pid)
                    if ($schedulerOwned) {
                        $enginePid = [int]$ownership.engine_pid
                        $ownershipReason = 'scheduler_owned'
                    } else {
                        $ownershipReason = 'scheduler_pid_mismatch'
                    }
                } catch {
                    $ownershipReason = 'ownership_output_unreadable'
                }
            } else {
                $ownershipReason = "ownership_probe_exit_$ownershipExit"
            }
        } elseif (-not $heartbeatReady) {
            $ownershipReason = 'heartbeat_not_ready'
        } else {
            $ownershipReason = 'starter_missing'
        }
        $reason = if (-not $fresh) { 'state_stale' }
            elseif (-not $identityOk) { 'identity_mismatch' }
            elseif (-not $sessionOk) { 'session_mismatch' }
            elseif (-not $healthy) { 'live_state_not_healthy' }
            elseif (-not $schedulerOwned) { "not_scheduler_owned:$ownershipReason" }
            else { 'ready' }
        return [pscustomobject]@{
            ready = ($heartbeatReady -and $healthy -and $schedulerOwned)
            heartbeat_ready = $heartbeatReady
            scheduler_owned = $schedulerOwned
            engine_pid = $enginePid
            age_seconds = [math]::Round($age, 1)
            reason = $reason
            session_id = $value.session_id
        }
    } catch {
        return [pscustomobject]@{ ready = $false; heartbeat_ready = $false; scheduler_owned = $false; engine_pid = $null; age_seconds = $null; reason = "state_unreadable:$($_.Exception.Message)"; session_id = $null }
    }
}

function Read-State {
    $out = @{
        consecutive_both_down = 0
        consecutive_relaunch_failed = 0
        last_reboot_requested_utc = $null
        last_incident_utc = $null
        last_recovery_utc = $null
        last_status = $null
        last_history_utc = $null
        last_history_status = $null
    }
    if (Test-Path -LiteralPath $stateFile -PathType Leaf) {
        try {
            $obj = Get-Content -LiteralPath $stateFile -Raw -ErrorAction Stop | ConvertFrom-Json
            foreach ($name in @($out.Keys)) {
                if ($obj.PSObject.Properties.Name -contains $name) { $out[$name] = $obj.$name }
            }
        } catch { }
    }
    return $out
}

function Write-Evidence {
    param([hashtable]$State, [System.Collections.IDictionary]$Record)
    $json = $Record | ConvertTo-Json -Compress -Depth 6
    if ($DryRun.IsPresent) {
        Write-Output $json
        return
    }
    try {
        [IO.Directory]::CreateDirectory($stateDir) | Out-Null
        $lastHistory = ConvertFrom-UtcStamp ([string]$State.last_history_utc)
        $historyDue = ($null -eq $lastHistory) -or (([DateTime]::UtcNow - $lastHistory).TotalMinutes -ge 15)
        $statusChanged = ([string]$State.last_history_status -ne [string]$Record.status)
        $actionful = @($Record.actions).Count -gt 0
        $writeHistory = $historyDue -or $statusChanged -or $actionful
        if ($writeHistory) {
            $State.last_history_utc = [string]$Record.ts
            $State.last_history_status = [string]$Record.status
        }
        # Keep the latest observation and the cross-run counters in one atomic
        # snapshot. Alert consumers need the process/session facts, while the
        # next watchdog cycle needs the durable counters.
        $latest = [ordered]@{}
        foreach ($key in $Record.Keys) { $latest[$key] = $Record[$key] }
        foreach ($key in $State.Keys) { $latest[$key] = $State[$key] }
        $tmp = "$stateFile.tmp"
        $utf8NoBom = [Text.UTF8Encoding]::new($false)
        [IO.File]::WriteAllText($tmp, ($latest | ConvertTo-Json -Depth 6), $utf8NoBom)
        Move-Item -LiteralPath $tmp -Destination $stateFile -Force
        if ($writeHistory) {
            [IO.File]::AppendAllText($historyFile, $json + [Environment]::NewLine, $utf8NoBom)
        }
    } catch { Write-Warning "Could not write live watchdog evidence: $($_.Exception.Message)" }
    Write-Output $json
}

$nowUtc = [DateTime]::UtcNow
$stamp = Get-UtcStamp
$state = Read-State
$proc = Get-LiveProcessState
$session = Get-TargetSession
$sessionSupervisor = Get-SessionSupervisorState -TargetSession $session
$autologon = Get-AutologonState
$recoveryTasks = Get-RecoveryTaskContractState
$dxzProfile = Get-ProfileLast -Path $dxzCommon
$ftmoProfile = Get-ProfileLast -Path $ftmoCommon
$profileOk = ($dxzProfile -eq $expectedDxzProfile) -and ($ftmoProfile -eq $expectedFtmoProfile)
$dxzExpertsEnabled = Get-ExpertsEnabled -Path $dxzCommon
$ftmoExpertsEnabled = Get-ExpertsEnabled -Path $ftmoCommon
$expertsEnabledOk = ($dxzExpertsEnabled -eq 1) -and ($ftmoExpertsEnabled -eq 1)
$sessionPlacementOk = $session.exists -and
    (@($proc.dxz | Where-Object { $_.SessionId -ne $session.id }).Count -eq 0) -and
    (@($proc.ftmo | Where-Object { $_.SessionId -ne $session.id }).Count -eq 0)
$actions = [Collections.Generic.List[string]]::new()
$errors = [Collections.Generic.List[string]]::new()

# The 2026-07-21 incident proved that tscon-on-disconnect races can destroy the
# very session they were meant to preserve. Keep the superseded task disabled.
if (-not $DryRun.IsPresent) {
    try {
        $unsafe = Get-ScheduledTask -TaskName $unsafeTsconTask -ErrorAction SilentlyContinue
        if ($unsafe -and $unsafe.State -ne 'Disabled') {
            Stop-ScheduledTask -TaskName $unsafeTsconTask -ErrorAction SilentlyContinue | Out-Null
            Disable-ScheduledTask -TaskName $unsafeTsconTask -ErrorAction Stop | Out-Null
            $actions.Add('disabled_unsafe_tscon_task')
        }
    } catch { $errors.Add("tscon_disable_failed:$($_.Exception.Message)") }
}

$maintenance = Test-MaintenanceRequested
if ($maintenance) {
    $status = 'maintenance'
    # A maintenance observation must never count toward a later destructive
    # action. Removing the flag always starts a fresh confirmation sequence.
    $state.consecutive_both_down = 0
    $state.consecutive_relaunch_failed = 0
    $actions.Add('noop_maintenance_flag')
} elseif (-not $proc.probe_ok) {
    # Fail closed: an unavailable WMI/CIM process inventory is UNKNOWN, never
    # proof that both terminals are down. Do not relaunch or advance reboot
    # confirmation counters on an unknown observation.
    $status = 'critical'
    $state.consecutive_both_down = 0
    $state.consecutive_relaunch_failed = 0
    $actions.Add('noop_process_probe_failed')
    $errors.Add("process_probe_failed:$($proc.probe_error)")
} else {
    # Restore the resident recovery loop itself when its heartbeat is stale or
    # absent. RunEx binds the task to the already existing qm-admin desktop,
    # including a disconnected RDP session; it never launches MT5 from SYSTEM.
    if ($session.exists -and -not $sessionSupervisor.heartbeat_ready) {
        if (-not $recoveryTasks.ready) {
            $errors.Add("session_supervisor_start_blocked_task_contract:$($recoveryTasks.reasons -join '|')")
        } elseif ($DryRun.IsPresent) {
            $actions.Add('would_start_session_supervisor_via_runex')
        } elseif (Test-MaintenanceRequested) {
            $actions.Add('session_supervisor_start_cancelled_maintenance')
        } else {
            $starterOutput = @(& $windowsPowerShell -NoProfile -NonInteractive -ExecutionPolicy Bypass `
                -File $sessionSupervisorStarter -SessionId ([int]$session.id) -VerifySeconds 20 2>&1)
            $starterExit = $LASTEXITCODE
            if ($starterExit -eq 0) {
                $actions.Add('session_supervisor_started_or_verified_via_runex')
                $sessionSupervisor = Get-SessionSupervisorState -TargetSession $session
            } else {
                $detail = (($starterOutput | ForEach-Object { [string]$_ }) -join ' ').Trim()
                if ($detail.Length -gt 300) { $detail = $detail.Substring(0, 300) }
                $errors.Add("session_supervisor_runex_failed:exit=${starterExit}:$detail")
            }
        }
    }

    $missingNames = [Collections.Generic.List[string]]::new()
    if (-not $proc.dxz_running) { $missingNames.Add('DXZ') }
    if (-not $proc.ftmo_running) { $missingNames.Add('FTMO') }

    if ($missingNames.Count -gt 0 -and $session.exists) {
        if ($sessionSupervisor.heartbeat_ready) {
            $actions.Add("delegated_to_session_supervisor:$($missingNames -join ',')")
        } else {
            $actions.Add("resident_supervisor_unavailable:$($missingNames -join ',')")
            $errors.Add("session_supervisor_not_ready:$($sessionSupervisor.reason)")
        }
        if (-not $DryRun.IsPresent -and $RelaunchWaitSeconds -gt 0) {
            Start-Sleep -Seconds $RelaunchWaitSeconds
            $proc = Get-LiveProcessState
        }
    } elseif ($missingNames.Count -gt 0) {
        $actions.Add('no_interactive_session_for_resident_relaunch')
    }

    $sessionPlacementOk = $session.exists -and
        (@($proc.dxz | Where-Object { $_.SessionId -ne $session.id }).Count -eq 0) -and
        (@($proc.ftmo | Where-Object { $_.SessionId -ne $session.id }).Count -eq 0)

    if (-not $proc.probe_ok) {
        # The verification probe after an attempted relaunch is subject to the
        # same fail-closed rule as the initial probe.
        $bothDown = $false
        $oneDown = $false
        $state.consecutive_both_down = 0
        $state.consecutive_relaunch_failed = 0
        $status = 'critical'
        $actions.Add('noop_post_relaunch_process_probe_failed')
        $errors.Add("process_probe_failed:$($proc.probe_error)")
    } else {
        $bothDown = (-not $proc.dxz_running) -and (-not $proc.ftmo_running)
        $oneDown = (-not $proc.dxz_running) -xor (-not $proc.ftmo_running)

        if ($bothDown) {
        $state.consecutive_both_down = [int]$state.consecutive_both_down + 1
        $state.consecutive_relaunch_failed = [int]$state.consecutive_relaunch_failed + 1
        if (-not $state.last_incident_utc) { $state.last_incident_utc = $stamp }
        $status = 'critical'
        } elseif ($oneDown) {
        $state.consecutive_both_down = 0
        $state.consecutive_relaunch_failed = [int]$state.consecutive_relaunch_failed + 1
        if (-not $state.last_incident_utc) { $state.last_incident_utc = $stamp }
        $status = 'degraded'
        } else {
        if ($state.last_incident_utc) { $state.last_recovery_utc = $stamp }
        $state.consecutive_both_down = 0
        $state.consecutive_relaunch_failed = 0
        $state.last_incident_utc = $null
        $status = if ($profileOk -and $expertsEnabledOk -and $sessionPlacementOk -and $sessionSupervisor.ready -and
            $autologon.ready -and $recoveryTasks.ready) { 'healthy' } else { 'degraded' }
        if (-not $profileOk) { $errors.Add("profile_mismatch:dxz=$dxzProfile,ftmo=$ftmoProfile") }
        if (-not $expertsEnabledOk) { $errors.Add("experts_disabled_or_unknown:dxz=$dxzExpertsEnabled,ftmo=$ftmoExpertsEnabled") }
        if (-not $sessionPlacementOk) { $errors.Add("live_process_session_mismatch:target=$($session.id)") }
        if (-not $sessionSupervisor.ready) { $errors.Add("session_supervisor_not_ready:$($sessionSupervisor.reason)") }
        if (-not $autologon.ready) { $errors.Add("autologon_not_ready:$($autologon.secret_probe)") }
        if (-not $recoveryTasks.ready) { $errors.Add("recovery_task_contract_drift:$($recoveryTasks.reasons -join '|')") }
        }

        if ($bothDown -and [int]$state.consecutive_both_down -ge $ConfirmCycles) {
        $uptimeMinutes = 0.0
        try {
            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            $uptimeMinutes = ((Get-Date) - $os.LastBootUpTime).TotalMinutes
        } catch { $errors.Add('uptime_probe_failed') }

        $lastReboot = ConvertFrom-UtcStamp ([string]$state.last_reboot_requested_utc)
        $cooldownOk = ($null -eq $lastReboot) -or (($nowUtc - $lastReboot).TotalMinutes -ge $RebootCooldownMinutes)
        if ($NoReboot.IsPresent -or $DryRun.IsPresent) {
            $actions.Add('reboot_suppressed_by_switch')
        } elseif ($uptimeMinutes -lt $StartupGraceMinutes) {
            $actions.Add("reboot_suppressed_startup_grace:$([math]::Round($uptimeMinutes,1))m")
        } elseif (-not $cooldownOk) {
            $actions.Add('reboot_suppressed_cooldown')
        } elseif (-not $autologon.ready) {
            $errors.Add("reboot_blocked_autologon_not_ready:$($autologon.secret_probe)")
        } elseif (-not $recoveryTasks.ready) {
            $errors.Add("reboot_blocked_recovery_task_contract:$($recoveryTasks.reasons -join '|')")
        } elseif (Test-MaintenanceRequested) {
            $maintenance = $true
            $status = 'maintenance'
            $state.consecutive_both_down = 0
            $state.consecutive_relaunch_failed = 0
            $actions.Add('reboot_cancelled_maintenance_before_final_probes')
        } else {
            # Hard safety invariant: re-query immediately before reboot and refuse
            # if either live process has appeared in the meantime. A second API
            # must independently agree; any UNKNOWN result fails closed.
            $finalProc = Get-LiveProcessState
            $independent = Get-IndependentLivePresence
            if (-not $finalProc.probe_ok -or -not $independent.probe_ok) {
                $actions.Add('reboot_cancelled_process_probe_unknown')
                $errors.Add('reboot_blocked_process_probe_unknown')
            } elseif ($finalProc.dxz_running -or $finalProc.ftmo_running -or $independent.any_live) {
                $actions.Add('reboot_cancelled_live_process_reappeared')
                $proc = $finalProc
            } elseif (Test-MaintenanceRequested) {
                $maintenance = $true
                $status = 'maintenance'
                $state.consecutive_both_down = 0
                $state.consecutive_relaunch_failed = 0
                $actions.Add('reboot_cancelled_maintenance_after_final_probes')
            } else {
                $state.last_reboot_requested_utc = $stamp
                $actions.Add('controlled_reboot_requested')
            }
        }
        }
    }
}

$state.last_status = $status
$state.last_checked_utc = $stamp
$state.last_action = ($actions -join ',')

if ($status -eq 'healthy' -and @($errors | Where-Object { $_ -like 'tscon_disable_failed:*' }).Count -gt 0) {
    $status = 'degraded'
    $state.last_status = $status
}

$record = [ordered]@{
    ts = $stamp
    status = $status
    maintenance = $maintenance
    process_probe_ok = [bool]$proc.probe_ok
    dxz_running = [bool]$proc.dxz_running
    dxz_pids = @($proc.dxz | ForEach-Object { $_.ProcessId })
    dxz_session_ids = @($proc.dxz | ForEach-Object { $_.SessionId })
    ftmo_running = [bool]$proc.ftmo_running
    ftmo_pids = @($proc.ftmo | ForEach-Object { $_.ProcessId })
    ftmo_session_ids = @($proc.ftmo | ForEach-Object { $_.SessionId })
    target_session_exists = [bool]$session.exists
    target_session_id = $session.id
    target_session_state = $session.state
    qwinsta_exit = $session.qwinsta_exit
    autologon_ready = [bool]$autologon.ready
    autologon_secret_probe = $autologon.secret_probe
    autologon_domain_matches = [bool]$autologon.domain_matches
    autologon_account_enabled = [bool]$autologon.account_enabled
    autologon_secret_payload_nonempty = [bool]$autologon.secret_payload_nonempty
    recovery_task_contract_ready = [bool]$recoveryTasks.ready
    recovery_task_contract_errors = @($recoveryTasks.reasons)
    recovery_task_expected_sid = $recoveryTasks.expected_sid
    dxz_profile = $dxzProfile
    expected_dxz_profile = $expectedDxzProfile
    ftmo_profile = $ftmoProfile
    expected_ftmo_profile = $expectedFtmoProfile
    dxz_experts_enabled = $dxzExpertsEnabled
    ftmo_experts_enabled = $ftmoExpertsEnabled
    session_placement_ok = [bool]$sessionPlacementOk
    session_supervisor_ready = [bool]$sessionSupervisor.ready
    session_supervisor_heartbeat_ready = [bool]$sessionSupervisor.heartbeat_ready
    session_supervisor_scheduler_owned = [bool]$sessionSupervisor.scheduler_owned
    session_supervisor_engine_pid = $sessionSupervisor.engine_pid
    session_supervisor_age_seconds = $sessionSupervisor.age_seconds
    session_supervisor_reason = $sessionSupervisor.reason
    session_supervisor_session_id = $sessionSupervisor.session_id
    consecutive_both_down = [int]$state.consecutive_both_down
    actions = @($actions)
    errors = @($errors)
}

Write-Evidence -State $state -Record $record

if ($actions -contains 'controlled_reboot_requested') {
    # Keep a short cancellable window. A late InteractiveToken recovery must not
    # be killed by a reboot that was valid a few seconds earlier. Re-read the
    # maintenance kill switch at the last possible point before shutdown.exe.
    if (Test-MaintenanceRequested) {
        $maintenance = $true
        $status = 'maintenance'
        $state.consecutive_both_down = 0
        $state.consecutive_relaunch_failed = 0
        $state.last_reboot_requested_utc = $null
        [void]$actions.Remove('controlled_reboot_requested')
        $actions.Add('reboot_cancelled_maintenance_before_shutdown')
        $state.last_status = $status
        $state.last_action = ($actions -join ',')
        $record.status = $status
        $record.maintenance = $true
        $record.consecutive_both_down = 0
        $record.actions = @($actions)
        $record.errors = @($errors)
        Write-Evidence -State $state -Record $record
        exit 0
    }

    & "$env:SystemRoot\System32\shutdown.exe" /r /t 20 /f /d p:4:1 /c "QM live uptime recovery: both MT5 terminals down and interactive relaunch failed" | Out-Null
    $shutdownExit = $LASTEXITCODE
    if ($shutdownExit -ne 0) {
        $state.last_reboot_requested_utc = $null
        $actions.Add("reboot_request_failed:$shutdownExit")
        $errors.Add("shutdown_exit:$shutdownExit")
        $state.last_action = ($actions -join ',')
        $record.actions = @($actions)
        $record.errors = @($errors)
        Write-Evidence -State $state -Record $record
        exit 3
    }

    for ($i = 0; $i -lt 19; $i++) {
        Start-Sleep -Seconds 1
        $countdownMaintenance = Test-MaintenanceRequested
        $countdownProc = Get-LiveProcessState
        $countdownIndependent = Get-IndependentLivePresence
        if ($countdownMaintenance -or (-not $countdownProc.probe_ok) -or (-not $countdownIndependent.probe_ok) -or
            $countdownProc.dxz_running -or $countdownProc.ftmo_running -or $countdownIndependent.any_live) {
            & "$env:SystemRoot\System32\shutdown.exe" /a | Out-Null
            $abortExit = $LASTEXITCODE
            $state.last_reboot_requested_utc = $null
            [void]$actions.Remove('controlled_reboot_requested')
            if ($countdownMaintenance) {
                $maintenance = $true
                $status = 'maintenance'
                $state.consecutive_both_down = 0
                $state.consecutive_relaunch_failed = 0
                $actions.Add("reboot_countdown_aborted_maintenance:abort_exit=$abortExit")
                $record.status = $status
                $record.maintenance = $true
                $record.consecutive_both_down = 0
            } else {
                $actions.Add("reboot_countdown_aborted:abort_exit=$abortExit")
            }
            if (-not $countdownMaintenance -and (-not $countdownProc.probe_ok -or -not $countdownIndependent.probe_ok)) {
                $errors.Add('countdown_process_probe_unknown')
            } elseif (-not $countdownMaintenance) {
                $proc = $countdownProc
                $record.dxz_running = [bool]$proc.dxz_running
                $record.dxz_pids = @($proc.dxz | ForEach-Object { $_.ProcessId })
                $record.ftmo_running = [bool]$proc.ftmo_running
                $record.ftmo_pids = @($proc.ftmo | ForEach-Object { $_.ProcessId })
            }
            $state.last_status = $status
            $state.last_action = ($actions -join ',')
            $record.actions = @($actions)
            $record.errors = @($errors)
            Write-Evidence -State $state -Record $record
            if ($abortExit -ne 0) { exit 4 }
            if ($countdownMaintenance) { exit 0 }
            exit 1
        }
    }
    exit 0
}

if ($status -eq 'critical') { exit 2 }
if ($status -eq 'maintenance') { exit 0 }
if ((-not $proc.dxz_running) -or (-not $proc.ftmo_running)) { exit 1 }
exit 0
