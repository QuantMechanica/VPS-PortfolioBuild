[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$BlockerJson = 'docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json',
    [string]$CustomVisibilityEvidenceJson = 'lessons-learned\evidence\2026-04-27_qua95_xtiusd_custom_visibility_probe_rerun.json',
    [string]$OutPath = '',
    [switch]$NoFail
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$path = Join-Path $RepoRoot $BlockerJson
if (-not (Test-Path -LiteralPath $path)) {
    throw "Blocker JSON missing: $path"
}

$b = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
$customPath = Join-Path $RepoRoot $CustomVisibilityEvidenceJson

$runtimeVisibilityRecovered = $false
if (Test-Path -LiteralPath $customPath) {
    try {
        $custom = Get-Content -Raw -LiteralPath $customPath | ConvertFrom-Json
        $targetRange = [int]$custom.target_probe.rates_range_m1_count
        $targetPos = [int]$custom.target_probe.rates_from_pos_m1_count
        $targetBarsVisible = ($targetRange -gt 0 -or $targetPos -gt 0)
        $isolatedFailure = [bool]$custom.isolated_custom_bars_visibility_failure
        $runtimeVisibilityRecovered = ($targetBarsVisible -and -not $isolatedFailure)
    } catch {}
}

$state = 'blocked'
$reason = 'acceptance_not_met'
if ($b.acceptance -and $b.acceptance.met -eq $true) {
    $state = 'clear'
    $reason = 'acceptance_met'
}

$effectiveOwners = @($b.unblock_owners)
if ($runtimeVisibilityRecovered) {
    $effectiveOwners = @($effectiveOwners | Where-Object { [string]$_.owner -ne 'runtime_custom_symbol_owner' })
}

$payload = [ordered]@{
    issue = $b.issue
    recommended_state = $state
    reason = $reason
    disposition = $b.current_observed.disposition
    last_checked_local = $b.last_checked_local
    bars_got = $b.current_observed.bars_got
    tail_shortfall_seconds = $b.current_observed.tail_shortfall_seconds
    runtime_visibility_recovered = $runtimeVisibilityRecovered
    unblock_owners = $effectiveOwners
}

$json = $payload | ConvertTo-Json -Depth 6
if (-not [string]::IsNullOrWhiteSpace($OutPath)) {
    $target = Join-Path $RepoRoot $OutPath
    $dir = Split-Path -Parent $target
    if ($dir) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $json | Set-Content -LiteralPath $target -Encoding UTF8
} else {
    $json
}

if ($NoFail.IsPresent) { exit 0 }
if ($state -eq 'clear') { exit 0 } else { exit 3 }
