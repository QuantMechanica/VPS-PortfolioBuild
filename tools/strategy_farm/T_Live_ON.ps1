<#
.SYNOPSIS
  Start the LIVE trading terminal (T_Live) and ensure it resumes the deployed EA portfolio.

.DESCRIPTION
  T_Live is the live Darwinex terminal at C:\QM\mt5\T_Live\MT5_Base (portable). After a VPS
  reboot the factory (T1-T10) is restored by QM_StrategyFarm_FactoryON_AtLogon, but T_Live has
  no such path - this closes that gap. Idempotent: if a T_Live terminal64 is already running it
  no-ops. When the terminal is NOT running it (1) pins the deployed chart profile + AutoTrading
  in config\common.ini so a cold/unclean reboot still loads the 13-EA portfolio and trades, then
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
$profile = 'DarwinexZero_V1'

function Test-TLiveRunning {
    $p = Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
         Where-Object { $_.CommandLine -like '*C:\QM\mt5\T_Live\MT5_Base*' }
    return [bool]$p
}

if ((Test-TLiveRunning) -and -not $Force) {
    Write-Host "T_Live already running - no action. $(Get-Date -Format o)"
    return
}

# Pin profile + AutoTrading in common.ini (only safe while terminal is stopped).
if (-not (Test-TLiveRunning) -and (Test-Path $common)) {
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
Start-Process -FilePath $exe -ArgumentList '/portable' -WorkingDirectory $base
Write-Host "T_Live launched: $exe /portable  $(Get-Date -Format o)"
