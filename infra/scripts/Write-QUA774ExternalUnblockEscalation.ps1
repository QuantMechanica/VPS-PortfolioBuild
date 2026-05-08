param(
    [string]$StatusPath = 'docs\ops\QUA-774_BLOCKER_STATUS_2026-05-08.json',
    [string]$ChildPayloadPath = 'docs\ops\QUA-774_EXTERNAL_UNBLOCK_CHILD_PAYLOAD_2026-05-08.json',
    [string]$OutPath = 'docs\ops\QUA-774_EXTERNAL_UNBLOCK_ESCALATION_2026-05-08.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$statusFull = Join-Path $repoRoot $StatusPath
$childFull = Join-Path $repoRoot $ChildPayloadPath
$outFull = Join-Path $repoRoot $OutPath

foreach ($p in @($statusFull, $childFull)) {
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) {
        throw "Required file missing: $p"
    }
}

$status = Get-Content -LiteralPath $statusFull -Raw | ConvertFrom-Json
$owner = $status.unblock.owner
$actions = @($status.unblock.required_action | ForEach-Object { (([string]$_) -replace '\s+', ' ').Trim() })
$failureFlags = @($status.gate.failure_flags)

$lines = @(
    '# QUA-774 External Unblock Escalation (2026-05-08)',
    '',
    "Issue remains blocked: $($status.gate.status)",
    "Failure flags: $([string]::Join(';', $failureFlags))",
    '',
    "Unblock owner: $owner",
    '',
    'Required unblock actions:'
)

for ($i = 0; $i -lt $actions.Count; $i++) {
    $lines += ('{0}. {1}' -f ($i + 1), $actions[$i])
}

$lines += @(
    '',
    'Child issue payload artifact:',
    "- $ChildPayloadPath",
    '',
    'Resume contract:',
    '- Update `docs/ops/QUA-774_EXTERNAL_UNBLOCK_SIGNAL.json` to `ready_to_resume=true` only after all external acceptance criteria are met.'
)

Set-Content -LiteralPath $outFull -Value ($lines -join [Environment]::NewLine) -Encoding UTF8

[pscustomobject]@{
    output_path = $OutPath
    issue_id = $status.issue_id
    gate_status = $status.gate.status
    unblock_owner = $owner
}
