param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$PayloadPath = 'C:\QM\repo\artifacts\qua-342\cto_payload_patch_template.json'
)

$base = Join-Path $RepoRoot 'artifacts\qua-342'

powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $base 'run_qua342_tick.ps1') -RepoRoot $RepoRoot | Out-Null

$validator = Join-Path $base 'validate_cto_mapping_payload.ps1'
$validationOutput = $null
$validationExit = 0
if (Test-Path -LiteralPath $validator) {
    $validationOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $validator -PayloadPath $PayloadPath 2>&1
    $validationExit = $LASTEXITCODE
}

$unblock = Get-Content -LiteralPath (Join-Path $base 'unblock_status_latest.json') -Raw | ConvertFrom-Json
$summary = [pscustomobject]@{
    issue = 'QUA-342'
    tick_utc = $unblock.tick_utc
    blocked = $unblock.blocked
    dispatch_ready = $unblock.dispatch_ready
    escalate_now = $unblock.escalate_now
    consecutive_unchanged_blocked_ticks = $unblock.consecutive_unchanged_blocked_ticks
    unblock_owner = $unblock.unblock_owner
    unblock_action = $unblock.unblock_action
    payload_validation_exit_code = $validationExit
    payload_validation_output = $validationOutput
}

$summaryPath = Join-Path $base 'cto_quickcheck_latest.json'
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath
Write-Output "quickcheck.output=$summaryPath"
Write-Output (Get-Content -LiteralPath $summaryPath -Raw)
