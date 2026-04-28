param(
    [string]$RepoRoot = "C:\QM\repo"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$setfilePath = Join-Path $RepoRoot "framework\EAs\QM5_SRC04_S03_lien_fade_double_zeros\sets\QM5_SRC04_S03_lien_fade_double_zeros_EURUSD.DWX_H1_backtest.set"
$evidencePath = Join-Path $RepoRoot "docs\ops\QUA-415_DISPATCH_GATE_EVIDENCE_2026-04-28.json"
$manifestPath = Join-Path $RepoRoot "docs\ops\QUA-415_CHANGESET_MANIFEST_2026-04-28.json"

$missing = @()
if (-not (Test-Path -LiteralPath $setfilePath -PathType Leaf)) { $missing += $setfilePath }
if (-not (Test-Path -LiteralPath $evidencePath -PathType Leaf)) { $missing += $evidencePath }
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { $missing += $manifestPath }

if ($missing.Count -gt 0) {
    [pscustomobject]@{
        status = "FAIL"
        issue = "QUA-415"
        missing = $missing
    } | ConvertTo-Json -Depth 6
    exit 1
}

$evidence = Get-Content -Raw -LiteralPath $evidencePath | ConvertFrom-Json
$rejectCode = [string]$evidence.reject_without_set.error_code
$scheduled = [string]$evidence.schedule_with_set.status

if ($rejectCode -ne "BACKTEST_REJECTED_NO_SETFILE" -or $scheduled -ne "scheduled") {
    [pscustomobject]@{
        status = "FAIL"
        issue = "QUA-415"
        reject_code = $rejectCode
        scheduled_status = $scheduled
    } | ConvertTo-Json -Depth 6
    exit 1
}

[pscustomobject]@{
    status = "PASS"
    issue = "QUA-415"
    reject_code = $rejectCode
    scheduled_status = $scheduled
    setfile_path = $setfilePath
} | ConvertTo-Json -Depth 6
