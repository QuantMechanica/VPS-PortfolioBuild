[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AgentTaskId,

    [ValidateRange(30, 600)]
    [int]$CompileTimeoutSeconds = 120,

    [ValidateRange(30, 600)]
    [int]$RunTimeoutSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ExpectedOperation = "framework_h5_dwx_tickvalue_verify"
$ExpectedTerminalRoot = "D:\QM\mt5\T_Export"
$ReportRoot = "D:\QM\reports\state"
$AgentTaskDb = "D:\QM\strategy_farm\state\farm_state.sqlite"
$CommonFilesRoot = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files"
$StageCsvRelative = "QM\state\dwx_tickvalue_dump_staging.csv"
$StageMarkerRelative = "QM\state\dwx_tickvalue_dump_complete.marker"
$ExpectedSymbols = @(
    "NDX.DWX",
    "WS30.DWX",
    "SP500.DWX",
    "GDAXI.DWX",
    "XAUUSD.DWX",
    "XTIUSD.DWX",
    "XNGUSD.DWX"
)
$ExpectedColumns = @(
    "schema_version", "timestamp_utc", "terminal_id", "terminal_build", "server",
    "account_currency", "symbol", "symbol_exists", "symbol_custom", "symbol_selected",
    "trade_calc_mode", "trade_calc_mode_name", "currency_base", "currency_profit",
    "currency_margin", "digits", "point", "tick_size", "tick_value", "tick_value_profit",
    "tick_value_loss", "contract_size", "volume_min", "volume_max", "volume_step", "bid",
    "ask", "last", "reference_price", "risk_money", "probe_ticks", "price_delta", "sl_points",
    "buy_profit_ok", "buy_profit_error", "buy_profit", "buy_loss_ok", "buy_loss_error",
    "buy_loss", "sell_profit_ok", "sell_profit_error", "sell_profit", "sell_loss_ok",
    "sell_loss_error", "sell_loss", "ordercalc_tick_value_profit", "ordercalc_tick_value_loss",
    "ordercalc_tick_value_conservative", "snapshot_ok", "snapshot_tick_value",
    "snapshot_tick_size", "snapshot_point", "snapshot_contract_size", "framework_value_path",
    "framework_point_value_per_lot", "framework_loss_per_lot", "framework_raw_lots",
    "framework_quantized_lots", "ordercalc_loss_per_lot", "ordercalc_raw_lots",
    "ordercalc_quantized_lots", "framework_lots_ordercalc_loss", "tick_value_rel_diff_pct",
    "raw_lots_rel_diff_pct", "quantized_lots_match", "verdict", "error_class"
)
$ExpectedHeader = $ExpectedColumns -join ","
$ForbiddenTerminalRoots = @(
    "D:\QM\mt5\T1", "D:\QM\mt5\T2", "D:\QM\mt5\T3", "D:\QM\mt5\T4",
    "D:\QM\mt5\T5", "D:\QM\mt5\T6", "D:\QM\mt5\T7", "D:\QM\mt5\T8",
    "D:\QM\mt5\T9", "D:\QM\mt5\T10", "D:\QM\mt5\T_Live",
    "C:\QM\mt5\T_Live", "C:\QM\mt5\T_Live\MT5_Base"
)

function Get-NormalizedPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    return [System.IO.Path]::GetFullPath($Path).TrimEnd("\", "/")
}

function Test-PathWithinRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $candidate = Get-NormalizedPath -Path $Path
    $rootPath = Get-NormalizedPath -Path $Root
    if ($candidate.Equals($rootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }
    return $candidate.StartsWith(
        $rootPath + [System.IO.Path]::DirectorySeparatorChar,
        [System.StringComparison]::OrdinalIgnoreCase
    )
}

function Assert-PathWithinRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if (-not (Test-PathWithinRoot -Path $Path -Root $Root)) {
        throw "$Label escapes the allowed root '$Root': $Path"
    }
}

function Assert-NotForbiddenTerminalPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )

    foreach ($forbiddenRoot in $ForbiddenTerminalRoots) {
        if (Test-PathWithinRoot -Path $Path -Root $forbiddenRoot) {
            throw "$Label resolves inside forbidden terminal root '$forbiddenRoot': $Path"
        }
    }
}

function Assert-NoReparsePoint {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $item = Get-Item -LiteralPath $Path -Force
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "$Label must not be a reparse point: $Path"
    }
}

