param(
    [string]$StatusJsonPath = 'docs\ops\QUA-774_DEVOPS_STATUS_2026-05-08.json',
    [string]$OutMarkdownPath = 'docs\ops\QUA-774_STATUS_SUMMARY_2026-05-08.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$statusFull = Join-Path $repoRoot $StatusJsonPath
$outFull = Join-Path $repoRoot $OutMarkdownPath

if (-not (Test-Path -LiteralPath $statusFull -PathType Leaf)) {
    throw "Status JSON missing: $statusFull"
}

$s = Get-Content -LiteralPath $statusFull -Raw -Encoding UTF8 | ConvertFrom-Json

$flags = @($s.failure_flags | ForEach-Object { [string]$_ })
$actions = @($s.unblock_action | ForEach-Object { [string]$_ })

$lines = @(
    "# QUA-774 Status Summary",
    "",
    "- issue: $($s.issue_id)",
    "- devops_state: $($s.devops_state)",
    "- gate_state: $($s.gate_state)",
    "- failure_flags: $($flags -join ';')",
    "- unblock_owner: $($s.unblock_owner)",
    "- evidence_summary: $($s.canonical_evidence.summary_current)",
    "",
    "## Required Unblock Action",
    "1. $($actions[0])",
    "2. $($actions[1])",
    "3. $($actions[2])",
    "4. $($actions[3])"
)

$outDir = Split-Path -Parent $outFull
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

Set-Content -LiteralPath $outFull -Value ($lines -join "`n") -Encoding UTF8
$outFull
