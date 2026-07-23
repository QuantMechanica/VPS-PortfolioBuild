<#
.SYNOPSIS
  Keep both live MT5 terminals running inside the qm-admin desktop session.

.DESCRIPTION
  InteractiveToken tasks can be queued instead of executed while an RDP session
  is disconnected. This resident process starts at qm-admin logon and remains in
  that session, so it can safely invoke the hardened live launchers after RDP
  disconnects. A target must be absent in two consecutive independent probes.

  The supervisor never stops a process, never reboots Windows, and never edits
  trading state directly. Any process-inventory uncertainty, duplicate, wrong
  session, maintenance flag, or launcher race is fail-closed.
#>
[CmdletBinding()]
param(
    [ValidateRange(5, 30)][int]$IntervalSeconds = 10,
    [ValidateRange(2, 5)][int]$MissingConfirmCycles = 2,
    [ValidateRange(30, 300)][int]$RetryCooldownSeconds = 60,
    [switch]$Once,
    [switch]$NoLaunch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$targetUser = 'qm-admin'
$stateDir = 'D:\QM\reports\state'
$stateFile = Join-Path $stateDir 'live_session_supervisor.json'
$maintenanceFlag = Join-Path $stateDir 'LIVE_UPTIME_MAINTENANCE.flag'
$dxzPath = 'C:\QM\mt5\T_Live\MT5_Base\terminal64.exe'
$ftmoPath = 'C:\Program Files\FTMO Global Markets MT5 Terminal\terminal64.exe'
$dxzLauncher = 'C:\QM\repo\tools\strategy_farm\T_Live_ON.ps1'
$ftmoLauncher = 'C:\QM\repo\tools\strategy_farm\FTMO_ON.ps1'

function Get-UtcStamp {
    return [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
}

function Compare-ProcessIds {
    param([object[]]$Left, [object[]]$Right)
    $leftIds = @($Left | ForEach-Object { [int]$_.ProcessId } | Sort-Object)
    $rightIds = @($Right | ForEach-Object { [int]$_.Id } | Sort-Object)
    return [string]::Join(',', $leftIds) -ceq [string]::Join(',', $rightIds)
}

function Get-ExactProcessState {
    try {
        $cimAll = @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction Stop)
    } catch {
        return [pscustomobject]@{ probe_ok = $false; error = "cim:$($_.Exception.Message)"; dxz = @(); ftmo = @() }
    }
    if (@($cimAll | Where-Object { -not $_.ExecutablePath }).Count -gt 0) {
        return [pscustomobject]@{ probe_ok = $false; error = 'cim:one_or_more_terminal64_paths_unreadable'; dxz = @(); ftmo = @() }
    }

    try {
        $nativeAll = @(Get-Process -ErrorAction Stop | Where-Object { $_.ProcessName -eq 'terminal64' })
        $nativePaths = @{}
        foreach ($process in $nativeAll) {
            $path = $process.Path
            if (-not $path) { throw "native path unreadable for PID $($process.Id)" }
            $nativePaths[[int]$process.Id] = $path
        }
    } catch {
        return [pscustomobject]@{ probe_ok = $false; error = "native:$($_.Exception.Message)"; dxz = @(); ftmo = @() }
    }

    $dxz = @($cimAll | Where-Object { $_.ExecutablePath.Equals($dxzPath, [StringComparison]::OrdinalIgnoreCase) })
    $ftmo = @($cimAll | Where-Object { $_.ExecutablePath.Equals($ftmoPath, [StringComparison]::OrdinalIgnoreCase) })
    $nativeDxz = @($nativeAll | Where-Object { $nativePaths[[int]$_.Id].Equals($dxzPath, [StringComparison]::OrdinalIgnoreCase) })
    $nativeFtmo = @($nativeAll | Where-Object { $nativePaths[[int]$_.Id].Equals($ftmoPath, [StringComparison]::OrdinalIgnoreCase) })
    if (-not (Compare-ProcessIds $dxz $nativeDxz) -or -not (Compare-ProcessIds $ftmo $nativeFtmo)) {
        return [pscustomobject]@{ probe_ok = $false; error = 'cim_native_target_pid_disagreement'; dxz = @(); ftmo = @() }
    }
    return [pscustomobject]@{ probe_ok = $true; error = $null; dxz = $dxz; ftmo = $ftmo }
}

function Get-TargetState {
    param([object[]]$Processes, [int]$SessionId)
    $items = @($Processes)
    if ($items.Count -eq 0) { return 'confidently_missing' }
    if ($items.Count -gt 1) { return 'duplicate' }
    if ([int]$items[0].SessionId -ne $SessionId) { return 'wrong_session' }
    return 'healthy'
}

function Write-SupervisorState {
    param([System.Collections.IDictionary]$Record)
    $tmp = $null
    $replaceBackup = $null
    try {
        [IO.Directory]::CreateDirectory($stateDir) | Out-Null
        $tmp = Join-Path $stateDir ('.live_session_supervisor.' + $PID + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
        $utf8NoBom = [Text.UTF8Encoding]::new($false)
        [IO.File]::WriteAllText($tmp, ($Record | ConvertTo-Json -Depth 6), $utf8NoBom)
        if (Test-Path -LiteralPath $stateFile -PathType Leaf) {
            $replaceBackup = Join-Path $stateDir ('.live_session_supervisor.' + $PID + '.' + [guid]::NewGuid().ToString('N') + '.bak')
            [IO.File]::Replace($tmp, $stateFile, $replaceBackup, $true)
        } else {
            [IO.File]::Move($tmp, $stateFile)
        }
        $tmp = $null
    } catch {
        Write-Warning "Could not write session-supervisor state: $($_.Exception.Message)"
    } finally {
        if ($tmp -and [IO.File]::Exists($tmp)) { [IO.File]::Delete($tmp) }
        if ($replaceBackup -and [IO.File]::Exists($replaceBackup)) { [IO.File]::Delete($replaceBackup) }
    }
}

function Start-LauncherChild {
    param(
        [string]$Name,
        [string]$Path,
        [int]$OwnSessionId,
        [hashtable]$Pending,
        [hashtable]$LastAttempt,
        [Collections.Generic.List[string]]$Actions,
        [Collections.Generic.List[string]]$Errors
    )
    if ($Pending.ContainsKey($Name)) {
        $Actions.Add("launcher_still_pending:$Name")
        return
    }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $Errors.Add("launcher_missing:${Name}:$Path")
        return
    }
    if (([DateTime]::UtcNow - [DateTime]$LastAttempt[$Name]).TotalSeconds -lt $RetryCooldownSeconds) {
        $Actions.Add("launcher_cooldown:$Name")
        return
    }
    if (Test-Path -LiteralPath $maintenanceFlag -PathType Leaf) {
        $Actions.Add("launch_cancelled_maintenance:$Name")
        return
    }
    $fresh = Get-ExactProcessState
    if (-not $fresh.probe_ok) {
        $Errors.Add("launch_cancelled_probe_unknown:${Name}:$($fresh.error)")
        return
    }
    $freshProcesses = if ($Name -eq 'DXZ') { @($fresh.dxz) } else { @($fresh.ftmo) }
    if ((Get-TargetState $freshProcesses $OwnSessionId) -ne 'confidently_missing') {
        $Actions.Add("launch_cancelled_target_changed:$Name")
        return
    }
    if ($NoLaunch.IsPresent) {
        $Actions.Add("would_launch:$Name")
        return
    }

    try {
        $powershell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Path`""
        $child = Start-Process -FilePath $powershell -ArgumentList $arguments -WindowStyle Hidden -PassThru -ErrorAction Stop
        $LastAttempt[$Name] = [DateTime]::UtcNow
        $childSession = (Get-Process -Id $child.Id -ErrorAction Stop).SessionId
        if ($childSession -ne $OwnSessionId) {
            $Errors.Add("launcher_wrong_session:${Name}:pid=$($child.Id):session=$childSession")
            $Pending[$Name] = $child
            return
        }
        if ($child.WaitForExit(30000)) {
            if ($child.ExitCode -eq 0) { $Actions.Add("launcher_completed:${Name}:exit=0") }
            else { $Errors.Add("launcher_failed:${Name}:exit=$($child.ExitCode)") }
        } else {
            $Pending[$Name] = $child
            $Errors.Add("launcher_pending_over_30s:${Name}:pid=$($child.Id)")
        }
    } catch {
        $Errors.Add("launcher_exception:${Name}:$($_.Exception.Message)")
    }
}

$identityObject = [Security.Principal.WindowsIdentity]::GetCurrent()
$identity = $identityObject.Name
$identitySid = $identityObject.User.Value
$targetSid = ([Security.Principal.NTAccount]("$env:COMPUTERNAME\$targetUser")).Translate(
    [Security.Principal.SecurityIdentifier]
).Value
$sessionId = (Get-Process -Id $PID).SessionId
if ($identitySid -ne $targetSid -or $sessionId -le 0) {
    Write-Error "Refusing non-interactive/wrong-user context: identity=$identity session=$sessionId"
    exit 2
}

$mutexName = "Global\QM.LiveMT5.SessionSupervisor.$identitySid"
$mutex = [Threading.Mutex]::new($false, $mutexName)
$mutexOwned = $false
try {
    try { $mutexOwned = $mutex.WaitOne(0) }
    catch [Threading.AbandonedMutexException] { $mutexOwned = $true }
    if (-not $mutexOwned) {
        Write-Host 'Live MT5 session supervisor already running; no duplicate started.'
        exit 0
    }

    $misses = @{ DXZ = 0; FTMO = 0 }
    $lastAttempt = @{ DXZ = [DateTime]::MinValue; FTMO = [DateTime]::MinValue }
    $pending = @{}

    do {
        $actions = [Collections.Generic.List[string]]::new()
        $errors = [Collections.Generic.List[string]]::new()
        foreach ($name in @($pending.Keys)) {
            try {
                $pending[$name].Refresh()
                if ($pending[$name].HasExited) {
                    $exitCode = $pending[$name].ExitCode
                    if ($exitCode -eq 0) { $actions.Add("pending_launcher_completed:${name}:exit=0") }
                    else { $errors.Add("pending_launcher_failed:${name}:exit=$exitCode") }
                    $pending.Remove($name)
                }
            } catch {
                $errors.Add("pending_launcher_probe_failed:${name}:$($_.Exception.Message)")
            }
        }

        $maintenance = Test-Path -LiteralPath $maintenanceFlag -PathType Leaf
        $before = Get-ExactProcessState
        $dxzState = if ($before.probe_ok) { Get-TargetState @($before.dxz) $sessionId } else { 'unknown' }
        $ftmoState = if ($before.probe_ok) { Get-TargetState @($before.ftmo) $sessionId } else { 'unknown' }

        if ($maintenance) {
            $misses.DXZ = 0
            $misses.FTMO = 0
            $actions.Add('noop_maintenance_flag')
        } elseif (-not $before.probe_ok) {
            $misses.DXZ = 0
            $misses.FTMO = 0
            $errors.Add("process_probe_failed:$($before.error)")
        } else {
            foreach ($name in @('DXZ', 'FTMO')) {
                $targetState = if ($name -eq 'DXZ') { $dxzState } else { $ftmoState }
                if ($targetState -eq 'confidently_missing') { $misses[$name] = [int]$misses[$name] + 1 }
                else { $misses[$name] = 0 }
                if ($targetState -in @('duplicate', 'wrong_session')) { $errors.Add("target_${name}:$targetState") }
            }
            if ($misses.DXZ -ge $MissingConfirmCycles) {
                Start-LauncherChild 'DXZ' $dxzLauncher $sessionId $pending $lastAttempt $actions $errors
            }
            if ($misses.FTMO -ge $MissingConfirmCycles) {
                Start-LauncherChild 'FTMO' $ftmoLauncher $sessionId $pending $lastAttempt $actions $errors
            }
        }

        $after = Get-ExactProcessState
        $dxzAfter = if ($after.probe_ok) { Get-TargetState @($after.dxz) $sessionId } else { 'unknown' }
        $ftmoAfter = if ($after.probe_ok) { Get-TargetState @($after.ftmo) $sessionId } else { 'unknown' }
        if (-not $after.probe_ok) { $errors.Add("post_probe_failed:$($after.error)") }
        $status = if ($maintenance) { 'maintenance' }
            elseif ($after.probe_ok -and $dxzAfter -eq 'healthy' -and $ftmoAfter -eq 'healthy' -and $errors.Count -eq 0) { 'healthy' }
            elseif ($after.probe_ok) { 'degraded' }
            else { 'unknown' }
        $record = [ordered]@{
            schema_version = 1
            last_checked_utc = Get-UtcStamp
            status = $status
            identity = $identity
            identity_sid = $identitySid
            session_id = $sessionId
            supervisor_pid = $PID
            interval_seconds = $IntervalSeconds
            maintenance = [bool]$maintenance
            process_probe_ok = [bool]$after.probe_ok
            process_probe_error = $after.error
            dxz_state = $dxzAfter
            dxz_running = [bool]($dxzAfter -eq 'healthy')
            dxz_pids = @($after.dxz | ForEach-Object { $_.ProcessId })
            dxz_session_ids = @($after.dxz | ForEach-Object { $_.SessionId })
            dxz_consecutive_missing = [int]$misses.DXZ
            ftmo_state = $ftmoAfter
            ftmo_running = [bool]($ftmoAfter -eq 'healthy')
            ftmo_pids = @($after.ftmo | ForEach-Object { $_.ProcessId })
            ftmo_session_ids = @($after.ftmo | ForEach-Object { $_.SessionId })
            ftmo_consecutive_missing = [int]$misses.FTMO
            pending_launchers = @($pending.Keys)
            actions = @($actions)
            errors = @($errors)
        }
        Write-SupervisorState $record
        if ($Once.IsPresent) { break }
        Start-Sleep -Seconds $IntervalSeconds
    } while ($true)
} finally {
    if ($mutexOwned) {
        try { $mutex.ReleaseMutex() } catch { }
    }
    $mutex.Dispose()
}
