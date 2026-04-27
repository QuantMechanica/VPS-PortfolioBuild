[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$EvidencePath = 'lessons-learned\evidence\2026-04-27_qua95_xtiusd_direct_verify_rerun.json',
    [string]$ProofPath = 'docs\ops\QUA-95_DIRECT_VERIFIER_RERUN_2026-04-27.md',
    [string]$BlockerPath = 'docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json',
    [int]$MaxEvidenceAgeMinutes = 240
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

if ([string]$evidence.issue -ne 'QUA-95') { Fail "evidence_issue_mismatch" }
if ([string]$evidence.symbol -ne 'XTIUSD.DWX') { Fail "evidence_symbol_mismatch" }

$capturedAtRaw = [string]$evidence.captured_at_local
if ([string]::IsNullOrWhiteSpace($capturedAtRaw)) { Fail "evidence_captured_at_missing" }

$capturedAt = [DateTimeOffset]::MinValue
if (-not [DateTimeOffset]::TryParse($capturedAtRaw, [ref]$capturedAt)) {
    Fail "evidence_captured_at_invalid"
}

$evidenceAgeMinutes = [math]::Floor(((Get-Date).ToUniversalTime() - $capturedAt.UtcDateTime).TotalMinutes)
if ($evidenceAgeMinutes -lt 0) { Fail "evidence_captured_at_in_future" }
if ($evidenceAgeMinutes -gt $MaxEvidenceAgeMinutes) {
    Fail ("evidence_too_old age_minutes={0} max_minutes={1}" -f $evidenceAgeMinutes, $MaxEvidenceAgeMinutes)
}

$verifyExit = [int]$evidence.verify_exit_code
$barsOneShot = [int]$evidence.bars_one_shot
$barsChunked = [int]$evidence.bars_chunked
$recommended = [string]$evidence.recommended_state
$disposition = [string]$evidence.disposition

if ($barsOneShot -le 0 -and $recommended -ne 'blocked') { Fail "evidence_recommended_state_mismatch" }
if ($barsChunked -le 0 -and $disposition -ne 'defer') { Fail "evidence_disposition_mismatch" }

if ([string]$blocker.recommended_state -ne $recommended) { Fail "blocker_recommended_state_mismatch" }
if ([string]$blocker.current_observed.disposition -ne $disposition) { Fail "blocker_disposition_mismatch" }

if ($proof -notmatch 'Direct Verifier Rerun Proof') { Fail "proof_heading_missing" }
if ($proof -notmatch [regex]::Escape([string]$evidence.symbol)) { Fail "proof_symbol_missing" }

Write-Host ("status=ok verify_exit_code={0} bars_one_shot={1} bars_chunked={2} disposition={3}" -f `
    $verifyExit, $barsOneShot, $barsChunked, $disposition)
exit 0
