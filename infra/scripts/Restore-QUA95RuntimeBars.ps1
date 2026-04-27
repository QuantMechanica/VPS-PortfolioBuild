[CmdletBinding()]
param(
    [string]$IssueId = 'QUA-207',
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$TargetSymbol = 'XTIUSD.DWX',
    [string]$TerminalRoot = 'D:\QM\mt5\T1',
    [string]$PythonExe = 'python',
    [string]$ProbeScript = 'C:\QM\repo\infra\scripts\probe_custom_symbol_visibility.py',
    [int]$MaxRestartAttempts = 2,
    [int]$PostStartWaitSeconds = 20,
    [int]$InterAttemptWaitSeconds = 10,
    [string]$OutEvidenceJson = 'docs\ops\QUA-207_RUNTIME_RESTORE_XTIUSD_2026-04-27.json',
    [string]$OutSummaryMd = 'docs\ops\QUA-207_RUNTIME_RESTORE_XTIUSD_2026-04-27.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($MaxRestartAttempts -lt 0) {
    throw "MaxRestartAttempts must be >= 0."
}
if ($PostStartWaitSeconds -lt 0) {
    throw "PostStartWaitSeconds must be >= 0."
}
if ($InterAttemptWaitSeconds -lt 0) {
    throw "InterAttemptWaitSeconds must be >= 0."
}
if ($TerminalRoot -match 'T6') {
    throw "Refusing T6 terminal scope: $TerminalRoot"
}
if (-not (Test-Path -LiteralPath $RepoRoot)) {
    throw "Repo root not found: $RepoRoot"
}
if (-not (Test-Path -LiteralPath $ProbeScript)) {
    throw "Probe script not found: $ProbeScript"
}

$terminalExe = Join-Path $TerminalRoot 'terminal64.exe'
if (-not (Test-Path -LiteralPath $terminalExe)) {
    throw "terminal64.exe not found: $terminalExe"
}

$evidenceFull = Join-Path $RepoRoot $OutEvidenceJson
$summaryFull = Join-Path $RepoRoot $OutSummaryMd
$tmpProbeJson = Join-Path $RepoRoot ("infra\smoke\qua95_runtime_restore_probe_{0}.json" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

New-Item -ItemType Directory -Path (Split-Path -Parent $evidenceFull) -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path -Parent $summaryFull) -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path -Parent $tmpProbeJson) -Force | Out-Null

function Get-TargetTerminalProcesses {
    param([string]$TerminalExePath)
    $resolved = [System.IO.Path]::GetFullPath($TerminalExePath)
    $all = @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue)
    $hits = @()
    foreach ($p in $all) {
        if ([string]::IsNullOrWhiteSpace($p.ExecutablePath)) {
            continue
        }
        if ([string]::Equals(
            [System.IO.Path]::GetFullPath($p.ExecutablePath),
            $resolved,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            $hits += $p
        }
    }
    return $hits
}

function Invoke-VisibilityProbe {
    param(
        [string]$Python,
        [string]$ScriptPath,
        [string]$Target,
        [string]$TerminalPath,
        [string]$JsonPath
    )

    if (Test-Path -LiteralPath $JsonPath) {
        Remove-Item -LiteralPath $JsonPath -Force
    }

    $out = & $Python $ScriptPath --target $Target --terminal $TerminalPath --json-out $JsonPath 2>&1
    $exitCode = $LASTEXITCODE
    $stdout = @($out | ForEach-Object { $_.ToString() })

    $payload = $null
    if (Test-Path -LiteralPath $JsonPath) {
        try {
            $payload = Get-Content -LiteralPath $JsonPath -Raw | ConvertFrom-Json
        } catch {
            $payload = $null
        }
    }

    $targetRange = 0
    $targetPos = 0
    $sourceRange = 0
    $sourcePos = 0
    $isolatedFailure = $true

    if ($null -ne $payload) {
        $targetRange = [int]$payload.target_probe.rates_range_m1_count
        $targetPos = [int]$payload.target_probe.rates_from_pos_m1_count
        $sourceRange = [int]$payload.source_probe.rates_range_m1_count
        $sourcePos = [int]$payload.source_probe.rates_from_pos_m1_count
        $isolatedFailure = [bool]$payload.isolated_custom_bars_visibility_failure
    }

    $targetBarsVisible = ($targetRange -gt 0 -or $targetPos -gt 0)
    $sourceBarsVisible = ($sourceRange -gt 0 -or $sourcePos -gt 0)
    $restored = ($targetBarsVisible -and $sourceBarsVisible -and -not $isolatedFailure)

    return [pscustomobject]@{
        probe_exit_code = $exitCode
        probe_stdout = $stdout
        probe_payload = $payload
        target_range_m1 = $targetRange
        target_pos_m1 = $targetPos
        source_range_m1 = $sourceRange
        source_pos_m1 = $sourcePos
        isolated_custom_failure = $isolatedFailure
        restored = $restored
    }
}

$runStarted = Get-Date
$precheck = Invoke-VisibilityProbe -Python $PythonExe -ScriptPath $ProbeScript -Target $TargetSymbol -TerminalPath $terminalExe -JsonPath $tmpProbeJson
$attempts = @()
$restored = [bool]$precheck.restored
$restoredOn = if ($restored) { 'precheck' } else { 'none' }

