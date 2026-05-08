param(
    [string]$EvidenceGlob = 'docs\ops\QUA-774_P2_REDEPLOY_SUMMARY_*.json',
    [string]$OutJson = 'docs\ops\QUA-774_BLOCKER_STATUS_2026-05-08.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$globPath = Join-Path $repoRoot $EvidenceGlob
$outPath = Join-Path $repoRoot $OutJson

$candidates = @(
    Get-ChildItem -Path $globPath -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending
)
if (-not $candidates -or $candidates.Count -eq 0) {
    throw "No QUA-774 evidence files matched: $globPath"
}

$latest = $candidates[0]
$raw = Get-Content -LiteralPath $latest.FullName -Raw -Encoding UTF8
$ev = $raw | ConvertFrom-Json

$flags = @()
if ($ev.failure_flags) {
    $flags = @($ev.failure_flags | ForEach-Object { [string]$_ })
}

$missingTerminals = @()
if ($ev.custom_symbol_presence) {
    $missingTerminals = @(
        $ev.custom_symbol_presence |
            Where-Object { $_.status -ne 'present' } |
            ForEach-Object { [string]$_.terminal }
    )
}

$missingTfs = @()
if ($ev.report_coverage) {
    $missingTfs = @(
        $ev.report_coverage |
            Where-Object { $_.status -eq 'REPORT_MISSING' } |
            ForEach-Object { [string]$_.timeframe }
    )
}

$ready = ($ev.verdict -eq 'PASS') -and ($flags.Count -eq 0)

$status = [ordered]@{
    issue_id = 'QUA-774'
    generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    source_evidence = [ordered]@{
        file = $latest.FullName
        file_name = $latest.Name
        file_last_write_utc = $latest.LastWriteTimeUtc.ToString('o')
        strategy_id = [string]$ev.strategy_id
        symbol = [string]$ev.symbol
        verdict = [string]$ev.verdict
    }
    gate = [ordered]@{
        status = if ($ready) { 'ready' } else { 'blocked' }
        blocker_reason = if ($ready) { '' } else { 'P2 redeploy summary still failing REPORT_MISSING;INCOMPLETE_RUNS for required H1/H4/D1 checks.' }
        failure_flags = $flags
        missing_terminals = $missingTerminals
        missing_timeframes = $missingTfs
    }
    unblock = [ordered]@{
        owner = 'DWX source acquisition + import pipeline owner'
        required_action = @(
            'Import US500.DWX history+ticks into T1 custom symbols.',
            'Sync US500.DWX from T1 to T2-T5 using infra/scripts/Sync-CustomSymbolData.ps1.',
            'Re-run QM5_1004 US500 P2 redeploy and regenerate reports.',
            'Re-run infra/scripts/Test-P2RedeploySummary.ps1 until verdict=PASS.'
        )
    }
}

$outDir = Split-Path -Parent $outPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$status | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outPath -Encoding UTF8
$status
