<#
.SYNOPSIS
  Start the LIVE trading terminal (T_Live) and ensure it resumes the deployed EA portfolio.

.DESCRIPTION
  T_Live is the live Darwinex terminal at C:\QM\mt5\T_Live\MT5_Base (portable). After a VPS
  reboot the factory (T1-T10) is restored by QM_StrategyFarm_FactoryON_AtLogon, but T_Live has
  no such path - this closes that gap. Idempotent: if a T_Live terminal64 is already running it
  no-ops. When the terminal is NOT running it (1) pins the deployed chart profile + AutoTrading
  in config\common.ini so a cold/unclean reboot still loads the approved portfolio and trades, then
  (2) launches terminal64.exe /portable in the interactive session.

  Hard Rule: T_Live AutoTrading = OWNER + Claude only. This auto-resume of an OWNER-authorized
  live state was requested by OWNER (2026-06-28) for reboot resilience; see the decision record.

  Run at logon via QM_T_Live_AtLogon and as the relaunch action of QM_T_Live_Watchdog.
#>
param([switch]$Force)
$ErrorActionPreference = 'Continue'
$base   = 'C:\QM\mt5\T_Live\MT5_Base'
$exe    = Join-Path $base 'terminal64.exe'
$common = Join-Path $base 'config\common.ini'
$profile = 'DarwinexZero_V2_LiveOps'
$profileDir = Join-Path $base "MQL5\Profiles\Charts\$profile"
$profileVerifier = 'C:\QM\repo\tools\strategy_farm\prepare_dxz_v2_liveops_profile.ps1'
$maintenanceFlag = 'D:\QM\reports\state\LIVE_UPTIME_MAINTENANCE.flag'
$launchMutexName = 'Global\QM.LiveMT5.Launch.DXZ'
$launchMutex = $null
$launchMutexOwned = $false
$launcherName = 'DXZ'
$launcherLogPath = 'D:\QM\reports\state\live_launcher_events.jsonl'
$launcherLogMutexName = 'Global\QM.LiveMT5.LauncherJournal'
$launcherStartedUtc = [DateTime]::UtcNow
$launcherIdentity = $null
$launcherSessionId = $null
$launcherProbeAttempts = [Collections.Generic.List[object]]::new()

function Get-LauncherBootAgeSeconds {
    try {
        # Windows PowerShell 5.1 runs on .NET Framework, where TickCount64 is
        # unavailable. Negative TickCount after its long-uptime wrap is treated
        # as unknown, which safely disables the boot-only retry.
        $seconds = [double][Environment]::TickCount / 1000.0
        if ($seconds -ge 0) { return [math]::Round($seconds, 1) }
    } catch { }
    return $null
}

function Write-LiveLauncherExitRecord {
    param(
        [int]$Code,
        [ValidateNotNullOrEmpty()][string]$Reason,
        [System.Collections.IDictionary]$Details
    )
    $journalMutex = $null
    $journalMutexOwned = $false
    try {
        if (-not $launcherIdentity) {
            try { $launcherIdentity = [Security.Principal.WindowsIdentity]::GetCurrent().Name } catch { }
        }
        if ($null -eq $launcherSessionId) {
            try { $launcherSessionId = (Get-Process -Id $PID -ErrorAction Stop).SessionId } catch { }
        }
        $stateDir = Split-Path -Parent $launcherLogPath
        [IO.Directory]::CreateDirectory($stateDir) | Out-Null
        $journalMutex = [Threading.Mutex]::new($false, $launcherLogMutexName)
        try { $journalMutexOwned = $journalMutex.WaitOne([TimeSpan]::FromSeconds(5)) }
        catch [Threading.AbandonedMutexException] { $journalMutexOwned = $true }
        if (-not $journalMutexOwned) { throw 'launcher journal mutex timeout' }

        $record = [ordered]@{
            schema_version = 1
            ts_utc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            launcher = $launcherName
            script_path = $PSCommandPath
            process_id = $PID
            identity = $launcherIdentity
            session_id = $launcherSessionId
            exit_code = $Code
            reason = $Reason
            boot_age_seconds = Get-LauncherBootAgeSeconds
            invocation_duration_seconds = [math]::Round(([DateTime]::UtcNow - $launcherStartedUtc).TotalSeconds, 3)
            probe_attempts = @($launcherProbeAttempts)
            details = $Details
        }
        $line = ($record | ConvertTo-Json -Compress -Depth 8) + [Environment]::NewLine
        [IO.File]::AppendAllText($launcherLogPath, $line, [Text.UTF8Encoding]::new($false))
    } catch {
        Write-Warning "Could not append live launcher journal: $($_.Exception.Message)"
    } finally {
        if ($journalMutex -and $journalMutexOwned) {
            try { $journalMutex.ReleaseMutex() } catch { }
        }
        if ($journalMutex) { $journalMutex.Dispose() }
    }
}

