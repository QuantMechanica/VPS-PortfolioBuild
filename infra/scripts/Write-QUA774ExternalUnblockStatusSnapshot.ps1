param(
    [string]$HandoffScript = 'infra\scripts\Invoke-QUA774ExternalUnblockHandoff.ps1',
    [string]$OutputPath = 'docs\ops\QUA-774_EXTERNAL_UNBLOCK_STATUS_2026-05-08.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$handoffFull = Join-Path $repoRoot $HandoffScript
$outputFull = Join-Path $repoRoot $OutputPath

if (-not (Test-Path -LiteralPath $handoffFull -PathType Leaf)) {
    throw "Handoff script missing: $handoffFull"
}

$bundle = & $handoffFull

$snapshot = [pscustomobject]@{
    issue_id = 'QUA-774'
    blocked = $true
    ready_to_resume = [bool]$bundle.signal_check.ready_to_resume
    signal_status = $bundle.signal_check.status
    signal_reason = $bundle.signal_check.reason
    package_status = $bundle.package_check.status
    handoff_skipped = [bool]$bundle.skipped
    handoff_skip_reason = $bundle.reason
    signal_fingerprint = $bundle.signal_fingerprint
    probe_cache_path = $bundle.probe_cache_path
    unblock_owner = $bundle.signal_check.unblock_owner
    unblock_action = $bundle.signal_check.unblock_action
    required_external_actions = @(
        'Import/sync US500.DWX on T1..T5'
        'Rerun QM5_1004 P2 with H1/H4/D1 reports'
        'Set QUA-774_EXTERNAL_UNBLOCK_SIGNAL.json ready_to_resume=true'
    )
}

$outDir = Split-Path -Parent $outputFull
if (-not [string]::IsNullOrWhiteSpace($outDir) -and -not (Test-Path -LiteralPath $outDir -PathType Container)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$nextJson = $snapshot | ConvertTo-Json -Depth 8
$write = $true
if (Test-Path -LiteralPath $outputFull -PathType Leaf) {
    $existingJson = Get-Content -LiteralPath $outputFull -Raw
    if ($existingJson.TrimEnd("`r","`n") -eq $nextJson.TrimEnd("`r","`n")) {
        $write = $false
    }
}

if ($write) {
    $nextJson | Set-Content -LiteralPath $outputFull -Encoding UTF8
}

[pscustomobject]@{
    issue_id = 'QUA-774'
    output_path = $OutputPath
    written = $write
    ready_to_resume = $snapshot.ready_to_resume
    signal_status = $snapshot.signal_status
    package_status = $snapshot.package_status
    handoff_skipped = $snapshot.handoff_skipped
}
