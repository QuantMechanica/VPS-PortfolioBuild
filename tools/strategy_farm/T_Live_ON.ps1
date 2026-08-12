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

function Complete-TLiveLauncher {
    param([int]$Code)
    if ($launchMutex -and $launchMutexOwned) {
        try { $launchMutex.ReleaseMutex() } catch { }
    }
    if ($launchMutex) { $launchMutex.Dispose() }
    exit $Code
}

function Get-TLiveProcessState {
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

if ($Force.IsPresent) {
    Write-Error 'ERROR: -Force is intentionally unsupported for a live terminal; duplicates are unsafe'
    exit 2
}
$identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$sessionId = (Get-Process -Id $PID).SessionId
if ($identity.Split('\')[-1] -ine 'qm-admin' -or $sessionId -le 0) {
    Write-Error "ERROR: refusing wrong-user/non-interactive launch context: identity=$identity session=$sessionId"
    exit 2
}
try {
    $launchMutex = [Threading.Mutex]::new($false, $launchMutexName)
    try { $launchMutexOwned = $launchMutex.WaitOne([TimeSpan]::FromSeconds(30)) }
    catch [Threading.AbandonedMutexException] { $launchMutexOwned = $true }
} catch {
    Write-Error "ERROR: live-launch mutex failed: $($_.Exception.Message)"
    exit 2
}
if (-not $launchMutexOwned) {
    Write-Error 'ERROR: another DXZ launcher still owns the 30-second launch mutex'
    Complete-TLiveLauncher 4
}

if (Test-Path -LiteralPath $maintenanceFlag -PathType Leaf) {
    Write-Host 'T_Live launch suppressed by LIVE_UPTIME_MAINTENANCE.flag'
    Complete-TLiveLauncher 0
}
$initial = Get-TLiveProcessState
if (-not $initial.probe_ok) {
    Write-Error "ERROR: DXZ process inventory unknown; refusing launch: $($initial.error)"
    Complete-TLiveLauncher 2
}
if (@($initial.matches).Count -gt 1) {
    Write-Error "ERROR: duplicate DXZ processes already exist: $(@($initial.matches).Count)"
    Complete-TLiveLauncher 2
}
if (@($initial.matches).Count -eq 1) {
    Write-Host "T_Live already running - no action. $(Get-Date -Format o)"
    Complete-TLiveLauncher 0
}

if (-not (Test-Path $exe)) { Write-Error "ERROR: $exe not found"; Complete-TLiveLauncher 2 }
if (-not (Test-Path $profileDir)) {
    Write-Error "ERROR: recovery profile not found: $profileDir"
    Complete-TLiveLauncher 2
}
if (-not (Test-Path -LiteralPath $profileVerifier -PathType Leaf)) {
    Write-Error "ERROR: recovery profile verifier not found: $profileVerifier"
    Complete-TLiveLauncher 2
}
& powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $profileVerifier -VerifyOnly
if ($LASTEXITCODE -ne 0) {
    Write-Error "ERROR: recovery profile contract verification failed: $profile"
    Complete-TLiveLauncher 2
}
if (-not (Test-Path $common -PathType Leaf)) { Write-Error "ERROR: common.ini not found: $common"; Complete-TLiveLauncher 2 }

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
    Complete-TLiveLauncher 2
}

$finalPrelaunch = Get-TLiveProcessState
if (-not $finalPrelaunch.probe_ok) {
    Write-Error "ERROR: final DXZ process inventory unknown; refusing launch: $($finalPrelaunch.error)"
    Complete-TLiveLauncher 2
}
if (@($finalPrelaunch.matches).Count -gt 1) {
    Write-Error "ERROR: duplicate DXZ processes appeared before launch: $(@($finalPrelaunch.matches).Count)"
    Complete-TLiveLauncher 2
}
if (@($finalPrelaunch.matches).Count -eq 1) {
    Write-Host 'T_Live appeared during preflight - no second process launched.'
    Complete-TLiveLauncher 0
}
if (Test-Path -LiteralPath $maintenanceFlag -PathType Leaf) {
    Write-Host 'T_Live launch cancelled because maintenance began during preflight.'
    Complete-TLiveLauncher 0
}
Start-Process -FilePath $exe -ArgumentList '/portable' -WorkingDirectory $base
Write-Host "T_Live launched: $exe /portable  $(Get-Date -Format o)"
Start-Sleep -Seconds 5
$post = Get-TLiveProcessState
if (-not $post.probe_ok -or @($post.matches).Count -ne 1 -or [int]$post.matches[0].SessionId -ne $sessionId) {
    Write-Error 'ERROR: T_Live process did not remain running after launch'
    Complete-TLiveLauncher 3
}
Complete-TLiveLauncher 0
