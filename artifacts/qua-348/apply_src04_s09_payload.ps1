param(
  [Parameter(Mandatory=$true)][string]$EAName,
  [Parameter(Mandatory=$true)][string]$SetfilePath,
  [string]$FromDate,
  [string]$ToDate,
  [switch]$DryRun
)

$manifestPath = "C:\QM\repo\artifacts\qua-348\src04_s09_cto_payload_proposal_2026-04-28T122900Z.json"
if(-not (Test-Path -LiteralPath $manifestPath)) {
  throw "Manifest not found: $manifestPath"
}

$data = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$setfileAbs = if([System.IO.Path]::IsPathRooted($SetfilePath)) { $SetfilePath } else { Join-Path "C:\QM\repo" $SetfilePath }
$eaSource = Get-ChildItem -Recurse -File C:\QM\repo\framework\EAs -Filter "*.mq5" | Where-Object { $_.BaseName -eq $EAName } | Select-Object -First 1
$eaBinary = Get-ChildItem -Recurse -File C:\QM\repo\framework\EAs -Filter "*.ex5" | Where-Object { $_.BaseName -eq $EAName } | Select-Object -First 1

$preflightMissing = @()
if(-not (Test-Path -LiteralPath $setfileAbs)) { $preflightMissing += "setfile_not_found:$setfileAbs" }
if($null -eq $eaSource) { $preflightMissing += "ea_source_not_found:$EAName" }
if($null -eq $eaBinary) { $preflightMissing += "ea_ex5_not_found:$EAName" }

if($DryRun) {
  $preview = [ordered]@{
    issue = "QUA-348"
    manifest = $manifestPath
    dry_run = $true
    proposed = [ordered]@{
      ea_name = $EAName
      setfile_path = $SetfilePath
      from = if($FromDate){$FromDate}else{$data.assumptions.from}
      to = if($ToDate){$ToDate}else{$data.assumptions.to}
    }
    preflight_missing = $preflightMissing
    preflight_ok = ($preflightMissing.Count -eq 0)
  }
  $preview | ConvertTo-Json -Depth 8 | Write-Output
  exit 0
}

$data.ea_name = $EAName
$data.setfile_path = $SetfilePath

if($FromDate) { $data.assumptions.from = $FromDate }
if($ToDate) { $data.assumptions.to = $ToDate }

$data | ConvertTo-Json -Depth 10 | Set-Content -Path $manifestPath

& "C:\QM\repo\artifacts\qua-348\validate_src04_s09_build_handoff.ps1" | Out-Null
& "C:\QM\repo\artifacts\qua-348\check_src04_s09_readiness.ps1" | Out-Null

Write-Output "UPDATED_MANIFEST=$manifestPath"
Write-Output "BUILD_VALIDATION=C:\QM\repo\artifacts\qua-348\src04_s09_build_handoff_validation.json"
Write-Output "READINESS=C:\QM\repo\artifacts\qua-348\src04_s09_readiness_latest.json"