function Get-TExportProcesses {
    param([Parameter(Mandatory = $true)][string]$TerminalRoot)

    $processNames = @(
        "terminal64.exe", "terminal.exe", "metaeditor64.exe", "metaeditor.exe",
        "metatester64.exe", "metatester.exe"
    )
    $rootPath = Get-NormalizedPath -Path $TerminalRoot
    $rootNeedle = $rootPath + [System.IO.Path]::DirectorySeparatorChar
    return @(
        Get-CimInstance Win32_Process -ErrorAction Stop |
            Where-Object { $processNames -contains $_.Name.ToLowerInvariant() } |
            Where-Object {
                $executableMatch = $_.ExecutablePath -and
                    (Test-PathWithinRoot -Path $_.ExecutablePath -Root $rootPath)
                $commandMatch = $_.CommandLine -and
                    $_.CommandLine.Contains($rootNeedle, [System.StringComparison]::OrdinalIgnoreCase)
                $executableMatch -or $commandMatch
            }
    )
}

function Assert-TExportIdle {
    param([Parameter(Mandatory = $true)][string]$TerminalRoot)

    $busy = @(Get-TExportProcesses -TerminalRoot $TerminalRoot)
    if ($busy.Count -gt 0) {
        $identities = ($busy | ForEach-Object { "$($_.Name):$($_.ProcessId)" }) -join ", "
        throw "T_Export is not parked: $identities"
    }
}

function Stop-TExportProcessesAfterTimeout {
    param([Parameter(Mandatory = $true)][string]$TerminalRoot)

    foreach ($process in @(Get-TExportProcesses -TerminalRoot $TerminalRoot)) {
        if ($process.ExecutablePath) {
            Assert-PathWithinRoot -Path $process.ExecutablePath -Root $TerminalRoot -Label "timeout process"
            Assert-NotForbiddenTerminalPath -Path $process.ExecutablePath -Label "timeout process"
        }
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    }
}

function Wait-ExactProcess {
    param(
        [Parameter(Mandatory = $true)][System.Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true)][string]$ExpectedExecutable,
        [Parameter(Mandatory = $true)][int]$TimeoutSeconds,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if ($Process.WaitForExit($TimeoutSeconds * 1000)) {
        return
    }

    $identity = Get-CimInstance Win32_Process -Filter "ProcessId=$($Process.Id)" -ErrorAction SilentlyContinue
    if ($identity -and $identity.ExecutablePath) {
        $actual = Get-NormalizedPath -Path $identity.ExecutablePath
        $expected = Get-NormalizedPath -Path $ExpectedExecutable
        if (-not $actual.Equals($expected, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "$Label timed out, but PID $($Process.Id) no longer belongs to the expected executable; refusing termination."
        }
        Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
    }
    throw "$Label timed out after $TimeoutSeconds seconds."
}

function Assert-AgentTaskAuthorization {
    param(
        [Parameter(Mandatory = $true)][string]$TaskId,
        [Parameter(Mandatory = $true)][string]$DatabasePath
    )

    $parsedGuid = [guid]::Empty
    if (-not [guid]::TryParse($TaskId, [ref]$parsedGuid)) {
        throw "AgentTaskId must be a GUID."
    }
    if (-not (Test-Path -LiteralPath $DatabasePath -PathType Leaf)) {
        throw "Agent task database not found: $DatabasePath"
    }

    $query = @'
import json
import sqlite3
import sys

db_path, task_id = sys.argv[1], sys.argv[2]
uri = "file:" + db_path.replace("\\", "/") + "?mode=ro"
connection = sqlite3.connect(uri, uri=True)
connection.row_factory = sqlite3.Row
row = connection.execute(
    "SELECT task_type, state, assigned_agent, payload_json FROM agent_tasks WHERE id=?",
    (task_id,),
).fetchone()
connection.close()
if row is None:
    print(json.dumps({"found": False}))
    raise SystemExit(0)
try:
    payload = json.loads(row["payload_json"] or "{}")
except json.JSONDecodeError:
    payload = {}
print(json.dumps({
    "found": True,
    "task_type": row["task_type"],
    "state": row["state"],
    "assigned_agent": row["assigned_agent"],
    "operation": payload.get("operation"),
    "terminal": payload.get("terminal"),
    "allow_terminal_launch": payload.get("allow_terminal_launch"),
    "verify_only": payload.get("verify_only"),
    "sizing_changes": payload.get("sizing_changes"),
}))
'@

    $queryResult = $query | & python - $DatabasePath $TaskId
    if ($LASTEXITCODE -ne 0) {
        throw "Read-only agent task authorization query failed with exit code $LASTEXITCODE."
    }
    $authorization = ($queryResult -join "`n") | ConvertFrom-Json
    if (-not $authorization.found) {
        throw "Agent task not found: $TaskId"
    }
    if ($authorization.task_type -ne "ops_issue" -or $authorization.state -ne "IN_PROGRESS") {
        throw "Agent task must be an IN_PROGRESS ops_issue."
    }
    if ($authorization.assigned_agent -ne "codex") {
        throw "Agent task must be assigned to codex."
    }
    if ($authorization.operation -ne $ExpectedOperation -or $authorization.terminal -ne "T_Export") {
        throw "Agent task payload does not authorize the H5 T_Export operation."
    }
    if ($authorization.allow_terminal_launch -ne $true -or
        $authorization.verify_only -ne $true -or
        $authorization.sizing_changes -ne $false) {
        throw "Agent task payload must set allow_terminal_launch=true, verify_only=true, sizing_changes=false."
    }
}

function Parse-CompileCounts {
    param([Parameter(Mandatory = $true)][string]$LogContent)

    $matches = [regex]::Matches(
        $LogContent,
        "(?im)(?<errors>\d+)\s+errors?\s*,\s*(?<warnings>\d+)\s+warnings?"
    )
    if ($matches.Count -eq 0) {
        throw "MetaEditor compile log has no errors/warnings summary."
    }
    $last = $matches[$matches.Count - 1]
    return [pscustomobject]@{
        errors = [int]$last.Groups["errors"].Value
        warnings = [int]$last.Groups["warnings"].Value
    }
}

function Read-CompletionMarker {
    param([Parameter(Mandatory = $true)][string]$Path)

    $values = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        $separator = $line.IndexOf("=")
        if ($separator -le 0) {
            continue
        }
        $values[$line.Substring(0, $separator)] = $line.Substring($separator + 1)
    }
    return $values
}

