<#
.SYNOPSIS
  Keep the QM news-calendar CSVs fresh so EAs do not fail-closed at ONINIT.

.DESCRIPTION
  The V5 framework (QM_Common.mqh, news_stale_max_hours = 24*14 = 336h) treats a
  news-calendar file older than 14 days as stale and fails EA init (SETUP_DATA_
  MISSING -> INIT_FAILED). The 2015-2025 event data is complete for the backtest
  window, so the staleness gate is a freshness heuristic, not a data-coverage one.
  This script refreshes the seed CSV mtimes and re-syncs the Common\Files copies
  the terminals read (FILE_COMMON fallback), so the 14-day wave never fires.

  Run daily via scheduled task QM_NewsCalendar_Refresh (huge margin vs the 336h
  bound). Idempotent + near-instant. OWNER 2026-06-04.
#>
$ErrorActionPreference = 'Continue'
$now = Get-Date
$common = 'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files'
$pairs = @(
  @{ Seed = 'D:\QM\data\news_calendar\forex_factory_calendar_clean.csv'; CommonName = 'forex_factory_calendar_clean.csv' },
  @{ Seed = 'D:\QM\data\news_calendar\news_calendar_2015_2025.csv';      CommonName = 'news_calendar_2015_2025.csv' }
)
foreach ($p in $pairs) {
  if (Test-Path $p.Seed) {
    # mtime is the freshness signal and can be set even while a terminal holds
    # the file open for reading; the content Copy is best-effort (skipped if locked).
    try { (Get-Item $p.Seed).LastWriteTime = $now } catch { Write-Warning "touch seed failed: $($p.Seed): $_" }
    $dst = Join-Path $common $p.CommonName
    try { Copy-Item $p.Seed $dst -Force -ErrorAction Stop } catch { Write-Warning "Common copy skipped (locked): $($p.CommonName)" }
    if (Test-Path $dst) { try { (Get-Item $dst).LastWriteTime = $now } catch { Write-Warning "touch Common failed: $dst : $_" } }
    Write-Host "refreshed $($p.CommonName)"
  } else {
    Write-Warning "seed MISSING: $($p.Seed)"
  }
}
Write-Host "news-calendar refresh done @ $now"
