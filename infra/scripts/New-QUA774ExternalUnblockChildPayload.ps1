param(
    [string]$OutPath = 'docs\ops\QUA-774_EXTERNAL_UNBLOCK_CHILD_PAYLOAD_2026-05-08.json',
    [string]$IssueId = 'QUA-774'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$outFull = Join-Path $repoRoot $OutPath
$outDir = Split-Path -Parent $outFull
if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$payload = [ordered]@{
    parent_issue_id = $IssueId
    child_issue_recommendation = [ordered]@{
        title = 'QUA-774 external unblock: US500.DWX import/sync + P2 rerun evidence'
        owner_role = 'DWX source acquisition + import pipeline owner'
        priority = 'high'
        status = 'todo'
        unblock_required_for = $IssueId
        acceptance_criteria = @(
            'US500.DWX imported on T1 with non-empty history/ticks',
            'US500.DWX synced from T1 to T2..T5',
            'QM5_1004 P2 rerun completed with H1/H4/D1 reports present',
            'Evidence paths attached for import/sync and P2 report outputs'
        )
        required_artifacts = @(
            'Evidence proving US500.DWX availability on T1..T5',
            'P2 redeploy report files for H1/H4/D1',
            'Timestamped execution log for import and rerun actions'
        )
        external_signal_update = [ordered]@{
            file = 'docs/ops/QUA-774_EXTERNAL_UNBLOCK_SIGNAL.json'
            set_ready_to_resume = $true
            note = 'Set only after all acceptance criteria are met.'
        }
    }
}

$json = $payload | ConvertTo-Json -Depth 8
$shouldWrite = $true
if (Test-Path -LiteralPath $outFull -PathType Leaf) {
    $existing = Get-Content -LiteralPath $outFull -Raw
    $existingNormalized = $existing.TrimEnd("`r", "`n")
    $jsonNormalized = $json.TrimEnd("`r", "`n")
    if ($existingNormalized -eq $jsonNormalized) {
        $shouldWrite = $false
    }
}
if ($shouldWrite) {
    Set-Content -LiteralPath $outFull -Value $json -Encoding UTF8
}

[pscustomobject]@{
    issue_id = $IssueId
    output_path = $OutPath
    child_issue_title = $payload.child_issue_recommendation.title
    written = $shouldWrite
}
