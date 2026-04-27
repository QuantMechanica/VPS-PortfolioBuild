[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$TerminalRoot = 'D:\QM\mt5\T1',
    [string]$TargetSymbol = 'XTIUSD.DWX',
    [string]$SourceSymbol = 'XTIUSD',
    [string]$PythonExe = 'python',
    [int]$ImportTimeoutMinutes = 30,
    [string]$OutReportJson = 'docs\ops\QUA-207_REIMPORT_REPAIR_XTIUSD_2026-04-27.json',
    [string]$OutReportMd = 'docs\ops\QUA-207_REIMPORT_REPAIR_XTIUSD_2026-04-27.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($TerminalRoot -match 'T6') {
    throw "Refusing T6 terminal scope: $TerminalRoot"
}
if ($ImportTimeoutMinutes -lt 1) {
    throw "ImportTimeoutMinutes must be >= 1."
}

$importsDir = Join-Path $TerminalRoot 'MQL5\Files\imports'
$doneDir = Join-Path $importsDir 'done'
$scriptsDir = Join-Path $TerminalRoot 'MQL5\Scripts'
$terminalExe = Join-Path $TerminalRoot 'terminal64.exe'
$metaEditorExe = Join-Path $TerminalRoot 'metaeditor64.exe'

foreach ($p in @($RepoRoot, $importsDir, $doneDir, $scriptsDir, $terminalExe, $metaEditorExe)) {
    if (-not (Test-Path -LiteralPath $p)) {
        throw "Required path missing: $p"
    }
}

$reportJsonFull = Join-Path $RepoRoot $OutReportJson
$reportMdFull = Join-Path $RepoRoot $OutReportMd
New-Item -ItemType Directory -Path (Split-Path -Parent $reportJsonFull) -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path -Parent $reportMdFull) -Force | Out-Null

function Stop-T1Process {
    param([string]$ExePath)
    $resolved = [System.IO.Path]::GetFullPath($ExePath)
    $hits = @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue | Where-Object {
        $_.ExecutablePath -and [string]::Equals(
            [System.IO.Path]::GetFullPath($_.ExecutablePath),
            $resolved,
            [System.StringComparison]::OrdinalIgnoreCase
        )
    })
    foreach ($p in $hits) {
        try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop } catch {}
    }
    if ($hits.Count -gt 0) {
        Start-Sleep -Seconds 2
    }
    return $hits.Count
}

function Parse-Sidecar {
    param([string]$Path)
    $kv = [ordered]@{}
    foreach ($line in (Get-Content -LiteralPath $Path)) {
        if ($line -notmatch '=') { continue }
        $i = $line.IndexOf('=')
        if ($i -lt 1) { continue }
        $k = $line.Substring(0, $i).Trim()
        $v = $line.Substring($i + 1).Trim()
        $kv[$k] = $v
    }
    return $kv
}

function Invoke-CompileScript {
    param(
        [string]$MetaEditor,
        [string]$ScriptMq5,
        [string]$CompileLog
    )
    & $MetaEditor "/compile:$ScriptMq5" "/log:$CompileLog" | Out-Null
    $code = $LASTEXITCODE
    return [pscustomobject]@{
        exit_code = $code
        log_path = $CompileLog
    }
}