function Complete-TLiveLauncher {
    param(
        [int]$Code,
        [ValidateNotNullOrEmpty()][string]$Reason,
        [System.Collections.IDictionary]$Details
    )
    Write-LiveLauncherExitRecord -Code $Code -Reason $Reason -Details $Details
    if ($launchMutex -and $launchMutexOwned) {
        try { $launchMutex.ReleaseMutex() } catch { }
    }
    if ($launchMutex) { $launchMutex.Dispose() }
    exit $Code
}

function Invoke-TLiveProcessProbe {
    try {
        $all = @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction Stop)
    } catch {
        return [pscustomobject]@{ probe_ok = $false; error = $_.Exception.Message; matches = @() }
    }
    if (@($all | Where-Object { -not $_.ExecutablePath }).Count -gt 0) {
        return [pscustomobject]@{ probe_ok = $false; error = 'one_or_more_terminal64_paths_unreadable'; matches = @() }
    }
    $matches = @($all | Where-Object {
        $_.ExecutablePath.Equals($exe, [StringComparison]::OrdinalIgnoreCase)
    })
    return [pscustomobject]@{ probe_ok = $true; error = $null; matches = $matches }
}

function Get-TLiveProcessState {
    param([ValidateNotNullOrEmpty()][string]$Stage)
    $bootAge = Get-LauncherBootAgeSeconds
    $maxAttempts = if ($null -ne $bootAge -and $bootAge -le 600) { 3 } else { 1 }
    $retryDelays = @(2, 4)
    $state = $null
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        $state = Invoke-TLiveProcessProbe
        $launcherProbeAttempts.Add([ordered]@{
            ts_utc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            stage = $Stage
            attempt = $attempt
            boot_age_seconds = Get-LauncherBootAgeSeconds
            probe_ok = [bool]$state.probe_ok
            error = $state.error
            match_count = @($state.matches).Count
            match_pids = @($state.matches | ForEach-Object { $_.ProcessId })
        }) | Out-Null
        if ($state.probe_ok) { return $state }
        if ($attempt -lt $maxAttempts) {
            Start-Sleep -Seconds $retryDelays[$attempt - 1]
        }
    }
    return $state
}

