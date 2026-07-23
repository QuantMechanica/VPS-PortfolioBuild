<#
.SYNOPSIS
  Start the FTMO challenge/trial terminal and ensure it resumes the deployed EA book.

.DESCRIPTION
  The FTMO Global Markets MT5 terminal is a NON-portable install: binaries under
  'C:\Program Files\FTMO Global Markets MT5 Terminal', data dir under
  %APPDATA%\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850. After a VPS reboot
  T_Live is restored by QM_T_Live_AtLogon and the factory by
  QM_StrategyFarm_FactoryON_AtLogon - the FTMO terminal had no such path (it was
  started manually on 2026-07-05). This closes that gap, mirroring T_Live_ON.ps1.

  Idempotent: if an FTMO terminal64 is already running it no-ops. When NOT running it
  (1) pins ProfileLast + Experts Enabled=1 in the data-dir config\common.ini so the
  deployed 12-leg Round25 book (profile 'Default', account 1513845506) reloads and
  trades after a cold reboot, then (2) launches terminal64.exe (no /portable - the
  install is registry/appdata based).

  Deployed-state authority: decisions/2026-07-05_ftmo_round25_phase1_deploy.md
  (OWNER-approved trial deploy incl. AutoTrading). Auto-resume mirrors the
  OWNER-requested T_Live reboot-resilience pattern (2026-06-28).

  Run at logon via QM_FTMO_AtLogon.
#>
param([switch]$Force)
$ErrorActionPreference = 'Continue'
$exeDir  = 'C:\Program Files\FTMO Global Markets MT5 Terminal'
$exe     = Join-Path $exeDir 'terminal64.exe'
# qm-admin is the renamed built-in Administrator account. Its profile directory
# remains C:\Users\Administrator. Keep this path explicit so recovery cannot
# drift with the caller's environment (SYSTEM, another admin, or a task update).
$dataDir = 'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850'
$common  = Join-Path $dataDir 'config\common.ini'
$profile = 'Default'
$profileDir = Join-Path $dataDir "MQL5\Profiles\Charts\$profile"
$contractVerifier = 'C:\QM\repo\tools\strategy_farm\verify_ftmo_round25_live_contract.ps1'
$maintenanceFlag = 'D:\QM\reports\state\LIVE_UPTIME_MAINTENANCE.flag'
$launchMutexName = 'Global\QM.LiveMT5.Launch.FTMO'
$launchMutex = $null
$launchMutexOwned = $false

function Complete-FtmoLauncher {
    param([int]$Code)
    if ($launchMutex -and $launchMutexOwned) {
        try { $launchMutex.ReleaseMutex() } catch { }
    }
    if ($launchMutex) { $launchMutex.Dispose() }
    exit $Code
}

function Get-FtmoProcessState {
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
    Write-Error 'ERROR: another FTMO launcher still owns the 30-second launch mutex'
    Complete-FtmoLauncher 4
}
if (Test-Path -LiteralPath $maintenanceFlag -PathType Leaf) {
    Write-Host 'FTMO launch suppressed by LIVE_UPTIME_MAINTENANCE.flag'
    Complete-FtmoLauncher 0
}
$initial = Get-FtmoProcessState
if (-not $initial.probe_ok) {
    Write-Error "ERROR: FTMO process inventory unknown; refusing launch: $($initial.error)"
    Complete-FtmoLauncher 2
}
if (@($initial.matches).Count -gt 1) {
    Write-Error "ERROR: duplicate FTMO processes already exist: $(@($initial.matches).Count)"
    Complete-FtmoLauncher 2
}
if (@($initial.matches).Count -eq 1) {
    Write-Host "FTMO terminal already running - no action. $(Get-Date -Format o)"
    Complete-FtmoLauncher 0
}

if (-not (Test-Path $exe)) { Write-Error "ERROR: $exe not found"; Complete-FtmoLauncher 2 }
if (-not (Test-Path $dataDir)) { Write-Error "ERROR: FTMO data directory not found: $dataDir"; Complete-FtmoLauncher 2 }
if (-not (Test-Path -LiteralPath $profileDir -PathType Container)) {
    Write-Error "ERROR: recovery profile not found: $profileDir"
    Complete-FtmoLauncher 2
}
if (-not (Test-Path -LiteralPath $contractVerifier -PathType Leaf)) {
    Write-Error "ERROR: FTMO recovery contract verifier not found: $contractVerifier"
    Complete-FtmoLauncher 2
}
& powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $contractVerifier
if ($LASTEXITCODE -ne 0) {
    Write-Error "ERROR: FTMO Round25 recovery contract verification failed: $profile"
    Complete-FtmoLauncher 2
}
if (-not (Test-Path $common -PathType Leaf)) { Write-Error "ERROR: common.ini not found: $common"; Complete-FtmoLauncher 2 }

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
    Complete-FtmoLauncher 2
}

$finalPrelaunch = Get-FtmoProcessState
if (-not $finalPrelaunch.probe_ok) {
    Write-Error "ERROR: final FTMO process inventory unknown; refusing launch: $($finalPrelaunch.error)"
    Complete-FtmoLauncher 2
}
if (@($finalPrelaunch.matches).Count -gt 1) {
    Write-Error "ERROR: duplicate FTMO processes appeared before launch: $(@($finalPrelaunch.matches).Count)"
    Complete-FtmoLauncher 2
}
if (@($finalPrelaunch.matches).Count -eq 1) {
    Write-Host 'FTMO appeared during preflight - no second process launched.'
    Complete-FtmoLauncher 0
}
if (Test-Path -LiteralPath $maintenanceFlag -PathType Leaf) {
    Write-Host 'FTMO launch cancelled because maintenance began during preflight.'
    Complete-FtmoLauncher 0
}
Start-Process -FilePath $exe -WorkingDirectory $exeDir
Write-Host "FTMO terminal launched: $exe  $(Get-Date -Format o)"
Start-Sleep -Seconds 5
$post = Get-FtmoProcessState
if (-not $post.probe_ok -or @($post.matches).Count -ne 1 -or [int]$post.matches[0].SessionId -ne $sessionId) {
    Write-Error 'ERROR: FTMO process did not remain running after launch'
    Complete-FtmoLauncher 3
}
Complete-FtmoLauncher 0
