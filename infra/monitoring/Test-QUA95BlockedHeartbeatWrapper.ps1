[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$WrapperScript = 'C:\QM\repo\infra\scripts\Invoke-QUA95BlockedHeartbeat.ps1',
    [string]$HeartbeatJson = 'C:\QM\repo\docs\ops\QUA-95_BLOCKED_HEARTBEAT_2026-04-27.json',
    [string]$AutomationHealthJson = 'C:\QM\repo\docs\ops\QUA-95_AUTOMATION_HEALTH_2026-04-27.json',
    [switch]$RunRefresh
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $WrapperScript)) {
    Write-Host ("status=critical reason=wrapper_missing path={0}" -f $WrapperScript)
    exit 2
}

$args = @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', $WrapperScript,
    '-RepoRoot', $RepoRoot,
    '-SkipAudit'
)
if (-not $RunRefresh.IsPresent) {
    $args += '-SkipRefresh'
}

$runOut = & powershell @args 2>&1
$runCode = $LASTEXITCODE
if ($runCode -ne 0) {
    $runText = ($runOut | ForEach-Object { $_.ToString() }) -join '; '
    Write-Host ("status=critical reason=wrapper_failed exit_code={0} output={1}" -f $runCode, $runText)
    exit 2
}

if (-not (Test-Path -LiteralPath $HeartbeatJson)) {
    Write-Host ("status=critical reason=heartbeat_json_missing path={0}" -f $HeartbeatJson)
    exit 2
}
if (-not (Test-Path -LiteralPath $AutomationHealthJson)) {
    Write-Host ("status=critical reason=automation_health_json_missing path={0}" -f $AutomationHealthJson)
    exit 2
}

$hb = Get-Content -Raw -LiteralPath $HeartbeatJson | ConvertFrom-Json
$automation = Get-Content -Raw -LiteralPath $AutomationHealthJson | ConvertFrom-Json
$issues = @()

if ($hb.issue -ne 'QUA-95') { $issues += 'issue_mismatch' }
if ($null -eq $hb.gate) { $issues += 'missing_gate' }
if ($null -eq $hb.infra_audit) { $issues += 'missing_infra_audit' }
if ($hb.gate.recommended_state -ne 'blocked') { $issues += ("unexpected_gate_state={0}" -f $hb.gate.recommended_state) }
if ([int]$hb.gate.bars_got -ne 0) { $issues += ("unexpected_bars_got={0}" -f $hb.gate.bars_got) }
if ([double]$hb.gate.tail_shortfall_seconds -le 0) { $issues += ("unexpected_tail_shortfall={0}" -f $hb.gate.tail_shortfall_seconds) }
if ([string]::IsNullOrWhiteSpace($hb.infra_audit.overall_status)) { $issues += 'missing_audit_status' }
if ($automation.overall_status -ne 'ok') { $issues += ("automation_health_not_ok={0}" -f $automation.overall_status) }

if ($issues.Count -gt 0) {
    Write-Host ("status=critical reason=validation_failed issues={0}" -f ($issues -join ','))
    exit 2
}

Write-Host ("status=ok gate_state={0} audit_status={1} checks_count={2} automation_health={3}" -f $hb.gate.recommended_state, $hb.infra_audit.overall_status, $hb.infra_audit.checks_count, $automation.overall_status)
exit 0
