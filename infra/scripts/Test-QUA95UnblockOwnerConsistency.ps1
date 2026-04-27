[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$ReadinessPath = 'docs\ops\QUA-95_UNBLOCK_READINESS_2026-04-27.json',
    [string]$GateDecisionPath = 'docs\ops\QUA-95_GATE_DECISION_2026-04-27.json',
    [string]$TransitionPayloadPath = 'docs\ops\QUA-95_ISSUE_TRANSITION_PAYLOAD_2026-04-27.json',
    [string]$SummaryPath = 'docs\ops\QUA-95_UNBLOCK_READINESS_SUMMARY_2026-04-27.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    Write-Host $Message
    exit 1
}

function Normalize-Owners($Owners) {
    return @(
        @($Owners | ForEach-Object {
            if (-not $_.owner -or -not $_.required_action) {
                throw "owner_or_action_missing"
            }
            ("{0}|{1}" -f ([string]$_.owner).Trim(), ([string]$_.required_action).Trim())
        }) | Sort-Object
    )
}

$readinessFull = Join-Path $RepoRoot $ReadinessPath
$gateFull = Join-Path $RepoRoot $GateDecisionPath
$transitionFull = Join-Path $RepoRoot $TransitionPayloadPath
$summaryFull = Join-Path $RepoRoot $SummaryPath

foreach ($path in @($readinessFull, $gateFull, $transitionFull, $summaryFull)) {
    if (-not (Test-Path -LiteralPath $path)) {
        Fail ("missing_file=" + $path)
    }
}

$readiness = Get-Content -LiteralPath $readinessFull -Raw | ConvertFrom-Json
$gate = Get-Content -LiteralPath $gateFull -Raw | ConvertFrom-Json
$transition = Get-Content -LiteralPath $transitionFull -Raw | ConvertFrom-Json
$summary = Get-Content -LiteralPath $summaryFull -Raw

$readinessOwners = Normalize-Owners $readiness.unblock_owners
$gateOwners = Normalize-Owners $gate.unblock_owners
$transitionOwners = Normalize-Owners $transition.unblock_owners

if (@($readinessOwners).Count -eq 0) { Fail 'owners_empty_readiness' }
if (@(Compare-Object -ReferenceObject $readinessOwners -DifferenceObject $gateOwners).Count -gt 0) {
    Fail 'owners_mismatch_readiness_vs_gate'
}
if (@(Compare-Object -ReferenceObject $readinessOwners -DifferenceObject $transitionOwners).Count -gt 0) {
    Fail 'owners_mismatch_readiness_vs_transition'
}

foreach ($ownerEntry in $readiness.unblock_owners) {
    $owner = [string]$ownerEntry.owner
    $action = [string]$ownerEntry.required_action
    if ($summary -notmatch [regex]::Escape($owner)) { Fail ("summary_owner_missing={0}" -f $owner) }
    if ($summary -notmatch [regex]::Escape($action)) { Fail ("summary_action_missing_for_owner={0}" -f $owner) }
}

Write-Host ("status=ok owner_count={0} owners={1}" -f `
    @($readinessOwners).Count, `
    ((@($readiness.unblock_owners | ForEach-Object { [string]$_.owner })) -join ','))
exit 0
