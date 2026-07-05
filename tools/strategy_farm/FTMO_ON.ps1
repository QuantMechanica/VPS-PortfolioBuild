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
$dataDir = Join-Path $env:APPDATA 'MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850'
$common  = Join-Path $dataDir 'config\common.ini'
$profile = 'Default'

function Test-FtmoRunning {
    $p = Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
         Where-Object { ($_.ExecutablePath -like "$exeDir*") -or ($_.CommandLine -like "*FTMO Global Markets*") }
    return [bool]$p
}

if ((Test-FtmoRunning) -and -not $Force) {
    Write-Host "FTMO terminal already running - no action. $(Get-Date -Format o)"
    return
}

# Pin profile + AutoTrading in common.ini (only safe while terminal is stopped).
if (-not (Test-FtmoRunning) -and (Test-Path $common)) {
    try {
        Copy-Item $common "$common.bak" -Force -ErrorAction SilentlyContinue
        $txt = Get-Content $common -Raw -Encoding Unicode
        if ($txt -match 'ProfileLast=') { $txt = $txt -replace 'ProfileLast=.*', "ProfileLast=$profile" }
        # [Experts] Enabled=1 -> AutoTrading on at start
        $txt = $txt -replace '(?m)^Enabled=0', 'Enabled=1'
        Set-Content $common -Value $txt -Encoding Unicode -NoNewline
        Write-Host "common.ini pinned: ProfileLast=$profile, Experts Enabled=1"
    } catch { Write-Host "common.ini pin failed (non-fatal): $_" }
}

if (-not (Test-Path $exe)) { Write-Host "ERROR: $exe not found"; return }
Start-Process -FilePath $exe -WorkingDirectory $exeDir
Write-Host "FTMO terminal launched: $exe  $(Get-Date -Format o)"
