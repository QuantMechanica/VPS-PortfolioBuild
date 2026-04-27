[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$CustomVisibilityEvidencePath = 'lessons-learned\evidence\2026-04-27_qua95_xtiusd_custom_visibility_probe_rerun.json',
    [string]$OutPath = 'docs\ops\QUA-207_ISSUE_TRANSITION_PAYLOAD_2026-04-27.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$customFull = Join-Path $RepoRoot $CustomVisibilityEvidencePath
$outFull = Join-Path $RepoRoot $OutPath

if (-not (Test-Path -LiteralPath $customFull)) {
    throw "Custom visibility evidence missing: $customFull"
}

$custom = Get-Content -LiteralPath $customFull -Raw | ConvertFrom-Json
$targetRange = [int]$custom.target_probe.rates_range_m1_count
$targetPos = [int]$custom.target_probe.rates_from_pos_m1_count
$targetBarsVisible = ($targetRange -gt 0 -or $targetPos -gt 0)
$isolatedFailure = [bool]$custom.isolated_custom_bars_visibility_failure
$runtimeCompleted = ($targetBarsVisible -and -not $isolatedFailure)

$status = if ($runtimeCompleted) { 'in_review' } else { 'blocked' }
$reason = if ($runtimeCompleted) { 'runtime_owner_scope_completed' } else { 'runtime_visibility_not_restored' }

$payload = [ordered]@{
    issue = 'QUA-207'
    generated_at_local = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
    recommended_transition = [ordered]@{
        status = $status
        reason = $reason
        resume = $true
    }
    objective = 'Restore MT5 custom symbol bars visibility for XTIUSD.DWX'
    completion_evidence = [ordered]@{
        custom_visibility_probe_json = $CustomVisibilityEvidencePath
        target_rates_range_m1_count = $targetRange
        target_rates_from_pos_m1_count = $targetPos
        isolated_custom_bars_visibility_failure = $isolatedFailure
    }
    owner_state = [ordered]@{
        runtime_custom_symbol_owner = if ($runtimeCompleted) { 'completed' } else { 'pending' }
        verifier_implementation_owner = if ($runtimeCompleted) { 'pending' } else { 'blocked_by_runtime' }
    }
    handoff = [ordered]@{
        next_owner = if ($runtimeCompleted) { 'verifier_implementation_owner' } else { 'runtime_custom_symbol_owner' }
        next_action = if ($runtimeCompleted) {
            'Rerun/fix verifier acceptance path for XTIUSD.DWX (bars_got > 0 and tail aligned), then rerun transition chain.'
        } else {
            'Restore runtime custom-symbol bars visibility and rerun custom visibility proof.'
        }
    }
    supporting_docs = @(
        'docs/ops/QUA-207_CLOSEOUT_PACKET_2026-04-27.md',
        'docs/ops/QUA-207_RUNTIME_OWNER_COMPLETION_2026-04-27.md',
        'docs/ops/QUA-207_RUNTIME_COMPLETION_CHECK_2026-04-27.md',
        'docs/ops/QUA-207_REIMPORT_REPAIR_XTIUSD_2026-04-27.md'
    )
}

$outDir = Split-Path -Parent $outFull
if (-not [string]::IsNullOrWhiteSpace($outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outFull -Encoding UTF8
Write-Host ("wrote={0}" -f $outFull)
Write-Host ("recommended_status={0}" -f $status)
Write-Host ("runtime_completed={0}" -f $runtimeCompleted)
exit 0
