[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$EvidencePath = 'lessons-learned\evidence\2026-04-27_qua95_xtiusd_custom_visibility_probe_rerun.json',
    [string]$ProofPath = 'docs\ops\QUA-95_CUSTOM_VISIBILITY_RERUN_2026-04-27.md',
    [string]$BlockerPath = 'docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    Write-Host $Message
    exit 1
}

$evidenceFull = Join-Path $RepoRoot $EvidencePath
$proofFull = Join-Path $RepoRoot $ProofPath
$blockerFull = Join-Path $RepoRoot $BlockerPath

foreach ($path in @($evidenceFull, $proofFull, $blockerFull)) {
    if (-not (Test-Path -LiteralPath $path)) {
        Fail ("missing_file=" + $path)
    }
}

$evidence = Get-Content -LiteralPath $evidenceFull -Raw | ConvertFrom-Json
$blocker = Get-Content -LiteralPath $blockerFull -Raw | ConvertFrom-Json
$proof = Get-Content -LiteralPath $proofFull -Raw

if ([string]$evidence.target -ne 'XTIUSD.DWX') { Fail "evidence_target_mismatch" }
if ([string]$evidence.source -ne 'XTIUSD') { Fail "evidence_source_mismatch" }

$targetRange = [int]$evidence.target_probe.rates_range_m1_count
$targetPos = [int]$evidence.target_probe.rates_from_pos_m1_count
$sourceRange = [int]$evidence.source_probe.rates_range_m1_count
$sourcePos = [int]$evidence.source_probe.rates_from_pos_m1_count
$isolatedFailure = [bool]$evidence.isolated_custom_bars_visibility_failure

if ($targetRange -lt 0 -or $targetPos -lt 0 -or $sourceRange -lt 0 -or $sourcePos -lt 0) {
    Fail "evidence_negative_counts"
}

if ($isolatedFailure) {
    if ([string]$blocker.recommended_state -ne 'blocked') { Fail "blocker_state_mismatch" }
    if ([string]$blocker.current_observed.disposition -ne 'defer') { Fail "blocker_disposition_mismatch" }
}

if ($proof -notmatch 'Custom Visibility Probe Rerun') { Fail "proof_heading_missing" }
if ($proof -notmatch [regex]::Escape([string]$evidence.target)) { Fail "proof_target_missing" }

Write-Host ("status=ok isolated_custom_failure={0} target_bars={1}/{2} source_bars={3}/{4}" -f `
    $isolatedFailure, $targetRange, $targetPos, $sourceRange, $sourcePos)
exit 0