if (-not $restored) {
    for ($attempt = 1; $attempt -le $MaxRestartAttempts; $attempt++) {
        $procBefore = @(Get-TargetTerminalProcesses -TerminalExePath $terminalExe)
        foreach ($p in $procBefore) {
            try {
                Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop
            } catch {}
        }

        if ($procBefore.Count -gt 0) {
            Start-Sleep -Seconds 2
        }

        $startedPid = $null
        try {
            $started = Start-Process -FilePath $terminalExe -ArgumentList '/portable' -PassThru
            $startedPid = $started.Id
        } catch {
            $startedPid = $null
        }

        if ($PostStartWaitSeconds -gt 0) {
            Start-Sleep -Seconds $PostStartWaitSeconds
        }

        $probe = Invoke-VisibilityProbe -Python $PythonExe -ScriptPath $ProbeScript -Target $TargetSymbol -TerminalPath $terminalExe -JsonPath $tmpProbeJson
        $attempts += [pscustomobject]@{
            attempt = $attempt
            stopped_process_count = $procBefore.Count
            started_pid = $startedPid
            probe_exit_code = $probe.probe_exit_code
            restored = $probe.restored
            isolated_custom_failure = $probe.isolated_custom_failure
            target_range_m1 = $probe.target_range_m1
            target_pos_m1 = $probe.target_pos_m1
            source_range_m1 = $probe.source_range_m1
            source_pos_m1 = $probe.source_pos_m1
        }

        if ($probe.restored) {
            $restored = $true
            $restoredOn = "restart_attempt_${attempt}"
            break
        }

        if ($attempt -lt $MaxRestartAttempts -and $InterAttemptWaitSeconds -gt 0) {
            Start-Sleep -Seconds $InterAttemptWaitSeconds
        }
    }
}

$finalProbe = Invoke-VisibilityProbe -Python $PythonExe -ScriptPath $ProbeScript -Target $TargetSymbol -TerminalPath $terminalExe -JsonPath $tmpProbeJson
$runEnded = Get-Date
$durationSeconds = [Math]::Round(($runEnded - $runStarted).TotalSeconds, 3)

$status = if ($restored -or $finalProbe.restored) { 'restored' } elseif ($precheck.probe_exit_code -eq 2) { 'probe_init_failed' } else { 'not_restored' }
$nextAction = if ($status -eq 'restored') {
    'Run verifier rerun proof and update QUA-95/QUA-207 blocker artifacts.'
} else {
    'Escalate to runtime custom-symbol owner for manual terminal/runtime recovery; rerun this script after recovery.'
}

$evidence = [ordered]@{
    issue = $IssueId
    generated_at_local = $runEnded.ToString('yyyy-MM-ddTHH:mm:ssK')
    target_symbol = $TargetSymbol
    terminal_exe = $terminalExe
    status = $status
    restored_on = $restoredOn
    duration_seconds = $durationSeconds
    parameters = [ordered]@{
        max_restart_attempts = $MaxRestartAttempts
        post_start_wait_seconds = $PostStartWaitSeconds
        inter_attempt_wait_seconds = $InterAttemptWaitSeconds
    }
    precheck = $precheck
    attempts = $attempts
    final_probe = $finalProbe
    next_action = $nextAction
}

$evidence | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $evidenceFull -Encoding UTF8

$summary = @(
    '# QUA-207 Runtime Restore - XTIUSD.DWX (2026-04-27)',
    '',
    ("- issue: {0}" -f $IssueId),
    ("- target_symbol: {0}" -f $TargetSymbol),
    ("- status: {0}" -f $status),
    ("- restored_on: {0}" -f $restoredOn),
    ("- precheck bars (target range/pos): {0}/{1}" -f $precheck.target_range_m1, $precheck.target_pos_m1),
    ("- final bars (target range/pos): {0}/{1}" -f $finalProbe.target_range_m1, $finalProbe.target_pos_m1),
    ("- final bars (source range/pos): {0}/{1}" -f $finalProbe.source_range_m1, $finalProbe.source_pos_m1),
    ("- final isolated_custom_failure: {0}" -f $finalProbe.isolated_custom_failure),
    ("- attempts_used: {0}" -f $attempts.Count),
    ("- evidence_json: {0}" -f $evidenceFull),
    ("- next_action: {0}" -f $nextAction)
)
$summary | Set-Content -LiteralPath $summaryFull -Encoding UTF8

if (Test-Path -LiteralPath $tmpProbeJson) {
    Remove-Item -LiteralPath $tmpProbeJson -Force
}

Write-Host ("status={0}" -f $status)
Write-Host ("restored_on={0}" -f $restoredOn)
Write-Host ("evidence_json={0}" -f $evidenceFull)
Write-Host ("summary_md={0}" -f $summaryFull)
Write-Host ("final_target_bars_range_pos={0}/{1}" -f $finalProbe.target_range_m1, $finalProbe.target_pos_m1)

if ($status -eq 'restored') {
    exit 0
}

exit 2
