[CmdletBinding()]
param(
    [int]$EAId = 0,
    [string]$EALabel,
    [Parameter(Mandatory = $true)]
    [string]$Symbol,
    [Parameter(Mandatory = $true)]
    [ValidateRange(2000, 2100)]
    [int]$Year,
    [string]$FromDate,
    [string]$ToDate,
    [ValidateSet("any", "T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8", "T9", "T10")]
    [string]$Terminal = "T1",
    [string]$Expert,
    [string]$Period = "H1",
    [ValidateRange(1, 10)]
    [int]$Runs = 2,
    [ValidateRange(0, 1000000)]
    [int]$MinTrades = 20,
    [ValidateSet(4)]
    [int]$Model = 4,
    [ValidateRange(60, 7200)]
    [int]$TimeoutSeconds = 1800,
    [string]$SetFile,
    [string]$ReportRoot = "D:\QM\reports\smoke",
    [string]$DispatchPhase = "P1",
    [string]$DispatchVersion = "smoke",
    [string]$DispatchSubGateHash,
    [switch]$AllowRunningTerminal,
    [switch]$AllowMissingRealTicksLogMarker
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($EAId -le 0) {
    if ([string]::IsNullOrWhiteSpace($EALabel) -or $EALabel -notmatch '^(?:QM5_)?(?<id>\d{4})') {
        throw "Provide -EAId or an -EALabel beginning with a four-digit EA id."
    }
    $EAId = [int]$Matches["id"]
}

function Convert-HtmlEntityText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    return ($Text -replace '&nbsp;', ' ' -replace '&amp;', '&' -replace '&lt;', '<' -replace '&gt;', '>' -replace '&quot;', '"')
}

function Get-ReportMetricValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Html,
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $regex = [regex]::new("(?is)<td[^>]*>\s*$([regex]::Escape($Label)):\s*</td>\s*<td[^>]*>\s*<b>(?<value>[^<]*)</b>", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $match = $regex.Match($Html)
    if (-not $match.Success) {
        throw "Could not find metric label '$Label' in report."
    }

    $value = Convert-HtmlEntityText -Text $match.Groups["value"].Value.Trim()
    return $value
}

function Get-ReportInvalidReasons {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Html,
        [Parameter(Mandatory = $true)]
        [string]$TesterLogTail,
        [Parameter(Mandatory = $true)]
        [string]$ExpectedSymbol,
        [Parameter(Mandatory = $true)]
        [string]$ExpectedFromDate,
        [Parameter(Mandatory = $true)]
        [string]$ExpectedToDate,
        [Parameter(Mandatory = $true)]
        [bool]$HasRealTicksMarker
    )

    $reasons = New-Object System.Collections.Generic.List[string]
    try {
        $expertValue = Get-ReportMetricValue -Html $Html -Label "Expert"
        $symbolValue = Get-ReportMetricValue -Html $Html -Label "Symbol"
        $periodValue = Get-ReportMetricValue -Html $Html -Label "Period"
        $barsValue = Get-ReportMetricValue -Html $Html -Label "Bars"
        $bars = [int](Convert-ReportNumber -Value $barsValue)

        if ([string]::IsNullOrWhiteSpace($expertValue)) { $reasons.Add("EMPTY_EXPERT") }
        if ([string]::IsNullOrWhiteSpace($symbolValue)) { $reasons.Add("EMPTY_SYMBOL") }
        if ($periodValue -match "(?i)\bM0\b" -or $periodValue -match "1970\.01\.01\s*-\s*1970\.01\.01") { $reasons.Add("M0_1970_PERIOD") }
        if ($bars -le 0) { $reasons.Add("BARS_ZERO") }
        if (Test-TesterLogShowsOnInitFailure -TesterLogTail $TesterLogTail) { $reasons.Add("ONINIT_FAILED") }
        if (Test-TesterLogShowsSetupDataMissing -TesterLogTail $TesterLogTail) { $reasons.Add("SETUP_DATA_MISSING") }
        if (Test-TesterLogHasNoHistoryForRun -TesterLogTail $TesterLogTail -ExpectedSymbol $ExpectedSymbol -ExpectedFromDate $ExpectedFromDate -ExpectedToDate $ExpectedToDate) { $reasons.Add("NO_HISTORY_LOG") }
        if (($periodValue -match "(?i)\bM0\b" -or $bars -le 0) -and $TesterLogTail -match "(?im)\bhistory\b") { $reasons.Add("HISTORY_CONTEXT_INVALID") }
        if ((-not $HasRealTicksMarker) -and $TesterLogTail -match "(?im)automatical testing finished") { $reasons.Add("NO_REAL_TICKS_MARKER_FAST_FINISH") }
    } catch {
        $reasons.Add("REPORT_PARSE_ERROR")
    }

    return @($reasons)
}

function Test-TesterLogShowsOnInitFailure {
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$TesterLogTail
    )

    if ([string]::IsNullOrWhiteSpace($TesterLogTail)) {
        return $false
    }
    return [regex]::IsMatch($TesterLogTail, "(?im)\btester stopped because OnInit returns non-zero code\b") -or
        [regex]::IsMatch($TesterLogTail, "(?im)\b(OnInit|init)\b.*\b(failed|INIT_FAILED)\b") -or
        [regex]::IsMatch($TesterLogTail, "(?im)initialization failed")
}

function Test-TesterLogShowsSetupDataMissing {
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$TesterLogTail
    )

    if ([string]::IsNullOrWhiteSpace($TesterLogTail)) {
        return $false
    }
    return [regex]::IsMatch($TesterLogTail, "(?im)\bSETUP_DATA_MISSING\b") -or
        [regex]::IsMatch($TesterLogTail, "(?im)\b(calendar_file_missing_or_unreadable|calendar_file_stale|calendar_csv_parse_failed|calendar_hash_failed|calendar_unavailable)\b")
}

function Test-TesterLogHasNoHistoryForRun {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TesterLogTail,
        [Parameter(Mandatory = $true)]
        [string]$ExpectedSymbol,
        [Parameter(Mandatory = $true)]
        [string]$ExpectedFromDate,
        [Parameter(Mandatory = $true)]
        [string]$ExpectedToDate
    )

    if ([string]::IsNullOrWhiteSpace($TesterLogTail)) {
        return $false
    }

    $symbolPattern = [regex]::Escape($ExpectedSymbol)
    $fromPattern = [regex]::Escape($ExpectedFromDate)
    $toPattern = [regex]::Escape($ExpectedToDate)
    $runNoHistoryPattern = "(?i)\b${symbolPattern}:\s+no history data from\s+$fromPattern\s+00:00\s+to\s+$toPattern\s+00:00\b"
    $stopPattern = "(?i)\bno history data,\s*stop testing\b"
    $lines = $TesterLogTail -split "\r?\n"

    for ($idx = 0; $idx -lt $lines.Count; $idx++) {
        if ($lines[$idx] -notmatch $runNoHistoryPattern) {
            continue
        }
        $lastContextLine = [Math]::Min($idx + 3, $lines.Count - 1)
        for ($contextIdx = $idx; $contextIdx -le $lastContextLine; $contextIdx++) {
            if ($lines[$contextIdx] -match $stopPattern) {
                return $true
            }
        }
    }

    return $false
}

function Resolve-InvalidReportVerdict {
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string[]]$InvalidReasons = @()
    )

    if ($null -eq $InvalidReasons) { $InvalidReasons = @() }

    if ($InvalidReasons -contains "ONINIT_FAILED") {
        return "ONINIT_FAILED"
    }
    if ($InvalidReasons -contains "SETUP_DATA_MISSING") {
        return "SETUP_DATA_MISSING"
    }
    if ($InvalidReasons -contains "NO_HISTORY_LOG" -or $InvalidReasons -contains "HISTORY_CONTEXT_INVALID") {
        return "NO_HISTORY"
    }
    if ($InvalidReasons -contains "NO_REAL_TICKS_MARKER_FAST_FINISH") {
        return "NO_REAL_TICKS"
    }
    if (@($InvalidReasons).Count -gt 0) {
        return "INVALID_REPORT"
    }
    return $null
}

