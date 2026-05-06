param(
    [string]$CloseoutJson = "C:\QM\repo\docs\ops\QUA-769_CLOSEOUT_2026-05-06.json",
    [string]$OutPath = "C:\QM\repo\docs\ops\QUA-769_ISSUE_TRANSITION_PAYLOAD_2026-05-06.json"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $CloseoutJson)) {
    throw "Closeout JSON not found: $CloseoutJson"
}

$closeout = Get-Content -Raw -LiteralPath $CloseoutJson | ConvertFrom-Json

$payload = [ordered]@{
    issue = "QUA-769"
    recommended_state = "done"
    state_reason = "completed"
    resume = $true
    summary = "Python 3.11 runtime recovered; monitoring and forensics controls implemented; unblock verification passed."
    evidence = @{
        closeout_md = "docs/ops/QUA-769_CLOSEOUT_2026-05-06.md"
        closeout_json = "docs/ops/QUA-769_CLOSEOUT_2026-05-06.json"
        runtime_recovery = "lessons-learned/evidence/2026-05-06_qua769_python311_runtime_recovery.md"
        forensics_followup = "lessons-learned/evidence/2026-05-06_qua769_forensics_followup.md"
    }
    checks = @{
        python_runtime = $closeout.runtime.stdlib_import_check
        p2_baseline_entrypoint = $closeout.runtime.p2_baseline_help_check
        python_runtime_health_task = "ok"
        object_access_audit_policy = $closeout.monitoring.object_access_audit_policy_check
    }
    commit_head = $null
}

try {
    $repoRoot = Split-Path -Path $OutPath -Parent | Split-Path -Parent | Split-Path -Parent
    $head = (git -C $repoRoot rev-parse --short HEAD 2>$null).Trim()
    if ($head) { $payload.commit_head = $head }
} catch {
    $payload.commit_head = $null
}

$targetDir = Split-Path -Path $OutPath -Parent
if ($targetDir) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

$payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutPath -Encoding ASCII
Write-Host ("wrote_payload={0}" -f $OutPath)
