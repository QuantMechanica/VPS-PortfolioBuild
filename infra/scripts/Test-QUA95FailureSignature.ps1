[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$DirectEvidencePath = 'lessons-learned\evidence\2026-04-27_qua95_xtiusd_direct_verify_rerun.json',
    [string]$CustomVisibilityEvidencePath = 'lessons-learned\evidence\2026-04-27_qua95_xtiusd_custom_visibility_probe_rerun.json',
    [string]$BlockerPath = 'docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    Write-Host $Message
    exit 1
}

$directEvidenceFull = Join-Path $RepoRoot $DirectEvidencePath
$customEvidenceFull = Join-Path $RepoRoot $CustomVisibilityEvidencePath
$blockerFull = Join-Path $RepoRoot $BlockerPath

foreach ($path in @($directEvidenceFull, $customEvidenceFull, $blockerFull)) {
    if (-not (Test-Path -LiteralPath $path)) {
        Fail ("missing_file=" + $path)
    }
}

$directEvidence = Get-Content -LiteralPath $directEvidenceFull -Raw | ConvertFrom-Json
$customEvidence = Get-Content -LiteralPath $customEvidenceFull -Raw | ConvertFrom-Json
$blocker = Get-Content -LiteralPath $blockerFull -Raw | ConvertFrom-Json

if ([string]$directEvidence.issue -ne 'QUA-95') { Fail 'direct_issue_mismatch' }
if ([string]$directEvidence.symbol -ne 'XTIUSD.DWX') { Fail 'direct_symbol_mismatch' }
if ([string]$customEvidence.target -ne 'XTIUSD.DWX') { Fail 'custom_target_mismatch' }
if ([string]$customEvidence.source -ne 'XTIUSD') { Fail 'custom_source_mismatch' }

$recommendedState = [string]$blocker.recommended_state
$disposition = [string]$blocker.current_observed.disposition
$barsGot = [int]$blocker.current_observed.bars_got

if ($recommendedState -ne 'blocked') {
    Write-Host ("status=ok signature_check=skipped blocker_state={0} disposition={1} bars_got={2}" -f $recommendedState, $disposition, $barsGot)
    exit 0
}

$midTicks = [int]$directEvidence.mid_ticks_5min
$barsOneShot = [int]$directEvidence.bars_one_shot
$barsChunked = [int]$directEvidence.bars_chunked
$isolatedFailure = [bool]$customEvidence.isolated_custom_bars_visibility_failure
$targetBarsRange = [int]$customEvidence.target_probe.rates_range_m1_count
$sourceBarsRange = [int]$customEvidence.source_probe.rates_range_m1_count

if ($midTicks -le 0) { Fail 'signature_mid_ticks_nonpositive' }
if ($barsOneShot -gt 0) { Fail 'signature_bars_one_shot_positive' }
if ($barsChunked -gt 0) { Fail 'signature_bars_chunked_positive' }
if (-not $isolatedFailure) { Fail 'signature_isolated_custom_failure_false' }
if ($targetBarsRange -gt 0) { Fail 'signature_target_bars_positive' }
if ($sourceBarsRange -le 0) { Fail 'signature_source_bars_nonpositive' }
if ($disposition -ne 'defer') { Fail 'signature_disposition_not_defer' }
if ($barsGot -gt 0) { Fail 'signature_blocker_bars_positive' }

Write-Host ("status=ok signature=blocked_systemic mid_ticks={0} bars_one_shot={1} bars_chunked={2} target_bars={3} source_bars={4}" -f `
    $midTicks, $barsOneShot, $barsChunked, $targetBarsRange, $sourceBarsRange)
exit 0
