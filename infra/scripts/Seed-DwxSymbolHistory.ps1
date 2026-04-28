[CmdletBinding()]
param(
    [string]$IssueId = 'QUA-270',
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$TerminalRoot = 'D:\QM\mt5\T1',
    [string]$SourceSymbol = 'EURUSD',
    [string]$TargetSymbol = '',
    [string]$CsvSourceDir = 'D:\QM\reports\setup\tick-data-timezone',
    [string]$PythonExe = 'python',
    [string]$PrepareImportScript = 'D:\QM\mt5\T1\dwx_import\prepare_import.py',
    [string]$VerifyImportScript = 'D:\QM\mt5\T1\dwx_import\verify_import.py',
    [string]$ProbeScript = 'C:\QM\repo\infra\scripts\probe_custom_symbol_visibility.py',
    [int]$ImportTimeoutSeconds = 1200,
    [int]$PollSeconds = 5,
    [int]$MinStableMinutes = 30,
    [int]$MaxRestartAttempts = 2,
    [int]$PostStartWaitSeconds = 20,
    [switch]$AllowDeleteReimport,
    [string]$OutEvidenceJson = 'docs\ops\QUA-270_T1_EURUSD_DWX_SEED_2026-04-27.json',
    [string]$OutSummaryMd = 'docs\ops\QUA-270_T1_EURUSD_DWX_SEED_2026-04-27.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($TargetSymbol)) {
    $TargetSymbol = "$SourceSymbol.DWX"
}

if ($TargetSymbol -notmatch '\.DWX$') {
    throw "TargetSymbol must end with .DWX. Got '$TargetSymbol'."
}
if ($ImportTimeoutSeconds -lt 30) {
    throw 'ImportTimeoutSeconds must be >= 30.'
}
if ($PollSeconds -lt 1) {
    throw 'PollSeconds must be >= 1.'
}
if ($MinStableMinutes -lt 0) {
    throw 'MinStableMinutes must be >= 0.'
}
if ($MaxRestartAttempts -lt 0) {
    throw 'MaxRestartAttempts must be >= 0.'
}
if ($PostStartWaitSeconds -lt 0) {
    throw 'PostStartWaitSeconds must be >= 0.'
}
if ($TerminalRoot -match 'T6') {
    throw "Refusing T6 terminal scope: $TerminalRoot"
}

$terminalExe = Join-Path $TerminalRoot 'terminal64.exe'
$metaEditorExe = Join-Path $TerminalRoot 'metaeditor64.exe'
$importQueueDir = Join-Path $TerminalRoot 'MQL5\Files\imports'
$doneDir = Join-Path $importQueueDir 'done'
$scriptsDir = Join-Path $TerminalRoot 'MQL5\Scripts'
$deleteScriptBaseName = 'Delete_One_Custom_Symbol_QM'
$deleteScriptMq5 = Join-Path $scriptsDir ("{0}.mq5" -f $deleteScriptBaseName)
$deleteScriptEx5 = Join-Path $scriptsDir ("{0}.ex5" -f $deleteScriptBaseName)
$deleteCompileLog = Join-Path $scriptsDir ("{0}.compile.log" -f $deleteScriptBaseName)
$deleteIniPath = Join-Path $TerminalRoot 'run_delete_one_custom_symbol_qm.ini'

foreach ($path in @($RepoRoot, $TerminalRoot, $terminalExe, $importQueueDir, $doneDir, $CsvSourceDir, $ProbeScript, $PrepareImportScript, $scriptsDir)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required path missing: $path"
    }
}
if ($AllowDeleteReimport.IsPresent -and -not (Test-Path -LiteralPath $metaEditorExe)) {
    throw "metaeditor64.exe missing (required for -AllowDeleteReimport): $metaEditorExe"
}

$tickCsv = Join-Path $CsvSourceDir ("{0}_GMT+2_US-DST.csv" -f $SourceSymbol)
$m1Csv = Join-Path $CsvSourceDir ("{0}_GMT+2_US-DST_M1.csv" -f $SourceSymbol)
foreach ($csv in @($tickCsv, $m1Csv)) {
    if (-not (Test-Path -LiteralPath $csv)) {
        throw "Required CSV missing: $csv"
    }
}

$evidenceFull = Join-Path $RepoRoot $OutEvidenceJson
$summaryFull = Join-Path $RepoRoot $OutSummaryMd
New-Item -ItemType Directory -Path (Split-Path -Parent $evidenceFull) -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path -Parent $summaryFull) -Force | Out-Null