function Write-SanitizedTerminalLog {
    param(
        [Parameter(Mandatory = $true)][string]$TerminalRoot,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $log = Get-ChildItem -LiteralPath (Join-Path $TerminalRoot "logs") -Filter "*.log" -File |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
    if (-not $log) {
        throw "T_Export produced no terminal log."
    }

    $lines = @(Get-Content -LiteralPath $log.FullName -Tail 800)
    $selected = @(
        $lines | Where-Object {
            $_ -match "QM_DWX_TICKVALUE|QM_Dump_DWX_TickValue"
        }
    )
    if ($selected.Count -eq 0) {
        $selected = @("[no matching H5 terminal log lines found]")
    }
    $sanitized = @(
        $selected | ForEach-Object {
            $line = [string]$_
            if ($line -match "(?i)password|credential") {
                "[redacted-sensitive-line]"
            } else {
                $line -replace "\b\d{6,}\b", "<redacted-id>"
            }
        }
    )
    $sanitized | Set-Content -LiteralPath $Destination -Encoding utf8NoBOM
}

function Publish-AtomicFile {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [Parameter(Mandatory = $true)][string]$RunTag
    )

    if (Test-Path -LiteralPath $Destination) {
        throw "Refusing to overwrite evidence: $Destination"
    }
    $temporary = "$Destination.$RunTag.tmp"
    if (Test-Path -LiteralPath $temporary) {
        Remove-Item -LiteralPath $temporary -Force
    }
    Copy-Item -LiteralPath $Source -Destination $temporary
    Move-Item -LiteralPath $temporary -Destination $Destination
}

$deployedScriptRoot = $null
$terminal = $null
$workRoot = $null
$publishComplete = $false

