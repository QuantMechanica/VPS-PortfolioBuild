[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string[]]$Files = @(
        'docs/ops/QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json',
        'docs/ops/QUA-95_GATE_DECISION_2026-04-27.json',
        'docs/ops/QUA-95_ISSUE_TRANSITION_PAYLOAD_2026-04-27.json',
        'docs/ops/QUA-95_BLOCKED_STATE_ASSERTION_2026-04-27.md',
        'docs/ops/QUA-95_UNBLOCK_READINESS_2026-04-27.json',
        'docs/ops/QUA-95_UNBLOCK_READINESS_SUMMARY_2026-04-27.md',
        'docs/ops/QUA-95_BLOCKED_HEARTBEAT_2026-04-27.json',
        'docs/ops/QUA-95_AUTOMATION_HEALTH_2026-04-27.json',
        'docs/ops/QUA-95_AUDIT_SIGNAL_2026-04-27.json',
        'docs/ops/QUA-95_OPS_SUITE_2026-04-27.json',
        'docs/ops/QUA-95_BLOCKED_AUTOMATION_RUNBOOK_2026-04-27.md'
    ),
    [string]$OutPath = 'docs/ops/QUA-95_OPS_BUNDLE_2026-04-27.sha256'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$lines = @()
foreach ($rel in $Files) {
    $full = Join-Path $RepoRoot $rel
    if (-not (Test-Path -LiteralPath $full)) {
        throw "Missing bundle file: $full"
    }
    $h = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLowerInvariant()
    $lines += ("{0}  {1}" -f $h, $rel)
}

$outFull = Join-Path $RepoRoot $OutPath
$outDir = Split-Path -Parent $outFull
if ($outDir) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$lines | Set-Content -LiteralPath $outFull -Encoding ASCII
Write-Output ("wrote=" + $outFull)
exit 0
