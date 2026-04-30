param(
  [string]$OutDir = "C:\QM\repo\artifacts\qua-348"
)

$issue = "QUA-348"
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$out = Join-Path $OutDir ("tick_bundle_{0}.json" -f $ts)

$readinessPath = Join-Path $OutDir "src04_s09_readiness_latest.json"
$buildValidationPath = Join-Path $OutDir "src04_s09_build_handoff_validation.json"
$manifestPath = Join-Path $OutDir "src04_s09_cto_payload_proposal_2026-04-28T122900Z.json"

$readiness = $null
if(Test-Path $readinessPath){ $readiness = Get-Content $readinessPath -Raw | ConvertFrom-Json }

$buildValidation = $null
if(Test-Path $buildValidationPath){ $buildValidation = Get-Content $buildValidationPath -Raw | ConvertFrom-Json }

$manifest = $null
if(Test-Path $manifestPath){ $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json }

$bundle = [ordered]@{
  issue = $issue
  generated_at_local = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
  blocker = [ordered]@{
    owner = "CTO (with Dev if build pending)"
    reason = "missing_src04_s09_ea_mapping_or_build_artifact"
    unblock_action = "Run apply_src04_s09_payload.ps1 with concrete EAName/SetfilePath and ensure VALID+READY"
  }
  manifest = [ordered]@{
    path = $manifestPath
    ea_name = if($manifest){$manifest.ea_name}else{$null}
    setfile_path = if($manifest){$manifest.setfile_path}else{$null}
  }
  build_handoff_validation = $buildValidation
  readiness = $readiness
  next_action_when_unblocked = "Execute first valid baseline cohort and publish filesystem-truth + report-size evidence"
}

$bundle | ConvertTo-Json -Depth 10 | Set-Content -Path $out
Write-Output $out