try {
Assert-AgentTaskAuthorization -TaskId $AgentTaskId -DatabasePath $AgentTaskDb

$terminalRoot = (Resolve-Path -LiteralPath $ExpectedTerminalRoot).Path
$normalizedTerminalRoot = Get-NormalizedPath -Path $terminalRoot
$normalizedExpectedRoot = Get-NormalizedPath -Path $ExpectedTerminalRoot
if (-not $normalizedTerminalRoot.Equals($normalizedExpectedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Terminal root drifted from the only authorized root: $terminalRoot"
}
Assert-NoReparsePoint -Path $terminalRoot -Label "T_Export root"
Assert-NotForbiddenTerminalPath -Path $terminalRoot -Label "T_Export root"

$terminalExe = (Resolve-Path -LiteralPath (Join-Path $terminalRoot "terminal64.exe")).Path
$metaEditorExe = (Resolve-Path -LiteralPath (Join-Path $terminalRoot "MetaEditor64.exe")).Path
foreach ($executable in @($terminalExe, $metaEditorExe)) {
    Assert-PathWithinRoot -Path $executable -Root $terminalRoot -Label "T_Export executable"
    Assert-NotForbiddenTerminalPath -Path $executable -Label "T_Export executable"
    Assert-NoReparsePoint -Path $executable -Label "T_Export executable"
}
Assert-TExportIdle -TerminalRoot $terminalRoot

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path
$sourcePath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "QM_Dump_DWX_TickValue.mq5")).Path
$riskSizerPath = (Resolve-Path -LiteralPath (Join-Path $repoRoot "framework\include\QM\QM_RiskSizer.mqh")).Path
$sourceHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash
$riskSizerHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $riskSizerPath).Hash

$utcNow = (Get-Date).ToUniversalTime()
$dateTag = $utcNow.ToString("yyyy-MM-dd")
$runTag = $utcNow.ToString("yyyyMMddTHHmmssZ") + "_" + ([guid]::NewGuid().ToString("N").Substring(0, 8))
$evidenceBase = "dwx_tickvalue_dump_$dateTag"
$finalCsv = Join-Path $ReportRoot "$evidenceBase.csv"
$finalManifest = Join-Path $ReportRoot "$evidenceBase.json"
$finalCompileLog = Join-Path $ReportRoot "${evidenceBase}_compile.log"
$finalTerminalLog = Join-Path $ReportRoot "${evidenceBase}_terminal.log"
foreach ($finalPath in @($finalCsv, $finalManifest, $finalCompileLog, $finalTerminalLog)) {
    if (Test-Path -LiteralPath $finalPath) {
        throw "Refusing to overwrite existing H5 evidence: $finalPath"
    }
}

New-Item -ItemType Directory -Path $ReportRoot -Force | Out-Null
$workRoot = Join-Path $ReportRoot ".dwx_tickvalue_dump_$runTag"
New-Item -ItemType Directory -Path $workRoot | Out-Null
Assert-PathWithinRoot -Path $workRoot -Root $ReportRoot -Label "run work directory"

$stagedRepoRoot = Join-Path $workRoot "source"
$stagedMq5 = Join-Path $stagedRepoRoot "framework\scripts\mt5_diagnostics\QM_Dump_DWX_TickValue.mq5"
$stagedRiskSizer = Join-Path $stagedRepoRoot "framework\include\QM\QM_RiskSizer.mqh"
New-Item -ItemType Directory -Path (Split-Path -Parent $stagedMq5) -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path -Parent $stagedRiskSizer) -Force | Out-Null
Copy-Item -LiteralPath $sourcePath -Destination $stagedMq5
Copy-Item -LiteralPath $riskSizerPath -Destination $stagedRiskSizer