function Convert-ReportNumber {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $m = [regex]::Match($Value, '[-+]?[0-9][0-9\s,\.]*')
    if (-not $m.Success) {
        throw "No numeric token in '$Value'."
    }

    $token = ($m.Value -replace '\s', '')
    if ($token.Contains('.') -and $token.Contains(',')) {
        $token = $token.Replace(",", "")
    } elseif ($token.Contains(',') -and -not $token.Contains('.')) {
        $token = $token.Replace(",", ".")
    }

    $number = 0.0
    if (-not [double]::TryParse($token, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$number)) {
        throw "Unable to parse numeric value '$token' from '$Value'."
    }

    return $number
}

function Resolve-TerminalRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TerminalName
    )

    $root = Join-Path "D:\QM\mt5" $TerminalName
    if ($TerminalName -notmatch '^T([1-9]|10)$') {
        throw "Refusing non-factory terminal '$TerminalName'. Allowed factory terminals are T1..T10; T_Live is off limits."
    }
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        throw "Terminal root does not exist: $root"
    }
    return (Resolve-Path -LiteralPath $root).Path
}

function Deploy-ExpertBinaryToTerminal {
    # Make run_smoke self-contained: copy the EA .ex5 from the repo into the
    # selected terminal's Experts subdir before invoking the tester. Without this, Codex
    # build → compile → smoke chains fail with "Experts\QM\<EA>.ex5 not found"
    # because nothing else deploys between compile and smoke (only
    # p2_baseline.py's ensure_expert_binary_deployed handles deploy, and that
    # runs at a later pipeline stage).
    #
    # ExpertPath format: "<subdir>\<EaLabel>" (e.g. "QM\QM5_1047_halloween-...").
    # Repo source: C:\QM\repo\framework\EAs\<EaLabel>\<EaLabel>.ex5
    # Destination: D:\QM\mt5\<Tn>\MQL5\Experts\<subdir>\<EaLabel>.ex5
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExpertPath,
        [Parameter(Mandatory = $true)]
        [string]$TerminalName
    )

    if ([string]::IsNullOrWhiteSpace($ExpertPath)) {
        return
    }
    $parts = $ExpertPath -split '[\\/]', 2
    if ($parts.Count -ne 2) {
        Write-Host ("run_smoke.deploy_skip=non_canonical_expert_path expert='{0}'" -f $ExpertPath)
        return
    }
    $subdir  = $parts[0]
    $eaLabel = $parts[1]

    $repoSource = Join-Path "C:\QM\repo\framework\EAs" (Join-Path $eaLabel "$eaLabel.ex5")
    if (-not (Test-Path -LiteralPath $repoSource -PathType Leaf)) {
        # No source .ex5 — let the tester surface the missing-binary error so the
        # smoke summary reasoner can classify it. Don't throw here; sometimes the
        # caller passes -Expert pointing at a pre-deployed legacy EA that lives
        # only under MQL5/Experts (e.g. framework smoke).
        Write-Host ("run_smoke.deploy_skip=source_missing source='{0}'" -f $repoSource)
        return
    }

    if ([string]::IsNullOrWhiteSpace($TerminalName)) {
        throw "run_smoke.deploy_failed terminal=<empty> err='TerminalName is required for per-terminal deploy.'"
    }

    $destDir = Join-Path "D:\QM\mt5" (Join-Path $TerminalName (Join-Path "MQL5" (Join-Path "Experts" $subdir)))
    if (-not (Test-Path -LiteralPath $destDir -PathType Container)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    $destFile = Join-Path $destDir "$eaLabel.ex5"
    try {
        Copy-Item -LiteralPath $repoSource -Destination $destFile -Force -ErrorAction Stop
    } catch {
        throw ("run_smoke.deploy_failed terminal={0} dest='{1}' err='{2}'" -f $TerminalName, $destFile, $_.Exception.Message)
    }
    Write-Host ("run_smoke.deploy_ok ea_label={0} subdir={1} terminal={2} source='{3}'" -f $eaLabel, $subdir, $TerminalName, $repoSource)
}

function Resolve-DispatchTerminal {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetTerminal,
        [Parameter(Mandatory = $true)]
        [int]$EAIdValue,
        [Parameter(Mandatory = $true)]
        [string]$SymbolName,
        [Parameter(Mandatory = $true)]
        [string]$PeriodName,
        [Parameter(Mandatory = $true)]
        [int]$YearValue,
        [string]$SetFilePath,
        [Parameter(Mandatory = $true)]
        [string]$DispatchPhaseValue,
        [Parameter(Mandatory = $true)]
        [string]$DispatchVersionValue
        ,
        [Parameter(Mandatory = $true)]
        [string]$DispatchSubGateHashValue
    )

    if ($TargetTerminal -ine 'any') {
        return $TargetTerminal
    }
    # $SetFilePath only required for any-terminal resolution; specific-terminal
    # early-return above. Codex strategy_farm builds invoke run_smoke without
    # -SetFile (the smoke pass runs against EA-internal defaults, setfiles are
    # generated AFTER smoke), and PowerShell Mandatory rejects empty strings
    # at bind time before the early-return executes (QM5_1045 build 2026-05-16).
    if ([string]::IsNullOrWhiteSpace($SetFilePath)) {
        throw "Resolve-DispatchTerminal requires -SetFilePath when -TargetTerminal='any'."
    }

    $resolverPath = Join-Path $PSScriptRoot "resolve_backtest_target.py"
    if (-not (Test-Path -LiteralPath $resolverPath -PathType Leaf)) {
        throw "resolve_backtest_target.py not found at $resolverPath"
    }
    $jobPath = Join-Path (Get-QmTempDirectory) ("qua307_dispatch_job_{0}.json" -f [guid]::NewGuid().ToString("N"))
    $statePath = "D:\QM\Reports\pipeline\dispatch_state.json"
    $job = [ordered]@{
        ea_id = "QM5_{0}" -f $EAIdValue
        version = $DispatchVersionValue
        symbol = $SymbolName
        phase = $DispatchPhaseValue
        sub_gate_config_hash = $DispatchSubGateHashValue
        target_terminal = "any"
        setfile_path = $SetFilePath
    } | ConvertTo-Json -Depth 4
    Set-Content -LiteralPath $jobPath -Value $job -Encoding utf8

    try {
        $raw = & python $resolverPath --job-json $jobPath --state-json $statePath --max-per-terminal 3
        if ($LASTEXITCODE -ne 0) {
            throw "resolve_backtest_target.py exited with code $LASTEXITCODE"
        }
        $decision = $raw | ConvertFrom-Json
        $decisionStatus = if ($decision.PSObject.Properties.Name -contains "status") { [string]$decision.status } else { "" }
        $decisionTerminal = if ($decision.PSObject.Properties.Name -contains "terminal") { [string]$decision.terminal } else { "" }
        if ([string]::IsNullOrWhiteSpace($decisionTerminal)) {
            $message = if ($decision.PSObject.Properties.Name -contains "message") { [string]$decision.message } else { "No message." }
            $errorCode = if ($decision.PSObject.Properties.Name -contains "error_code") { [string]$decision.error_code } else { "none" }
            throw "Terminal resolution returned no terminal. status=$decisionStatus error_code=$errorCode message=$message"
        }
        Write-Host ("run_smoke.dispatch_status={0}" -f $decisionStatus)
        Write-Host ("run_smoke.dispatch_terminal={0}" -f $decisionTerminal)
        return $decisionTerminal
    } finally {
        if (Test-Path -LiteralPath $jobPath) {
            Remove-Item -LiteralPath $jobPath -Force
        }
    }
}

