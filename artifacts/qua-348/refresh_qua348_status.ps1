param(
  [string]$ArtifactsDir = "C:\QM\repo\artifacts\qua-348",
  [string]$StatusPath = "C:\QM\repo\docs\ops\QUA-348_ISSUE_STATUS_UPDATE_2026-04-28.json"
)

$validator = Join-Path $ArtifactsDir "validate_src04_s09_build_handoff.ps1"
$readiness = Join-Path $ArtifactsDir "check_src04_s09_readiness.ps1"
$tick = Join-Path $ArtifactsDir "run_qua348_tick.ps1"

$validatorResult = "UNKNOWN"
$readinessResult = "UNKNOWN"
$tickPath = ""

if(Test-Path $validator) { $validatorResult = (& $validator | Select-Object -Last 1) }
if(Test-Path $readiness) { $readinessResult = (& $readiness | Select-Object -Last 1) }
if(Test-Path $tick) { $tickPath = (& $tick | Select-Object -Last 1) }

$payload = [ordered]@{
  issue = "QUA-348"
  generated_at_local = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
  recommended_transition = [ordered]@{
    status = "blocked"
    reason = "missing_src04_s09_ea_mapping_or_build_artifact"
    resume = $true
  }
  wake_delta_handling = [ordered]@{
    continuation_mode = "implementation"
    refresh_script_ran = $true
    build_handoff_validator_last_result = $validatorResult
    readiness_last_result = $readinessResult
    tick_bundle_generated = $tickPath
  }
  unblock = [ordered]@{
    owner = "CTO (with Dev if build pending)"
    action = "Provide concrete EAName/SetfilePath via apply helper until validator=VALID and readiness=READY"
  }
  pipeline_next_action_when_unblocked = "Execute first valid factory baseline cohort for SRC04_S09 and post filesystem-truth counters plus report-size evidence"
}

$payload | ConvertTo-Json -Depth 8 | Set-Content -Path $StatusPath
Write-Output "STATUS_REFRESHED=$StatusPath"
