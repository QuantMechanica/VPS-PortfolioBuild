param(
  [string]$RepoRoot = "C:\QM\worktrees\development",
  [string]$WriteStatusPath = ""
)

$cardPath = Join-Path $RepoRoot "strategy-seeds\cards\lien-fader_card.md"
$registryPath = Join-Path $RepoRoot "framework\registry\ea_id_registry.csv"

$result = [ordered]@{
  issue = "QUA-405"
  strategy_id = "SRC04_S06"
  slug = "lien-fader"
  card_exists = Test-Path $cardPath
  card_approved = $false
  card_ea_id = $null
  registry_row_exists = $false
  ready_for_implementation = $false
}

if ($result.card_exists) {
  $card = Get-Content $cardPath
  $statusLine = $card | Where-Object { $_ -match '^status:\s*' } | Select-Object -First 1
  $eaLine = $card | Where-Object { $_ -match '^ea_id:\s*' } | Select-Object -First 1

  if ($statusLine) {
    $status = ($statusLine -replace '^status:\s*', '').Trim()
    $result.card_approved = ($status -eq 'APPROVED')
  }
  if ($eaLine) {
    $result.card_ea_id = ($eaLine -replace '^ea_id:\s*', '').Trim()
  }
}

if (Test-Path $registryPath) {
  $rows = Get-Content $registryPath
  $match = $rows | Where-Object { $_ -match '(^|,)lien-fader,' -or $_ -match '(^|,)SRC04_S06(,|$)' } | Select-Object -First 1
  if ($match) {
    $result.registry_row_exists = $true
  }
}

$result.ready_for_implementation = (
  $result.card_exists -and
  $result.card_approved -and
  $result.card_ea_id -and
  $result.card_ea_id -ne 'TBD' -and
  $result.registry_row_exists
)

$json = $result | ConvertTo-Json -Depth 4

if ($WriteStatusPath -ne "") {
  Set-Content -Encoding ASCII -LiteralPath $WriteStatusPath $json
}

$json
