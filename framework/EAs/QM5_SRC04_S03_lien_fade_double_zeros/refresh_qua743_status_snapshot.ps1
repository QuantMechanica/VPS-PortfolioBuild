param(
    [string]$ReportCsv = "D:\QM\reports\pipeline\QM5_SRC04_S03\P2\report.csv",
    [string]$OutJson = "C:\QM\repo\framework\EAs\QM5_SRC04_S03_lien_fade_double_zeros\QUA-743_STATUS_SNAPSHOT_2026-05-05.json"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ReportCsv -PathType Leaf)) {
    throw "report.csv not found: $ReportCsv"
}

$rows = Import-Csv $ReportCsv | Select-Object -Last 5
if ($rows.Count -lt 5) {
    throw "Need at least 5 rows in report.csv to compute cohort snapshot."
}

$ztCount = 0
foreach ($r in $rows) {
    if (-not (Test-Path -LiteralPath $r.evidence -PathType Leaf)) { continue }
    $summary = Get-Content -LiteralPath $r.evidence -Raw | ConvertFrom-Json
    $allZero = $true
    foreach ($run in $summary.runs) {
        if (($run.total_trades | ForEach-Object { [int]$_ }) -ne 0) { $allZero = $false; break }
    }
    if ($allZero) { $ztCount++ }
}

$snapshot = [ordered]@{
    issue = "QUA-743"
    ea_id = 1009
    ea_slug = "QM5_SRC04_S03_lien_fade_double_zeros"
    strategy_card = "strategy-seeds/cards/lien-fade-double-zeros_card.md"
    date_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
    phase_state = [ordered]@{
        g0 = "done"
        p1 = "done"
        p2 = "zt_recovery_triggered"
        p3_to_p10 = "gated"
    }
    zt_recovery = [ordered]@{
        cohort_threshold_met = ($ztCount -ge 5)
        cohort_size = 5
        cohort_zt_count = $ztCount
        verdict_class = "MIN_TRADES_NOT_MET"
        proposed_v2_change = "order_expiration_minutes 60 -> 240"
    }
    next_action_owner = "R-and-D then CEO"
    next_action = "Record R-and-D verdict and CEO dispatch decision; start CTO v2 build only after both."
}

$snapshot | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutJson -Encoding UTF8
Write-Output "snapshot_refreshed=$OutJson"
