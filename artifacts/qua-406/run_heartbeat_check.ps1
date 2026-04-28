param(
  [string]$RepoRoot = "C:\QM\worktrees\development"
)

$readinessScript = Join-Path $RepoRoot "artifacts\qua-406\check_src04_s07_readiness.ps1"
$jsonPath = Join-Path $RepoRoot "docs\ops\QUA-406_READINESS_CHECK_2026-04-28.json"
$mdPath = Join-Path $RepoRoot "docs\ops\QUA-406_HEARTBEAT_STATUS_2026-04-28.md"

if (-not (Test-Path $readinessScript)) {
  throw "Missing readiness script: $readinessScript"
}

$json = & $readinessScript -RepoRoot $RepoRoot | ConvertFrom-Json
$json | ConvertTo-Json -Depth 8 | Set-Content -Path $jsonPath -Encoding UTF8

$md = @(
  "# QUA-406 Heartbeat Status (auto)"
  ""
  "- checked_at_utc: $($json.checked_at_utc)"
  "- strategy_id: $($json.strategy_id)"
  "- card_status: $($json.card.status)"
  "- card_ea_id: $($json.card.ea_id)"
  "- registry_row_found: $($json.registry.row_found)"
  "- manifest_exists: $($json.manifest.exists)"
  "- ready_for_implementation: $($json.ready_for_implementation)"
)

$md -join "`r`n" | Set-Content -Path $mdPath -Encoding UTF8

Write-Output "Wrote:"
Write-Output $jsonPath
Write-Output $mdPath
