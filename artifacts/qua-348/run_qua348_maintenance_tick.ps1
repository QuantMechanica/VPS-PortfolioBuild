$refresh = "C:\QM\repo\artifacts\qua-348\refresh_qua348_status.ps1"
$source = "C:\QM\repo\docs\ops\QUA-348_ISSUE_STATUS_UPDATE_2026-04-28.json"
$mirror = "C:\QM\repo\artifacts\qua-348\latest_status.json"
$integrity = "C:\QM\repo\artifacts\qua-348\check_status_integrity.ps1"
$triage = "C:\QM\repo\docs\ops\QUA-348_WAKE_TRIAGE_2026-04-28.md"

if(Test-Path $refresh) { & $refresh | Out-Null }
if(Test-Path $source) { Copy-Item -LiteralPath $source -Destination $mirror -Force }
$sync = "INTEGRITY_UNKNOWN"
if(Test-Path $integrity) { $sync = (& $integrity | Select-Object -Last 1) }

$latestBundle = Get-ChildItem C:\QM\repo\artifacts\qua-348\tick_bundle_*.json | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$status = Get-Content $source -Raw | ConvertFrom-Json

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$noChangeOut = "C:\QM\repo\artifacts\qua-348\heartbeat_no_change_${ts}.json"
$noChange = [ordered]@{
  issue = "QUA-348"
  generated_at_local = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
  heartbeat_type = "no_change"
  blocker_owner = "CTO (with Dev if build pending)"
  blocker_reason = "missing_src04_s09_ea_mapping_or_build_artifact"
  validator = $status.wake_delta_handling.build_handoff_validator_last_result
  readiness = $status.wake_delta_handling.readiness_last_result
  missing_fields = @("ea_name", "setfile_path")
  latest_tick_bundle = if($latestBundle){$latestBundle.FullName}else{$null}
  next_action_when_unblocked = "Execute first valid baseline cohort and publish filesystem-truth/report-size evidence"
}
$noChange | ConvertTo-Json -Depth 8 | Set-Content -Path $noChangeOut
Copy-Item -LiteralPath $noChangeOut -Destination "C:\QM\repo\artifacts\qua-348\latest_no_change.json" -Force

$entry = @"
## Wake Checkpoint — $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')

- maintenance_tick_script_ran: true
- integrity: $sync
- latest_tick_bundle: $($latestBundle.FullName)
- latest_no_change: $noChangeOut
- validator: $($status.wake_delta_handling.build_handoff_validator_last_result)
- readiness: $($status.wake_delta_handling.readiness_last_result)
"@
Add-Content -Path $triage -Value $entry
Write-Output "MAINTENANCE_TICK_DONE"