function Invoke-DispatchCompletion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OriginalTargetTerminal,
        [Parameter(Mandatory = $true)]
        [int]$EAIdValue,
        [Parameter(Mandatory = $true)]
        [string]$SymbolName,
        [Parameter(Mandatory = $true)]
        [string]$PeriodName,
        [Parameter(Mandatory = $true)]
        [int]$YearValue,
        [string]$SetFilePath,
        [Parameter(Mandatory = $true)]
        [string]$DispatchPhaseValue,
        [Parameter(Mandatory = $true)]
        [string]$DispatchVersionValue
        ,
        [Parameter(Mandatory = $true)]
        [string]$DispatchSubGateHashValue
    )

    if ($OriginalTargetTerminal -ine 'any') {
        return
    }
    if ([string]::IsNullOrWhiteSpace($SetFilePath)) {
        Write-Warning "run_smoke.dispatch_complete skipped; SetFilePath empty for any-terminal completion."
        return
    }

    $resolverPath = Join-Path $PSScriptRoot "resolve_backtest_target.py"
    if (-not (Test-Path -LiteralPath $resolverPath -PathType Leaf)) {
        Write-Warning "run_smoke.dispatch_complete skipped; resolver missing at $resolverPath"
        return
    }

    $jobPath = Join-Path (Get-QmTempDirectory) ("qua307_dispatch_job_{0}.json" -f [guid]::NewGuid().ToString("N"))
    $statePath = "D:\QM\Reports\pipeline\dispatch_state.json"
    $job = [ordered]@{
        ea_id = "QM5_{0}" -f $EAIdValue
        version = $DispatchVersionValue
        symbol = $SymbolName
        phase = $DispatchPhaseValue
        sub_gate_config_hash = $DispatchSubGateHashValue
        target_terminal = "any"
        setfile_path = $SetFilePath
    } | ConvertTo-Json -Depth 4
    Set-Content -LiteralPath $jobPath -Value $job -Encoding utf8
    try {
        $raw = & python $resolverPath --job-json $jobPath --state-json $statePath --event complete --prune-completed
        if ($LASTEXITCODE -eq 0 -and $raw) {
            $decision = $raw | ConvertFrom-Json
            Write-Host ("run_smoke.dispatch_complete_status={0}" -f $decision.status)
            if ($decision.terminal) {
                Write-Host ("run_smoke.dispatch_complete_terminal={0}" -f $decision.terminal)
            }
        } else {
            Write-Warning "run_smoke.dispatch_complete failed (exit=$LASTEXITCODE)"
        }
    } finally {
        if (Test-Path -LiteralPath $jobPath) {
            Remove-Item -LiteralPath $jobPath -Force
        }
    }
}

function Resolve-TerminalExecutable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TerminalRoot
    )

    $candidate = Join-Path $TerminalRoot "terminal64.exe"
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw "terminal64.exe not found at $candidate"
    }
    return (Resolve-Path -LiteralPath $candidate).Path
}

function Test-TerminalAlreadyRunning {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TerminalRoot
    )

    $escaped = [regex]::Escape((Join-Path $TerminalRoot "terminal64.exe"))
    $processes = Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue
    if (-not $processes) {
        return $false
    }

    foreach ($proc in $processes) {
        $line = [string]$proc.CommandLine
        if ($line -and [regex]::IsMatch($line, $escaped, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
            return $true
        }
    }

    return $false
}

function Write-TesterIni {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$ExpertPath,
        [Parameter(Mandatory = $true)]
        [string]$SymbolName,
        [Parameter(Mandatory = $true)]
        [string]$Timeframe,
        [Parameter(Mandatory = $true)]
        [int]$ModelMode,
        [Parameter(Mandatory = $true)]
        [string]$FromDate,
        [Parameter(Mandatory = $true)]
        [string]$ToDate,
        [Parameter(Mandatory = $true)]
        [string]$ReportValue,
        [Parameter(Mandatory = $true)]
        [string]$TerminalRoot,
        [string]$SetFilePath
    )

    # Load canonical tester defaults (DL-054 G2 source of truth).
    # Origin: framework/registry/tester_defaults.json — codified 2026-05-01 after
    # tester journal showed 'initial deposit 10000.00 USD' (wrong by 10x).
    $localRepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
    $defaultsPath = Join-Path $localRepoRoot "framework\registry\tester_defaults.json"
    if (-not (Test-Path -LiteralPath $defaultsPath -PathType Leaf)) {
        throw "tester_defaults.json missing at $defaultsPath - cannot launch backtest without canonical defaults (DL-054 G2)."
    }
    $defaults = Get-Content -LiteralPath $defaultsPath -Raw | ConvertFrom-Json
    $deposit = [int]$defaults.initial_deposit
    $currency = [string]$defaults.deposit_currency
    $leverage = [int]$defaults.leverage
    if ($deposit -le 0 -or [string]::IsNullOrWhiteSpace($currency) -or $leverage -le 0) {
        throw "tester_defaults.json invalid: initial_deposit=$deposit currency=$currency leverage=$leverage"
    }

    $lines = @(
        "[Tester]",
        "Expert=$ExpertPath",
        "Symbol=$SymbolName",
        "Period=$Timeframe",
        "Model=$ModelMode",
        "ExecutionMode=0",
        "Optimization=0",
        "OptimizationCriterion=0",
        "FromDate=$FromDate",
        "ToDate=$ToDate",
        "ForwardMode=0",
        "Deposit=$deposit",
        "Currency=$currency",
        "ProfitInPips=0",
        "Leverage=$leverage",
        "UseLocal=1",
        "Visual=0",
        "Replace=1",
        "ReplaceReport=1",
        "ShutdownTerminal=1",
        "Report=$ReportValue"
    )

    if ($SetFilePath) {
        $testerProfileDir = Join-Path $TerminalRoot "MQL5\Profiles\Tester"
        New-Item -ItemType Directory -Path $testerProfileDir -Force | Out-Null
        $setfileName = Split-Path -Leaf $SetFilePath
        $terminalSetfilePath = Join-Path $testerProfileDir $setfileName
        Copy-Item -LiteralPath $SetFilePath -Destination $terminalSetfilePath -Force
        $lines += "ExpertParameters=$setfileName"
    }

    Set-Content -LiteralPath $Path -Value $lines -Encoding ascii
}

function Get-RelativeReportFileName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$EaLabel,
        [Parameter(Mandatory = $true)]
        [string]$SymbolName,
        [Parameter(Mandatory = $true)]
        [string]$RunTag,
        [Parameter(Mandatory = $true)]
        [string]$RunName
    )

    $sanitizedSymbol = ($SymbolName -replace '[^A-Za-z0-9]+', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($sanitizedSymbol)) {
        $sanitizedSymbol = "symbol"
    }
    return "{0}_{1}_{2}_{3}.htm" -f $EaLabel, $sanitizedSymbol, $RunTag, $RunName
}

function Use-LegacyRelativeReportExport {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TerminalRoot,
        [Parameter(Mandatory = $true)]
        [string]$AbsoluteReportPath,
        [Parameter(Mandatory = $true)]
        [string]$LegacyRelativePath
    )

    if (Test-Path -LiteralPath $AbsoluteReportPath -PathType Leaf) {
        return $false
    }
    if (-not (Test-Path -LiteralPath $LegacyRelativePath -PathType Leaf)) {
        return $false
    }
    try {
        Copy-Item -LiteralPath $LegacyRelativePath -Destination $AbsoluteReportPath -Force
        return (Test-Path -LiteralPath $AbsoluteReportPath -PathType Leaf)
    } catch {
        return $false
    }
}