$tmpProbeJson = Join-Path $RepoRoot ("infra\smoke\qua270_seed_probe_{0}.json" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Path (Split-Path -Parent $tmpProbeJson) -Force | Out-Null

function Invoke-VisibilityProbe {
    param(
        [string]$Python,
        [string]$ScriptPath,
        [string]$Target,
        [string]$TerminalExePath,
        [string]$JsonPath
    )

    if (Test-Path -LiteralPath $JsonPath) {
        Remove-Item -LiteralPath $JsonPath -Force
    }

    $run = Invoke-ExternalCommand -FilePath $Python -ArgumentList @($ScriptPath, '--target', $Target, '--terminal', $TerminalExePath, '--json-out', $JsonPath)
    $exitCode = $run.exit_code
    $stdout = @($run.output)
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
        payload = $payload
        target_range_m1 = $targetRange
        target_pos_m1 = $targetPos
        source_range_m1 = $sourceRange
        source_pos_m1 = $sourcePos
        isolated_custom_failure = $isolatedFailure
        restored = $restored
    }
}

function Get-LatestDoneSidecar {
    param([string]$DoneDirectory, [string]$Target)
    return Get-ChildItem -LiteralPath $DoneDirectory -File -Filter "*_${Target}.import.txt" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

function Get-QueuedSidecar {
    param([string]$QueueDirectory, [string]$Target)
    return Get-ChildItem -LiteralPath $QueueDirectory -File -Filter "*${Target}.import.txt" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

function Invoke-VerifyImport {
    param(
        [string]$Python,
        [string]$ScriptPath,
        [string]$Symbol
    )
    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        return [pscustomobject]@{
            ran = $false
            exit_code = $null
            stdout = @("verify_import.py missing: $ScriptPath")
        }
    }

    $run = Invoke-ExternalCommand -FilePath $Python -ArgumentList @($ScriptPath, '--symbol', $Symbol, '--tail-basis', 'source', '--tail-tol-ms', '1000')
    return [pscustomobject]@{
        ran = $true
        exit_code = $run.exit_code
        stdout = @($run.output)
    }
}

function Get-TargetTerminalProcesses {
    param([string]$TerminalExePath)
    $resolved = [System.IO.Path]::GetFullPath($TerminalExePath)
    $hits = @(
        Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
            Where-Object {
                $_.ExecutablePath -and [string]::Equals(
                    [System.IO.Path]::GetFullPath($_.ExecutablePath),
                    $resolved,
                    [System.StringComparison]::OrdinalIgnoreCase
                )
            }
    )
    return $hits
}

function Invoke-ExternalCommand {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $quotedArgs = @()
    foreach ($arg in $ArgumentList) {
        if ($arg -match '[\s"]') {
            $quotedArgs += ('"{0}"' -f ($arg -replace '"', '\"'))
        } else {
            $quotedArgs += $arg
        }
    }
    $psi.Arguments = ($quotedArgs -join ' ')

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()

    $lines = @()
    if (-not [string]::IsNullOrWhiteSpace($stdout)) {
        $lines += @($stdout -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
    if (-not [string]::IsNullOrWhiteSpace($stderr)) {
        $lines += @($stderr -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    return [pscustomobject]@{
        exit_code = $proc.ExitCode
        output = $lines
    }
}

function Invoke-TerminalConfigRun {
    param(
        [string]$TerminalExePath,
        [string]$IniPath,
        [int]$TimeoutSeconds
    )

    $proc = Start-Process -FilePath $TerminalExePath -ArgumentList '/portable', "/config:$IniPath" -PassThru
    $finished = $proc.WaitForExit($TimeoutSeconds * 1000)
    if (-not $finished) {
        try { Stop-Process -Id $proc.Id -Force -ErrorAction Stop } catch {}
    }
    return [pscustomobject]@{
        pid = $proc.Id
        timed_out = (-not $finished)
        exit_code = if ($finished) { $proc.ExitCode } else { $null }
    }
}

$started = Get-Date
$startUtc = $started.ToUniversalTime()
$stableBefore = $started.AddMinutes(-1 * $MinStableMinutes)
$tickInfo = Get-Item -LiteralPath $tickCsv
$m1Info = Get-Item -LiteralPath $m1Csv
$csvStable = ($tickInfo.LastWriteTime -le $stableBefore) -and ($m1Info.LastWriteTime -le $stableBefore)

$preProbe = Invoke-VisibilityProbe -Python $PythonExe -ScriptPath $ProbeScript -Target $TargetSymbol -TerminalExePath $terminalExe -JsonPath $tmpProbeJson
$existingDone = Get-LatestDoneSidecar -DoneDirectory $doneDir -Target $TargetSymbol
$existingQueue = Get-QueuedSidecar -QueueDirectory $importQueueDir -Target $TargetSymbol

$action = 'noop_already_healthy'
$stageExit = $null
$stageOutput = @()
$restartAttempts = @()
$deleteReimport = [ordered]@{
    enabled = $AllowDeleteReimport.IsPresent
    attempted = $false
    compile_exit_code = $null
    compile_log = $deleteCompileLog
    delete_run = $null
    restage_exit_code = $null
}
$queueTimedOut = $false
$queueWaitSeconds = 0
$verify = [pscustomobject]@{
    ran = $false
    exit_code = $null
    stdout = @()
}

if (-not $preProbe.restored) {
    if (-not $csvStable) {
        $action = 'blocked_csv_not_stable'
    } elseif ($null -ne $existingQueue) {
        $action = 'wait_existing_queue'
    } else {
        $action = 'stage_prepare_import'
        $stageRun = Invoke-ExternalCommand -FilePath $PythonExe -ArgumentList @($PrepareImportScript, $tickCsv)
        $stageExit = $stageRun.exit_code
        $stageOutput = @($stageRun.output)

        if ($stageExit -ne 0) {
            $alreadyExists = ($stageOutput -join "`n") -match 'already exists'
            if ($alreadyExists -and $MaxRestartAttempts -gt 0) {
                $action = 'recover_runtime_restart'
                for ($attempt = 1; $attempt -le $MaxRestartAttempts; $attempt++) {
                    $procs = @(Get-TargetTerminalProcesses -TerminalExePath $terminalExe)
                    foreach ($p in $procs) {
                        try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop } catch {}
                    }
                    if ($procs.Count -gt 0) {
                        Start-Sleep -Seconds 2
                    }

                    $startedPid = $null
                    try {
                        $startedProc = Start-Process -FilePath $terminalExe -ArgumentList '/portable' -PassThru
                        $startedPid = $startedProc.Id
                    } catch {
                        $startedPid = $null
                    }

                    if ($PostStartWaitSeconds -gt 0) {
                        Start-Sleep -Seconds $PostStartWaitSeconds
                    }

                    $probeAttempt = Invoke-VisibilityProbe -Python $PythonExe -ScriptPath $ProbeScript -Target $TargetSymbol -TerminalExePath $terminalExe -JsonPath $tmpProbeJson
                    $restartAttempts += [pscustomobject]@{
                        attempt = $attempt
                        stopped_process_count = $procs.Count
                        started_pid = $startedPid
                        target_range_m1 = $probeAttempt.target_range_m1
                        target_pos_m1 = $probeAttempt.target_pos_m1
                        source_range_m1 = $probeAttempt.source_range_m1
                        source_pos_m1 = $probeAttempt.source_pos_m1
                        isolated_custom_failure = $probeAttempt.isolated_custom_failure
                        restored = $probeAttempt.restored
                    }

                    if ($probeAttempt.restored) {
                        break
                    }
                }
            }

            if ($alreadyExists -and $AllowDeleteReimport.IsPresent) {
                $latestProbe = Invoke-VisibilityProbe -Python $PythonExe -ScriptPath $ProbeScript -Target $TargetSymbol -TerminalExePath $terminalExe -JsonPath $tmpProbeJson
                if (-not $latestProbe.restored) {
                    $action = 'delete_reimport'
                    $deleteReimport.attempted = $true

                    $deleteScriptContent = @"
#property strict
#property version "1.00"
input string TargetSymbol = "$TargetSymbol";
void OnStart()
{
   long chart = ChartFirst();
   while(chart >= 0)
   {
      string cs = ChartSymbol(chart);
      long next = ChartNext(chart);
      if(cs == TargetSymbol)
         ChartClose(chart);
      chart = next;
   }
   SymbolSelect(TargetSymbol, false);
   Sleep(250);
   bool ok = false;
   for(int attempt=1; attempt<=10; attempt++)
   {
      ResetLastError();
      ok = CustomSymbolDelete(TargetSymbol);
      int err = GetLastError();
      PrintFormat("DELETE|target=%s|attempt=%d|ok=%s|err=%d", TargetSymbol, attempt, (ok ? "true" : "false"), err);
      if(ok) return;
      Sleep(500);
   }
}
"@

                    $writeScript = $true
                    if (Test-Path -LiteralPath $deleteScriptMq5) {
                        $existingScript = Get-Content -LiteralPath $deleteScriptMq5 -Raw
                        if ($existingScript -eq $deleteScriptContent) {
                            $writeScript = $false
                        }
                    }
                    if ($writeScript) {
                        Set-Content -LiteralPath $deleteScriptMq5 -Value $deleteScriptContent -Encoding ASCII
                    }

                    $compileRun = Invoke-ExternalCommand -FilePath $metaEditorExe -ArgumentList @("/compile:$deleteScriptMq5", "/log:$deleteCompileLog")
                    $deleteReimport.compile_exit_code = $compileRun.exit_code

                    if (-not (Test-Path -LiteralPath $deleteScriptEx5)) {
                        throw "Delete custom symbol script compile did not produce ex5: $deleteScriptEx5"
                    }
                    $compileLogText = if (Test-Path -LiteralPath $deleteCompileLog) { Get-Content -LiteralPath $deleteCompileLog -Raw } else { '' }
                    if ($compileLogText -match 'Result:\s+([1-9]\d*)\s+errors') {
                        throw "Delete custom symbol script compile log reports errors."
                    }

                    $deleteIni = @"
[StartUp]
Script=$deleteScriptBaseName
Symbol=EURUSD
Period=M1
ShutdownTerminal=1
"@
                    Set-Content -LiteralPath $deleteIniPath -Value $deleteIni -Encoding ASCII

                    $deleteProcs = @(Get-TargetTerminalProcesses -TerminalExePath $terminalExe)
                    foreach ($p in $deleteProcs) {
                        try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop } catch {}
                    }
                    if ($deleteProcs.Count -gt 0) {
                        Start-Sleep -Seconds 2
                    }

                    $deleteRun = Invoke-TerminalConfigRun -TerminalExePath $terminalExe -IniPath $deleteIniPath -TimeoutSeconds 300
                    $deleteReimport.delete_run = $deleteRun

                    $restageRun = Invoke-ExternalCommand -FilePath $PythonExe -ArgumentList @($PrepareImportScript, $tickCsv)
                    $deleteReimport.restage_exit_code = $restageRun.exit_code
                    $stageExit = $restageRun.exit_code
                    $stageOutput += @($restageRun.output)

                    # Ensure the MT5 service host is up so queued jobs can drain.
                    $runningAfterRestage = @(Get-TargetTerminalProcesses -TerminalExePath $terminalExe)
                    if ($runningAfterRestage.Count -eq 0) {
                        try { Start-Process -FilePath $terminalExe -ArgumentList '/portable' | Out-Null } catch {}
                        Start-Sleep -Seconds 3
                    }
                }
            }
        }
    }

    if (($action -eq 'wait_existing_queue') -or (($action -in @('stage_prepare_import', 'delete_reimport')) -and $stageExit -eq 0)) {
        $deadline = (Get-Date).AddSeconds($ImportTimeoutSeconds)
        while ((Get-Date) -lt $deadline) {
            $queued = Get-QueuedSidecar -QueueDirectory $importQueueDir -Target $TargetSymbol
            if ($null -eq $queued) {
                break
            }
            Start-Sleep -Seconds $PollSeconds
            $queueWaitSeconds += $PollSeconds
        }
        if ($null -ne (Get-QueuedSidecar -QueueDirectory $importQueueDir -Target $TargetSymbol)) {
            $queueTimedOut = $true
        }
    }

    $verify = Invoke-VerifyImport -Python $PythonExe -ScriptPath $VerifyImportScript -Symbol $TargetSymbol
}

$postProbe = Invoke-VisibilityProbe -Python $PythonExe -ScriptPath $ProbeScript -Target $TargetSymbol -TerminalExePath $terminalExe -JsonPath $tmpProbeJson
$latestDone = Get-LatestDoneSidecar -DoneDirectory $doneDir -Target $TargetSymbol
$ended = Get-Date

$status = 'not_restored'
if ($preProbe.restored -and $postProbe.restored) {
    $status = 'already_healthy'
} elseif ($postProbe.restored) {
    $status = 'restored'
} elseif ($action -eq 'blocked_csv_not_stable') {
    $status = 'blocked_csv_not_stable'
} elseif ($queueTimedOut) {
    $status = 'queue_timeout'
} elseif (($action -eq 'stage_prepare_import' -or $action -eq 'delete_reimport') -and $stageExit -ne 0) {
    $status = 'prepare_import_failed'
}

$evidence = [ordered]@{
    issue = $IssueId
    generated_at_local = $ended.ToString('yyyy-MM-ddTHH:mm:ssK')
    duration_seconds = [Math]::Round(($ended - $started).TotalSeconds, 3)
    terminal_root = $TerminalRoot
    terminal_exe = $terminalExe
    source_symbol = $SourceSymbol
    target_symbol = $TargetSymbol
    status = $status
    action = $action
    queue_wait_seconds = $queueWaitSeconds
    queue_timed_out = $queueTimedOut
    csv_inputs = [ordered]@{
        tick_csv = $tickCsv
        tick_bytes = [int64]$tickInfo.Length
        tick_last_write_local = $tickInfo.LastWriteTime.ToString('yyyy-MM-ddTHH:mm:ssK')
        m1_csv = $m1Csv
        m1_bytes = [int64]$m1Info.Length
        m1_last_write_local = $m1Info.LastWriteTime.ToString('yyyy-MM-ddTHH:mm:ssK')
        min_stable_minutes = $MinStableMinutes
        stable_before_local = $stableBefore.ToString('yyyy-MM-ddTHH:mm:ssK')
        stable = $csvStable
    }
    queue = [ordered]@{
        existing_queue_sidecar = if ($null -eq $existingQueue) { $null } else { $existingQueue.FullName }
        existing_done_sidecar = if ($null -eq $existingDone) { $null } else { $existingDone.FullName }
        latest_done_sidecar = if ($null -eq $latestDone) { $null } else { $latestDone.FullName }
        latest_done_after_start = if ($null -eq $latestDone) { $false } else { $latestDone.LastWriteTimeUtc -ge $startUtc }
    }
    stage_prepare_import = [ordered]@{
        script = $PrepareImportScript
        exit_code = $stageExit
        output = $stageOutput
    }
    runtime_recovery = [ordered]@{
        max_restart_attempts = $MaxRestartAttempts
        post_start_wait_seconds = $PostStartWaitSeconds
        attempts = $restartAttempts
    }
    delete_reimport = $deleteReimport
    verify_import = $verify
    probe = [ordered]@{
        pre = $preProbe
        post = $postProbe
    }
    next_action = if ($status -eq 'restored' -or $status -eq 'already_healthy') {
        'Run Step 22 Model-4 smoke rerun on T1 with EURUSD.DWX and attach evidence.'
    } elseif ($status -eq 'blocked_csv_not_stable') {
        'Wait until EURUSD tick and M1 CSV files are stable, then re-run this script.'
    } elseif ($status -eq 'queue_timeout') {
        'Inspect Import_DWX_Queue_Service and T1 terminal health, then re-run this script.'
    } else {
        'Investigate prepare_import/verify logs and escalate DWX runtime owner if needed.'
    }
}

$evidence | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $evidenceFull -Encoding UTF8

$summaryLines = @(
    '# QUA-270 EURUSD.DWX Seed - T1',
    '',
    ("- status: {0}" -f $status),
    ("- action: {0}" -f $action),
    ("- target bars pre (range/pos): {0}/{1}" -f $preProbe.target_range_m1, $preProbe.target_pos_m1),
    ("- target bars post (range/pos): {0}/{1}" -f $postProbe.target_range_m1, $postProbe.target_pos_m1),
    ("- source bars post (range/pos): {0}/{1}" -f $postProbe.source_range_m1, $postProbe.source_pos_m1),
    ("- queue_timed_out: {0}" -f $queueTimedOut),
    ("- latest_done_sidecar: {0}" -f $(if ($null -eq $latestDone) { '<none>' } else { $latestDone.FullName })),
    ("- evidence_json: {0}" -f $evidenceFull),
    ("- next_action: {0}" -f $evidence.next_action)
)
$summaryLines | Set-Content -LiteralPath $summaryFull -Encoding UTF8

if (Test-Path -LiteralPath $tmpProbeJson) {
    Remove-Item -LiteralPath $tmpProbeJson -Force
}

Write-Host ("status={0}" -f $status)
Write-Host ("evidence_json={0}" -f $evidenceFull)
Write-Host ("summary_md={0}" -f $summaryFull)
Write-Host ("target_bars_pre={0}/{1}" -f $preProbe.target_range_m1, $preProbe.target_pos_m1)
Write-Host ("target_bars_post={0}/{1}" -f $postProbe.target_range_m1, $postProbe.target_pos_m1)

if ($status -eq 'restored' -or $status -eq 'already_healthy') {
    exit 0
}

exit 2
