[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [int]$EAId,
    [Parameter(Mandatory = $true)]
    [string]$Symbol,
    [Parameter(Mandatory = $true)]
    [ValidateRange(2000, 2100)]
    [int]$Year,
    [ValidateSet("T1", "T2", "T3", "T4", "T5")]
    [string]$Terminal = "T1",
    [string]$Expert,
    [string]$Period = "H1",
    [ValidateRange(2, 10)]
    [int]$Runs = 2,
    [ValidateRange(0, 1000000)]
    [int]$MinTrades = 20,
    [ValidateSet(4)]
    [int]$Model = 4,
    [ValidateRange(60, 7200)]
    [int]$TimeoutSeconds = 1800,
    [string]$SetFile,
    [string]$ReportRoot = "D:\QM\reports\smoke",
    [switch]$AllowRunningTerminal,
    [switch]$AllowMissingRealTicksLogMarker
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        throw "Terminal root does not exist: $root"
    }
    return (Resolve-Path -LiteralPath $root).Path
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
        [string]$ReportPath,
        [string]$SetFilePath
    )

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
        "Deposit=10000",
        "Currency=USD",
        "ProfitInPips=0",
        "Leverage=100",
        "UseLocal=1",
        "Visual=0",
        "Replace=1",
        "ReplaceReport=1",
        "ShutdownTerminal=1",
        "Report=$ReportPath"
    )

    if ($SetFilePath) {
        $lines += "ExpertParameters=$SetFilePath"
    }

    Set-Content -LiteralPath $Path -Value $lines -Encoding ascii
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

function Start-TesterRun {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TerminalExe,
        [Parameter(Mandatory = $true)]
        [string]$IniPath,
        [Parameter(Mandatory = $true)]
        [int]$TimeoutSec
    )

    $args = @("/portable", "/config:$IniPath")
    $proc = Start-Process -FilePath $TerminalExe -ArgumentList $args -PassThru
    $finished = $proc.WaitForExit($TimeoutSec * 1000)
    if (-not $finished) {
        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
        } catch {
        }
        throw "Tester run timed out after $TimeoutSec seconds for ini: $IniPath"
    }
    return $proc.ExitCode
}

function Convert-RunMetricsToFingerprint {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Metrics
    )

    return "{0}|{1}|{2}|{3}" -f $Metrics.total_trades_raw, $Metrics.profit_factor_raw, $Metrics.drawdown_raw, $Metrics.net_profit_raw
}

$terminalRoot = Resolve-TerminalRoot -TerminalName $Terminal
$terminalExe = Resolve-TerminalExecutable -TerminalRoot $terminalRoot

if (-not $AllowRunningTerminal.IsPresent) {
    if (Test-TerminalAlreadyRunning -TerminalRoot $terminalRoot) {
        throw "Terminal instance is already running for $TerminalRoot. Stop it first or pass -AllowRunningTerminal."
    }
}

if (-not $Expert) {
    $Expert = "QM\QM5_{0}" -f $EAId
}

if ($SetFile) {
    $SetFile = (Resolve-Path -LiteralPath $SetFile).Path
}

$runTag = (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss")
$eaLabel = "QM5_{0}" -f $EAId
$reportDir = Join-Path $ReportRoot "$eaLabel\$runTag"
$rawDir = Join-Path $reportDir "raw"
$frameworkEvidenceDir = "D:\QM\reports\framework\22"

New-Item -ItemType Directory -Path $rawDir -Force | Out-Null
New-Item -ItemType Directory -Path $frameworkEvidenceDir -Force | Out-Null

$fromDate = "{0}.01.01" -f $Year
$toDate = "{0}.12.31" -f $Year

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
    $runStartUtc = (Get-Date).ToUniversalTime()

    Write-TesterIni -Path $iniPath `
        -ExpertPath $Expert `
        -SymbolName $Symbol `
        -Timeframe $Period `
        -ModelMode $Model `
        -FromDate $fromDate `
        -ToDate $toDate `
        -ReportPath $reportHtmPath `
        -SetFilePath $SetFile

    $exitCode = $null
    try {
        $exitCode = Start-TesterRun -TerminalExe $terminalExe -IniPath $iniPath -TimeoutSec $TimeoutSeconds
    } catch {
        $globalTimeoutFailure = $true
        $globalRealTicksMarker = $false
        $reasonClasses.Add("TIMEOUT")
        $runResults += [pscustomobject]@{
            run = $runName
            status = "FAIL"
            failure = "TIMEOUT"
            error = $_.Exception.Message
            exit_code = $null
            report_path = $reportHtmPath
            tester_log_path = $null
        }
        continue
    }

    if (-not (Test-Path -LiteralPath $reportHtmPath -PathType Leaf)) {
        $reasonClasses.Add("REPORT_MISSING")
        $globalRealTicksMarker = $false
        $runResults += [pscustomobject]@{
            run = $runName
            status = "FAIL"
            failure = "REPORT_MISSING"
            error = "Strategy tester did not produce report file."
            exit_code = $exitCode
            report_path = $reportHtmPath
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
        $testerLogTail = ((Get-Content -LiteralPath $testerLogPath | Select-Object -Last 800) -join [Environment]::NewLine)
    }

    $onInitFailure = $false
    if ($testerLogTail) {
        $onInitFailure = [regex]::IsMatch($testerLogTail, "(?im)\b(OnInit|init)\b.*\b(failed|INIT_FAILED)\b") -or
            [regex]::IsMatch($testerLogTail, "(?im)initialization failed")
    }

    $hasRealTicksMarker = $false
    if ($testerLogTail) {
        $hasRealTicksMarker = [regex]::IsMatch($testerLogTail, "(?im)generating based on real ticks")
    }

    if ($onInitFailure) {
        $globalOnInitFailure = $true
        $reasonClasses.Add("ONINIT_FAILED")
    }
    if (-not $hasRealTicksMarker) {
        $globalRealTicksMarker = $false
        $reasonClasses.Add("NO_REAL_TICKS_MARKER")
    }

    $runResults += [pscustomobject]@{
        run = $runName
        status = "OK"
        exit_code = $exitCode
        report_path = $reportHtmPath
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
$tradeGatePassed = $false
$deterministic = $false

if ($completedRuns.Count -eq $Runs) {
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
    $deterministic = (($fingerprints | Select-Object -Unique).Count -eq 1)
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

$passed = ($completedRuns.Count -eq $Runs) -and
    (-not $globalOnInitFailure) -and
    $tradeGatePassed -and
    $deterministic -and
    (-not $globalTimeoutFailure) -and
    $realTicksGatePassed

if ($reasonClasses.Count -eq 0) {
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
    runs = $runResults
}

$summaryPath = Join-Path $reportDir "summary.json"
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding utf8

$evidencePath = Join-Path $frameworkEvidenceDir ("{0}_{1}_run_smoke.md" -f $runTag, $eaLabel)
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
    "- report_dir: $reportDir"
)
Set-Content -LiteralPath $evidencePath -Value $evidenceLines -Encoding utf8

Write-Output "run_smoke.result=$($summary.result)"
Write-Output "run_smoke.reason_classes=$([string]::Join(';', $summary.reason_classes))"
Write-Output "run_smoke.summary=$summaryPath"
Write-Output "run_smoke.report_dir=$reportDir"
Write-Output "run_smoke.evidence=$evidencePath"

if (-not $passed) {
    exit 1
}

exit 0
