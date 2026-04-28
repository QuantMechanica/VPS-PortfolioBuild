param(
  [string]$RepoRoot = "C:\QM\repo"
)

$cardPath = Join-Path $RepoRoot "strategy-seeds\cards\lien-carry-trade_card.md"
$registryPath = Join-Path $RepoRoot "framework\registry\ea_id_registry.csv"

$cardExists = Test-Path $cardPath
$registryExists = Test-Path $registryPath

$cardHeader = [ordered]@{}
if ($cardExists) {
  $lines = Get-Content $cardPath
  foreach ($k in @('strategy_id','ea_id','slug','status')) {
    $m = $lines | Select-String -Pattern "^${k}:\s*(.+)$" -CaseSensitive | Select-Object -First 1
    $cardHeader[$k] = if ($m) { $m.Matches[0].Groups[1].Value.Trim() } else { $null }
  }
}

$registryRowPresent = $false
if ($registryExists) {
  $rows = Import-Csv $registryPath
  $registryRowPresent = @($rows | Where-Object { $_.strategy_id -eq 'SRC04_S11' -and $_.slug -eq 'lien-carry-trade' }).Count -gt 0
}

$blocked = -not ($cardExists -and $registryExists -and $cardHeader['status'] -eq 'APPROVED' -and $cardHeader['ea_id'] -and $cardHeader['ea_id'] -ne 'TBD' -and $registryRowPresent)

$out = [ordered]@{
  issue = 'QUA-409'
  checked_at = (Get-Date).ToString('o')
  head = (git -C $RepoRoot rev-parse --short HEAD).Trim()
  card_path = $cardPath
  registry_path = $registryPath
  card_exists = $cardExists
  registry_exists = $registryExists
  card_header = $cardHeader
  registry_row_present = $registryRowPresent
  blocked = $blocked
  unblock_owner = 'CEO + CTO'
  unblock_actions = @(
    'Approve card SRC04_S11 and set status APPROVED with concrete ea_id',
    'Add ea_id row for slug=lien-carry-trade, strategy_id=SRC04_S11 in framework/registry/ea_id_registry.csv',
    'Re-dispatch Development on QUA-409'
  )
}

$outPath = Join-Path $RepoRoot "artifacts\qua-409\readiness_latest.json"
$out | ConvertTo-Json -Depth 6 | Set-Content $outPath
Write-Output $outPath
