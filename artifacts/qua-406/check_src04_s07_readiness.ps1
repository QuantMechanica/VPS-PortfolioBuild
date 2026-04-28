param(
  [string]$RepoRoot = "C:\QM\worktrees\development"
)

$cardPath = Join-Path $RepoRoot "strategy-seeds\cards\lien-20day-breakout_card.md"
$registryPath = Join-Path $RepoRoot "framework\registry\ea_id_registry.csv"
$manifestPath = Join-Path $RepoRoot "artifacts\qua-346\src04_s07_run_manifest_template.json"

$cardExists = Test-Path $cardPath
$registryExists = Test-Path $registryPath
$manifestExists = Test-Path $manifestPath

$cardStatus = $null
$cardEaId = $null
$registryRow = $null

if ($cardExists) {
  $cardLines = Get-Content $cardPath
  $statusLine = $cardLines | Where-Object { $_ -match '^status:\s*' } | Select-Object -First 1
  $eaIdLine = $cardLines | Where-Object { $_ -match '^ea_id:\s*' } | Select-Object -First 1
  if ($statusLine) { $cardStatus = ($statusLine -replace '^status:\s*','').Trim() }
  if ($eaIdLine) { $cardEaId = ($eaIdLine -replace '^ea_id:\s*','').Trim() }
}

if ($registryExists) {
  $rows = Import-Csv $registryPath
  $registryRow = $rows | Where-Object {
    $_.strategy_id -eq 'SRC04_S07' -or $_.slug -eq 'lien-20day-breakout'
  } | Select-Object -First 1
}

$isReady = $false
if ($cardExists -and $manifestExists -and $registryRow -and $cardStatus -eq 'APPROVED' -and $cardEaId -and $cardEaId -ne 'TBD') {
  if ($registryRow.ea_id -eq $cardEaId) {
    $isReady = $true
  }
}

$result = [ordered]@{
  issue = "QUA-406"
  strategy_id = "SRC04_S07"
  slug = "lien-20day-breakout"
  checked_at_utc = (Get-Date).ToUniversalTime().ToString("o")
  card = @{
    path = $cardPath
    exists = $cardExists
    status = $cardStatus
    ea_id = $cardEaId
  }
  registry = @{
    path = $registryPath
    exists = $registryExists
    row_found = [bool]$registryRow
    row = $registryRow
  }
  manifest = @{
    path = $manifestPath
    exists = $manifestExists
  }
  ready_for_implementation = $isReady
}

$result | ConvertTo-Json -Depth 8
