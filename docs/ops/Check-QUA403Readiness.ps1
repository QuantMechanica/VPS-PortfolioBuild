param(
  [string]$RepoRoot = "C:\QM\repo"
)

$card = Join-Path $RepoRoot "strategy-seeds/cards/lien-waiting-deal_card.md"
$registry = Join-Path $RepoRoot "framework/registry/ea_id_registry.csv"

if(!(Test-Path $card)) { throw "Missing card file: $card" }
if(!(Test-Path $registry)) { throw "Missing registry file: $registry" }

$cardLines = Get-Content $card
$eaId = (($cardLines | Where-Object { $_ -match '^ea_id:' }) -replace '^ea_id:\s*','').Trim()
$status = (($cardLines | Where-Object { $_ -match '^status:' }) -replace '^status:\s*','').Trim()
$registryHas = ((Get-Content $registry) -match 'SRC04_S04').Count -gt 0

$result = [pscustomobject]@{
  issue = 'QUA-403'
  strategy_id = 'SRC04_S04'
  card_ea_id = $eaId
  card_status = $status
  registry_has_src04_s04 = $registryHas
  blocked = -not (($eaId -ne 'TBD') -and ($status -eq 'APPROVED') -and $registryHas)
  checked_at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
}

$result | ConvertTo-Json -Depth 4