function Invoke-TerminalConfigRun {
    param(
        [string]$TerminalExePath,
        [string]$IniPath,
        [int]$TimeoutMinutes
    )
    $p = Start-Process -FilePath $TerminalExePath -ArgumentList "/portable", "/config:$IniPath" -PassThru
    $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
    while (-not $p.HasExited -and (Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 2
        $p.Refresh()
    }
    $timedOut = -not $p.HasExited
    if ($timedOut) {
        try { Stop-Process -Id $p.Id -Force -ErrorAction Stop } catch {}
    }
    return [pscustomobject]@{
        pid = $p.Id
        timed_out = $timedOut
        exit_code = if ($timedOut) { $null } else { $p.ExitCode }
    }
}

$started = Get-Date

$latestSidecar = Get-ChildItem -LiteralPath $doneDir -Filter "*_${TargetSymbol}.import.txt" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if ($null -eq $latestSidecar) {
    throw "No archived sidecar found for target symbol: $TargetSymbol"
}

$sidecarKv = Parse-Sidecar -Path $latestSidecar.FullName
$tickBinName = [string]$sidecarKv['tick_bin']
$m1BinName = [string]$sidecarKv['m1_bin']
if ([string]::IsNullOrWhiteSpace($tickBinName) -or [string]::IsNullOrWhiteSpace($m1BinName)) {
    throw "Sidecar missing tick_bin or m1_bin: $($latestSidecar.FullName)"
}

$archivedTick = Get-ChildItem -LiteralPath $doneDir -Filter "*_${TargetSymbol}.tick.bin" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
$archivedM1 = Get-ChildItem -LiteralPath $doneDir -Filter "*_${TargetSymbol}.m1.bin" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if ($null -eq $archivedTick -or $null -eq $archivedM1) {
    throw "Archived binaries missing for target symbol: $TargetSymbol"
}

$queuedSidecar = Join-Path $importsDir "${TargetSymbol}.import.txt"
$queuedTick = Join-Path $importsDir $tickBinName
$queuedM1 = Join-Path $importsDir $m1BinName

$deleteScriptMq5 = Join-Path $scriptsDir 'Delete_One_Custom_Symbol.mq5'
$deleteScriptEx5 = Join-Path $scriptsDir 'Delete_One_Custom_Symbol.ex5'
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
   int total = SymbolsTotal(false);
   bool exists = false;
   for(int i=0; i<total; i++)
      if(SymbolName(i,false) == TargetSymbol) { exists = true; break; }
   if(!exists)
   {
      PrintFormat("DELETE|target=%s|status=absent", TargetSymbol);
      return;
   }
   bool ok = false;
   int err = 0;
   for(int attempt=1; attempt<=10; attempt++)
   {
      ResetLastError();
      ok = CustomSymbolDelete(TargetSymbol);
      err = GetLastError();
      PrintFormat("DELETE|target=%s|attempt=%d|ok=%s|err=%d", TargetSymbol, attempt, (ok ? "true" : "false"), err);
      if(ok) break;
      Sleep(500);
   }
}
"@

$needsWrite = $true
if (Test-Path -LiteralPath $deleteScriptMq5) {
    $existing = Get-Content -LiteralPath $deleteScriptMq5 -Raw
    if ($existing -eq $deleteScriptContent) {
        $needsWrite = $false
    }
}
if ($needsWrite) {
    Set-Content -LiteralPath $deleteScriptMq5 -Value $deleteScriptContent -Encoding ASCII
}

$compileLog = Join-Path $scriptsDir 'Delete_One_Custom_Symbol.compile.log'
$compile = Invoke-CompileScript -MetaEditor $metaEditorExe -ScriptMq5 $deleteScriptMq5 -CompileLog $compileLog
if (-not (Test-Path -LiteralPath $deleteScriptEx5)) {
    throw "Delete_One_Custom_Symbol compile did not produce ex5: $deleteScriptEx5"
}
$compileLogText = if (Test-Path -LiteralPath $compileLog) { Get-Content -LiteralPath $compileLog -Raw } else { '' }
if ($compileLogText -match 'Result:\s+([1-9]\d*)\s+errors') {
    throw "Delete_One_Custom_Symbol compile log reports errors."
}

$deleteIni = Join-Path $TerminalRoot 'run_delete_one_custom_symbol.ini'
$deleteIniContent = @"
[StartUp]
Script=Delete_One_Custom_Symbol
Symbol=EURUSD
Period=M1
ShutdownTerminal=1
"@
Set-Content -LiteralPath $deleteIni -Value $deleteIniContent -Encoding ASCII

$importIni = Join-Path $TerminalRoot 'run_import_dwx_from_bin.ini'
$importIniContent = @"
[StartUp]
Script=Import_DWX_From_Bin
Symbol=EURUSD
Period=M1
ShutdownTerminal=1
"@
Set-Content -LiteralPath $importIni -Value $importIniContent -Encoding ASCII

$stoppedBeforeDelete = Stop-T1Process -ExePath $terminalExe
$deleteRun = Invoke-TerminalConfigRun -TerminalExePath $terminalExe -IniPath $deleteIni -TimeoutMinutes 5

$queueRestaged = $false
Copy-Item -LiteralPath $latestSidecar.FullName -Destination $queuedSidecar -Force
Copy-Item -LiteralPath $archivedTick.FullName -Destination $queuedTick -Force
Copy-Item -LiteralPath $archivedM1.FullName -Destination $queuedM1 -Force
$queueRestaged = $true

$stoppedBeforeImport = Stop-T1Process -ExePath $terminalExe
$importRun = Invoke-TerminalConfigRun -TerminalExePath $terminalExe -IniPath $importIni -TimeoutMinutes $ImportTimeoutMinutes

