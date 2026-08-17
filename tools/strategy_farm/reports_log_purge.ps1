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
#  2026-06-10 (Claude, OWNER accelerate directive): multi-root + defaults
#  retuned 48h->6h. At ~1,500 work_items/day the old 48h retention held
#  300-900 GB of dead journals; D: hit 7 GB free on 2026-06-10 before the
#  6h purge reclaimed 405 GB. Also covers D:\QM\reports\smoke (same
#  disposable tester journals, 70 GB found uncovered).
#  2026-07-22 (Claude, OWNER disk-fix directive): added D:\QM\reports\pipeline
#  to roots — the per-EA pipeline dir had accumulated 154 GB of *.log the
#  purge was missing (evidence .htm/.json/.set are tiny and kept). One-time
#  manual reclaim freed 153.7 GB (D: 119.7->273.4 GB); this makes it durable.
#  2026-08-17 (Claude, OWNER retention directive): 2h -> 12h, plus a SIZE BUDGET.
#  Why the raise is safe now: journals are ~150x smaller than in the June crisis
#  (measured median 0.1 MB, p90 2.3 MB vs ~15 MB then), so the accrual across all
#  three roots is 0.022 GB/h and a 12h window holds ~0.27 GB against 152 GB free.
#  Why the raise is NEEDED: a failure classified later than the retention window
#  has no journal, so it becomes failure_class UNCLASSIFIED — which is not a
#  recognised deterministic class, so the hourly stranded-INFRA sweep re-enqueues
#  it and the pair can loop. Measured: 16 rows / 11 triples / 49 dispatches
#  (~25 slot-hours over 5 days), 5 of 11 converging. Retention is therefore the
#  precondition for a per-pair stopping rule, not merely forensics.
#  Why the BUDGET: retention alone is the wrong shape. If a LOG_BOMB-style class
#  returns, per-file size can jump back by two orders of magnitude and a 12h
#  window would hold tens of GB. MaxTreeGB collapses the window automatically in
#  that case, so the guard the 2h setting provided is kept without paying for it
#  in normal operation.
[CmdletBinding()]
param(
    [int]$RetentionHours = 6,
    [string[]]$ReportsRoot = @("D:\QM\reports\work_items", "D:\QM\reports\smoke", "D:\QM\reports\pipeline"),
    # 0 disables the budget. 8 GB is ~30x the projected 12h volume, so it never
    # binds in normal operation and binds hard on a size regression.
    [double]$MaxTreeGB = 0,
    [switch]$DryRun
)
$ErrorActionPreference = 'Continue'
$log = "D:\QM\reports\state\reports_log_purge.log"
function Now { (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
function FreeGB { [math]::Round((Get-PSDrive D).Free / 1GB, 2) }
function Log($m) { $line = "$(Now) $m"; Write-Output $line; try { Add-Content -Path $log -Value $line -Encoding UTF8 } catch {} }

$roots = @($ReportsRoot | Where-Object { Test-Path $_ })
if (-not $roots) { Log "SKIP: no ReportsRoot found ($($ReportsRoot -join ', '))"; return }

$cutoff = (Get-Date).AddHours(-$RetentionHours)
$freeBefore = FreeGB
$count = 0
[long]$bytes = 0

foreach ($root in $roots) {
    Get-ChildItem $root -Recurse -File -Filter *.log -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        ForEach-Object {
            $bytes += $_.Length
            if ($DryRun) { $count++ }
            else { try { Remove-Item $_.FullName -Force -ErrorAction Stop; $count++ } catch {} }
        }
}

$gb = [math]::Round($bytes / 1GB, 2)
if ($DryRun) {
    Log "DRYRUN: would delete $count .log older than ${RetentionHours}h (~${gb}GB); D: free ${freeBefore}GB"
}
else {
    Log "PURGED $count .log older than ${RetentionHours}h (~${gb}GB); D: free ${freeBefore}GB -> $(FreeGB)GB"
}

# ---- size budget: retention OR budget, whichever binds first ----------------
# Runs only when MaxTreeGB > 0. Deletes OLDEST-FIRST until the surviving journal
# tree fits the budget, so a size regression cannot outrun the age window. The
# newest journals are the ones classification needs, hence oldest-first.
if ($MaxTreeGB -gt 0) {
    $survivors = @()
    foreach ($root in $roots) {
        $survivors += Get-ChildItem $root -Recurse -File -Filter *.log -ErrorAction SilentlyContinue
    }
    [long]$treeBytes = 0
    foreach ($f in $survivors) { $treeBytes += $f.Length }
    $treeGB = [math]::Round($treeBytes / 1GB, 2)
    [long]$budgetBytes = [long]($MaxTreeGB * 1GB)
    if ($treeBytes -le $budgetBytes) {
        Log "BUDGET_OK tree ${treeGB}GB <= ${MaxTreeGB}GB after age purge; no size trim"
    }
    else {
        $trimCount = 0
        [long]$trimBytes = 0
        foreach ($f in ($survivors | Sort-Object LastWriteTime)) {
            if ($treeBytes -le $budgetBytes) { break }
            $len = $f.Length
            if ($DryRun) { $trimCount++; $trimBytes += $len; $treeBytes -= $len; continue }
            try {
                Remove-Item $f.FullName -Force -ErrorAction Stop
                $trimCount++; $trimBytes += $len; $treeBytes -= $len
            }
            catch { }
        }
        $trimGB = [math]::Round($trimBytes / 1GB, 2)
        $verb = if ($DryRun) { "BUDGET_DRYRUN would trim" } else { "BUDGET_TRIM removed" }
        Log "$verb $trimCount oldest .log (~${trimGB}GB) to fit ${MaxTreeGB}GB; tree was ${treeGB}GB, now $([math]::Round($treeBytes/1GB,2))GB"
    }
}
