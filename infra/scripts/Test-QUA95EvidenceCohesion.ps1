[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$DirectEvidencePath = 'lessons-learned\evidence\2026-04-27_qua95_xtiusd_direct_verify_rerun.json',
    [string]$CustomVisibilityEvidencePath = 'lessons-learned\evidence\2026-04-27_qua95_xtiusd_custom_visibility_probe_rerun.json',
    [string]$BlockerPath = 'docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json',
    [int]$MaxPairSkewMinutes = 20
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    Write-Host $Message
    exit 1
}

function Parse-DateOrFail {
    param(
        [string]$Value,
        [string]$ErrorCode
    )

    $parsed = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse($Value, [ref]$parsed)) {
        Fail $ErrorCode
    }

    return $parsed
}

function Get-JsonPropertyValue {
    param(
        [Parameter(Mandatory=$true)] [object]$Object,
        [Parameter(Mandatory=$true)] [string]$Name
    )

    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    return $prop.Value
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
$customEvidenceFile = Get-Item -LiteralPath $customEvidenceFull

if ([string]$directEvidence.issue -ne 'QUA-95') { Fail 'direct_issue_mismatch' }
if ([string]$directEvidence.symbol -ne 'XTIUSD.DWX') { Fail 'direct_symbol_mismatch' }
if ([string]$customEvidence.target -ne 'XTIUSD.DWX') { Fail 'custom_target_mismatch' }

$directCapturedRaw = [string]$directEvidence.captured_at_local
if ([string]::IsNullOrWhiteSpace($directCapturedRaw)) { Fail 'direct_captured_at_missing' }
$directCaptured = Parse-DateOrFail -Value $directCapturedRaw -ErrorCode 'direct_captured_at_invalid'

$customCapturedRaw = [string](Get-JsonPropertyValue -Object $customEvidence -Name 'captured_at_local')
$customCaptured = [DateTimeOffset]::MinValue
if ([string]::IsNullOrWhiteSpace($customCapturedRaw)) {
    $customCaptured = [DateTimeOffset]::new($customEvidenceFile.LastWriteTimeUtc, [TimeSpan]::Zero)
}
else {
    $customCaptured = Parse-DateOrFail -Value $customCapturedRaw -ErrorCode 'custom_captured_at_invalid'
}

$blockerCheckedRaw = [string]$blocker.last_checked_local
if ([string]::IsNullOrWhiteSpace($blockerCheckedRaw)) { Fail 'blocker_last_checked_missing' }
$blockerChecked = Parse-DateOrFail -Value $blockerCheckedRaw -ErrorCode 'blocker_last_checked_invalid'

$directVsCustom = [math]::Abs(($directCaptured - $customCaptured).TotalMinutes)
$directVsBlocker = [math]::Abs(($directCaptured - $blockerChecked).TotalMinutes)
$customVsBlocker = [math]::Abs(($customCaptured - $blockerChecked).TotalMinutes)
$maxObservedSkew = [math]::Round([math]::Max($directVsCustom, [math]::Max($directVsBlocker, $customVsBlocker)), 2)

if ($directVsCustom -gt $MaxPairSkewMinutes) { Fail ("cohesion_direct_custom_skew_exceeded observed={0} max={1}" -f [math]::Round($directVsCustom,2), $MaxPairSkewMinutes) }
if ($directVsBlocker -gt $MaxPairSkewMinutes) { Fail ("cohesion_direct_blocker_skew_exceeded observed={0} max={1}" -f [math]::Round($directVsBlocker,2), $MaxPairSkewMinutes) }
if ($customVsBlocker -gt $MaxPairSkewMinutes) { Fail ("cohesion_custom_blocker_skew_exceeded observed={0} max={1}" -f [math]::Round($customVsBlocker,2), $MaxPairSkewMinutes) }

Write-Host ("status=ok max_pair_skew_minutes={0} direct_at={1} custom_at={2} blocker_at={3}" -f `
    $maxObservedSkew, `
    $directCaptured.ToString('o'), `
    $customCaptured.ToString('o'), `
    $blockerChecked.ToString('o'))
exit 0
