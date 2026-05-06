param(
    [string]$RepoRoot = "C:\QM\repo"
)

$ErrorActionPreference = "Stop"

$closeoutJson = Join-Path $RepoRoot "docs\ops\QUA-769_CLOSEOUT_2026-05-06.json"
$transitionJson = Join-Path $RepoRoot "docs\ops\QUA-769_ISSUE_TRANSITION_PAYLOAD_2026-05-06.json"
$runtimeEvidence = Join-Path $RepoRoot "lessons-learned\evidence\2026-05-06_qua769_python311_runtime_recovery.md"
$forensicsEvidence = Join-Path $RepoRoot "lessons-learned\evidence\2026-05-06_qua769_forensics_followup.md"

$issues = @()

foreach ($path in @($closeoutJson, $transitionJson, $runtimeEvidence, $forensicsEvidence)) {
    if (-not (Test-Path -LiteralPath $path)) {
        $issues += "missing_file:$path"
    }
}

if ($issues.Count -eq 0) {
    $closeout = Get-Content -Raw -LiteralPath $closeoutJson | ConvertFrom-Json
    $transition = Get-Content -Raw -LiteralPath $transitionJson | ConvertFrom-Json

    $validCloseoutStatuses = @("ready_to_close", "closed_done_completed")
    if ($validCloseoutStatuses -notcontains [string]$closeout.status) {
        $issues += "closeout_status_invalid"
    }
    if ($transition.recommended_state -ne "done") {
        $issues += "transition_state_not_done"
    }
    if ($transition.state_reason -ne "completed") {
        $issues += "transition_reason_not_completed"
    }
    if ($transition.checks.python_runtime -ne "pass") {
        $issues += "python_runtime_check_not_pass"
    }
    if ($transition.checks.object_access_audit_policy -ne "ok") {
        $issues += "object_access_audit_policy_not_ok"
    }
}

$status = if ($issues.Count -eq 0) { "ok" } else { "critical" }
$result = [ordered]@{
    issue = "QUA-769"
    status = $status
    issues = $issues
}

$result | ConvertTo-Json -Depth 6
if ($status -ne "ok") {
    exit 2
}
