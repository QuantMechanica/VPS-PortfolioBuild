param(
  [string]$RepoRoot = "C:\QM\repo"
)

$cardPath = Join-Path $RepoRoot "strategy-seeds/cards/lien-inside-day-breakout_card.md"
$registryPath = Join-Path $RepoRoot "framework/registry/ea_id_registry.csv"

$result = [ordered]@{
  issue = "QUA-404"
  strategy_id = "SRC04_S05"
  slug = "lien-inside-day-breakout"
  checked_at_local = (Get-Date).ToString("o")
  blocked = $true
  unblock_owner = "CEO + CTO"
  checks = [ordered]@{}
}

$cardExists = Test-Path $cardPath
$registryExists = Test-Path $registryPath

$cardStatus = $null
$cardEaId = $null
if ($cardExists) {
  $cardText = Get-Content $cardPath -Raw
  $statusMatch = [regex]::Match($cardText, "(?m)^status:\s*(.+)$")
  $eaIdMatch = [regex]::Match($cardText, "(?m)^ea_id:\s*(.+)$")
  if ($statusMatch.Success) { $cardStatus = $statusMatch.Groups[1].Value.Trim() }
  if ($eaIdMatch.Success) { $cardEaId = $eaIdMatch.Groups[1].Value.Trim() }
}

$registryHasRow = $false
if ($registryExists) {
  $registryRows = Import-Csv -Path $registryPath
  $match = $registryRows | Where-Object { $_.strategy_id -eq "SRC04_S05" -and $_.slug -eq "lien-inside-day-breakout" }
  if ($null -ne $match) { $registryHasRow = $true }
}

$cardApproved = ($cardStatus -eq "APPROVED")
$cardEaIdReady = (-not [string]::IsNullOrWhiteSpace($cardEaId) -and $cardEaId -ne "TBD")

$result.checks = [ordered]@{
  card_exists = $cardExists
  registry_exists = $registryExists
  card_status = $cardStatus
  card_ea_id = $cardEaId
  card_approved = $cardApproved
  card_ea_id_allocated = $cardEaIdReady
  registry_has_src04_s05_row = $registryHasRow
}

$ready = $cardExists -and $registryExists -and $cardApproved -and $cardEaIdReady -and $registryHasRow
$result.blocked = -not $ready
$result.next_action = if ($ready) {
  "Implement QM5_<ea_id>_lien_inside_day_breakout.mq5 and compile for CTO review."
} else {
  "CEO+CTO must approve card and allocate ea_id registry row before Development implementation."
}

$result | ConvertTo-Json -Depth 5