function Get-LatestTesterLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TerminalRoot,
        [Parameter(Mandatory = $true)]
        [datetime]$SinceUtc
    )

    $logsDir = Join-Path $TerminalRoot "Tester\logs"
    if (-not (Test-Path -LiteralPath $logsDir -PathType Container)) {
        return $null
    }

    $candidate = Get-ChildItem -LiteralPath $logsDir -File |
        Where-Object { $_.LastWriteTimeUtc -ge $SinceUtc.AddMinutes(-2) } |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1

    return $candidate
}

function Get-TesterLogTailText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TesterLogPath,
        [int]$LineCount = 800
    )

    if (-not (Test-Path -LiteralPath $TesterLogPath -PathType Leaf)) {
        return ""
    }
    $logBytes = [System.IO.File]::ReadAllBytes($TesterLogPath)
    if ($logBytes.Length -ge 2 -and $logBytes[0] -eq 0xFF -and $logBytes[1] -eq 0xFE) {
        return ((Get-Content -LiteralPath $TesterLogPath -Encoding Unicode | Select-Object -Last $LineCount) -join [Environment]::NewLine)
    }
    return ((Get-Content -LiteralPath $TesterLogPath | Select-Object -Last $LineCount) -join [Environment]::NewLine)
}

function Start-TesterRun {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TerminalExe,
        [Parameter(Mandatory = $true)]
        [string]$IniPath,
        [Parameter(Mandatory = $true)]
        [int]$TimeoutSec,
        [string]$TerminalName = $TerminalExe
    )

    $args = @("/portable", "/config:$IniPath")
    $spawnStartedAfter = Get-Date
    Write-Host ("run_smoke.stage=terminal_start exe='{0}' args='{1}' timeout_seconds={2}" -f $TerminalExe, ([string]::Join(' ', $args)), $TimeoutSec)
    $proc = Start-Process -FilePath $TerminalExe -ArgumentList $args -PassThru -WindowStyle Hidden
    $childTerminal = Wait-TerminalSpawn -TerminalExe $TerminalExe -IniPath $IniPath -TerminalName $TerminalName -StartedAfter $spawnStartedAfter
    Write-Host ("run_smoke.stage=terminal_spawn_confirmed terminal_pid={0} start_time='{1:o}'" -f $childTerminal.Id, $childTerminal.StartTime)
    $finished = $proc.WaitForExit($TimeoutSec * 1000)
    $timedOut = -not $finished
    if ($timedOut) {
        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
        } catch {
        }
    }
    $loggedExitCode = if ($finished) { $proc.ExitCode } else { "<timeout>" }
    Write-Host ("run_smoke.stage=terminal_exit terminal_pid={0} exit_code={1} timed_out={2}" -f $childTerminal.Id, $loggedExitCode, $timedOut)

    return [pscustomobject]@{
        exit_code = $(if ($finished) { $proc.ExitCode } else { $null })
        timed_out = $timedOut
        terminal_pid = $childTerminal.Id
    }
}

function Set-IniValue {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.ArrayList]$Lines,
        [Parameter(Mandatory = $true)]
        [string]$Section,
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $sectionHeader = "[$Section]"
    $sectionIndex = -1
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i].Trim() -ieq $sectionHeader) {
            $sectionIndex = $i
            break
        }
    }

    if ($sectionIndex -lt 0) {
        [void]$Lines.Add($sectionHeader)
        [void]$Lines.Add("$Key=$Value")
        return
    }

    $insertIndex = $Lines.Count
    for ($i = $sectionIndex + 1; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '^\s*\[.+\]\s*$') {
            $insertIndex = $i
            break
        }
        if ($Lines[$i] -match "^\s*$([regex]::Escape($Key))\s*=") {
            $Lines[$i] = "$Key=$Value"
            return
        }
    }

    $Lines.Insert($insertIndex, "$Key=$Value")
}

function Set-BacktestTerminalConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TerminalRoot,
        [Parameter(Mandatory = $true)]
        [string]$TerminalName
    )

    $commonPath = Join-Path $TerminalRoot "config\common.ini"
    if (-not (Test-Path -LiteralPath $commonPath -PathType Leaf)) {
        return
    }

    $lines = [System.Collections.ArrayList]::new()
    foreach ($line in (Get-Content -LiteralPath $commonPath)) {
        [void]$lines.Add($line)
    }

    Set-IniValue -Lines $lines -Section "Common" -Key "Services" -Value "0"
    Set-IniValue -Lines $lines -Section "Common" -Key "NewsEnable" -Value "0"
    Set-IniValue -Lines $lines -Section "Charts" -Key "ProfileLast" -Value "QMBacktest"
    Set-IniValue -Lines $lines -Section "Charts" -Key "PreloadCharts" -Value "0"

    $current = (Get-Content -LiteralPath $commonPath -Raw)
    $updated = ($lines -join [Environment]::NewLine) + [Environment]::NewLine
    if ($current -ne $updated) {
        Set-Content -LiteralPath $commonPath -Value $updated -Encoding ASCII
        Write-Host ("run_smoke.stage=terminal_config_sanitized terminal={0} common_ini='{1}' services=0 news=0 profile=QMBacktest preload_charts=0" -f $TerminalName, $commonPath)
    }

    foreach ($profileRoot in @(
        (Join-Path $TerminalRoot "MQL5\Profiles\Charts\QMBacktest"),
        (Join-Path $TerminalRoot "Profiles\Charts\QMBacktest")
    )) {
        if (-not (Test-Path -LiteralPath $profileRoot -PathType Container)) {
            New-Item -ItemType Directory -Path $profileRoot -Force | Out-Null
        }
    }
}

function Wait-TerminalSpawn {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TerminalExe,
        [Parameter(Mandatory = $true)]
        [string]$IniPath,
        [string]$TerminalName = $TerminalExe,
        [int]$SpawnWaitSeconds = 30,
        [int]$PollMilliseconds = 500,
        [datetime]$StartedAfter = (Get-Date).AddSeconds(-30)
    )

    $spawnDeadline = (Get-Date).AddSeconds($SpawnWaitSeconds)
    $childTerminal = $null
    while ((Get-Date) -lt $spawnDeadline -and -not $childTerminal) {
        Start-Sleep -Milliseconds $PollMilliseconds
        $childTerminal = Get-Process -Name terminal64 -ErrorAction SilentlyContinue |
            Where-Object {
                try {
                    $_.Path -eq $TerminalExe -and $_.StartTime -ge $StartedAfter
                } catch {
                    $false
                }
            } |
            Sort-Object StartTime -Descending |
            Select-Object -First 1
    }

    if (-not $childTerminal) {
        throw "TERMINAL_SPAWN_FAILURE: terminal=$TerminalName exe=$TerminalExe did not appear within 30s; ini=$IniPath"
    }

    return $childTerminal
}

function Get-MetaTesterProcessesForTerminalRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TerminalRoot
    )

    $normalizedRoot = $TerminalRoot.TrimEnd('\')
    $escapedRoot = [regex]::Escape($normalizedRoot)
    $processes = Get-CimInstance Win32_Process -Filter "Name='metatester64.exe'" -ErrorAction SilentlyContinue
    if (-not $processes) {
        return @()
    }

    $matches = @()
    foreach ($proc in $processes) {
        $exePath = [string]$proc.ExecutablePath
        $cmdLine = [string]$proc.CommandLine
        $matchesRoot = ($exePath -and [regex]::IsMatch($exePath, "^$escapedRoot\\", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) -or
            ($cmdLine -and [regex]::IsMatch($cmdLine, $escapedRoot, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase))
        if ($matchesRoot) {
            $matches += $proc
        }
    }

    return @($matches)
}

function Wait-ForReportExport {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReportPath,
        [Parameter(Mandatory = $true)]
        [string]$TerminalRoot,
        [ValidateRange(0, 300)]
        [int]$MaxWaitSeconds = 30
    )

    $deadline = (Get-Date).ToUniversalTime().AddSeconds($MaxWaitSeconds)
    do {
        if (Test-Path -LiteralPath $ReportPath -PathType Leaf) {
            return $true
        }

        # Do not early-return when metatester is gone: report export can lag
        # process exit under filesystem contention.
        $activeMetaTesters = @(Get-MetaTesterProcessesForTerminalRoot -TerminalRoot $TerminalRoot)
        if (@($activeMetaTesters).Count -gt 0) {
            Start-Sleep -Milliseconds 500
        } else {
            Start-Sleep -Milliseconds 250
        }
    } while ((Get-Date).ToUniversalTime() -lt $deadline)

    return (Test-Path -LiteralPath $ReportPath -PathType Leaf)
}

function Convert-RunMetricsToFingerprint {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Metrics
    )

    return "{0}|{1}|{2}|{3}" -f $Metrics.total_trades_raw, $Metrics.profit_factor_raw, $Metrics.drawdown_raw, $Metrics.net_profit_raw
}

function Get-QmTempDirectory {
    $candidates = @(
        $env:TEMP,
        $env:TMP,
        [System.IO.Path]::GetTempPath(),
        "D:\QM\tmp",
        "C:\QM\tmp"
    )
    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
            $resolved = $candidate.Trim()
            if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
                New-Item -ItemType Directory -Path $resolved -Force | Out-Null
            }
            return $resolved
        }
    }
    throw "Unable to resolve writable temp directory."
}

function Get-ExpectedTradesPerYear {
    param(
        [Parameter(Mandatory = $true)]
        [int]$EAIdValue
    )

    $cardsDir = "D:\QM\strategy_farm\artifacts\cards_approved"
    if (-not (Test-Path -LiteralPath $cardsDir -PathType Container)) {
        return $null
    }
    $prefix = "QM5_{0:d4}" -f $EAIdValue
    $card = Get-ChildItem -LiteralPath $cardsDir -Filter "$prefix*.md" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $card) {
        return $null
    }
    $text = Get-Content -LiteralPath $card.FullName -Raw -Encoding UTF8
    $m = [regex]::Match($text, "(?ms)^---\s*\r?\n(?<fm>.*?)\r?\n---")
    if (-not $m.Success) {
        return $null
    }
    $fm = $m.Groups["fm"].Value
    $v = [regex]::Match($fm, "(?m)^expected_trades_per_year_per_symbol\s*:\s*(?<n>\d+)\s*$")
    if (-not $v.Success) {
        return $null
    }
    $cardExpected = [int]$v.Groups["n"].Value
    $universeLines = @($text -split "\r?\n" | Where-Object {
        $_ -match "^\s*(?:Universe|Target symbol\(s\)|Target symbols?)\b"
    })
    $symbolSearchText = if ($universeLines.Count -gt 0) { $universeLines -join "`n" } else { $text }
    $symbolMatches = [regex]::Matches(
        $symbolSearchText,
        "\b([A-Z]{3}USD|USD[A-Z]{3}|EURJPY|GBPJPY|AUDJPY|CADJPY|CHFJPY|NZDJPY|XAUUSD|XTIUSD|WTI|NDX|WS30|GDAXI|GER40|DAX|UK100|SP500)(?:\.DWX)?\b"
    )
    $symbols = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($match in $symbolMatches) {
        $sym = $match.Groups[1].Value.ToUpperInvariant()
        if ($sym.EndsWith(".DWX")) {
            $sym = $sym.Substring(0, $sym.Length - 4)
        }
        switch ($sym) {
            "DAX" { $sym = "GDAXI.DWX" }
            "GER40" { $sym = "GDAXI.DWX" }
            "WTI" { $sym = "XTIUSD.DWX" }
            default {
                if (-not $sym.EndsWith(".DWX")) {
                    $sym = "$sym.DWX"
                }
            }
        }
        [void]$symbols.Add($sym)
    }
    $isBasket = ($symbols.Count -gt 1) -and ($text -match "(?i)multi[- ]asset|basket|universe")
    $effectiveExpected = $cardExpected
    $scope = "per_symbol_card"
    if ($isBasket) {
        $effectiveExpected = [Math]::Max(1, [int][Math]::Floor($cardExpected / $symbols.Count))
        $scope = "basket_scaled_from_card"
    }
    return [pscustomobject]@{
        ExpectedTradesPerYearPerSymbol = $effectiveExpected
        ExpectedTradesPerYearCard = $cardExpected
        CardUniverseSymbolCount = [Math]::Max(1, $symbols.Count)
        MinTradeScope = $scope
    }
}

function Resolve-NewsCalendarDiagnostics {
    $baseDir = "D:\QM\data\news_calendar"
    $primary = Join-Path $baseDir "news_calendar_2015_2025.csv"
    $secondary = Join-Path $baseDir "forex_factory_calendar_clean.csv"
    $maxAgeHours = 24 * 14
    $paths = @($primary, $secondary)
    $missing = @($paths | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) })
    $latestModifiedUtc = $null
    if (@($missing).Count -eq 0) {
        $latestModifiedUtc = ($paths | ForEach-Object { (Get-Item -LiteralPath $_).LastWriteTimeUtc } | Sort-Object -Descending | Select-Object -First 1)
    }
    $ageHours = $null
    $status = "OK"
    if (@($missing).Count -gt 0) {
        $status = "MISSING"
    } elseif ($null -ne $latestModifiedUtc) {
        $ageHours = [int][Math]::Floor(((Get-Date).ToUniversalTime() - $latestModifiedUtc).TotalHours)
        if ($ageHours -gt $maxAgeHours) {
            $status = "STALE"
        }
    }
    return [pscustomobject]@{
        status = $status
        base_dir = $baseDir
        primary_path = $primary
        secondary_path = $secondary
        missing_paths = @($missing)
        latest_modified_utc = $(if ($null -ne $latestModifiedUtc) { $latestModifiedUtc.ToString("o") } else { $null })
        age_hours = $ageHours
        max_age_hours = $maxAgeHours
    }
}

function Get-SmokeYearCount {
    param(
        [Parameter(Mandatory = $true)]
        [string]$StartDate,
        [Parameter(Mandatory = $true)]
        [string]$EndDate
    )

    $startYear = [int]($StartDate.Substring(0, 4))
    $endYear = [int]($EndDate.Substring(0, 4))
    return [Math]::Max(1, ($endYear - $startYear + 1))
}

if ([string]::IsNullOrWhiteSpace($DispatchSubGateHash)) {
    $DispatchSubGateHash = "{0}-{1}" -f $Period, $Year
}

$effectiveTerminal = Resolve-DispatchTerminal -TargetTerminal $Terminal -EAIdValue $EAId -SymbolName $Symbol -PeriodName $Period -YearValue $Year -SetFilePath $SetFile -DispatchPhaseValue $DispatchPhase -DispatchVersionValue $DispatchVersion -DispatchSubGateHashValue $DispatchSubGateHash
Write-Host ("run_smoke.stage=resolved_terminal terminal={0}" -f $effectiveTerminal)
$terminalRoot = Resolve-TerminalRoot -TerminalName $effectiveTerminal
$terminalExe = Resolve-TerminalExecutable -TerminalRoot $terminalRoot
Write-Host ("run_smoke.stage=resolved_terminal_exe terminal={0} exe='{1}'" -f $effectiveTerminal, $terminalExe)
Set-BacktestTerminalConfig -TerminalRoot $terminalRoot -TerminalName $effectiveTerminal

