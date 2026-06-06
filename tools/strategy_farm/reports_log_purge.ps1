# =====================================================================
#  QuantMechanica - Reports .log Purge (permanent fix for D: fill-up)
#  The dominant D: consumer is NOT the tester cache but the per-work_item
#  MT5 strategy-tester JOURNAL logs under D:\QM\reports\work_items\**\*.log
#  (incident 2026-06-06: 36,103 .log = 529 GB vs only 3.5 GB of .htm reports).
#
#  These .log are pure tester diagnostics (tick generation, memory stats,
#  "testing finished") — they hold NO trades, NO metrics, NO config. All
#  archive-relevant data lives in report.htm + summary.json + the .set file,
#  which this script NEVER touches. Verified: 0 DB evidence_path point at .log.
#
#  Unlike tester_cache_purge.ps1, deleting a finished work_item's .log needs
#  NO factory stop and NO interactive session: a completed run never reopens
#  its journal. So this runs safely as SYSTEM in session 0, every day.
#
#  Deletes ONLY: D:\QM\reports\work_items\**\*.log older than RetentionHours.
#  KEEPS: every .htm (reports), .json (metrics), .set (configs), .ini.
# =====================================================================
[CmdletBinding()]
param(
    [int]$RetentionHours = 48,
    [string]$ReportsRoot = "D:\QM\reports\work_items",
    [switch]$DryRun
)
$ErrorActionPreference = 'Continue'
$log = "D:\QM\reports\state\reports_log_purge.log"
function Now { (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
function FreeGB { [math]::Round((Get-PSDrive D).Free / 1GB, 2) }
function Log($m) { $line = "$(Now) $m"; Write-Output $line; try { Add-Content -Path $log -Value $line -Encoding UTF8 } catch {} }

if (-not (Test-Path $ReportsRoot)) { Log "SKIP: $ReportsRoot not found"; return }

$cutoff = (Get-Date).AddHours(-$RetentionHours)
$freeBefore = FreeGB
$count = 0
[long]$bytes = 0

Get-ChildItem $ReportsRoot -Recurse -File -Filter *.log -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt $cutoff } |
    ForEach-Object {
        $bytes += $_.Length
        if ($DryRun) { $count++ }
        else { try { Remove-Item $_.FullName -Force -ErrorAction Stop; $count++ } catch {} }
    }

$gb = [math]::Round($bytes / 1GB, 2)
if ($DryRun) {
    Log "DRYRUN: would delete $count .log older than ${RetentionHours}h (~${gb}GB); D: free ${freeBefore}GB"
}
else {
    Log "PURGED $count .log older than ${RetentionHours}h (~${gb}GB); D: free ${freeBefore}GB -> $(FreeGB)GB"
}
