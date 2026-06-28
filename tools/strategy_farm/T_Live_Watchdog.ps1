<#
.SYNOPSIS
  Watchdog for the LIVE terminal (T_Live). If T_Live's terminal64 is not running, relaunch it
  via the interactive logon task (NOT a direct SYSTEM spawn).

.DESCRIPTION
  Mirrors the factory watchdog lesson (project memory 2026-06-24): a SYSTEM CreateProcessAsUser
  respawn yields a terminal whose child dies 0xC0000142; the working fix is to Start-ScheduledTask
  the interactive AtLogon task so the terminal launches in the real desktop session. Runs every
  ~5 min as SYSTEM. Only relaunches; never kills.
#>
$ErrorActionPreference = 'Continue'
$running = Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
           Where-Object { $_.CommandLine -like '*C:\QM\mt5\T_Live\MT5_Base*' }
if ($running) {
    Write-Host "T_Live alive (pid $($running.ProcessId -join ',')) $(Get-Date -Format o)"
    exit 0
}
Write-Host "T_Live DOWN - triggering QM_T_Live_AtLogon $(Get-Date -Format o)"
try { Start-ScheduledTask -TaskName 'QM_T_Live_AtLogon' -ErrorAction Stop }
catch { Write-Host "Start-ScheduledTask failed: $_" }