if (($Terminal -ine "any") -and (-not $AllowRunningTerminal.IsPresent)) {
    if (Test-TerminalAlreadyRunning -TerminalRoot $terminalRoot) {
        throw "Terminal instance is already running for $terminalRoot. Stop it first or pass -AllowRunningTerminal."
    }
}

if (-not $Expert) {
    if ($EALabel) {
        # Canonical V5 convention: tester resolves to <terminal>/MQL5/Experts/QM/<EALabel>.ex5,
        # so Expert path is "QM\<EALabel>". Earlier "EALabel\EALabel" form depended on a
        # nested Experts/<EALabel>/<EALabel>.ex5 layout that nothing in the pipeline
        # actually deploys to, causing REPORT_MISSING. p2_baseline.py
        # (ensure_expert_binary_deployed) writes to QM\<EALabel> already.
        $Expert = "QM\$EALabel"
    } else {
        $Expert = "QM\QM5_{0}" -f $EAId
    }
}

# Fail-safe deploy: copy the EA .ex5 from the repo to the selected terminal's
# Experts subdir before the tester runs. Idempotent (overwrite). Without this,
# Codex build → compile → smoke chains failed at "Experts\QM\<EA>.ex5 not
# found" because only p2_baseline.py deployed binaries — run_smoke had no
# self-deploy step. 2026-05-16 QM5_1046 build hit exactly this.
Deploy-ExpertBinaryToTerminal -ExpertPath $Expert -TerminalName $effectiveTerminal

if ($SetFile) {
    $SetFile = (Resolve-Path -LiteralPath $SetFile).Path
}
Write-Host ("run_smoke.stage=resolved_setfile setfile='{0}'" -f $SetFile)

