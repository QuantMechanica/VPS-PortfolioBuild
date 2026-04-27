[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$BlockerJson = 'docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$path = Join-Path $RepoRoot $BlockerJson
if (-not (Test-Path -LiteralPath $path)) {
    throw "Blocker JSON missing: $path"
}

$b = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json

$state = 'blocked'
$reason = 'acceptance_not_met'
if ($b.acceptance -and $b.acceptance.met -eq $true) {
    $state = 'clear'
    $reason = 'acceptance_met'
}

$payload = [ordered]@{
    issue = $b.issue
    recommended_state = $state
    reason = $reason
    disposition = $b.current_observed.disposition
    last_checked_local = $b.last_checked_local
    bars_got = $b.current_observed.bars_got
    tail_shortfall_seconds = $b.current_observed.tail_shortfall_seconds
    unblock_owners = $b.unblock_owners
}

$payload | ConvertTo-Json -Depth 6
if ($state -eq 'clear') { exit 0 } else { exit 3 }
