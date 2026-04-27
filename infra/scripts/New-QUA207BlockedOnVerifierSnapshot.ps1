[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$CustomVisibilityEvidencePath = 'lessons-learned\evidence\2026-04-27_qua95_xtiusd_custom_visibility_probe_rerun.json',
    [string]$TransitionPayloadPath = 'docs\ops\QUA-207_ISSUE_TRANSITION_PAYLOAD_2026-04-27.json',
    [string]$OutPath = 'docs\ops\QUA-207_BLOCKED_ON_VERIFIER_2026-04-27.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$customFull = Join-Path $RepoRoot $CustomVisibilityEvidencePath
$transitionFull = Join-Path $RepoRoot $TransitionPayloadPath
$outFull = Join-Path $RepoRoot $OutPath

foreach ($p in @($customFull, $transitionFull)) {
    if (-not (Test-Path -LiteralPath $p)) {
        throw "Required input missing: $p"
    }
}

$custom = Get-Content -LiteralPath $customFull -Raw | ConvertFrom-Json
$transition = Get-Content -LiteralPath $transitionFull -Raw | ConvertFrom-Json

$targetPos = [int]$custom.target_probe.rates_from_pos_m1_count
$isolatedFailure = [bool]$custom.isolated_custom_bars_visibility_failure
$runtimeCompleted = ($targetPos -gt 0 -and -not $isolatedFailure)

$payload = [ordered]@{
    issue = 'QUA-207'
    generated_at_local = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
    status = 'blocked'
    reason = 'runtime_scope_completed_waiting_on_verifier_owner'
    runtime_owner_scope = [ordered]@{
        owner = 'runtime_custom_symbol_owner'
        state = if ($runtimeCompleted) { 'completed' } else { 'pending' }
        evidence = $CustomVisibilityEvidencePath
        target_rates_from_pos_m1_count = $targetPos
        isolated_custom_bars_visibility_failure = $isolatedFailure
    }
    unblock_owner = [ordered]@{
        owner = 'verifier_implementation_owner'
        required_action = 'Rerun/fix verifier acceptance path for XTIUSD.DWX until bars_got > 0 and tail is aligned.'
    }
    transition_state = [ordered]@{
        recommended_status = $transition.recommended_transition.status
        next_owner = $transition.handoff.next_owner
    }
    next_action_after_unblock = 'Refresh QUA-95 transition/readiness chain and advance QUA-207 per board policy.'
}

$outDir = Split-Path -Parent $outFull
if (-not [string]::IsNullOrWhiteSpace($outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outFull -Encoding UTF8
Write-Host ("wrote={0}" -f $outFull)
Write-Host ("runtime_completed={0}" -f $runtimeCompleted)
exit 0
