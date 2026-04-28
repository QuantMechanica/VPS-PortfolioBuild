param(
  [string]$RepoRoot = "C:\QM\repo"
)

$checker = Join-Path $RepoRoot "artifacts\qua-409\check_readiness.ps1"
if (-not (Test-Path $checker)) {
  Write-Error "Missing checker: $checker"
  exit 2
}

powershell -ExecutionPolicy Bypass -File $checker -RepoRoot $RepoRoot | Out-Null

$latest = Join-Path $RepoRoot "artifacts\qua-409\readiness_latest.json"
if (-not (Test-Path $latest)) {
  Write-Error "Missing readiness output: $latest"
  exit 3
}

$obj = Get-Content $latest | ConvertFrom-Json
$statusLine = "issue={0} blocked={1} head={2} status={3} ea_id={4} registry_row_present={5}" -f `
  $obj.issue, $obj.blocked, $obj.head, $obj.card_header.status, $obj.card_header.ea_id, $obj.registry_row_present

Write-Output $statusLine
if ($obj.blocked) { exit 1 }
exit 0
