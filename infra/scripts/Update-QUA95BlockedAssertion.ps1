[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$BlockerJson = 'docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json',
    [string]$GateJson = 'docs\ops\QUA-95_GATE_DECISION_2026-04-27.json',
    [string]$OutPath = 'docs\ops\QUA-95_BLOCKED_STATE_ASSERTION_2026-04-27.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$blockerPath = Join-Path $RepoRoot $BlockerJson
$gatePath = Join-Path $RepoRoot $GateJson
$outFull = Join-Path $RepoRoot $OutPath

foreach ($p in @($blockerPath, $gatePath)) {
    if (-not (Test-Path -LiteralPath $p)) {
        throw "Required input missing: $p"
    }
}

$blocker = Get-Content -Raw -LiteralPath $blockerPath | ConvertFrom-Json
$gate = Get-Content -Raw -LiteralPath $gatePath | ConvertFrom-Json

$generatedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
$owner1 = @($blocker.unblock_owners)[0]
$owner2 = @($blocker.unblock_owners)[1]

$md = @"
# QUA-95 Blocked State Assertion (2026-04-27)

Issue: `QUA-95`  
Generated from canonical artifacts at `$generatedAt`.

## Current gate

- `recommended_state=$($gate.recommended_state)`
- `reason=$($gate.reason)`
- `disposition=$($gate.disposition)`
- `bars_got=$($gate.bars_got)`
- `tail_shortfall_seconds=$($gate.tail_shortfall_seconds)`

## Source artifacts

- `docs/ops/QUA-95_GATE_DECISION_2026-04-27.json`
- `docs/ops/QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json`
- `docs/ops/QUA-95_XTIUSD_VERIFIER_HANDOFF_2026-04-27.sha256`

## Unblock owners

1. `$($owner1.owner)`
- $($owner1.required_action)

2. `$($owner2.owner)`
- $($owner2.required_action)
"@

$dir = Split-Path -Parent $outFull
if (-not [string]::IsNullOrWhiteSpace($dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

$md | Set-Content -LiteralPath $outFull -Encoding UTF8
Write-Output ("wrote=" + $outFull)
exit 0
