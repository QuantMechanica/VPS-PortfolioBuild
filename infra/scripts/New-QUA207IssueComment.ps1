[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$TransitionPayloadPath = 'docs\ops\QUA-207_ISSUE_TRANSITION_PAYLOAD_2026-04-27.json',
    [string]$CustomVisibilityEvidencePath = 'lessons-learned\evidence\2026-04-27_qua95_xtiusd_custom_visibility_probe_rerun.json',
    [string]$OutPath = 'docs\ops\QUA-207_ISSUE_COMMENT_2026-04-27.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$transitionFull = Join-Path $RepoRoot $TransitionPayloadPath
$customFull = Join-Path $RepoRoot $CustomVisibilityEvidencePath
$outFull = Join-Path $RepoRoot $OutPath

foreach ($p in @($transitionFull, $customFull)) {
    if (-not (Test-Path -LiteralPath $p)) {
        throw "Required input missing: $p"
    }
}

$transition = Get-Content -LiteralPath $transitionFull -Raw | ConvertFrom-Json
$custom = Get-Content -LiteralPath $customFull -Raw | ConvertFrom-Json

$targetRange = [int]$custom.target_probe.rates_range_m1_count
$targetPos = [int]$custom.target_probe.rates_from_pos_m1_count
$isolatedFailure = [bool]$custom.isolated_custom_bars_visibility_failure
$statusValue = [string]$transition.recommended_transition.status
$statusLine = switch ($statusValue) {
    'done' { 'closure recommended (resolved via upstream DEVOPS-004 family final pass)' ; break }
    'in_review' { 'runtime owner scope completed (ready for review)' ; break }
    default { 'runtime restore still in progress' ; break }
}
$nextOwner = [string]$transition.handoff.next_owner
$nextAction = [string]$transition.handoff.next_action

$lines = @(
    ('## Status: {0}' -f $statusLine),
    '',
    '- Runtime visibility evidence refreshed for `XTIUSD.DWX`.',
    ('- `target rates_range_m1_count={0}`' -f $targetRange),
    ('- `target rates_from_pos_m1_count={0}`' -f $targetPos),
    ('- `isolated_custom_bars_visibility_failure={0}`' -f $isolatedFailure),
    ('- Recommended transition status: `{0}`' -f $statusValue),
    ('- Remaining owner: `{0}`' -f $nextOwner),
    ('- Next action: {0}' -f $nextAction),
    '',
    '### Links',
    '',
    ('- `{0}`' -f $CustomVisibilityEvidencePath),
    ('- `{0}`' -f $TransitionPayloadPath),
    '- `docs/ops/QUA-207_CLOSEOUT_PACKET_2026-04-27.md`',
    '- `docs/ops/QUA-207_RUNTIME_COMPLETION_CHECK_2026-04-27.md`'
)

$outDir = Split-Path -Parent $outFull
if (-not [string]::IsNullOrWhiteSpace($outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$lines -join [Environment]::NewLine | Set-Content -LiteralPath $outFull -Encoding UTF8
Write-Host ("wrote={0}" -f $outFull)
Write-Host ("recommended_status={0}" -f $transition.recommended_transition.status)
exit 0