if ($Force.IsPresent) {
    Write-Error 'ERROR: -Force is intentionally unsupported for a live terminal; duplicates are unsafe'
    Complete-TLiveLauncher -Code 2 -Reason 'force_unsupported'
}
try {
    $launcherIdentity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $launcherSessionId = (Get-Process -Id $PID -ErrorAction Stop).SessionId
} catch {
    Write-Error "ERROR: could not establish launcher identity/session: $($_.Exception.Message)"
    Complete-TLiveLauncher -Code 2 -Reason 'identity_or_session_probe_failed' -Details @{ error = $_.Exception.Message }
}
$identity = $launcherIdentity
$sessionId = $launcherSessionId
if ($identity.Split('\')[-1] -ine 'qm-admin' -or $sessionId -le 0) {
    Write-Error "ERROR: refusing wrong-user/non-interactive launch context: identity=$identity session=$sessionId"
    Complete-TLiveLauncher -Code 2 -Reason 'wrong_identity_or_session'
}
try {
    $launchMutex = [Threading.Mutex]::new($false, $launchMutexName)
    try { $launchMutexOwned = $launchMutex.WaitOne([TimeSpan]::FromSeconds(30)) }
    catch [Threading.AbandonedMutexException] { $launchMutexOwned = $true }
} catch {
    Write-Error "ERROR: live-launch mutex failed: $($_.Exception.Message)"
    Complete-TLiveLauncher -Code 2 -Reason 'launch_mutex_error' -Details @{ error = $_.Exception.Message }
}
if (-not $launchMutexOwned) {
    Write-Error 'ERROR: another DXZ launcher still owns the 30-second launch mutex'
    Complete-TLiveLauncher -Code 4 -Reason 'launch_mutex_timeout'
}

if (Test-Path -LiteralPath $maintenanceFlag -PathType Leaf) {
    Write-Host 'T_Live launch suppressed by LIVE_UPTIME_MAINTENANCE.flag'
    Complete-TLiveLauncher -Code 0 -Reason 'maintenance_preflight'
}
$initial = Get-TLiveProcessState -Stage 'initial'
if (-not $initial.probe_ok) {
    Write-Error "ERROR: DXZ process inventory unknown; refusing launch: $($initial.error)"
    Complete-TLiveLauncher -Code 2 -Reason 'initial_process_probe_unknown' -Details @{ error = [string]$initial.error }
}
if (@($initial.matches).Count -gt 1) {
    Write-Error "ERROR: duplicate DXZ processes already exist: $(@($initial.matches).Count)"
    Complete-TLiveLauncher -Code 2 -Reason 'initial_duplicate_processes' -Details @{ pids = @($initial.matches | ForEach-Object { $_.ProcessId }) }
}
if (@($initial.matches).Count -eq 1) {
    Write-Host "T_Live already running - no action. $(Get-Date -Format o)"
    Complete-TLiveLauncher -Code 0 -Reason 'already_running' -Details @{ pids = @($initial.matches | ForEach-Object { $_.ProcessId }) }
}

if (-not (Test-Path $exe)) { Write-Error "ERROR: $exe not found"; Complete-TLiveLauncher -Code 2 -Reason 'terminal_executable_missing' }
if (-not (Test-Path $profileDir)) {
    Write-Error "ERROR: recovery profile not found: $profileDir"
    Complete-TLiveLauncher -Code 2 -Reason 'recovery_profile_missing'
}
if (-not (Test-Path -LiteralPath $profileVerifier -PathType Leaf)) {
    Write-Error "ERROR: recovery profile verifier not found: $profileVerifier"
    Complete-TLiveLauncher -Code 2 -Reason 'profile_verifier_missing'
}
& powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $profileVerifier -VerifyOnly
if ($LASTEXITCODE -ne 0) {
    Write-Error "ERROR: recovery profile contract verification failed: $profile"
    Complete-TLiveLauncher -Code 2 -Reason 'profile_contract_failed' -Details @{ verifier_exit_code = $LASTEXITCODE }
}
if (-not (Test-Path $common -PathType Leaf)) { Write-Error "ERROR: common.ini not found: $common"; Complete-TLiveLauncher -Code 2 -Reason 'common_ini_missing' }

# Pin only ProfileLast and [Experts] Enabled while the terminal is stopped.
# Any parse/write/verification failure blocks launch; process-up with the wrong
# profile or AutoTrading disabled is not a successful recovery.
try {
    $txt = [IO.File]::ReadAllText($common, [Text.Encoding]::Unicode)
    if ($txt -notmatch '(?m)^ProfileLast=') { throw 'ProfileLast key missing' }
    $txt = [regex]::Replace($txt, '(?m)^ProfileLast=.*$', "ProfileLast=$profile")
    $experts = [regex]::Match($txt, '(?ms)^\[Experts\]\s*\r?\n.*?(?=^\[|\z)')
    if (-not $experts.Success) { throw '[Experts] section missing' }
    if ($experts.Value -notmatch '(?m)^Enabled=') { throw '[Experts] Enabled key missing' }
    $expertsPinned = [regex]::Replace($experts.Value, '(?m)^Enabled=.*$', 'Enabled=1')
    $txt = $txt.Substring(0, $experts.Index) + $expertsPinned + $txt.Substring($experts.Index + $experts.Length)
    Copy-Item -LiteralPath $common -Destination "$common.bak" -Force -ErrorAction Stop
    [IO.File]::WriteAllText($common, $txt, [Text.Encoding]::Unicode)

    $verify = [IO.File]::ReadAllText($common, [Text.Encoding]::Unicode)
    $verifyExperts = [regex]::Match($verify, '(?ms)^\[Experts\]\s*\r?\n.*?(?=^\[|\z)')
    if ($verify -notmatch "(?m)^ProfileLast=$([regex]::Escape($profile))\s*$" -or
        $verifyExperts.Value -notmatch '(?m)^Enabled=1\s*$') {
        throw 'post-write verification failed'
    }
    Write-Host "common.ini pinned and verified: ProfileLast=$profile, Experts Enabled=1"
} catch {
    Write-Error "ERROR: common.ini recovery pin failed; terminal not launched: $($_.Exception.Message)"
    Complete-TLiveLauncher -Code 2 -Reason 'common_ini_pin_failed' -Details @{ error = $_.Exception.Message }
}

$finalPrelaunch = Get-TLiveProcessState -Stage 'final_prelaunch'
if (-not $finalPrelaunch.probe_ok) {
    Write-Error "ERROR: final DXZ process inventory unknown; refusing launch: $($finalPrelaunch.error)"
    Complete-TLiveLauncher -Code 2 -Reason 'final_process_probe_unknown' -Details @{ error = [string]$finalPrelaunch.error }
}
if (@($finalPrelaunch.matches).Count -gt 1) {
    Write-Error "ERROR: duplicate DXZ processes appeared before launch: $(@($finalPrelaunch.matches).Count)"
    Complete-TLiveLauncher -Code 2 -Reason 'duplicate_processes_before_launch' -Details @{ pids = @($finalPrelaunch.matches | ForEach-Object { $_.ProcessId }) }
}
if (@($finalPrelaunch.matches).Count -eq 1) {
    Write-Host 'T_Live appeared during preflight - no second process launched.'
    Complete-TLiveLauncher -Code 0 -Reason 'appeared_during_preflight' -Details @{ pids = @($finalPrelaunch.matches | ForEach-Object { $_.ProcessId }) }
}
if (Test-Path -LiteralPath $maintenanceFlag -PathType Leaf) {
    Write-Host 'T_Live launch cancelled because maintenance began during preflight.'
    Complete-TLiveLauncher -Code 0 -Reason 'maintenance_during_preflight'
}
Start-Process -FilePath $exe -ArgumentList '/portable' -WorkingDirectory $base
Write-Host "T_Live launched: $exe /portable  $(Get-Date -Format o)"
Start-Sleep -Seconds 5
$post = Get-TLiveProcessState -Stage 'post_launch'
if (-not $post.probe_ok -or @($post.matches).Count -ne 1 -or [int]$post.matches[0].SessionId -ne $sessionId) {
    Write-Error 'ERROR: T_Live process did not remain running after launch'
    Complete-TLiveLauncher -Code 3 -Reason 'post_launch_verification_failed' -Details @{
        probe_ok = [bool]$post.probe_ok
        error = $post.error
        pids = @($post.matches | ForEach-Object { $_.ProcessId })
    }
}
Complete-TLiveLauncher -Code 0 -Reason 'launched' -Details @{ pids = @($post.matches | ForEach-Object { $_.ProcessId }) }
