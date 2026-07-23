$ErrorActionPreference = 'Stop'
$card = 'strategy-seeds/cards/lien-inside-day-breakout_card.md'
$manifest = 'docs/ops/QUA-344_STATE_MANIFEST.json'
$out = 'docs/ops/QUA-344_GUARD_RESULT.txt'

$ea = (Select-String -Path $card -Pattern '^ea_id:\s*(.+)$' | Select-Object -First 1).Matches.Groups[1].Value
$status = (Select-String -Path $card -Pattern '^status:\s*(.+)$' | Select-Object -First 1).Matches.Groups[1].Value
if (-not $ea) { $ea = 'TBD' }
if (-not $status) { $status = 'UNKNOWN' }

if ($status -eq 'DRAFT' -and $ea -eq 'TBD') {
  $msg = "GUARD: no_change blocked signature=blocked|DRAFT|TBD|TBD owner=Dev + CTO"
} else {
  $msg = "GUARD: state_changed signature=blocked|$status|$ea|TBD"
}

$ts = (Get-Date).ToString('o')
"$ts $msg" | Set-Content -Path $out -Encoding UTF8
Write-Host $out
Write-Host $msg
