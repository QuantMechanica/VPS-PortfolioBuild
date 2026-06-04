<#
.SYNOPSIS
  Provision additional factory MT5 terminals by cloning an existing one.
  OWNER 2026-06-04 - adds T11-T14 on the 8-physical-core VPS.

.DESCRIPTION
  Clones a SOURCE terminal (default T1) into TARGET terminals. Copies the
  binaries, Config, MQL5, dwx_import, and Bases\Custom (the .DWX custom-symbol
  ticks the factory backtests use). DELIBERATELY SKIPS:
    - Tester\           regenerable backtest cache (huge)
    - Bases\Darwinex-Live  broker live history (~14GB) - .DWX backtests don't use it
    - logs\, *.png/*.htm/*.html/*.log  loose report artifacts

  MUST be run during a FACTORY-IDLE window (no terminal64.exe running): cloning
  or cache-clearing while backtests run risks partial copies / cache corruption.
  The desktop-heap reboot (SharedSection 65536) is the natural idle window.

.PARAMETER ClearCache
  Before cloning, delete regenerable Tester caches across all T* terminals to
  free disk for the new Bases (each Custom clone is ~42GB).

.EXAMPLE
  pwsh -File provision_terminals.ps1 -WhatIf
  pwsh -File provision_terminals.ps1 -ClearCache
#>
param(
  [string]$Source = 'T1',
  [string[]]$Targets = @('T11','T12','T13','T14'),
  [switch]$ClearCache,
  [switch]$WhatIf
)
$ErrorActionPreference = 'Stop'
$root = 'D:\QM\mt5'
$src  = Join-Path $root $Source

if (-not (Test-Path (Join-Path $src 'terminal64.exe'))) { throw "Source $Source has no terminal64.exe at $src" }

# Safety: never clone/clear while the factory is running.
$running = @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'")
if ($running.Count -gt 0) {
  Write-Warning "$($running.Count) terminal64.exe running. Cloning/cache-clearing during active backtests risks partial copies. Stop the factory first."
  if (-not $WhatIf) { throw "Refusing to provision while terminals run. Stop workers (or run inside the reboot window), then re-run." }
}

$free = [math]::Round((Get-PSDrive D).Free/1GB,1)
Write-Host "D: free before: $free GB"

# 1. Optional: free disk by clearing regenerable Tester caches.
if ($ClearCache) {
  foreach ($d in (Get-ChildItem $root -Directory -Filter 'T*' -ErrorAction SilentlyContinue)) {
    $tc = Join-Path $d.FullName 'Tester'
    if (Test-Path $tc) {
      $gb = [math]::Round(((Get-ChildItem $tc -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum)/1GB,1)
      Write-Host "Clearing $tc ($gb GB)"
      if (-not $WhatIf) { Remove-Item (Join-Path $tc '*') -Recurse -Force -ErrorAction SilentlyContinue }
    }
  }
  $free = [math]::Round((Get-PSDrive D).Free/1GB,1)
  Write-Host "D: free after cache-clear: $free GB"
}

# 2. Clone source -> each target.
$excludeDirs  = @('Tester','logs','signals') + @((Join-Path $src 'Bases\Darwinex-Live'))
$excludeFiles = @('*.png','*.htm','*.html','*.log','*.gif')
foreach ($t in $Targets) {
  $dst = Join-Path $root $t
  Write-Host "=== Cloning $Source -> $t ==="
  if (Test-Path (Join-Path $dst 'terminal64.exe')) { Write-Warning "$t already provisioned - skipping"; continue }
  $rcArgs = @($src, $dst, '/E', '/COPY:DAT', '/R:1', '/W:1', '/MT:8', '/NFL', '/NDL', '/NP')
  foreach ($x in $excludeDirs)  { $rcArgs += @('/XD', $x) }
  $rcArgs += @('/XF') + $excludeFiles
  if ($WhatIf) { Write-Host "robocopy $($rcArgs -join ' ')"; continue }
  & robocopy @rcArgs | Out-Null   # robocopy exit codes 0-7 are success
  $okExe    = Test-Path (Join-Path $dst 'terminal64.exe')
  $custom   = Join-Path $dst 'Bases\Custom'
  $okCustom = Test-Path $custom
  $cgb = if ($okCustom) { [math]::Round(((Get-ChildItem $custom -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum)/1GB,1) } else { 0 }
  Write-Host ("  {0}: terminal64={1}  Bases\Custom={2} ({3} GB)" -f $t, $okExe, $okCustom, $cgb)
  if (-not ($okExe -and $okCustom)) { Write-Warning "$t clone INCOMPLETE - investigate before starting its worker." }
}

Write-Host ""
Write-Host "Next:"
Write-Host "  1. Reboot (desktop-heap SharedSection 65536 takes effect)."
Write-Host "  2. Validate symbol data on T11-T14 (custom-symbol presence + DST/timestamp parity vs T1)."
Write-Host "  3. python tools/strategy_farm/start_terminal_workers.py --dedupe   # launches T1-T14"
Write-Host "  4. farmctl mt5-slots  # confirm 14 terminals feed the queue"