$compileLogTemp = Join-Path $workRoot "compile.log"
$compileStartedUtc = (Get-Date).ToUniversalTime()
$metaEditor = Start-Process -FilePath $metaEditorExe -ArgumentList @(
    "/compile:$stagedMq5",
    "/log:$compileLogTemp"
) -PassThru -WindowStyle Hidden
Wait-ExactProcess -Process $metaEditor -ExpectedExecutable $metaEditorExe `
    -TimeoutSeconds $CompileTimeoutSeconds -Label "T_Export diagnostic compile"
if (-not (Test-Path -LiteralPath $compileLogTemp -PathType Leaf)) {
    throw "MetaEditor did not produce the requested compile log: $compileLogTemp"
}
$compileLogContent = Get-Content -Raw -LiteralPath $compileLogTemp
$compileCounts = Parse-CompileCounts -LogContent $compileLogContent
if ($compileCounts.errors -ne 0 -or $compileCounts.warnings -ne 0) {
    throw "H5 diagnostic compile failed: exit=$($metaEditor.ExitCode) errors=$($compileCounts.errors) warnings=$($compileCounts.warnings). Evidence: $compileLogTemp"
}
$stagedEx5 = [System.IO.Path]::ChangeExtension($stagedMq5, ".ex5")
if (-not (Test-Path -LiteralPath $stagedEx5 -PathType Leaf)) {
    throw "MetaEditor reported success but produced no EX5: $stagedEx5"
}
if ((Get-Item -LiteralPath $stagedEx5).LastWriteTimeUtc -lt $compileStartedUtc.AddSeconds(-2)) {
    throw "Compiled EX5 predates this run: $stagedEx5"
}

Assert-TExportIdle -TerminalRoot $terminalRoot
$deployedScriptRoot = Join-Path $terminalRoot "MQL5\Scripts\QM_Diagnostics\$runTag"
Assert-PathWithinRoot -Path $deployedScriptRoot -Root $terminalRoot -Label "diagnostic deployment"
Assert-NotForbiddenTerminalPath -Path $deployedScriptRoot -Label "diagnostic deployment"
New-Item -ItemType Directory -Path $deployedScriptRoot | Out-Null
$deployedEx5 = Join-Path $deployedScriptRoot "QM_Dump_DWX_TickValue.ex5"
Copy-Item -LiteralPath $stagedEx5 -Destination $deployedEx5

$commonStateRoot = Join-Path $CommonFilesRoot "QM\state"
New-Item -ItemType Directory -Path $commonStateRoot -Force | Out-Null
$stageCsv = Join-Path $CommonFilesRoot $StageCsvRelative
$stageMarker = Join-Path $CommonFilesRoot $StageMarkerRelative
Assert-PathWithinRoot -Path $stageCsv -Root $CommonFilesRoot -Label "FILE_COMMON CSV"
Assert-PathWithinRoot -Path $stageMarker -Root $CommonFilesRoot -Label "FILE_COMMON marker"
foreach ($staleStage in @($stageCsv, $stageMarker)) {
    if (Test-Path -LiteralPath $staleStage) {
        Remove-Item -LiteralPath $staleStage -Force
    }
}

$startupIni = Join-Path $workRoot "run_h5_tickvalue.ini"
$scriptName = "QM_Diagnostics\$runTag\QM_Dump_DWX_TickValue"
@(
    "[StartUp]",
    "Script=$scriptName",
    "ShutdownTerminal=1"
) | Set-Content -LiteralPath $startupIni -Encoding ascii

$runStartedUtc = (Get-Date).ToUniversalTime()
$terminal = Start-Process -FilePath $terminalExe -ArgumentList @(
    "/portable",
    "/config:$startupIni"
) -PassThru -WindowStyle Hidden

$deadline = [DateTime]::UtcNow.AddSeconds($RunTimeoutSeconds)
$runFinished = $false
while ([DateTime]::UtcNow -lt $deadline) {
    Start-Sleep -Milliseconds 500
    $scopedProcesses = @(Get-TExportProcesses -TerminalRoot $terminalRoot)
    if ((Test-Path -LiteralPath $stageMarker -PathType Leaf) -and $scopedProcesses.Count -eq 0) {
        $runFinished = $true
        break
    }
    if ($terminal.HasExited -and $scopedProcesses.Count -eq 0 -and
        -not (Test-Path -LiteralPath $stageMarker -PathType Leaf)) {
        break
    }
}
if (-not $runFinished) {
    Stop-TExportProcessesAfterTimeout -TerminalRoot $terminalRoot
    throw "T_Export diagnostic did not complete within $RunTimeoutSeconds seconds. Work evidence: $workRoot"
}
Assert-TExportIdle -TerminalRoot $terminalRoot
$terminal.Refresh()
$terminalExitCode = if ($terminal.HasExited) { $terminal.ExitCode } else { $null }
if ($null -ne $terminalExitCode -and $terminalExitCode -ne 0) {
    throw "T_Export exited with code $terminalExitCode."
}

if (-not (Test-Path -LiteralPath $stageCsv -PathType Leaf)) {
    throw "Completion marker exists but FILE_COMMON CSV is missing: $stageCsv"
}
$marker = Read-CompletionMarker -Path $stageMarker
if ($marker["status"] -ne "COMPLETE" -or $marker["schema_version"] -ne "1" -or
    [int]$marker["rows"] -ne 7 -or $marker["csv"] -ne $StageCsvRelative) {
    throw "FILE_COMMON completion marker failed validation: $stageMarker"
}

$actualHeader = Get-Content -LiteralPath $stageCsv -TotalCount 1
if ($actualHeader -cne $ExpectedHeader) {
    throw "H5 CSV header does not match the checked-in schema."
}
$rows = @(Import-Csv -LiteralPath $stageCsv)
if ($rows.Count -ne 7) {
    throw "H5 CSV must contain exactly 7 data rows; got $($rows.Count)."
}
$actualSymbols = @($rows | ForEach-Object { $_.symbol })
$symbolDifference = @(Compare-Object -ReferenceObject $ExpectedSymbols -DifferenceObject $actualSymbols)
if ($symbolDifference.Count -ne 0 -or @($actualSymbols | Select-Object -Unique).Count -ne 7) {
    throw "H5 CSV symbol set or uniqueness check failed."
}
if (@($rows | Where-Object { $_.schema_version -ne "1" }).Count -ne 0) {
    throw "H5 CSV contains an unexpected schema version."
}
if (@($rows | Where-Object { $_.terminal_id -ne "T_Export" }).Count -ne 0) {
    throw "H5 CSV was not produced by T_Export."
}
if (@($rows | Where-Object { [string]::IsNullOrWhiteSpace($_.account_currency) }).Count -ne 0) {
    throw "H5 CSV is missing the required account_currency."
}
$accountCurrencies = @($rows.account_currency | Select-Object -Unique)
if ($accountCurrencies.Count -ne 1) {
    throw "H5 CSV contains inconsistent account currencies."
}
$terminalBuilds = @($rows.terminal_build | Select-Object -Unique)
if ($terminalBuilds.Count -ne 1 -or [string]::IsNullOrWhiteSpace($terminalBuilds[0])) {
    throw "H5 CSV contains an invalid terminal build identity."
}
$allowedVerdicts = @("MATCH", "CONSERVATIVE_UNDERSIZE", "OVER_RISK", "DIVERGENT", "UNRESOLVED")
if (@($rows | Where-Object { $allowedVerdicts -notcontains $_.verdict }).Count -ne 0) {
    throw "H5 CSV contains an unknown verdict."
}
$unresolvedCount = @($rows | Where-Object { $_.verdict -eq "UNRESOLVED" }).Count
if ([int]$marker["unresolved_count"] -ne $unresolvedCount) {
    throw "Completion marker unresolved_count does not match the CSV."
}

$sourceHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash
$riskSizerHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $riskSizerPath).Hash
if ($sourceHashAfter -ne $sourceHashBefore) {
    throw "Diagnostic source changed while the runner was executing."
}
if ($riskSizerHashAfter -ne $riskSizerHashBefore) {
    throw "QM_RiskSizer.mqh changed while the verification-only runner was executing."
}

$terminalLogTemp = Join-Path $workRoot "terminal_sanitized.log"
Write-SanitizedTerminalLog -TerminalRoot $terminalRoot -Destination $terminalLogTemp
Publish-AtomicFile -Source $stageCsv -Destination $finalCsv -RunTag $runTag
Publish-AtomicFile -Source $compileLogTemp -Destination $finalCompileLog -RunTag $runTag
Publish-AtomicFile -Source $terminalLogTemp -Destination $finalTerminalLog -RunTag $runTag

$verdictCounts = [ordered]@{}
foreach ($group in @($rows | Group-Object verdict | Sort-Object Name)) {
    $verdictCounts[$group.Name] = $group.Count
}
$manifest = [ordered]@{
    schema_version = 1
    operation = $ExpectedOperation
    result = if ($unresolvedCount -eq 0) { "PASS" } else { "INCOMPLETE" }
    timestamp_utc = (Get-Date).ToUniversalTime().ToString("o")
    run_started_utc = $runStartedUtc.ToString("o")
    agent_task_id = $AgentTaskId
    terminal_id = "T_Export"
    terminal_root = $terminalRoot
    terminal_build = $terminalBuilds[0]
    terminal_exit_code = $terminalExitCode
    account_currency = $accountCurrencies[0]
    symbols = $ExpectedSymbols
    row_count = $rows.Count
    unresolved_count = $unresolvedCount
    verdict_counts = $verdictCounts
    source = [ordered]@{
        path = $sourcePath
        sha256 = $sourceHashBefore
    }
    risk_sizer = [ordered]@{
        path = $riskSizerPath
        sha256_before = $riskSizerHashBefore
        sha256_after = $riskSizerHashAfter
        unchanged = ($riskSizerHashBefore -eq $riskSizerHashAfter)
    }
    compiled_ex5_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $stagedEx5).Hash
    compile = [ordered]@{
        metaeditor_path = $metaEditorExe
        exit_code = $metaEditor.ExitCode
        errors = $compileCounts.errors
        warnings = $compileCounts.warnings
    }
    completion_marker_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $stageMarker).Hash
    evidence = [ordered]@{
        csv = $finalCsv
        csv_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $finalCsv).Hash
        compile_log = $finalCompileLog
        compile_log_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $finalCompileLog).Hash
        terminal_log = $finalTerminalLog
        terminal_log_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $finalTerminalLog).Hash
    }
    safety = [ordered]@{
        verify_only = $true
        sizing_changes = $false
        order_api_used = "OrderCalcProfit only"
        authorized_terminal = "D:\QM\mt5\T_Export"
    }
}
$manifestTemp = Join-Path $workRoot "manifest.json"
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestTemp -Encoding utf8NoBOM
Publish-AtomicFile -Source $manifestTemp -Destination $finalManifest -RunTag $runTag
$publishComplete = $true

Write-Output "result=$($manifest.result)"
Write-Output "csv=$finalCsv"
Write-Output "manifest=$finalManifest"
Write-Output "compile_log=$finalCompileLog"
Write-Output "terminal_log=$finalTerminalLog"
if ($unresolvedCount -gt 0) {
    throw "H5 evidence was published, but $unresolvedCount symbol rows are UNRESOLVED."
}
} finally {
    if ($null -ne $terminal) {
        try {
            $terminal.Refresh()
            if (-not $terminal.HasExited) {
                $identity = Get-CimInstance Win32_Process -Filter "ProcessId=$($terminal.Id)" `
                    -ErrorAction SilentlyContinue
                if ($identity -and $identity.ExecutablePath) {
                    Assert-PathWithinRoot -Path $identity.ExecutablePath -Root $ExpectedTerminalRoot `
                        -Label "diagnostic terminal cleanup"
                    Assert-NotForbiddenTerminalPath -Path $identity.ExecutablePath `
                        -Label "diagnostic terminal cleanup"
                    Stop-Process -Id $terminal.Id -Force -ErrorAction SilentlyContinue
                }
            }
        } catch {
            Write-Warning "Could not finish exact-PID T_Export cleanup: $($_.Exception.Message)"
        }
    }

    if ($deployedScriptRoot -and (Test-Path -LiteralPath $deployedScriptRoot)) {
        try {
            if (@(Get-TExportProcesses -TerminalRoot $ExpectedTerminalRoot).Count -eq 0) {
                $resolvedDeployment = (Resolve-Path -LiteralPath $deployedScriptRoot).Path
                Assert-PathWithinRoot -Path $resolvedDeployment `
                    -Root (Join-Path $ExpectedTerminalRoot "MQL5\Scripts\QM_Diagnostics") `
                    -Label "diagnostic deployment cleanup"
                Assert-NotForbiddenTerminalPath -Path $resolvedDeployment `
                    -Label "diagnostic deployment cleanup"
                Remove-Item -LiteralPath $resolvedDeployment -Recurse -Force
            }
        } catch {
            Write-Warning "Could not remove the isolated diagnostic deployment: $($_.Exception.Message)"
        }
    }

    if ($publishComplete -and $workRoot -and (Test-Path -LiteralPath $workRoot)) {
        $resolvedWorkRoot = (Resolve-Path -LiteralPath $workRoot).Path
        $workLeaf = Split-Path -Leaf $resolvedWorkRoot
        Assert-PathWithinRoot -Path $resolvedWorkRoot -Root $ReportRoot -Label "run work cleanup"
        if ($workLeaf -notlike ".dwx_tickvalue_dump_*") {
            throw "Refusing to remove unexpected run work directory: $resolvedWorkRoot"
        }
        Remove-Item -LiteralPath $resolvedWorkRoot -Recurse -Force
    }
}
