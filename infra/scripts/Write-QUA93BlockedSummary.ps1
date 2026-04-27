[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$BlockerJson = 'docs\ops\QUA-93_XAUUSD_BLOCKER_STATUS_2026-04-27.json',
    [string]$OutPath = 'docs\ops\QUA-93_BLOCKED_COMMENT_2026-04-27.md'
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
$lines += ("- Parent: {0}" -f $data.parent_issue)
$lines += ("- Symbol: {0}" -f $data.current_observed.symbol)
$lines += ("- Verdict: {0}" -f $data.current_observed.verdict)
$lines += ("- bars_got: {0}" -f $data.current_observed.bars_got)
$lines += ("- tail_shortfall_seconds: {0}" -f $data.current_observed.tail_shortfall_seconds)
$lines += ("- acceptance_met: {0}" -f $data.acceptance.met)
$lines += ("- last_checked_local: {0}" -f $data.last_checked_local)
$lines += ("- last_evidence_path: {0}" -f $data.last_evidence_path)
$lines += ""
$lines += "Unblock owners:"
foreach ($owner in $data.unblock_owners) {
    $lines += ("- {0}: {1}" -f $owner.owner, $owner.required_action)
}
$lines += ""
$lines += "Handoff artifacts:"
$lines += ("- investigation: {0}" -f $data.handoff_artifacts.investigation_markdown)
$lines += ("- rerun evidence: {0}" -f $data.handoff_artifacts.rerun_evidence_json)
$lines += ("- tail alignment: {0}" -f $data.handoff_artifacts.csv_tail_alignment_json)
$lines += ("- desktop nudge evidence: {0}" -f $data.handoff_artifacts.csv_mismatch_nudge_json)

$lines | Set-Content -LiteralPath $outFull -Encoding UTF8
Write-Host ("wrote={0}" -f $outFull)
