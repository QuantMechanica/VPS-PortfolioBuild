param(
  [string]$RepoRoot = "C:\QM\repo"
)

$checkScript = Join-Path $RepoRoot "artifacts/qua-408/check_readiness.ps1"
$historyPath = Join-Path $RepoRoot "artifacts/qua-408/readiness_history.csv"

powershell -NoProfile -ExecutionPolicy Bypass -File $checkScript -RepoRoot $RepoRoot
$checkExit = $LASTEXITCODE

$jsonPath = Join-Path $RepoRoot "artifacts/qua-408/readiness_latest.json"
$json = Get-Content $jsonPath | ConvertFrom-Json

if (!(Test-Path $historyPath)) {
  'checked_at_local,ready,status,card_status,card_ea_id,has_strategy_id,has_slug' | Set-Content $historyPath
}

"$($json.checked_at_local),$($json.ready),$($json.status),$($json.card.status),$($json.card.ea_id),$($json.registry.has_strategy_id_src04_s09),$($json.registry.has_slug_lien_perfect_order)" | Add-Content $historyPath

Write-Output "check_exit_code=$checkExit"
Write-Output $jsonPath
Write-Output $historyPath
exit $checkExit