$proofScript = Join-Path $RepoRoot 'infra\scripts\Run-QUA95CustomVisibilityProof.ps1'
if (-not (Test-Path -LiteralPath $proofScript)) {
    throw "Proof script missing: $proofScript"
}
$proofOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $proofScript -RepoRoot $RepoRoot -Target $TargetSymbol -ProbeScript (Join-Path $RepoRoot 'infra\scripts\probe_custom_symbol_visibility.py') 2>&1
$proofExit = $LASTEXITCODE

$probeEvidencePath = Join-Path $RepoRoot 'lessons-learned\evidence\2026-04-27_qua95_xtiusd_custom_visibility_probe_rerun.json'
$probeEvidence = $null
if (Test-Path -LiteralPath $probeEvidencePath) {
    $probeEvidence = Get-Content -LiteralPath $probeEvidencePath -Raw | ConvertFrom-Json
}

$ended = Get-Date
$status = 'failed'
if ($proofExit -eq 0 -and $null -ne $probeEvidence) {
    $targetRange = [int]$probeEvidence.target_probe.rates_range_m1_count
    $targetPos = [int]$probeEvidence.target_probe.rates_from_pos_m1_count
    if ($targetRange -gt 0 -or $targetPos -gt 0) {
        $status = 'restored'
    } else {
        $status = 'not_restored'
    }
}

$report = [ordered]@{
    issue = 'QUA-207'
    generated_at_local = $ended.ToString('yyyy-MM-ddTHH:mm:ssK')
    target_symbol = $TargetSymbol
    source_symbol = $SourceSymbol
    terminal_root = $TerminalRoot
    status = $status
    duration_seconds = [Math]::Round(($ended - $started).TotalSeconds, 3)
    restage = [ordered]@{
        source_sidecar = $latestSidecar.FullName
        source_tick_bin = $archivedTick.FullName
        source_m1_bin = $archivedM1.FullName
        queued_sidecar = $queuedSidecar
        queued_tick_bin = $queuedTick
        queued_m1_bin = $queuedM1
    }
    compile = $compile
    delete_step = [ordered]@{
        stopped_processes = $stoppedBeforeDelete
        run = $deleteRun
        ini = $deleteIni
    }
    import_step = [ordered]@{
        stopped_processes = $stoppedBeforeImport
        run = $importRun
        ini = $importIni
        timeout_minutes = $ImportTimeoutMinutes
        queue_restaged = $queueRestaged
    }
    proof = [ordered]@{
        exit_code = $proofExit
        evidence_path = $probeEvidencePath
        target_range_m1 = if ($null -eq $probeEvidence) { $null } else { [int]$probeEvidence.target_probe.rates_range_m1_count }
        target_pos_m1 = if ($null -eq $probeEvidence) { $null } else { [int]$probeEvidence.target_probe.rates_from_pos_m1_count }
        source_range_m1 = if ($null -eq $probeEvidence) { $null } else { [int]$probeEvidence.source_probe.rates_range_m1_count }
        source_pos_m1 = if ($null -eq $probeEvidence) { $null } else { [int]$probeEvidence.source_probe.rates_from_pos_m1_count }
        isolated_custom_failure = if ($null -eq $probeEvidence) { $null } else { [bool]$probeEvidence.isolated_custom_bars_visibility_failure }
        output = @($proofOutput | ForEach-Object { $_.ToString() })
    }
    next_action = if ($status -eq 'restored') {
        'Run direct verifier proof and unblock readiness chain.'
    } else {
        'Escalate to runtime owner for manual MT5 custom-symbol recovery and rerun this script.'
    }
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $reportJsonFull -Encoding UTF8

$md = @(
    '# QUA-207 Reimport Repair - XTIUSD.DWX (2026-04-27)',
    '',
    ("- status: {0}" -f $status),
    ("- target bars (range/pos): {0}/{1}" -f $report.proof.target_range_m1, $report.proof.target_pos_m1),
    ("- source bars (range/pos): {0}/{1}" -f $report.proof.source_range_m1, $report.proof.source_pos_m1),
    ("- isolated_custom_failure: {0}" -f $report.proof.isolated_custom_failure),
    ("- report_json: {0}" -f $reportJsonFull),
    ("- probe_evidence: {0}" -f $probeEvidencePath),
    ("- next_action: {0}" -f $report.next_action)
)
$md | Set-Content -LiteralPath $reportMdFull -Encoding UTF8

Write-Host ("status={0}" -f $status)
Write-Host ("report_json={0}" -f $reportJsonFull)
Write-Host ("report_md={0}" -f $reportMdFull)
Write-Host ("probe_evidence={0}" -f $probeEvidencePath)

if ($status -eq 'restored') {
    exit 0
}

exit 2
