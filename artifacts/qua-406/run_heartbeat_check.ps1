param(
  [string]$RepoRoot = "C:\QM\worktrees\development"
)

$readinessScript = Join-Path $RepoRoot "artifacts\qua-406\check_src04_s07_readiness.ps1"
$jsonPath = Join-Path $RepoRoot "docs\ops\QUA-406_READINESS_CHECK_2026-04-28.json"
$mdPath = Join-Path $RepoRoot "docs\ops\QUA-406_HEARTBEAT_STATUS_2026-04-28.md"

if (-not (Test-Path $readinessScript)) {
  throw "Missing readiness script: $readinessScript"
}

$raw = & $readinessScript -RepoRoot $RepoRoot
$rawText = ($raw -join "`n")
$json = $rawText | ConvertFrom-Json
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($jsonPath, $rawText, $utf8NoBom)
$checkedAt = [regex]::Match($rawText, '"checked_at_utc"\s*:\s*"([^"]+)"').Groups[1].Value

$md = @(
  "# QUA-406 Heartbeat Status (auto)"
  ""
  "- checked_at_utc: $checkedAt"
  "- strategy_id: $($json.strategy_id)"
  "- card_status: $($json.card.status)"
  "- card_ea_id: $($json.card.ea_id)"
  "- registry_row_found: $($json.registry.row_found)"
  "- manifest_exists: $($json.manifest.exists)"
  "- ready_for_implementation: $($json.ready_for_implementation)"
)

[System.IO.File]::WriteAllText($mdPath, ($md -join "`r`n"), $utf8NoBom)

Write-Output "Wrote:"
Write-Output $jsonPath
Write-Output $mdPath