$runTag = (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss")
$eaLabel = "QM5_{0}" -f $EAId
$reportDir = Join-Path $ReportRoot "$eaLabel\$runTag"
$rawDir = Join-Path $reportDir "raw"
$frameworkEvidenceDir = "D:\QM\reports\framework\22"

New-Item -ItemType Directory -Path $rawDir -Force | Out-Null
New-Item -ItemType Directory -Path $frameworkEvidenceDir -Force | Out-Null

$fromDate = if ($FromDate) { $FromDate } else { "{0}.01.01" -f $Year }
$toDate = if ($ToDate) { $ToDate } else { "{0}.12.31" -f $Year }
$newsCalendarDiagnostics = Resolve-NewsCalendarDiagnostics
Write-Host ("run_smoke.news_calendar_status={0} latest_modified_utc='{1}' age_hours={2} max_age_hours={3}" -f $newsCalendarDiagnostics.status, $newsCalendarDiagnostics.latest_modified_utc, $newsCalendarDiagnostics.age_hours, $newsCalendarDiagnostics.max_age_hours)
$expectedTradeInfo = Get-ExpectedTradesPerYear -EAIdValue $EAId
if ($null -ne $expectedTradeInfo) {
    $expectedTradesPerYear = [int]$expectedTradeInfo.ExpectedTradesPerYearPerSymbol
    $smokeYearCount = Get-SmokeYearCount -StartDate $fromDate -EndDate $toDate
    $effectiveMinTrades = [Math]::Max(1, [int][Math]::Floor($expectedTradesPerYear * $smokeYearCount * 0.5))
    if ($effectiveMinTrades -ne $MinTrades) {
        Write-Host ("run_smoke.min_trades_override ea_id=QM5_{0:d4} expected_per_year={1} years={2} old={3} effective={4} scope={5} card_expected={6} card_symbols={7}" -f $EAId, $expectedTradesPerYear, $smokeYearCount, $MinTrades, $effectiveMinTrades, $expectedTradeInfo.MinTradeScope, $expectedTradeInfo.ExpectedTradesPerYearCard, $expectedTradeInfo.CardUniverseSymbolCount)
        $MinTrades = $effectiveMinTrades
    }
}

$runResults = @()
$globalOnInitFailure = $false
$globalRealTicksMarker = $true
$globalTimeoutFailure = $false
$reasonClasses = New-Object System.Collections.Generic.List[string]

for ($i = 1; $i -le $Runs; $i++) {
    $runName = "run_{0:d2}" -f $i
    $runDir = Join-Path $rawDir $runName
    New-Item -ItemType Directory -Path $runDir -Force | Out-Null

    $iniPath = Join-Path $runDir "tester.ini"
    $reportHtmPath = Join-Path $runDir "report.htm"
    $relativeReportFile = Get-RelativeReportFileName -EaLabel $eaLabel -SymbolName $Symbol -RunTag $runTag -RunName $runName
    $legacyRelativeSourcePath = Join-Path $terminalRoot $relativeReportFile
    $sourceReportPath = $legacyRelativeSourcePath
    $runStartUtc = (Get-Date).ToUniversalTime()

    if (Test-Path -LiteralPath $legacyRelativeSourcePath -PathType Leaf) {
        Remove-Item -LiteralPath $legacyRelativeSourcePath -Force
    }
    if (Test-Path -LiteralPath $reportHtmPath -PathType Leaf) {
        Remove-Item -LiteralPath $reportHtmPath -Force
    }

    Write-TesterIni -Path $iniPath `
        -ExpertPath $Expert `
        -SymbolName $Symbol `
        -Timeframe $Period `
        -ModelMode $Model `
        -FromDate $fromDate `
        -ToDate $toDate `
        -ReportValue $relativeReportFile `
        -TerminalRoot $terminalRoot `
        -SetFilePath $SetFile

    Write-Host ("run_smoke.stage=ini_written run={0} ini='{1}'" -f $runName, $iniPath)
    Write-Host ("run_smoke.stage=start_terminal terminal={0} run={1} ini='{2}'" -f $effectiveTerminal, $runName, $iniPath)
    try {
        $runExec = Start-TesterRun -TerminalExe $terminalExe -IniPath $iniPath -TimeoutSec $TimeoutSeconds -TerminalName $effectiveTerminal
    } catch {
        Write-Host ("run_smoke.start_failed terminal={0} run={1} ini='{2}' err='{3}'" -f $effectiveTerminal, $runName, $iniPath, $_.Exception.Message)
        throw
    }
    $exitCode = $runExec.exit_code

    if ($runExec.timed_out) {
        $lingeringMeta = @(Get-MetaTesterProcessesForTerminalRoot -TerminalRoot $terminalRoot)
        foreach ($metaProc in $lingeringMeta) {
            try {
                Stop-Process -Id $metaProc.ProcessId -Force -ErrorAction Stop
            } catch {
            }
        }
        $globalTimeoutFailure = $true
        $globalRealTicksMarker = $false
        $reasonClasses.Add("TIMEOUT")
        if (@($lingeringMeta).Count -gt 0) {
            $reasonClasses.Add("METATESTER_HUNG")
        }
        $runResults += [pscustomobject]@{
            run = $runName
            status = "FAIL"
            failure = "TIMEOUT"
            error = "Tester run timed out after $TimeoutSeconds seconds for ini: $iniPath"
            exit_code = $null
            report_source_path = $sourceReportPath
            report_canonical_path = $reportHtmPath
            report_size_bytes = 0
            tester_log_path = $null
        }
        continue
    }

    # MT5 report writes can lag significantly under terminal contention; allow a longer settle window
    # before classifying as infra REPORT_MISSING.
    $reportMaterialized = Wait-ForReportExport -ReportPath $sourceReportPath -TerminalRoot $terminalRoot -MaxWaitSeconds 240
    if (-not $reportMaterialized) {
        $reportMaterialized = Use-LegacyRelativeReportExport -TerminalRoot $terminalRoot -AbsoluteReportPath $reportHtmPath -LegacyRelativePath $legacyRelativeSourcePath
    }
    if (-not $reportMaterialized) {
        $reasonClasses.Add("REPORT_MISSING")
        $globalRealTicksMarker = $false
        $testerLog = Get-LatestTesterLog -TerminalRoot $terminalRoot -SinceUtc $runStartUtc
        if (-not $testerLog) {
            $logsDir = Join-Path $terminalRoot "Tester\\logs"
            if (Test-Path -LiteralPath $logsDir -PathType Container) {
                $testerLog = Get-ChildItem -LiteralPath $logsDir -File |
                    Sort-Object LastWriteTimeUtc -Descending |
                    Select-Object -First 1
            }
        }
        $testerLogPath = $null
        $testerLogTail = ""
        if ($testerLog) {
            $testerLogPath = Join-Path $runDir $testerLog.Name
            Copy-Item -LiteralPath $testerLog.FullName -Destination $testerLogPath -Force
            $testerLogTail = Get-TesterLogTailText -TesterLogPath $testerLogPath -LineCount 120
        }
        $failureHints = New-Object System.Collections.Generic.List[string]
        if (Test-TesterLogShowsOnInitFailure -TesterLogTail $testerLogTail) {
            $failureHints.Add("ONINIT_FAILED")
            $reasonClasses.Add("ONINIT_FAILED")
            $globalOnInitFailure = $true
            if ($newsCalendarDiagnostics.status -ne "OK") {
                $failureHints.Add("NEWS_CALENDAR_$($newsCalendarDiagnostics.status)")
                $reasonClasses.Add("NEWS_CALENDAR_$($newsCalendarDiagnostics.status)")
            }
        }
        if (Test-TesterLogShowsSetupDataMissing -TesterLogTail $testerLogTail) {
            $failureHints.Add("SETUP_DATA_MISSING")
            $reasonClasses.Add("SETUP_DATA_MISSING")
        }
        $lingeringMeta = @(Get-MetaTesterProcessesForTerminalRoot -TerminalRoot $terminalRoot)
        if (@($lingeringMeta).Count -gt 0) {
            $failureHints.Add("METATESTER_HUNG")
            $reasonClasses.Add("METATESTER_HUNG")
            foreach ($metaProc in $lingeringMeta) {
                try {
                    Stop-Process -Id $metaProc.ProcessId -Force -ErrorAction Stop
                } catch {
                }
            }
        }
        $runResults += [pscustomobject]@{
            run = $runName
            status = "FAIL"
            failure = "REPORT_MISSING"
            error = "Strategy tester did not produce report file at canonical or legacy relative export path."
            exit_code = $exitCode
            report_source_path = $sourceReportPath
            report_canonical_path = $reportHtmPath
            report_size_bytes = 0
            tester_log_path = $testerLogPath
            tester_log_tail = $testerLogTail
            failure_hints = @($failureHints)
        }
        continue
    }

    $sourceInfo = Get-Item -LiteralPath $sourceReportPath
    if ($sourceInfo.Length -le 0) {
        $reasonClasses.Add("REPORT_EMPTY")
        $globalRealTicksMarker = $false
        $runResults += [pscustomobject]@{
            run = $runName
            status = "FAIL"
            failure = "REPORT_EMPTY"
            error = "Strategy tester produced size-0 report file (infra NO_REPORT)."
            exit_code = $exitCode
            report_source_path = $sourceReportPath
            report_canonical_path = $reportHtmPath
            report_size_bytes = [int64]$sourceInfo.Length
            tester_log_path = $null
        }
        continue
    }

    if (-not (Test-Path -LiteralPath $reportHtmPath -PathType Leaf)) {
        try {
            Copy-Item -LiteralPath $sourceReportPath -Destination $reportHtmPath -Force
        } catch {
        }
    }
    if (-not (Test-Path -LiteralPath $reportHtmPath -PathType Leaf)) {
        $reasonClasses.Add("REPORT_MISSING")
        $globalRealTicksMarker = $false
        $runResults += [pscustomobject]@{
            run = $runName
            status = "FAIL"
            failure = "REPORT_MISSING"
            error = "Report source exists but canonical copy could not be created."
            exit_code = $exitCode
            report_source_path = $sourceReportPath
            report_canonical_path = $reportHtmPath
            report_size_bytes = [int64]$sourceInfo.Length
            tester_log_path = $null
        }
        continue
    }

    $canonicalInfo = Get-Item -LiteralPath $reportHtmPath
    if ($canonicalInfo.Length -le 0) {
        $reasonClasses.Add("REPORT_EMPTY")
        $globalRealTicksMarker = $false
        $runResults += [pscustomobject]@{
            run = $runName
            status = "FAIL"
            failure = "REPORT_EMPTY"
            error = "Canonical report copy is size-0 (infra NO_REPORT)."
            exit_code = $exitCode
            report_source_path = $sourceReportPath
            report_canonical_path = $reportHtmPath
            report_size_bytes = [int64]$canonicalInfo.Length
            tester_log_path = $null
        }
        continue
    }

    $reportHtml = Get-Content -Raw -LiteralPath $reportHtmPath

    $totalTradesRaw = Get-ReportMetricValue -Html $reportHtml -Label "Total Trades"
    $profitFactorRaw = Get-ReportMetricValue -Html $reportHtml -Label "Profit Factor"
    $drawdownRaw = Get-ReportMetricValue -Html $reportHtml -Label "Equity Drawdown Maximal"
    $netProfitRaw = Get-ReportMetricValue -Html $reportHtml -Label "Total Net Profit"

    $totalTrades = [int](Convert-ReportNumber -Value $totalTradesRaw)
    $profitFactor = Convert-ReportNumber -Value $profitFactorRaw
    $drawdown = Convert-ReportNumber -Value $drawdownRaw
    $netProfit = Convert-ReportNumber -Value $netProfitRaw

    $testerLog = Get-LatestTesterLog -TerminalRoot $terminalRoot -SinceUtc $runStartUtc
    $testerLogPath = $null
    $testerLogTail = ""
    if ($testerLog) {
        $testerLogPath = Join-Path $runDir $testerLog.Name
        Copy-Item -LiteralPath $testerLog.FullName -Destination $testerLogPath -Force
        $testerLogTail = Get-TesterLogTailText -TesterLogPath $testerLogPath -LineCount 800
    }

    $onInitFailure = Test-TesterLogShowsOnInitFailure -TesterLogTail $testerLogTail

    $hasRealTicksMarker = $false
    if ($testerLogTail) {
        $hasRealTicksMarker = [regex]::IsMatch($testerLogTail, "(?im)generating based on real ticks")
    }

    $invalidReasons = Get-ReportInvalidReasons -Html $reportHtml -TesterLogTail $testerLogTail -ExpectedSymbol $Symbol -ExpectedFromDate $fromDate -ExpectedToDate $toDate -HasRealTicksMarker $hasRealTicksMarker
    $invalidVerdict = Resolve-InvalidReportVerdict -InvalidReasons $invalidReasons
    if ($invalidVerdict) {
        $reasonClasses.Add($invalidVerdict)
        if ($invalidReasons -contains "ONINIT_FAILED") {
            $globalOnInitFailure = $true
            if ($newsCalendarDiagnostics.status -ne "OK") {
                $reasonClasses.Add("NEWS_CALENDAR_$($newsCalendarDiagnostics.status)")
            }
        }
        $globalRealTicksMarker = $globalRealTicksMarker -and $hasRealTicksMarker
        $runResults += [pscustomobject]@{
            run = $runName
            status = "INVALID"
            failure = $invalidVerdict
            invalid_report_reasons = @($invalidReasons)
            exit_code = $exitCode
            report_source_path = $sourceReportPath
            report_canonical_path = $reportHtmPath
            report_size_bytes = [int64]$canonicalInfo.Length
            tester_log_path = $testerLogPath
            total_trades = $totalTrades
            total_trades_raw = $totalTradesRaw
            profit_factor = $profitFactor
            profit_factor_raw = $profitFactorRaw
            drawdown = $drawdown
            drawdown_raw = $drawdownRaw
            net_profit = $netProfit
            net_profit_raw = $netProfitRaw
        }
        continue
    }

    if ($onInitFailure) {
        $globalOnInitFailure = $true
        $reasonClasses.Add("ONINIT_FAILED")
        if ($newsCalendarDiagnostics.status -ne "OK") {
            $reasonClasses.Add("NEWS_CALENDAR_$($newsCalendarDiagnostics.status)")
        }
    }
    if (-not $hasRealTicksMarker) {
        $globalRealTicksMarker = $false
        $reasonClasses.Add("NO_REAL_TICKS_MARKER")
    }

    $runResults += [pscustomobject]@{
        run = $runName
        status = "OK"
        exit_code = $exitCode
        report_source_path = $sourceReportPath
        report_canonical_path = $reportHtmPath
        report_size_bytes = [int64]$canonicalInfo.Length
        tester_log_path = $testerLogPath
        oninit_failure = $onInitFailure
        real_ticks_marker = $hasRealTicksMarker
        total_trades = $totalTrades
        total_trades_raw = $totalTradesRaw
        profit_factor = $profitFactor
        profit_factor_raw = $profitFactorRaw
        drawdown = $drawdown
        drawdown_raw = $drawdownRaw
        net_profit = $netProfit
        net_profit_raw = $netProfitRaw
    }
}

$completedRuns = @($runResults | Where-Object { $_.status -eq "OK" })
$completedRunCount = @($completedRuns).Count
$tradeGatePassed = $false
$deterministic = $false

if ($completedRunCount -eq $Runs) {
    $minTradesSeen = ($completedRuns | Measure-Object -Property total_trades -Minimum).Minimum
    $tradeGatePassed = ($minTradesSeen -ge $MinTrades)
    if (-not $tradeGatePassed) {
        $reasonClasses.Add("MIN_TRADES_NOT_MET")
    }

    $fingerprints = $completedRuns | ForEach-Object {
        Convert-RunMetricsToFingerprint -Metrics @{
            total_trades_raw = $_.total_trades_raw
            profit_factor_raw = $_.profit_factor_raw
            drawdown_raw = $_.drawdown_raw
            net_profit_raw = $_.net_profit_raw
        }
    }
    $deterministic = (@($fingerprints | Select-Object -Unique).Count -eq 1)
    if (-not $deterministic) {
        $reasonClasses.Add("NON_DETERMINISTIC")
    }
} else {
    $reasonClasses.Add("INCOMPLETE_RUNS")
}

$realTicksGatePassed = $globalRealTicksMarker -or $AllowMissingRealTicksLogMarker.IsPresent
if (-not $realTicksGatePassed -and -not $AllowMissingRealTicksLogMarker.IsPresent) {
    $reasonClasses.Add("MODEL4_MARKER_REQUIRED")
}

$passed = ($completedRunCount -eq $Runs) -and
    (-not $globalOnInitFailure) -and
    $tradeGatePassed -and
    $deterministic -and
    (-not $globalTimeoutFailure) -and
    $realTicksGatePassed

if (@($reasonClasses).Count -eq 0) {
    $reasonClasses.Add("OK")
}

$summary = [ordered]@{
    timestamp_utc = (Get-Date).ToUniversalTime().ToString("o")
    run_tag = $runTag
    result = $(if ($passed) { "PASS" } else { "FAIL" })
    reason_classes = @($reasonClasses | Select-Object -Unique)
    ea_id = $EAId
    ea_label = $eaLabel
    expert = $Expert
    symbol = $Symbol
    year = $Year
    terminal = $Terminal
    model = $Model
    period = $Period
    min_trades_required = $MinTrades
    deterministic = $deterministic
    oninit_failure_detected = $globalOnInitFailure
    model4_log_marker_detected = $globalRealTicksMarker
    report_dir = $reportDir
    report_export_mode = "relative_with_absolute_fallback"
    news_calendar = $newsCalendarDiagnostics
    runs = $runResults
}

$summaryPath = Join-Path $reportDir "summary.json"
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding utf8

$safeSymbol = ($Symbol -replace '[^A-Za-z0-9]+', '_').Trim('_')
if ([string]::IsNullOrWhiteSpace($safeSymbol)) {
    $safeSymbol = "symbol"
}
$evidencePath = Join-Path $frameworkEvidenceDir ("{0}_{1}_{2}_{3}_run_smoke.md" -f $runTag, $eaLabel, $effectiveTerminal, $safeSymbol)
$evidenceLines = @(
    "# Step 22 Smoke Evidence",
    "",
    "- timestamp_utc: $($summary.timestamp_utc)",
    "- result: $($summary.result)",
    "- ea_id: $EAId",
    "- expert: $Expert",
    "- symbol: $Symbol",
    "- terminal: $Terminal",
    "- year: $Year",
    "- model: $Model",
    "- reason_classes: $([string]::Join(', ', $summary.reason_classes))",
    "- summary_json: $summaryPath",
    "- report_dir: $reportDir",
    "- report_export_mode: relative_with_absolute_fallback",
    "",
    "## Report Chain Evidence"
)

foreach ($run in $runResults) {
    $evidenceLines += "- $($run.run): source=$($run.report_source_path) -> target=$($run.report_canonical_path) bytes=$($run.report_size_bytes) status=$($run.status)"
}
try {
    Set-Content -LiteralPath $evidencePath -Value $evidenceLines -Encoding utf8 -ErrorAction Stop
} catch {
    Write-Host ("run_smoke.evidence_write_failed path='{0}' err='{1}'" -f $evidencePath, $_.Exception.Message)
    $fallbackEvidencePath = Join-Path $reportDir "run_smoke_evidence.md"
    Set-Content -LiteralPath $fallbackEvidencePath -Value $evidenceLines -Encoding utf8
    $evidencePath = $fallbackEvidencePath
}

Write-Output "run_smoke.result=$($summary.result)"
Write-Output "run_smoke.reason_classes=$([string]::Join(';', $summary.reason_classes))"
Write-Output "run_smoke.summary=$summaryPath"
Write-Output "run_smoke.report_dir=$reportDir"
Write-Output "run_smoke.evidence=$evidencePath"

    Invoke-DispatchCompletion -OriginalTargetTerminal $Terminal -EAIdValue $EAId -SymbolName $Symbol -PeriodName $Period -YearValue $Year -SetFilePath $SetFile -DispatchPhaseValue $DispatchPhase -DispatchVersionValue $DispatchVersion -DispatchSubGateHashValue $DispatchSubGateHash

try {
    $pumpExe = (Get-Command pythonw.exe -ErrorAction SilentlyContinue).Source
    if (-not $pumpExe) { $pumpExe = (Get-Command python.exe).Source }
    Start-Process -FilePath $pumpExe -ArgumentList @(
        'tools/strategy_farm/farmctl.py','pump'
    ) -WorkingDirectory 'C:/QM/repo' -WindowStyle Hidden
    Write-Output "run_smoke.stage=post_run_pump_triggered"
} catch {
    Write-Host "post-run pump trigger failed (non-fatal): $_"
}

if (-not $passed) {
    exit 1
}

exit 0

