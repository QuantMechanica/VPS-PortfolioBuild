# Reclaim stale MT5 tester-agent scratch from BUSY terminals.
#
# tester_cache_purge.ps1 targets exactly these directories but only for IDLE slots,
# by design: "MT5 agents read these caches mid-run, the factory MUST be stopped first."
# The terminal causing the fill is therefore permanently exempt while it runs, and a
# Q07 multiseed on XAUUSD writes ~87 GB/h of bar*.tmp scratch.
#
# Safety, three independent layers:
#   1. only bar*.tmp under Tester\Agent-*\temp -- regenerable scratch, never source data
#   2. only files older than -MinAgeMinutes (the live seed's files are recent)
#   3. per-file exclusive-open test; anything the agent still holds is SKIPPED, not forced
#
# Reports reclaimed volume and skipped locks. -Apply required to delete.
[CmdletBinding()]
param(
    [int]$MinAgeMinutes = 20,
    [switch]$Apply
)

$cut = (Get-Date).AddMinutes(-$MinAgeMinutes)
$freeBefore = [math]::Round((Get-PSDrive D).Free/1GB, 1)
"D: frei vorher: $freeBefore GB   Modus: $(if ($Apply) { 'APPLY' } else { 'DRY-RUN' })   Altersgrenze: ${MinAgeMinutes}min"
""

$totalDeleted = 0.0; $totalSkipped = 0; $totalFiles = 0
foreach ($t in 1..10) {
    $roots = Get-ChildItem "D:\QM\mt5\T$t\Tester" -Directory -Filter 'Agent-*' -EA SilentlyContinue
    foreach ($r in $roots) {
        $tmp = Join-Path $r.FullName 'temp'
        if (-not (Test-Path -LiteralPath $tmp)) { continue }
        $cand = Get-ChildItem $tmp -File -Filter 'bar*.tmp' -EA SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt $cut }
        if (-not $cand) { continue }
        $gb = [math]::Round((($cand | Measure-Object -Sum Length).Sum)/1GB, 2)
        $del = 0.0; $skip = 0
        foreach ($f in $cand) {
            try {
                $fs = [IO.File]::Open($f.FullName, 'Open', 'ReadWrite', 'None')
                $fs.Close()
            } catch { $skip++; continue }   # in use by the agent -> leave alone
            if ($Apply) {
                try { $len = $f.Length; Remove-Item $f.FullName -Force -EA Stop; $del += $len/1GB }
                catch { $skip++ }
            } else { $del += $f.Length/1GB }
        }
        $totalDeleted += $del; $totalSkipped += $skip; $totalFiles += $cand.Count
        "  T$t $($r.Name): $($cand.Count) Kandidaten, $gb GB -> $(if ($Apply) {'freigegeben'} else {'freigebbar'}) {0:N2} GB, gesperrt uebersprungen $skip" -f $del
    }
}
""
"SUMME: $totalFiles Kandidaten, $(if ($Apply) {'freigegeben'} else {'freigebbar'}) {0:N2} GB, gesperrt uebersprungen $totalSkipped" -f $totalDeleted
if ($Apply) {
    Start-Sleep -Seconds 2
    $freeAfter = [math]::Round((Get-PSDrive D).Free/1GB, 1)
    "D: frei nachher: $freeAfter GB   Gewinn: {0:N1} GB" -f ($freeAfter - $freeBefore)
}
