param(
  [string]$ManifestPath = "C:\QM\repo\artifacts\qua-348\src04_s09_cto_payload_proposal_2026-04-28T122900Z.json",
  [string]$OutPath = "C:\QM\repo\artifacts\qua-348\src04_s09_readiness_latest.json"
)

$ready = $true
$missing = @()

if(-not (Test-Path -LiteralPath $ManifestPath)) {
  $ready = $false
  $missing += "manifest_missing"
  $result = [ordered]@{
    issue = "QUA-348"
    strategy_id = "SRC04_S09"
    checked_at_local = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
    ready = $false
    missing = $missing
    manifest_path = $ManifestPath
  }
  $result | ConvertTo-Json -Depth 6 | Set-Content -Path $OutPath
  Write-Output "NOT_READY: manifest missing"
  exit 0
}

$raw = Get-Content -LiteralPath $ManifestPath -Raw
$data = $raw | ConvertFrom-Json

function Require-NonEmpty([string]$value, [string]$name) {
  if([string]::IsNullOrWhiteSpace($value) -or $value -like "TODO:*" -or $value -eq "<CTO_FILL_REQUIRED>") {
    $script:ready = $false
    $script:missing += $name
  }
}

if(-not $data.symbols_proposed -or $data.symbols_proposed.Count -lt 1) {
  $ready = $false
  $missing += "symbols_proposed"
}

Require-NonEmpty $data.assumptions.from "assumptions.from"
Require-NonEmpty $data.assumptions.to "assumptions.to"
Require-NonEmpty $data.output_root "output_root"

if(-not $data.terminal_allocation_proposed) {
  $ready = $false
  $missing += "terminal_allocation_proposed"
}
else {
  foreach($slot in @("T1","T2","T3","T4","T5")) {
    $val = $data.terminal_allocation_proposed.$slot
    if([string]::IsNullOrWhiteSpace($val) -or $val -like "TODO:*") {
      $ready = $false
      $missing += "terminal_allocation_proposed.$slot"
    }
  }
}

if(-not $data.ea_name) {
  $ready = $false
  $missing += "ea_name"
}
else {
  Require-NonEmpty ([string]$data.ea_name) "ea_name"
}

if(-not $data.setfile_path) {
  $ready = $false
  $missing += "setfile_path"
}
else {
  Require-NonEmpty ([string]$data.setfile_path) "setfile_path"
}

$result = [ordered]@{
  issue = "QUA-348"
  strategy_id = "SRC04_S09"
  checked_at_local = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
  ready = $ready
  missing = $missing
  manifest_path = $ManifestPath
  out_path = $OutPath
  next_action_when_ready = "Run first valid baseline cohort and publish filesystem-truth + report-size evidence"
}

$result | ConvertTo-Json -Depth 8 | Set-Content -Path $OutPath
if($ready) {
  Write-Output "READY"
} else {
  Write-Output "NOT_READY"
}
