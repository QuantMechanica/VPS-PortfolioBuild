param(
  [string]$RepoRoot = "C:\QM\repo"
)

$cardPath = Join-Path $RepoRoot "strategy-seeds/cards/lien-perfect-order_card.md"
$registryPath = Join-Path $RepoRoot "framework/registry/ea_id_registry.csv"

$card = Get-Content $cardPath -Raw
$eaIdMatch = [regex]::Match($card, "(?m)^ea_id:\s*(.+)$")
$statusMatch = [regex]::Match($card, "(?m)^status:\s*(.+)$")

$eaId = if ($eaIdMatch.Success) { $eaIdMatch.Groups[1].Value.Trim() } else { "UNKNOWN" }
$status = if ($statusMatch.Success) { $statusMatch.Groups[1].Value.Trim() } else { "UNKNOWN" }

$registry = Get-Content $registryPath -Raw
$hasStrategyId = $registry -match "(?m)^.*SRC04_S09.*$"
$hasSlug = $registry -match "(?m)^.*lien-perfect-order.*$"

$ready = ($status -eq "APPROVED") -and ($eaId -notin @("TBD", "UNKNOWN", "")) -and $hasStrategyId

$result = [ordered]@{
  issue = "QUA-408"
  checked_at_local = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
  ready = $ready
  status = if ($ready) { "ready" } else { "blocked" }
  card = [ordered]@{
    path = "strategy-seeds/cards/lien-perfect-order_card.md"
    ea_id = $eaId
    status = $status
  }
  registry = [ordered]@{
    path = "framework/registry/ea_id_registry.csv"
    has_strategy_id_src04_s09 = $hasStrategyId
    has_slug_lien_perfect_order = $hasSlug
  }
  unblock = [ordered]@{
    owner = "CEO + CTO"
    action = "Approve SRC04_S09 and allocate/register EA ID for lien-perfect-order"
  }
}

$outPath = Join-Path $RepoRoot "artifacts/qua-408/readiness_latest.json"
$result | ConvertTo-Json -Depth 5 | Set-Content $outPath
Write-Output $outPath
if ($ready) {
  exit 0
}
exit 2
