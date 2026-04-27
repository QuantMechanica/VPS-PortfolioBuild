[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$CustomVisibilityEvidencePath = 'lessons-learned\evidence\2026-04-27_qua95_xtiusd_custom_visibility_probe_rerun.json',
    [string]$GateDecisionPath = 'docs\ops\QUA-95_GATE_DECISION_2026-04-27.json',
    [string]$TransitionPayloadPath = 'docs\ops\QUA-95_ISSUE_TRANSITION_PAYLOAD_2026-04-27.json',
    [string]$ReadinessPath = 'docs\ops\QUA-95_UNBLOCK_READINESS_2026-04-27.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    Write-Host $Message
    exit 1
}

function OwnerNames([object]$Owners) {
    return @(@($Owners) | ForEach-Object { [string]$_.owner })
}

$customFull = Join-Path $RepoRoot $CustomVisibilityEvidencePath
$gateFull = Join-Path $RepoRoot $GateDecisionPath
$transitionFull = Join-Path $RepoRoot $TransitionPayloadPath
$readinessFull = Join-Path $RepoRoot $ReadinessPath

foreach ($p in @($customFull, $gateFull, $transitionFull, $readinessFull)) {
    if (-not (Test-Path -LiteralPath $p)) {
        Fail ("missing_file={0}" -f $p)
    }
}

$custom = Get-Content -LiteralPath $customFull -Raw | ConvertFrom-Json
$gate = Get-Content -LiteralPath $gateFull -Raw | ConvertFrom-Json
$transition = Get-Content -LiteralPath $transitionFull -Raw | ConvertFrom-Json
$readiness = Get-Content -LiteralPath $readinessFull -Raw | ConvertFrom-Json

$targetRange = [int]$custom.target_probe.rates_range_m1_count
$targetPos = [int]$custom.target_probe.rates_from_pos_m1_count
$targetBarsVisible = ($targetRange -gt 0 -or $targetPos -gt 0)
$isolatedFailure = [bool]$custom.isolated_custom_bars_visibility_failure

if (-not $targetBarsVisible) {
    Fail ("target_bars_not_visible range={0} pos={1}" -f $targetRange, $targetPos)
}
if ($isolatedFailure) {
    Fail 'isolated_custom_failure_still_true'
}

if ($null -eq $gate.runtime_visibility_recovered -or -not [bool]$gate.runtime_visibility_recovered) {
    Fail 'gate_runtime_visibility_recovered_not_true'
}

$gateOwners = OwnerNames $gate.unblock_owners
$transitionOwners = OwnerNames $transition.unblock_owners
$readinessOwners = OwnerNames $readiness.unblock_owners

foreach ($ownerSet in @($gateOwners, $transitionOwners, $readinessOwners)) {
    if ($ownerSet -contains 'runtime_custom_symbol_owner') {
        Fail 'runtime_owner_still_present'
    }
}

if (-not ($gateOwners -contains 'verifier_implementation_owner')) {
    Fail 'verifier_owner_missing_in_gate'
}
if (-not ($transitionOwners -contains 'verifier_implementation_owner')) {
    Fail 'verifier_owner_missing_in_transition'
}
if (-not ($readinessOwners -contains 'verifier_implementation_owner')) {
    Fail 'verifier_owner_missing_in_readiness'
}

Write-Host ("status=ok target_range={0} target_pos={1} isolated_custom_failure={2} owners={3}" -f `
    $targetRange, `
    $targetPos, `
    $isolatedFailure, `
    ($gateOwners -join ','))
exit 0
