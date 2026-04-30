param(
  [string]$ManifestPath = "C:\QM\repo\artifacts\qua-348\src04_s09_cto_payload_proposal_2026-04-28T122900Z.json",
  [string]$OutPath = "C:\QM\repo\artifacts\qua-348\src04_s09_build_handoff_validation.json"
)

$ok = $true
$missing = @()
$found = @{}

if(-not (Test-Path -LiteralPath $ManifestPath)) {
  $ok = $false
  $missing += "manifest_missing"
}

$manifest = $null
if($ok) {
  $manifest = (Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json)
}

function Is-Unset([string]$v) {
  return [string]::IsNullOrWhiteSpace($v) -or $v -like "TODO:*" -or $v -eq "<CTO_FILL_REQUIRED>"
}

$eaName = ""
$setfile = ""
if($manifest) {
  $eaName = [string]$manifest.ea_name
  $setfile = [string]$manifest.setfile_path
}

if(Is-Unset $eaName) { $ok = $false; $missing += "ea_name" }
if(Is-Unset $setfile) { $ok = $false; $missing += "setfile_path" }

if(-not (Is-Unset $setfile)) {
  $setfileAbs = if([System.IO.Path]::IsPathRooted($setfile)) { $setfile } else { Join-Path "C:\QM\repo" $setfile }
  $found.setfile_path = $setfileAbs
  if(-not (Test-Path -LiteralPath $setfileAbs)) { $ok = $false; $missing += "setfile_file_missing" }
}

if(-not (Is-Unset $eaName)) {
  $mq5 = Get-ChildItem -Recurse -File C:\QM\repo\framework\EAs -Filter "*.mq5" | Where-Object { $_.BaseName -eq $eaName } | Select-Object -First 1
  $ex5 = Get-ChildItem -Recurse -File C:\QM\repo\framework\EAs -Filter "*.ex5" | Where-Object { $_.BaseName -eq $eaName } | Select-Object -First 1
  if($null -eq $mq5) { $ok = $false; $missing += "ea_source_missing" } else { $found.ea_source_path = $mq5.FullName }
  if($null -eq $ex5) { $ok = $false; $missing += "ea_ex5_missing" } else { $found.ea_ex5_path = $ex5.FullName }
}

$result = [ordered]@{
  issue = "QUA-348"
  strategy_id = "SRC04_S09"
  checked_at_local = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
  valid = $ok
  missing = $missing
  manifest_path = $ManifestPath
  discovered = $found
  unblock_when_valid = "Pipeline-Operator can execute baseline cohort once valid=true and readiness check is READY"
}

$result | ConvertTo-Json -Depth 8 | Set-Content -Path $OutPath
if($ok) { Write-Output "VALID" } else { Write-Output "INVALID" }
