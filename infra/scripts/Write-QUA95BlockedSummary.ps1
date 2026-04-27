[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$BlockerJson = 'docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json',
    [string]$OutPath = 'docs\ops\QUA-95_BLOCKED_COMMENT_2026-04-27.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$jsonPath = Join-Path $RepoRoot $BlockerJson
if (-not (Test-Path -LiteralPath $jsonPath)) {
    throw "Blocker JSON not found: $jsonPath"
}

$data = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
$outFull = Join-Path $RepoRoot $OutPath
$outDir = Split-Path -Parent $outFull
if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$lines = @()
$lines += ("Status: **{0}** (`{1}`)" -f $data.recommended_state, $data.current_observed.disposition)
$lines += ""
$lines += ("- Issue: {0}" -f $data.issue)
$lines += ("- Symbol: {0}" -f $data.current_observed.symbol)
$lines += ("- Verdict: {0}" -f $data.current_observed.verdict)
$lines += ("- bars_got: {0}" -f $data.current_observed.bars_got)
$lines += ("- tail_shortfall_seconds: {0}" -f $data.current_observed.tail_shortfall_seconds)
$lines += ""
$lines += "Unblock owners:"
foreach ($owner in $data.unblock_owners) {
    $lines += ("- {0}: {1}" -f $owner.owner, $owner.required_action)
}
$lines += ""
$lines += "Handoff artifacts:"
$lines += ("- {0}" -f $data.handoff_package.markdown)
$lines += ("- {0}" -f $data.handoff_package.json)
$lines += ("- {0}" -f $data.handoff_package.sha256)

$lines | Set-Content -LiteralPath $outFull -Encoding UTF8
Write-Host ("wrote={0}" -f $outFull)
