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
    [ValidateSet("any", "DEV1", "DEV2", "T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8", "T9", "T10")]
    [string]$Terminal = "T1",
    [string]$Expert,
    [string]$Period = "H1",
    [ValidateRange(1, 10)]
    [int]$Runs = 2,
    [ValidateRange(0, 1000000)]
    [int]$MinTrades = 5,
    [ValidateSet(4)]
    [int]$Model = 4,
    # Max raised 7200 -> 28800 (2026-07-02): multi-symbol basket Q02 runs pay a
    # one-time cold tick-sync of EVERY member symbol (~10 min/member; a 28-symbol
    # basket like T-WIN needs ~5h). farmctl passes a symbol-scaled timeout capped
    # at 25200s; the old 7200 max rejected it at parameter binding and the basket
    # class INFRA_FAILed in 2s. Single-symbol dispatches still pass <=14400.
    [ValidateRange(60, 28800)]
    [int]$TimeoutSeconds = 1800,
    [string]$SetFile,
    [string]$ReportRoot = "D:\QM\reports\smoke",
    [string]$DispatchPhase = "P1",
    [string]$DispatchVersion = "smoke",
    [string]$DispatchSubGateHash,
    [switch]$AllowRunningTerminal,
    [switch]$AllowMissingRealTicksLogMarker,
    # Q04 commission gate: round-trip USD/lot to apply via the tester groups file.
    # 0 (default) = restore the canonical real Darwinex schedule unchanged (Q02/Q03).
    [ValidateRange(0, 1000)]
    [double]$CommissionPerLot = 0,
    # Exact native-currency amount charged on every IN and OUT deal. This is a
    # separate, empirically reconciled interface; never pass a USD round trip here.
    [ValidateRange(0, 1000)]
    [double]$CommissionPerSideNative = 0,
    [ValidatePattern('^[A-Z]{3}$')]
    [string]$TesterCurrencyOverride,
    [ValidateRange(0, 2147483647)]
    [int]$TesterDepositOverride = 0,
    # 2026-07-07: build-smoke context. The Q02 min-trades floor (Max(5, 5*years))
    # exists to judge FREQUENCY over full history; applying it to a single-year
    # BUILD smoke false-fails genuinely low-frequency / episodic EAs with
    # MIN_TRADES_NOT_MET (e.g. QM5_13018 XAG vol-compression: 4 real trades in
    # 2024 -> FAIL vs floor 5), which codex_review then rejects. Frequency is
    # Q02's judgment, not the build's — the build smoke only verifies the EA
    # compiles AND generates orders. In SmokeMode the caller's -MinTrades is
    # honored verbatim (build passes 1); Q02 never sets this switch, so its
    # floor is untouched.
    [switch]$SmokeMode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (($Terminal -ieq "DEV1") -and $AllowRunningTerminal.IsPresent) {
    throw "Refusing -Terminal DEV1 with -AllowRunningTerminal. DEV1 smoke runs require an idle terminal."
}
if (($Terminal -ieq "DEV2") -and $AllowRunningTerminal.IsPresent) {
    throw "Refusing -Terminal DEV2 with -AllowRunningTerminal. DEV2 smoke runs require an idle terminal."
}

if ($Terminal -ieq "DEV1") {
    try {
        $dev1Account = New-Object System.Security.Principal.NTAccount("$env:COMPUTERNAME\QMDev1")
        $dev1Sid = $dev1Account.Translate([System.Security.Principal.SecurityIdentifier]).Value
        $currentSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    } catch {
        throw "Unable to verify the required DEV1 Windows identity '$env:COMPUTERNAME\QMDev1': $($_.Exception.Message)"
    }
    if ($currentSid -cne $dev1Sid) {
        throw "Refusing -Terminal DEV1 under Windows SID '$currentSid'. DEV1 requires the isolated '$env:COMPUTERNAME\QMDev1' identity (SID '$dev1Sid')."
    }
}
if ($Terminal -ieq "DEV2") {
    try {
        $dev2Account = New-Object System.Security.Principal.NTAccount("$env:COMPUTERNAME\QMDev2")
        $dev2Sid = $dev2Account.Translate([System.Security.Principal.SecurityIdentifier]).Value
        $currentSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    } catch {
        throw "Unable to verify the required DEV2 Windows identity '$env:COMPUTERNAME\QMDev2': $($_.Exception.Message)"
    }
    if ($currentSid -cne $dev2Sid) {
        throw "Refusing -Terminal DEV2 under Windows SID '$currentSid'. DEV2 requires the isolated '$env:COMPUTERNAME\QMDev2' identity (SID '$dev2Sid')."
    }
}

if ($EAId -le 0) {
    if ([string]::IsNullOrWhiteSpace($EALabel) -or $EALabel -notmatch '^(?:QM5_)?(?<id>\d+)') {
        throw "Provide -EAId or an -EALabel beginning with a numeric EA id."
    }
    $EAId = [int]$Matches["id"]
}

function Convert-HtmlEntityText {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text
    )

    return ($Text -replace '&nbsp;', ' ' -replace '&amp;', '&' -replace '&lt;', '<' -replace '&gt;', '>' -replace '&quot;', '"')
}

function Get-ReportMetricValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Html,
        [Parameter(Mandatory = $true)]
        [string]$Label,
        [switch]$AllowMissing
    )

    # MT5 renders the report in the terminal UI language. T2/T6 run a German UI
    # (docs/ops: T2/T6 German-locale report drift) so the English labels miss and
    # the run false-fails as REPORT_FORMAT_DRIFT even when the EA traded. Try each
    # label's German alias too. German strings verified against a real German
    # report.htm (QM5_10440 baseline 2026-06-05), not invented; "Symbol" is
    # identical in the German UI so it needs no alias.
    $germanAliases = @{
        "Total Trades"            = "Gesamtanzahl Trades"
        "Profit Factor"           = "Profitfaktor"
        "Total Net Profit"        = "Nettogewinn gesamt"
        "Expert"                  = "Expertenprogramm"
        "Period"                  = "Periode"
        "Bars"                    = "Balken"
        # 2026-07-06 audit G1: these two were missing from the alias map, so on
        # German terminals the drawdown silently parsed as 0.0 — the DD ceiling
        # never bound there. Verified against the same real German report
        # (QM5_10440 baseline: "Rückgang Equity maximal", "Qualität der Historie").
        "Equity Drawdown Maximal" = "Rückgang Equity maximal"
        "History Quality"         = "Qualität der Historie"
    }
    $candidateLabels = @($Label)
    if ($germanAliases.ContainsKey($Label)) { $candidateLabels += $germanAliases[$Label] }

    foreach ($candidate in $candidateLabels) {
        $regex = [regex]::new("(?is)<td[^>]*>\s*$([regex]::Escape($candidate)):\s*</td>\s*<td[^>]*>\s*<b>(?<value>[^<]*)</b>", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        $match = $regex.Match($Html)
        if ($match.Success) {
            return Convert-HtmlEntityText -Text $match.Groups["value"].Value.Trim()
        }
    }

    if ($AllowMissing) { return $null }
    throw "Could not find metric label '$Label' in report."
}

function Test-ReportShowsRealTicks {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Html
    )

    $historyQuality = Get-ReportMetricValue -Html $Html -Label "History Quality" -AllowMissing
    return ($null -ne $historyQuality -and $historyQuality -match "(?i)\breal\s+ticks\b")
}

# FW8-classifier 2026-05-23 — per-metric error isolation. Pre-fix, this
# function wrapped 8 separate label reads in one try/catch — any single
# missing label collapsed all 8 checks to REPORT_PARSE_ERROR, which the
# verdict resolver then mapped to INVALID_REPORT. Result: a legitimate
# 0-trade run with a slightly drifted HTML label flagged INVALID instead
# of routing through MIN_TRADES_NOT_MET. New behaviour:
#   * Read each metric with -AllowMissing → null on miss, no throw.
#   * Add REPORT_METRIC_MISSING:<label> for each missing label (preserves
#     diagnostic detail without collapsing the run).
#   * Genuinely unparseable HTML (empty or no <td> at all) → REPORT_EMPTY.
#   * BARS_ZERO is now a distinct verdict (was buried in INVALID_REPORT).
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
        [bool]$HasRealTicksMarker,
        # FW9 2026-05-24 — when the strategy actually traded (> 0 deals) we
        # know the tester ran far enough to execute logic; suppressing the
        # NO_REAL_TICKS_MARKER_FAST_FINISH flag in that case avoids false
        # INVALIDs on basket EAs whose host-symbol marker log line gets
        # consumed before run_smoke's tail window.
        [int]$ReportTotalTrades = -1
    )

    $reasons = New-Object System.Collections.Generic.List[string]

    # Pre-flight: is this HTML even a tester report?
    if ([string]::IsNullOrWhiteSpace($Html) -or $Html.Length -lt 100 -or $Html -notmatch '(?is)<td[^>]*>') {
        $reasons.Add("REPORT_EMPTY")
        return @($reasons)
    }

    $expertValue = Get-ReportMetricValue -Html $Html -Label "Expert" -AllowMissing
    $symbolValue = Get-ReportMetricValue -Html $Html -Label "Symbol" -AllowMissing
    $periodValue = Get-ReportMetricValue -Html $Html -Label "Period" -AllowMissing
    $barsValue   = Get-ReportMetricValue -Html $Html -Label "Bars"   -AllowMissing

    if ($null -eq $expertValue) { $reasons.Add("REPORT_METRIC_MISSING:Expert") }
    elseif ([string]::IsNullOrWhiteSpace($expertValue)) { $reasons.Add("EMPTY_EXPERT") }

    if ($null -eq $symbolValue) { $reasons.Add("REPORT_METRIC_MISSING:Symbol") }
    elseif ([string]::IsNullOrWhiteSpace($symbolValue)) { $reasons.Add("EMPTY_SYMBOL") }

    if ($null -eq $periodValue) { $reasons.Add("REPORT_METRIC_MISSING:Period") }
    elseif ($periodValue -match "(?i)\bM0\b" -or $periodValue -match "1970\.01\.01\s*-\s*1970\.01\.01") { $reasons.Add("M0_1970_PERIOD") }

    $bars = -1
    if ($null -eq $barsValue) {
        $reasons.Add("REPORT_METRIC_MISSING:Bars")
    } else {
        try {
            $bars = [int](Convert-ReportNumber -Value $barsValue)
            if ($bars -le 0) { $reasons.Add("BARS_ZERO") }
        } catch {
            $reasons.Add("REPORT_METRIC_UNPARSEABLE:Bars")
        }
    }

    # 2026-07-06 audit G13: graded metrics (Trades/PF/Drawdown/Net) previously
    # had NO invalid marker — a drifted or unlocalized label produced a
    # structurally "OK" run whose 0-defaults were then graded as strategy
    # metrics (0 trades -> MIN_TRADES_NOT_MET, pf 0.0 -> pf_below_floor).
    # A missing label on an otherwise-real report is parser drift, not a result.
    foreach ($gradedLabel in @("Total Trades", "Profit Factor", "Equity Drawdown Maximal", "Total Net Profit")) {
        $gradedValue = Get-ReportMetricValue -Html $Html -Label $gradedLabel -AllowMissing
        if ($null -eq $gradedValue) {
            $reasons.Add("REPORT_METRIC_MISSING:$($gradedLabel -replace '\s', '')")
        }
    }

    # Log-tail driven checks run only when the report did not prove execution.
    # Busy terminals append unrelated later EA failures to the shared tester log;
    # a current report with trades proves this run's OnInit succeeded.
    if ($ReportTotalTrades -le 0 -and (Test-TesterLogShowsOnInitFailure -TesterLogTail $TesterLogTail)) { $reasons.Add("ONINIT_FAILED") }
    if (Test-TesterLogShowsSetupDataMissing -TesterLogTail $TesterLogTail) { $reasons.Add("SETUP_DATA_MISSING") }
    $hasCurrentRunNoHistory = Test-TesterLogHasNoHistoryForRun -TesterLogTail $TesterLogTail -ExpectedSymbol $ExpectedSymbol -ExpectedFromDate $ExpectedFromDate -ExpectedToDate $ExpectedToDate
    if ($hasCurrentRunNoHistory) { $reasons.Add("NO_HISTORY_LOG") }
    if ($bars -ge 0 -and ($periodValue -match "(?i)\bM0\b" -or $bars -le 0) -and $hasCurrentRunNoHistory) { $reasons.Add("HISTORY_CONTEXT_INVALID") }
    # FW9 2026-05-24 — only flag NO_REAL_TICKS if the EA also produced 0 trades.
    # If the report shows real trade activity, the marker absence is a
    # logging quirk (esp. on basket EAs) not a tester-failure signal.
    if ((-not $HasRealTicksMarker) -and $TesterLogTail -match "(?im)automatical testing finished" -and ($ReportTotalTrades -le 0)) {
        $reasons.Add("NO_REAL_TICKS_MARKER_FAST_FINISH")
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
        [regex]::IsMatch($TesterLogTail, "(?im)\bOnInit\b[^\r\n]*(?:failed|INIT_FAILED|non-zero\s+code)") -or
        [regex]::IsMatch($TesterLogTail, "(?im)\bINIT_FAILED\b") -or
        [regex]::IsMatch($TesterLogTail, "(?im)\binitialization\s+failed\b")
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

function Test-TesterLogShowsAccountNotSpecified {
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$TesterLogTail
    )

    if ([string]::IsNullOrWhiteSpace($TesterLogTail)) {
        return $false
    }
    return [regex]::IsMatch($TesterLogTail, "(?im)\btester not started because the account is not specified\b")
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
    $runStartPattern = "(?i)\b${symbolPattern},[^\r\n]*:\s+testing of Experts\\[^\r\n]+\s+from\s+$fromPattern\s+00:00\s+to\s+$toPattern\s+00:00\b"
    $syncErrorPattern = "(?i)\b${symbolPattern}:\s+history synchronization error\b"
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

    # MT5 build 5833 can abort before exporting even an empty report and emits
    # only "<symbol>: history synchronization error". Scope this shorter form
    # to the exact EA-run marker and requested date window so an unrelated
    # failure appended to the shared tester log cannot poison the current run.
    for ($idx = 0; $idx -lt $lines.Count; $idx++) {
        if ($lines[$idx] -notmatch $runStartPattern) {
            continue
        }
        $lastContextLine = [Math]::Min($idx + 5, $lines.Count - 1)
        for ($contextIdx = $idx + 1; $contextIdx -le $lastContextLine; $contextIdx++) {
            if ($lines[$contextIdx] -match $syncErrorPattern) {
                return $true
            }
        }
    }

    return $false
}

function Get-TesterLogCurrentRunText {
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$TesterLogTail
    )

    if ([string]::IsNullOrWhiteSpace($TesterLogTail)) {
        return ""
    }

    # MetaTester reuses one daily journal per terminal agent.  A copied log can
    # therefore contain a previous EA's OnInit failure before the current run.
    # The last test-start marker begins the only journal section relevant to
    # the report we are classifying.
    $matches = [regex]::Matches(
        $TesterLogTail,
        "(?im)^.*\btesting of Experts\\.*\.ex5\s+from\s+.*\bstarted with inputs:\s*$"
    )
    if ($matches.Count -eq 0) {
        return $TesterLogTail
    }

    return $TesterLogTail.Substring($matches[$matches.Count - 1].Index)
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
    # FW8-classifier — REPORT_EMPTY is "MT5 wrote nothing" (genuinely broken);
    # BARS_ZERO is "MT5 ran but loaded no bars" (history gap, distinct cause).
    if ($InvalidReasons -contains "REPORT_EMPTY") {
        return "REPORT_EMPTY"
    }
    if ($InvalidReasons -contains "BARS_ZERO") {
        return "BARS_ZERO"
    }
    # If only metric-missing reasons remain (HTML format drift), surface them
    # explicitly so we can fix the parser instead of swallowing as INVALID.
    $onlyMetricMissing = $true
    foreach ($r in $InvalidReasons) {
        if (-not $r.StartsWith("REPORT_METRIC_MISSING:") -and -not $r.StartsWith("REPORT_METRIC_UNPARSEABLE:")) {
            $onlyMetricMissing = $false
            break
        }
    }
    if ($onlyMetricMissing -and @($InvalidReasons).Count -gt 0) {
        return "REPORT_FORMAT_DRIFT"
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
    $isFactoryTerminal = $TerminalName -match '^T([1-9]|10)$'
    $isExplicitDevTerminal = $TerminalName -match '^DEV[12]$'
    if (-not $isFactoryTerminal -and -not $isExplicitDevTerminal) {
        throw "Refusing terminal '$TerminalName'. Allowed terminals are factory T1..T10 plus explicit development terminals DEV1/DEV2; T_Live is off limits."
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
    # Repo source: <this script's resolved repo root>\framework\EAs\<EaLabel>\<EaLabel>.ex5
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

    $localRepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
    $repoSource = Join-Path (Join-Path $localRepoRoot "framework\EAs") (Join-Path $eaLabel "$eaLabel.ex5")
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
    # Some bounded build-smoke callers intentionally run before a P2 setfile
    # exists. They still need "any" terminal dispatch, but cannot provide a
    # setfile identity for resolve_backtest_target.py. Pick a currently-free
    # factory terminal directly instead of aborting before MT5 starts.
    if ([string]::IsNullOrWhiteSpace($SetFilePath)) {
        foreach ($candidate in @("T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8", "T9", "T10")) {
            try {
                $candidateRoot = Resolve-TerminalRoot -TerminalName $candidate
                if (-not (Test-TerminalAlreadyRunning -TerminalRoot $candidateRoot)) {
                    Write-Host "run_smoke.dispatch_status=fallback_no_setfile"
                    Write-Host ("run_smoke.dispatch_terminal={0}" -f $candidate)
                    return $candidate
                }
            } catch {
                Write-Host ("run_smoke.dispatch_skip_terminal={0} err='{1}'" -f $candidate, $_.Exception.Message)
            }
        }
        throw "Resolve-DispatchTerminal found no free T1-T10 terminal for -TargetTerminal='any' without -SetFilePath."
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
        if ($decisionTerminal -notmatch '^T([1-9]|10)$') {
            throw "Terminal resolution returned non-factory terminal '$decisionTerminal'. -Terminal any is restricted to T1..T10."
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

    $terminalExe = Join-Path $TerminalRoot "terminal64.exe"
    try {
        $terminalExe = (Resolve-Path -LiteralPath $terminalExe -ErrorAction Stop).Path
    } catch {
    }
    $escapedExe = [regex]::Escape($terminalExe)
    $escapedRoot = [regex]::Escape($TerminalRoot.TrimEnd('\', '/'))
    $rootWithBoundary = $escapedRoot + '(?:[\\/"]|$)'
    $processes = Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue
    if (-not $processes) {
        return $false
    }

    foreach ($proc in $processes) {
        $exePath = [string]$proc.ExecutablePath
        if ($exePath -and ($exePath -ieq $terminalExe)) {
            return $true
        }

        $line = [string]$proc.CommandLine
        if ($line -and (
            [regex]::IsMatch($line, $escapedExe, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase) -or
            [regex]::IsMatch($line, $rootWithBoundary, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        )) {
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
        [string]$SetFilePath,
        [string]$CurrencyOverride,
        [ValidateRange(0, 2147483647)]
        [int]$DepositOverride = 0
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

    $manifestPath = $null
    $manifest = $null
    if (-not [string]::IsNullOrWhiteSpace($SetFilePath)) {
        $setDir = Split-Path -Parent $SetFilePath
        $eaDir = Split-Path -Parent $setDir
        $manifestPath = Join-Path $eaDir "basket_manifest.json"
        if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
            try {
                $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
            } catch {
                Write-Host ("run_smoke.warn=basket_manifest_unreadable path='{0}' err='{1}'" -f $manifestPath, $_.Exception.Message)
            }
        }
    }

    $manifestDepositApplied = $false
    if ($manifest) {
        if ([string]::IsNullOrWhiteSpace($CurrencyOverride)) {
            $currencyProperty = $manifest.PSObject.Properties["tester_currency"]
            if ($null -ne $currencyProperty) {
                $manifestCurrency = [string]$currencyProperty.Value
                if (-not [string]::IsNullOrWhiteSpace($manifestCurrency)) {
                    $currency = $manifestCurrency.Trim().ToUpperInvariant()
                }
            }
        }

        foreach ($depositPropertyName in @("tester_deposit", "tester_initial_deposit")) {
            $depositProperty = $manifest.PSObject.Properties[$depositPropertyName]
            if ($null -eq $depositProperty) {
                continue
            }
            $manifestDepositText = [string]$depositProperty.Value
            if ([string]::IsNullOrWhiteSpace($manifestDepositText)) {
                continue
            }
            $manifestDeposit = [int]$manifestDepositText
            if ($manifestDeposit -gt 0) {
                $deposit = $manifestDeposit
                $manifestDepositApplied = $true
            }
            break
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($CurrencyOverride)) {
        $currency = $CurrencyOverride.Trim().ToUpperInvariant()
    }
    if ($DepositOverride -gt 0) {
        $deposit = $DepositOverride
        Write-Host ("run_smoke.tester_deposit_override={0}" -f $deposit)
    } elseif ($manifestDepositApplied) {
        Write-Host ("run_smoke.tester_deposit_manifest={0} path='{1}'" -f $deposit, $manifestPath)
    }
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

function Set-TesterGroupsCommission {
    param(
        [Parameter(Mandatory = $true)][string]$TerminalRoot,
        [Parameter(Mandatory = $true)][string]$SymbolName,
        [Parameter(Mandatory = $true)][double]$CommissionPerLot,
        [Parameter(Mandatory = $true)][double]$CommissionPerSideNative
    )

    # The MT5 strategy tester reads commission from the server-keyed groups file
    # <terminal>\MQL5\Profiles\Tester\Groups\Darwinex-Live_real.txt. The canonical real
    # schedule keys commission to broker paths (Forex\*, Indices\*, ...) that custom
    # .DWX symbols do not match. Q04 injects a top-priority Custom\... matcher for the
    # tested symbol class; CommissionPerLot<=0 restores the canonical file unchanged.
    $localRepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
    $canonical = Join-Path $localRepoRoot "framework\registry\tester_groups\Darwinex-Live_real.canonical.txt"
    if (-not (Test-Path -LiteralPath $canonical -PathType Leaf)) {
        throw "canonical tester groups file missing at $canonical"
    }
    $groupsDir = Join-Path $TerminalRoot "MQL5\Profiles\Tester\Groups"
    New-Item -ItemType Directory -Path $groupsDir -Force | Out-Null
    $target = Join-Path $groupsDir "Darwinex-Live_real.txt"

    $text = [System.IO.File]::ReadAllText($canonical, [System.Text.Encoding]::Unicode)
    $commissionMatcher = $null
    $commissionMode = $null
    if ($CommissionPerLot -gt 0) {
        # Mode=1 charged the documented USD round trip on both sides in symbol
        # base currency. A Build-5833 Mode=0 canary then booked exactly 0.00 on
        # every deal. Until a fixed override is empirically encoded, accepting a
        # positive value would silently misprice research, so fail closed. The
        # canonical Custom\... blocks remain active when the value is zero.
        throw 'UNVALIDATED_FIXED_COMMISSION_OVERRIDE: use CommissionPerLot=0 with the canonical tester group'
    }
    if ($CommissionPerSideNative -gt 0) {
        # Even a correctly dimensioned native block was ignored in an isolated
        # Build-5833 canary because the offline tester never activated the custom
        # groups file. Do not expose a value that the report silently drops.
        throw 'UNAPPLIED_NATIVE_COMMISSION_OVERRIDE: isolated DEV lanes require external deal-level cost reconciliation'
    }
    [System.IO.File]::WriteAllText($target, $text, [System.Text.Encoding]::Unicode)
    $canonicalHash = (Get-FileHash -LiteralPath $canonical -Algorithm SHA256).Hash.ToLowerInvariant()
    $installedHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    return [pscustomobject]@{
        canonical_path = $canonical
        target_path = $target
        canonical_sha256 = $canonicalHash
        installed_sha256 = $installedHash
        commission_per_lot = $CommissionPerLot
        commission_per_side_native = $CommissionPerSideNative
        commission_matcher = $commissionMatcher
        commission_mode = $commissionMode
    }
}

function Get-DwxSymbolAssetClass {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$SymbolName
    )

    $matrix = Join-Path $RepoRoot "framework\registry\dwx_symbol_matrix.csv"
    if (Test-Path -LiteralPath $matrix -PathType Leaf) {
        $row = Import-Csv -LiteralPath $matrix | Where-Object { $_.symbol -eq $SymbolName } | Select-Object -First 1
        if ($null -ne $row -and -not [string]::IsNullOrWhiteSpace($row.asset_class)) {
            return $row.asset_class.ToLowerInvariant()
        }
    }

    if ($SymbolName -match '^(?:GDAXI|NDX|SP500|UK100|WS30|JPN225|GER40|FRA40|AUS200)\.DWX$') {
        return "indices"
    }
    if ($SymbolName -match '^X(?:AU|AG|TI|BR|NG|CU)USD\.DWX$') {
        return "commodities"
    }
    return "forex"
}

function Get-DwxCommissionMatcher {
    param(
        [Parameter(Mandatory = $true)][string]$AssetClass,
        [Parameter(Mandatory = $true)][string]$SymbolName
    )

    switch ($AssetClass.ToLowerInvariant()) {
        "forex" { return "Custom\Forex\*" }
        "commodities" { return "Custom\Commodities\*" }
        "indices" {
            switch -Regex ($SymbolName) {
                '^(?:WS30)\.DWX$' { return "Custom\Indices\Index 1\*" }
                '^(?:GDAXI|GER40)\.DWX$' { return "Custom\Indices\Index DAX\*" }
                default { return "Custom\Indices\Index 3\*" }
            }
        }
        default { return "Custom\*" }
    }
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
        return $true
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

function Publish-TesterReportCandidate {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceReportPath,
        [Parameter(Mandatory = $true)]
        [string]$CanonicalReportPath
    )

    $candidatePaths = @($CanonicalReportPath, $SourceReportPath) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique

    foreach ($candidatePath in $candidatePaths) {
        if (-not (Test-Path -LiteralPath $candidatePath -PathType Leaf)) {
            continue
        }
        try {
            $candidateInfo = Get-Item -LiteralPath $candidatePath -ErrorAction Stop
            if ($candidateInfo.Length -le 0) {
                continue
            }
            if ($candidatePath -ne $CanonicalReportPath) {
                Copy-Item -LiteralPath $candidatePath -Destination $CanonicalReportPath -Force -ErrorAction Stop
            }
            if (Test-Path -LiteralPath $CanonicalReportPath -PathType Leaf) {
                $canonicalInfo = Get-Item -LiteralPath $CanonicalReportPath -ErrorAction Stop
                if ($canonicalInfo.Length -gt 0) {
                    return $CanonicalReportPath
                }
            }
        } catch {
        }
    }

    return $null
}

function Get-FilePrefixSha256 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, [long]::MaxValue)]
        [long]$Length
    )

    $stream = [System.IO.File]::Open(
        $Path,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::ReadWrite
    )
    try {
        if ($stream.Length -lt $Length) {
            throw "File is shorter than the requested hash prefix: path='$Path' length=$($stream.Length) prefix=$Length"
        }

        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        try {
            $buffer = New-Object byte[] 1048576
            $remaining = $Length
            while ($remaining -gt 0) {
                $requested = [int][Math]::Min([long]$buffer.Length, $remaining)
                $read = $stream.Read($buffer, 0, $requested)
                if ($read -le 0) {
                    throw "Unexpected EOF while hashing '$Path'."
                }
                [void]$sha256.TransformBlock($buffer, 0, $read, $null, 0)
                $remaining -= $read
            }
            [void]$sha256.TransformFinalBlock([byte[]]::new(0), 0, 0)
            return ([System.BitConverter]::ToString($sha256.Hash) -replace '-', '').ToLowerInvariant()
        } finally {
            $sha256.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

function Get-QmLoggerFileState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TerminalRoot,
        [Parameter(Mandatory = $true)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$EAIdValue
    )

    $state = @{}
    $testerRoot = Join-Path $TerminalRoot "Tester"
    if (-not (Test-Path -LiteralPath $testerRoot -PathType Container)) {
        return ,$state
    }

    $filePattern = "QM5_{0:d4}_ea-{0:d4}.log" -f $EAIdValue
    $agentDirs = @(Get-ChildItem -LiteralPath $testerRoot -Directory -Filter "Agent-*" -ErrorAction SilentlyContinue |
        Sort-Object FullName)
    foreach ($agentDir in $agentDirs) {
        foreach ($relativeLoggerDir in @("MQL5\Logs\QM", "MQL5\Files\QM")) {
            $loggerDir = Join-Path $agentDir.FullName $relativeLoggerDir
            if (-not (Test-Path -LiteralPath $loggerDir -PathType Container)) {
                continue
            }
            $loggerFiles = @(Get-ChildItem -LiteralPath $loggerDir -File -Filter $filePattern -ErrorAction SilentlyContinue |
                Sort-Object FullName)
            foreach ($loggerFile in $loggerFiles) {
                $state[$loggerFile.FullName] = [pscustomobject]@{
                    length = [long]$loggerFile.Length
                    prefix_sha256 = Get-FilePrefixSha256 -Path $loggerFile.FullName -Length ([long]$loggerFile.Length)
                    ends_with_lf = $(if ($loggerFile.Length -eq 0) {
                        $true
                    } else {
                        $tail = New-Object byte[] 1
                        $tailStream = [System.IO.File]::Open(
                            $loggerFile.FullName,
                            [System.IO.FileMode]::Open,
                            [System.IO.FileAccess]::Read,
                            [System.IO.FileShare]::ReadWrite
                        )
                        try {
                            [void]$tailStream.Seek(-1, [System.IO.SeekOrigin]::End)
                            [void]$tailStream.Read($tail, 0, 1)
                        } finally {
                            $tailStream.Dispose()
                        }
                        ($tail[0] -eq 0x0A)
                    })
                }
            }
        }
    }

    return ,$state
}

function Save-QmLoggerDelta {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$BeforeState,
        [Parameter(Mandatory = $true)]
        [string]$TerminalRoot,
        [Parameter(Mandatory = $true)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$EAIdValue,
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    $afterState = Get-QmLoggerFileState -TerminalRoot $TerminalRoot -EAIdValue $EAIdValue
    $grownFiles = New-Object System.Collections.Generic.List[object]

    foreach ($beforePath in $BeforeState.Keys) {
        if (-not $afterState.ContainsKey($beforePath)) {
            Write-Warning "Structured logger capture skipped: a pre-run logger file disappeared: '$beforePath'."
            return $null
        }
        if ([long]$afterState[$beforePath].length -lt [long]$BeforeState[$beforePath].length) {
            Write-Warning "Structured logger capture skipped: a pre-run logger file was truncated: '$beforePath'."
            return $null
        }
        if ([long]$afterState[$beforePath].length -eq [long]$BeforeState[$beforePath].length -and
            [string]$afterState[$beforePath].prefix_sha256 -cne [string]$BeforeState[$beforePath].prefix_sha256) {
            Write-Warning "Structured logger capture skipped: an unchanged-length logger file was rewritten: '$beforePath'."
            return $null
        }
    }

    foreach ($afterPath in @($afterState.Keys | Sort-Object)) {
        $beforeLength = [long]0
        $beforeHash = $null
        $beforeEndsWithLf = $true
        if ($BeforeState.ContainsKey($afterPath)) {
            $beforeLength = [long]$BeforeState[$afterPath].length
            $beforeHash = [string]$BeforeState[$afterPath].prefix_sha256
            $beforeEndsWithLf = [bool]$BeforeState[$afterPath].ends_with_lf
        }
        $afterLength = [long]$afterState[$afterPath].length
        if ($afterLength -le $beforeLength) {
            continue
        }
        if (-not $beforeEndsWithLf) {
            Write-Warning "Structured logger capture skipped: pre-run logger file did not end at a line boundary: '$afterPath'."
            return $null
        }
        if ($beforeLength -gt 0) {
            $afterPrefixHash = Get-FilePrefixSha256 -Path $afterPath -Length $beforeLength
            if ($afterPrefixHash -cne $beforeHash) {
                Write-Warning "Structured logger capture skipped: pre-run logger bytes changed: '$afterPath'."
                return $null
            }
        }
        $grownFiles.Add([pscustomobject]@{
            path = $afterPath
            start_offset = $beforeLength
            end_offset_exclusive = $afterLength
            snapshot_sha256 = [string]$afterState[$afterPath].prefix_sha256
        })
    }

    if ($grownFiles.Count -ne 1) {
        Write-Warning ("Structured logger capture skipped: expected exactly one growing logger file, found {0}." -f $grownFiles.Count)
        return $null
    }

    $source = $grownFiles[0]
    $deltaLength = [long]$source.end_offset_exclusive - [long]$source.start_offset
    if ($deltaLength -le 0 -or $deltaLength -gt [int]::MaxValue) {
        Write-Warning ("Structured logger capture skipped: invalid delta length {0}." -f $deltaLength)
        return $null
    }

    $deltaBytes = New-Object byte[] ([int]$deltaLength)
    $sourceStream = [System.IO.File]::Open(
        $source.path,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::ReadWrite
    )
    try {
        if ($sourceStream.Length -ne [long]$source.end_offset_exclusive) {
            Write-Warning "Structured logger capture skipped: logger file changed after the post-run snapshot."
            return $null
        }
        [void]$sourceStream.Seek([long]$source.start_offset, [System.IO.SeekOrigin]::Begin)
        $totalRead = 0
        while ($totalRead -lt $deltaBytes.Length) {
            $read = $sourceStream.Read($deltaBytes, $totalRead, $deltaBytes.Length - $totalRead)
            if ($read -le 0) {
                Write-Warning "Structured logger capture skipped: unexpected EOF while reading the logger delta."
                return $null
            }
            $totalRead += $read
        }
    } finally {
        $sourceStream.Dispose()
    }

    $currentSnapshotHash = Get-FilePrefixSha256 -Path $source.path -Length ([long]$source.end_offset_exclusive)
    $currentSourceLength = (Get-Item -LiteralPath $source.path -ErrorAction Stop).Length
    if ($currentSourceLength -ne [long]$source.end_offset_exclusive -or
        $currentSnapshotHash -cne [string]$source.snapshot_sha256) {
        Write-Warning "Structured logger capture skipped: logger bytes changed during delta extraction."
        return $null
    }

    if ($deltaBytes[$deltaBytes.Length - 1] -ne 0x0A) {
        Write-Warning "Structured logger capture skipped: logger delta ended with a partial line."
        return $null
    }

    try {
        $utf8 = [System.Text.UTF8Encoding]::new($false, $true)
        $deltaText = $utf8.GetString($deltaBytes)
    } catch {
        Write-Warning "Structured logger capture skipped: exact logger bytes are not valid UTF-8 JSONL."
        return $null
    }

    $requiredFields = @("sv", "ts_utc", "ts_broker", "level", "ea_id", "slug", "symbol", "tf", "magic", "event", "payload")
    $eventCount = 0
    foreach ($line in @($deltaText -split "`n")) {
        $candidate = $line.TrimEnd("`r")
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }
        try {
            $row = $candidate | ConvertFrom-Json -ErrorAction Stop
        } catch {
            Write-Warning "Structured logger capture skipped: logger delta contains invalid JSON."
            return $null
        }
        $fieldNames = @($row.PSObject.Properties.Name)
        foreach ($requiredField in $requiredFields) {
            if ($fieldNames -notcontains $requiredField) {
                Write-Warning "Structured logger capture skipped: logger row is missing '$requiredField'."
                return $null
            }
        }
        try {
            $rowSchemaVersion = [int]$row.sv
            $rowEAId = [int]$row.ea_id
        } catch {
            Write-Warning "Structured logger capture skipped: logger schema version or EA id is not an integer."
            return $null
        }
        if ($rowSchemaVersion -ne 1 -or $rowEAId -ne $EAIdValue -or
            -not ($row.event -is [string]) -or [string]::IsNullOrWhiteSpace($row.event)) {
            Write-Warning "Structured logger capture skipped: logger row has the wrong schema, EA id, or event."
            return $null
        }
        $eventCount++
    }
    if ($eventCount -le 0) {
        Write-Warning "Structured logger capture skipped: logger delta contained no event rows."
        return $null
    }

    $destinationDir = Split-Path -Parent $DestinationPath
    if (-not [string]::IsNullOrWhiteSpace($destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }
    [System.IO.File]::WriteAllBytes($DestinationPath, $deltaBytes)
    $sampleHash = Get-FilePrefixSha256 -Path $DestinationPath -Length ([long]$deltaBytes.Length)

    return [pscustomobject]@{
        path = [System.IO.Path]::GetFullPath($DestinationPath)
        source_path = [string]$source.path
        source_offset_start = [long]$source.start_offset
        source_offset_end_exclusive = [long]$source.end_offset_exclusive
        source_snapshot_sha256 = [string]$source.snapshot_sha256
        size_bytes = [long]$deltaBytes.Length
        sha256 = $sampleHash
        event_count = $eventCount
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

    # Local tester agents write the decisive NO_HISTORY / OnInit diagnostics
    # under Tester\Agent-*\logs, while Tester\logs normally contains only the
    # controller transcript.  Searching only the controller directory turns a
    # real, classifiable infra fault into REPORT_MISSING and makes the farm burn
    # both retries without preserving the cause.
    $candidate = Get-ChildItem -LiteralPath (Join-Path $TerminalRoot "Tester") -File -Recurse -Filter "*.log" |
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

function Test-TesterReportHasCompleteMetrics {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReportPath
    )

    if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
        return $false
    }
    try {
        $info = Get-Item -LiteralPath $ReportPath -ErrorAction Stop
        if ($info.Length -le 0) {
            return $false
        }
        $html = Get-Content -Raw -LiteralPath $ReportPath -ErrorAction Stop
        $expertValue = Get-ReportMetricValue -Html $html -Label "Expert" -AllowMissing
        $symbolValue = Get-ReportMetricValue -Html $html -Label "Symbol" -AllowMissing
        $periodValue = Get-ReportMetricValue -Html $html -Label "Period" -AllowMissing
        $barsValue = Get-ReportMetricValue -Html $html -Label "Bars" -AllowMissing
        $totalTradesRaw = Get-ReportMetricValue -Html $html -Label "Total Trades" -AllowMissing
        $profitFactorRaw = Get-ReportMetricValue -Html $html -Label "Profit Factor" -AllowMissing
        $drawdownRaw = Get-ReportMetricValue -Html $html -Label "Equity Drawdown Maximal" -AllowMissing

        if ([string]::IsNullOrWhiteSpace($expertValue) -or
            [string]::IsNullOrWhiteSpace($symbolValue) -or
            [string]::IsNullOrWhiteSpace($periodValue) -or
            [string]::IsNullOrWhiteSpace($barsValue) -or
            $null -eq $totalTradesRaw -or
            $null -eq $profitFactorRaw -or
            $null -eq $drawdownRaw) {
            return $false
        }
        if ($periodValue -match "(?i)\bM0\b" -or $periodValue -match "1970\.01\.01\s*-\s*1970\.01\.01") {
            return $false
        }
        $bars = [int](Convert-ReportNumber -Value $barsValue)
        return ($bars -gt 0)
    } catch {
        return $false
    }
}

# Log-bomb guard (mirrors tools/strategy_farm/terminal_worker.py). Some EAs spam
# the tester journal per-tick (~10 GB/min); the work-item worker guards its own
# runs, but smoke/build/ad-hoc runs on free terminals were unguarded (2026-07-06:
# 12 GB and 26 GB T8 journals from build smokes filled D:). Trigger on GROWTH
# RATE (catches the spam within one check window) with a high absolute hard
# ceiling as disk-safety backstop; a legit journal grows ~50-200 MB/min and
# trips neither. Fail-open on any error so a measurement glitch never kills a
# legit run.
$script:LogBombRateMBPerMin = 1500.0
$script:LogBombHardCeilBytes = 4GB
$script:LogBombCheckSeconds = 10.0

function Test-TesterJournalBomb {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ScanDirs,
        [Parameter(Mandatory = $true)]
        [hashtable]$Sizes
    )

    try {
        $nowUtc = (Get-Date).ToUniversalTime()
        foreach ($dir in $ScanDirs) {
            if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
                continue
            }
            $logs = @(Get-ChildItem -LiteralPath $dir -Recurse -Filter *.log -File -ErrorAction SilentlyContinue)
            foreach ($log in $logs) {
                $fp = $log.FullName
                $sz = [double]$log.Length
                $prev = $null
                if ($Sizes.ContainsKey($fp)) {
                    $prev = $Sizes[$fp]
                }
                $Sizes[$fp] = @($sz, $nowUtc)
                $gb = [math]::Round($sz / 1GB, 2)
                if ($sz -gt $script:LogBombHardCeilBytes) {
                    return [pscustomobject]@{
                        path = $fp
                        gb = $gb
                        reason = ("abs>{0}GB" -f [int]($script:LogBombHardCeilBytes / 1GB))
                    }
                }
                if ($prev) {
                    $dMin = [math]::Max(($nowUtc - $prev[1]).TotalMinutes, 1e-6)
                    $rate = (($sz - $prev[0]) / 1MB) / $dMin
                    if ($rate -gt $script:LogBombRateMBPerMin) {
                        return [pscustomobject]@{
                            path = $fp
                            gb = $gb
                            reason = ("rate>{0}MB/min(~{1})" -f [int]$script:LogBombRateMBPerMin, [int]$rate)
                        }
                    }
                }
            }
        }
    } catch {
        return $null
    }
    return $null
}

function Start-TesterRun {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TerminalExe,
        [Parameter(Mandatory = $true)]
        [string]$IniPath,
        [Parameter(Mandatory = $true)]
        [int]$TimeoutSec,
        [string]$ReportPath,
        [string]$TerminalName = $TerminalExe
    )

    $args = @("/portable", "/config:$IniPath")
    $spawnStartedAfter = Get-Date
    Write-Host ("run_smoke.stage=terminal_start exe='{0}' args='{1}' timeout_seconds={2}" -f $TerminalExe, ([string]::Join(' ', $args)), $TimeoutSec)
    $proc = Start-Process -FilePath $TerminalExe -ArgumentList $args -PassThru -WindowStyle Hidden
    $childTerminal = Wait-TerminalSpawn -TerminalExe $TerminalExe -IniPath $IniPath -TerminalName $TerminalName -StartedAfter $spawnStartedAfter
    Write-Host ("run_smoke.stage=terminal_spawn_confirmed terminal_pid={0} start_time='{1:o}'" -f $childTerminal.Id, $childTerminal.StartTime)

    $finished = $false
    $latchedReport = $false
    # Log-bomb guard state: tester journals live under <root>\Tester (dispatcher
    # logs\ + per-run Agent-*\logs) and <root>\logs. Sizes carried across checks
    # so growth rate can be measured.
    $terminalRootForBomb = Split-Path -Parent $TerminalExe
    $logBombScanDirs = @(
        (Join-Path $terminalRootForBomb "Tester"),
        (Join-Path $terminalRootForBomb "logs")
    )
    $logBombSizes = @{}
    $logBombHit = $null
    $logBombLastCheckUtc = (Get-Date).ToUniversalTime()
    $deadline = (Get-Date).ToUniversalTime().AddSeconds($TimeoutSec)
    while ((Get-Date).ToUniversalTime() -lt $deadline) {
        if ($childTerminal.HasExited) {
            $finished = $true
            break
        }
        $nowUtcForBomb = (Get-Date).ToUniversalTime()
        if (($nowUtcForBomb - $logBombLastCheckUtc).TotalSeconds -ge $script:LogBombCheckSeconds) {
            $logBombLastCheckUtc = $nowUtcForBomb
            $logBombHit = Test-TesterJournalBomb -ScanDirs $logBombScanDirs -Sizes $logBombSizes
            if ($logBombHit) {
                Write-Host ("run_smoke.stage=log_bomb_killed terminal_pid={0} journal='{1}' journal_gb={2} bomb_reason='{3}'" -f $childTerminal.Id, $logBombHit.path, $logBombHit.gb, $logBombHit.reason)
                try {
                    Stop-Process -Id $childTerminal.Id -Force -ErrorAction Stop
                } catch {
                }
                if ($proc.Id -ne $childTerminal.Id) {
                    try {
                        Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                    } catch {
                    }
                }
                [void]$childTerminal.WaitForExit(10000)
                $lingeringMeta = @(Get-MetaTesterProcessesForTerminalRoot -TerminalRoot $terminalRootForBomb)
                foreach ($metaProc in $lingeringMeta) {
                    try {
                        Stop-Process -Id $metaProc.ProcessId -Force -ErrorAction Stop
                    } catch {
                    }
                }
                # Reclaim the disk immediately; the journal is spam, not evidence
                # (the stage line above records path/size/reason). May be briefly
                # locked while metatester dies -> short retry, then fail-open.
                for ($delAttempt = 1; $delAttempt -le 3; $delAttempt++) {
                    try {
                        Remove-Item -LiteralPath $logBombHit.path -Force -ErrorAction Stop
                        break
                    } catch {
                        Start-Sleep -Seconds 2
                    }
                }
                break
            }
        }
        if (-not [string]::IsNullOrWhiteSpace($ReportPath) -and (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
            $sizeBefore = (Get-Item -LiteralPath $ReportPath).Length
            if ($sizeBefore -gt 0) {
                Start-Sleep -Milliseconds 500
                $sizeAfter = if (Test-Path -LiteralPath $ReportPath -PathType Leaf) { (Get-Item -LiteralPath $ReportPath).Length } else { 0 }
                if ($sizeAfter -eq $sizeBefore -and (Test-TesterReportHasCompleteMetrics -ReportPath $ReportPath)) {
                    $latchedReport = $true
                    Write-Host ("run_smoke.stage=valid_report_latched terminal_pid={0} report='{1}' size={2}" -f $childTerminal.Id, $ReportPath, $sizeAfter)
                    try {
                        Stop-Process -Id $childTerminal.Id -Force -ErrorAction Stop
                    } catch {
                    }
                    if ($proc.Id -ne $childTerminal.Id) {
                        try {
                            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                        } catch {
                        }
                    }
                    [void]$childTerminal.WaitForExit(10000)
                    $terminalRootForMeta = Split-Path -Parent $TerminalExe
                    $lingeringMeta = @(Get-MetaTesterProcessesForTerminalRoot -TerminalRoot $terminalRootForMeta)
                    foreach ($metaProc in $lingeringMeta) {
                        try {
                            Stop-Process -Id $metaProc.ProcessId -Force -ErrorAction Stop
                        } catch {
                        }
                    }
                    break
                }
            }
        }
        Start-Sleep -Milliseconds 500
    }

    if (-not $finished -and -not $latchedReport -and -not $logBombHit -and $childTerminal.HasExited) {
        $finished = $true
    }

    $timedOut = (-not $finished) -and (-not $latchedReport) -and (-not $logBombHit)
    if ($timedOut) {
        try {
            Stop-Process -Id $childTerminal.Id -Force -ErrorAction Stop
        } catch {
        }
        if ($proc.Id -ne $childTerminal.Id) {
            try {
                Stop-Process -Id $proc.Id -Force -ErrorAction Stop
            } catch {
            }
        }
    }
    $loggedExitCode = if ($finished) { $childTerminal.ExitCode } else { "<timeout>" }
    if ($latchedReport) {
        $loggedExitCode = "<valid_report_latched>"
    }
    if ($logBombHit) {
        $loggedExitCode = "<log_bomb_killed>"
    }
    Write-Host ("run_smoke.stage=terminal_exit terminal_pid={0} exit_code={1} timed_out={2} valid_report_latched={3} log_bomb={4}" -f $childTerminal.Id, $loggedExitCode, $timedOut, $latchedReport, [bool]$logBombHit)

    return [pscustomobject]@{
        exit_code = $(if ($finished) { $childTerminal.ExitCode } elseif ($latchedReport) { 0 } else { $null })
        timed_out = $timedOut
        terminal_pid = $childTerminal.Id
        valid_report_latched = $latchedReport
        log_bomb = [bool]$logBombHit
        log_bomb_journal = $(if ($logBombHit) { $logBombHit.path } else { $null })
        log_bomb_journal_gb = $(if ($logBombHit) { $logBombHit.gb } else { $null })
        log_bomb_reason = $(if ($logBombHit) { $logBombHit.reason } else { $null })
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
        # BOTH legs must anchor on root + trailing backslash: the unanchored
        # CommandLine match made "...\T1" a SUBSTRING of "...\T10", so every T1
        # run_smoke cleanup Force-killed T10's RUNNING tester agent mid-run (no
        # OnDeinit -> skeleton report + silent q08 stream). 2026-07-15 QM5_13117
        # zero-trades forensics: D:\QM\reports\deep_dive_13117\FINDINGS.md.
        $matchesRoot = ($exePath -and [regex]::IsMatch($exePath, "^$escapedRoot\\", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) -or
            ($cmdLine -and [regex]::IsMatch($cmdLine, "$escapedRoot\\", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase))
        if ($matchesRoot) {
            $matches += $proc
        }
    }

    return @($matches)
}

function Wait-ForMetaTesterQuiescence {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TerminalRoot,
        [ValidateRange(1, 60)]
        [int]$MaxWaitSeconds = 10
    )

    $deadline = (Get-Date).ToUniversalTime().AddSeconds($MaxWaitSeconds)
    do {
        if (@(Get-MetaTesterProcessesForTerminalRoot -TerminalRoot $TerminalRoot).Count -eq 0) {
            return $true
        }
        Start-Sleep -Milliseconds 250
    } while ((Get-Date).ToUniversalTime() -lt $deadline)

    return (@(Get-MetaTesterProcessesForTerminalRoot -TerminalRoot $TerminalRoot).Count -eq 0)
}

function Wait-ForReportExport {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReportPath,
        [Parameter(Mandatory = $true)]
        [string]$TerminalRoot,
        [ValidateRange(0, 300)]
        [int]$MaxWaitSeconds = 30,
        [switch]$RequireCompleteMetrics
    )

    $deadline = (Get-Date).ToUniversalTime().AddSeconds($MaxWaitSeconds)
    do {
        if (Test-Path -LiteralPath $ReportPath -PathType Leaf) {
            if (-not $RequireCompleteMetrics -or (Test-TesterReportHasCompleteMetrics -ReportPath $ReportPath)) {
                return $true
            }
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

    if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
        return $false
    }
    return (-not $RequireCompleteMetrics -or (Test-TesterReportHasCompleteMetrics -ReportPath $ReportPath))
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

# Resolve every isolated development-lane boundary before mutating terminal configuration,
# deploying an expert, or creating report directories.
$resolvedReportRoot = [System.IO.Path]::GetFullPath($ReportRoot)
if ($effectiveTerminal -ieq "DEV1") {
    $dev1ReportRoot = [System.IO.Path]::GetFullPath("D:\QM\reports\dev1")
    $dev1Prefix = $dev1ReportRoot.TrimEnd('\') + '\'
    if (($resolvedReportRoot -ine $dev1ReportRoot) -and
        (-not $resolvedReportRoot.StartsWith($dev1Prefix, [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "DEV1 ReportRoot must stay under 'D:\QM\reports\dev1'. Got: $resolvedReportRoot"
    }
}
if ($effectiveTerminal -ieq "DEV2") {
    $dev2ReportRoot = [System.IO.Path]::GetFullPath("D:\QM\reports\dev2")
    $dev2Prefix = $dev2ReportRoot.TrimEnd('\') + '\'
    if (($resolvedReportRoot -ine $dev2ReportRoot) -and
        (-not $resolvedReportRoot.StartsWith($dev2Prefix, [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "DEV2 ReportRoot must stay under 'D:\QM\reports\dev2'. Got: $resolvedReportRoot"
    }
}

if (($Terminal -ine "any") -and (-not $AllowRunningTerminal.IsPresent)) {
    if (Test-TerminalAlreadyRunning -TerminalRoot $terminalRoot) {
        throw "Terminal instance is already running for $terminalRoot. Stop it first or pass -AllowRunningTerminal."
    }
}

Set-BacktestTerminalConfig -TerminalRoot $terminalRoot -TerminalName $effectiveTerminal

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
$reportDir = Join-Path $resolvedReportRoot "$eaLabel\$runTag"
$rawDir = Join-Path $reportDir "raw"
$frameworkEvidenceDir = if ($effectiveTerminal -ieq "DEV1" -or $effectiveTerminal -ieq "DEV2") {
    Join-Path $resolvedReportRoot "_framework_evidence\22"
} else {
    "D:\QM\reports\framework\22"
}

New-Item -ItemType Directory -Path $rawDir -Force | Out-Null
New-Item -ItemType Directory -Path $frameworkEvidenceDir -Force | Out-Null

$fromDate = if ($FromDate) { $FromDate } else { "{0}.01.01" -f $Year }
$toDate = if ($ToDate) { $ToDate } else { "{0}.12.31" -f $Year }
$newsCalendarDiagnostics = Resolve-NewsCalendarDiagnostics
Write-Host ("run_smoke.news_calendar_status={0} latest_modified_utc='{1}' age_hours={2} max_age_hours={3}" -f $newsCalendarDiagnostics.status, $newsCalendarDiagnostics.latest_modified_utc, $newsCalendarDiagnostics.age_hours, $newsCalendarDiagnostics.max_age_hours)
# Q02 trade floor (OWNER 2026-06-26): flat 5 trades/year, NOT coupled to the card's
# declared frequency. The old `expected * years * 0.5` rule killed genuine low-freq edges
# whose cards over-declared (ICT Silver Bullet QM5_12571: card 100/yr, reality ~8-14/yr ->
# 50-floor -> FAIL). OOS frequency robustness (>= 5/yr) is enforced at Q04, not here.
$Q02MinTradesPerYear = 5
$expectedTradeInfo = Get-ExpectedTradesPerYear -EAIdValue $EAId
$smokeYearCount = Get-SmokeYearCount -StartDate $fromDate -EndDate $toDate
$effectiveMinTrades = [Math]::Max($Q02MinTradesPerYear, [int]($Q02MinTradesPerYear * $smokeYearCount))
# 2026-07-07: build smoke honors its explicit -MinTrades (does the EA run + trade
# at all?) — the Q02 frequency floor belongs to Q02's full-history judgment, not
# a single-year build check. Without this, low-freq/episodic EAs false-FAIL with
# MIN_TRADES_NOT_MET at build and never reach the gate that can actually judge them.
if ($SmokeMode) {
    Write-Host ("run_smoke.smoke_mode min_trades={0} (Q02 floor bypassed for build smoke)" -f $MinTrades)
    $effectiveMinTrades = $MinTrades
}
if ($effectiveMinTrades -ne $MinTrades) {
    $cardExpected = if ($null -ne $expectedTradeInfo) { $expectedTradeInfo.ExpectedTradesPerYearCard } else { "n/a" }
    $cardScope = if ($null -ne $expectedTradeInfo) { $expectedTradeInfo.MinTradeScope } else { "n/a" }
    Write-Host ("run_smoke.min_trades_override ea_id=QM5_{0:d4} rate_per_year={1} years={2} old={3} effective={4} scope={5} card_expected={6}" -f $EAId, $Q02MinTradesPerYear, $smokeYearCount, $MinTrades, $effectiveMinTrades, $cardScope, $cardExpected)
    $MinTrades = $effectiveMinTrades
}

# Install the canonical tester commission schedule before launching. Positive
# fixed overrides are fail-closed because both historical encodings were proven
# materially wrong. The finally block restores and verifies the canonical file.
$commissionGroupEvidence = $null
$commissionGroupRestoreEvidence = $null
try {
    $commissionGroupEvidence = Set-TesterGroupsCommission -TerminalRoot $terminalRoot -SymbolName $Symbol -CommissionPerLot $CommissionPerLot -CommissionPerSideNative $CommissionPerSideNative
    Write-Host ("run_smoke.commission_per_lot={0} native_per_side={1} terminal={2} symbol={3} injected_sha256={4}" -f $CommissionPerLot, $CommissionPerSideNative, $effectiveTerminal, $Symbol, $commissionGroupEvidence.installed_sha256)

$runResults = @()
$loggerSampleCaptures = New-Object System.Collections.Generic.List[object]
$globalOnInitFailure = $false
$globalRealTicksMarker = $true
$globalTimeoutFailure = $false
$globalLogBombFailure = $false
$reasonClasses = New-Object System.Collections.Generic.List[string]

# MT5 can occasionally emit an invalid warm-up report before history/tick context
# settles, then produce valid deterministic reports immediately afterward. Keep
# the requested OK-run contract, but allow a small number of extra attempts so a
# transient invalid report does not become a terminal Q02/Q03 infra failure.
$maxRunAttempts = [Math]::Min(10, ($Runs + 2))

for ($i = 1; $i -le $maxRunAttempts; $i++) {
    $okRunCount = @($runResults | Where-Object { $_.status -eq "OK" }).Count
    if ($okRunCount -ge $Runs) {
        break
    }
    if ($globalOnInitFailure -or $globalTimeoutFailure -or $globalLogBombFailure) {
        break
    }

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
        -SetFilePath $SetFile `
        -CurrencyOverride $TesterCurrencyOverride `
        -DepositOverride $TesterDepositOverride

    Write-Host ("run_smoke.stage=ini_written run={0} ini='{1}'" -f $runName, $iniPath)
    if (-not [string]::IsNullOrWhiteSpace($TesterCurrencyOverride)) {
        Write-Host ("run_smoke.tester_currency_override={0} run={1}" -f $TesterCurrencyOverride.Trim().ToUpperInvariant(), $runName)
    }
    Write-Host ("run_smoke.stage=start_terminal terminal={0} run={1} ini='{2}'" -f $effectiveTerminal, $runName, $iniPath)
    $loggerStateBefore = $null
    if (-not $AllowRunningTerminal.IsPresent) {
        $loggerStateBefore = Get-QmLoggerFileState -TerminalRoot $terminalRoot -EAIdValue $EAId
    } else {
        Write-Host ("run_smoke.logger_sample_skipped run={0} reason=allow_running_terminal" -f $runName)
    }
    try {
        $runExec = Start-TesterRun -TerminalExe $terminalExe -IniPath $iniPath -TimeoutSec $TimeoutSeconds -ReportPath $sourceReportPath -TerminalName $effectiveTerminal
    } catch {
        Write-Host ("run_smoke.start_failed terminal={0} run={1} ini='{2}' err='{3}'" -f $effectiveTerminal, $runName, $iniPath, $_.Exception.Message)
        throw
    }
    $exitCode = $runExec.exit_code

    if ($runExec.log_bomb) {
        # Journal bomb: the EA spams the tester journal per-tick; retrying would
        # bomb again (~10 GB/min for the whole timeout window), so this is
        # terminal for the smoke, like ONINIT_FAILED/TIMEOUT.
        $globalLogBombFailure = $true
        $globalRealTicksMarker = $false
        $reasonClasses.Add("LOG_BOMB")
        $runResults += [pscustomobject]@{
            run = $runName
            status = "FAIL"
            failure = "LOG_BOMB"
            error = ("Tester journal bomb killed the run: {0} ({1} GB, {2})" -f $runExec.log_bomb_journal, $runExec.log_bomb_journal_gb, $runExec.log_bomb_reason)
            exit_code = $null
            report_source_path = $sourceReportPath
            report_canonical_path = $reportHtmPath
            report_size_bytes = 0
            tester_log_path = $null
        }
        continue
    }

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

    # Capture only after every writer for this stopped tester agent is gone.
    # Timeout and log-bomb branches continue above, so their partial prefixes
    # can never become a schema sample. A naturally finishing/latching run may
    # leave metatester alive briefly while it flushes; skip rather than publish
    # if that bounded quiescence check cannot be proven.
    if ($null -ne $loggerStateBefore) {
        if (Wait-ForMetaTesterQuiescence -TerminalRoot $terminalRoot) {
            $runLoggerSamplePath = Join-Path $runDir "logger_sample.jsonl"
            $loggerCapture = Save-QmLoggerDelta `
                -BeforeState $loggerStateBefore `
                -TerminalRoot $terminalRoot `
                -EAIdValue $EAId `
                -DestinationPath $runLoggerSamplePath
            if ($null -ne $loggerCapture) {
                $loggerCapture | Add-Member -NotePropertyName run -NotePropertyValue $runName
                $loggerSampleCaptures.Add($loggerCapture)
                Write-Host ("run_smoke.logger_sample_captured run={0} path='{1}' events={2} bytes={3} sha256={4}" -f $runName, $loggerCapture.path, $loggerCapture.event_count, $loggerCapture.size_bytes, $loggerCapture.sha256)
            }
        } else {
            Write-Warning ("Structured logger capture skipped: metatester writer still active for terminal '{0}'." -f $effectiveTerminal)
        }
    }

    # MT5 report writes can lag significantly under terminal contention; allow a longer settle window
    # before classifying as infra REPORT_MISSING. A complete report may be latched
    # early, but an incomplete non-empty MT5 shell report is still evidence and must
    # go through INVALID_REPORT parsing instead of being hidden as missing.
    $reportMaterialized = Wait-ForReportExport -ReportPath $sourceReportPath -TerminalRoot $terminalRoot -MaxWaitSeconds 240 -RequireCompleteMetrics
    if (-not $reportMaterialized) {
        [void](Use-LegacyRelativeReportExport -TerminalRoot $terminalRoot -AbsoluteReportPath $reportHtmPath -LegacyRelativePath $legacyRelativeSourcePath)
        $publishedReportPath = Publish-TesterReportCandidate -SourceReportPath $sourceReportPath -CanonicalReportPath $reportHtmPath
        if ($publishedReportPath) {
            $reportMaterialized = $true
            if (-not (Test-Path -LiteralPath $sourceReportPath -PathType Leaf)) {
                $sourceReportPath = $publishedReportPath
            }
            Write-Host ("run_smoke.stage=incomplete_report_published run={0} report='{1}'" -f $runName, $publishedReportPath)
        }
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
            $testerLogTail = Get-TesterLogCurrentRunText -TesterLogTail $testerLogTail
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
        if (Test-TesterLogShowsAccountNotSpecified -TesterLogTail $testerLogTail) {
            $failureHints.Add("ACCOUNT_NOT_SPECIFIED")
            $reasonClasses.Add("ACCOUNT_NOT_SPECIFIED")
        }
        if (Test-TesterLogHasNoHistoryForRun -TesterLogTail $testerLogTail -ExpectedSymbol $Symbol -ExpectedFromDate $fromDate -ExpectedToDate $toDate) {
            $failureHints.Add("NO_HISTORY_LOG")
            $reasonClasses.Add("NO_HISTORY_LOG")
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

    # FW8-classifier — tolerant metric reads. Pre-fix this block threw on any
    # missing label, crashing run_smoke before the run could be classified at
    # all. Now: read each metric with -AllowMissing; defaults below match what
    # downstream code (MIN_TRADES_NOT_MET, determinism check) expects on a
    # 0-trade or report-missing-label run.
    $totalTradesRaw = Get-ReportMetricValue -Html $reportHtml -Label "Total Trades" -AllowMissing
    $profitFactorRaw = Get-ReportMetricValue -Html $reportHtml -Label "Profit Factor" -AllowMissing
    $drawdownRaw = Get-ReportMetricValue -Html $reportHtml -Label "Equity Drawdown Maximal" -AllowMissing
    $netProfitRaw = Get-ReportMetricValue -Html $reportHtml -Label "Total Net Profit" -AllowMissing

    $totalTrades = 0
    $profitFactor = 0.0
    $drawdown = 0.0
    $netProfit = 0.0
    if ($null -ne $totalTradesRaw) { try { $totalTrades = [int](Convert-ReportNumber -Value $totalTradesRaw) } catch {} }
    if ($null -ne $profitFactorRaw) { try { $profitFactor = Convert-ReportNumber -Value $profitFactorRaw } catch {} }
    if ($null -ne $drawdownRaw) { try { $drawdown = Convert-ReportNumber -Value $drawdownRaw } catch {} }
    if ($null -ne $netProfitRaw) { try { $netProfit = Convert-ReportNumber -Value $netProfitRaw } catch {} }

    $testerLog = Get-LatestTesterLog -TerminalRoot $terminalRoot -SinceUtc $runStartUtc
    $testerLogPath = $null
    $testerLogTail = ""
    if ($testerLog) {
        $testerLogPath = Join-Path $runDir $testerLog.Name
        Copy-Item -LiteralPath $testerLog.FullName -Destination $testerLogPath -Force
        $testerLogTail = Get-TesterLogTailText -TesterLogPath $testerLogPath -LineCount 800
        $testerLogTail = Get-TesterLogCurrentRunText -TesterLogTail $testerLogTail
    }

    $onInitFailure = $false
    if ($totalTrades -le 0) {
        $onInitFailure = Test-TesterLogShowsOnInitFailure -TesterLogTail $testerLogTail
    }

    # Scan the FULL tester log, not just the tail. In large real-tick runs the
    # "generating based on real ticks" marker appears near the START (right after
    # synchronization), far outside an 800-line tail window — tail-only scanning
    # falsely flagged valid high-activity runs (millions of ticks / hundreds of
    # trades) as NO_REAL_TICKS_MARKER -> INVALID -> INFRA_FAIL. Verified on a 21MB
    # / 95k-line NDX.DWX log: marker present 148x (first at line 38), 0x in the tail.
    $hasRealTicksMarker = $false
    if ($testerLogPath -and (Test-Path -LiteralPath $testerLogPath)) {
        $hasRealTicksMarker = [bool](Select-String -LiteralPath $testerLogPath -Pattern "generating based on real ticks" -SimpleMatch -Quiet -ErrorAction SilentlyContinue)
    }
    if (-not $hasRealTicksMarker -and $testerLogTail) {
        $hasRealTicksMarker = [regex]::IsMatch($testerLogTail, "(?im)generating based on real ticks")
    }
    if (-not $hasRealTicksMarker) {
        $hasRealTicksMarker = Test-ReportShowsRealTicks -Html $reportHtml
    }

    $invalidReasons = Get-ReportInvalidReasons -Html $reportHtml -TesterLogTail $testerLogTail -ExpectedSymbol $Symbol -ExpectedFromDate $fromDate -ExpectedToDate $toDate -HasRealTicksMarker $hasRealTicksMarker -ReportTotalTrades $totalTrades
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
} finally {
    $commissionGroupRestoreEvidence = Set-TesterGroupsCommission -TerminalRoot $terminalRoot -SymbolName $Symbol -CommissionPerLot 0 -CommissionPerSideNative 0
    if ($commissionGroupRestoreEvidence.installed_sha256 -cne $commissionGroupRestoreEvidence.canonical_sha256) {
        throw "tester groups canonical restore hash mismatch: target=$($commissionGroupRestoreEvidence.installed_sha256) canonical=$($commissionGroupRestoreEvidence.canonical_sha256)"
    }
    Write-Host ("run_smoke.commission_groups_restored sha256={0} target='{1}'" -f $commissionGroupRestoreEvidence.installed_sha256, $commissionGroupRestoreEvidence.target_path)
}

$completedRuns = @($runResults | Where-Object { $_.status -eq "OK" })
$completedRunCount = @($completedRuns).Count
$attemptedRunCount = @($runResults).Count
$nonOkRunCount = @($runResults | Where-Object { $_.status -ne "OK" }).Count
$tradeGatePassed = $false
$deterministic = $false

if ($completedRunCount -eq $Runs) {
    $reasonClasses = New-Object System.Collections.Generic.List[string]
    $globalRealTicksMarker = $true
    foreach ($completedRun in $completedRuns) {
        $globalRealTicksMarker = $globalRealTicksMarker -and [bool]$completedRun.real_ticks_marker
    }
    $globalOnInitFailure = [bool](@($completedRuns | Where-Object { $_.oninit_failure }).Count -gt 0)
    if ($globalOnInitFailure) {
        $reasonClasses.Add("ONINIT_FAILED")
    }

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
    (-not $globalLogBombFailure) -and
    $realTicksGatePassed

if (@($reasonClasses).Count -eq 0) {
    $reasonClasses.Add("OK")
}

$loggerSamplePath = $null
$loggerSampleEvidence = $null
if ($loggerSampleCaptures.Count -gt 0) {
    $selectedLoggerCapture = $loggerSampleCaptures[$loggerSampleCaptures.Count - 1]
    $candidateLoggerSamplePath = Join-Path $reportDir "logger_sample.jsonl"
    try {
        $selectedBytes = [System.IO.File]::ReadAllBytes($selectedLoggerCapture.path)
        [System.IO.File]::WriteAllBytes($candidateLoggerSamplePath, $selectedBytes)
        $publishedHash = Get-FilePrefixSha256 -Path $candidateLoggerSamplePath -Length ([long]$selectedBytes.Length)
        if ($publishedHash -cne $selectedLoggerCapture.sha256) {
            throw "published logger sample hash mismatch"
        }
        $loggerSamplePath = [System.IO.Path]::GetFullPath($candidateLoggerSamplePath)
        $loggerSampleEvidence = [ordered]@{
            run = $selectedLoggerCapture.run
            path = $loggerSamplePath
            source_path = $selectedLoggerCapture.source_path
            source_offset_start = $selectedLoggerCapture.source_offset_start
            source_offset_end_exclusive = $selectedLoggerCapture.source_offset_end_exclusive
            source_snapshot_sha256 = $selectedLoggerCapture.source_snapshot_sha256
            size_bytes = $selectedLoggerCapture.size_bytes
            sha256 = $selectedLoggerCapture.sha256
            event_count = $selectedLoggerCapture.event_count
            exact_byte_copy = $true
        }
    } catch {
        Write-Warning ("Structured logger sample publish skipped: {0}" -f $_.Exception.Message)
        $loggerSamplePath = $null
        $loggerSampleEvidence = $null
    }
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
    requested_runs = $Runs
    max_run_attempts = $maxRunAttempts
    attempted_runs = $attemptedRunCount
    non_ok_attempts = $nonOkRunCount
    min_trades_required = $MinTrades
    deterministic = $deterministic
    oninit_failure_detected = $globalOnInitFailure
    log_bomb_detected = $globalLogBombFailure
    model4_log_marker_detected = $globalRealTicksMarker
    report_dir = $reportDir
    report_export_mode = "relative_with_absolute_fallback"
    logger_sample_path = $loggerSamplePath
    logger_sample = $loggerSampleEvidence
    commission_group = [ordered]@{
        commission_per_lot = $CommissionPerLot
        commission_per_side_native = $CommissionPerSideNative
        commission_matcher = $commissionGroupEvidence.commission_matcher
        commission_mode = $commissionGroupEvidence.commission_mode
        injected_sha256 = $commissionGroupEvidence.installed_sha256
        canonical_sha256 = $commissionGroupEvidence.canonical_sha256
        restored_sha256 = $commissionGroupRestoreEvidence.installed_sha256
        restored_to_canonical = ($commissionGroupRestoreEvidence.installed_sha256 -ceq $commissionGroupRestoreEvidence.canonical_sha256)
    }
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
    "- logger_sample_jsonl: $loggerSamplePath",
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
if (-not [string]::IsNullOrWhiteSpace($loggerSamplePath)) {
    Write-Output "run_smoke.logger_sample=$loggerSamplePath"
}

    Invoke-DispatchCompletion -OriginalTargetTerminal $Terminal -EAIdValue $EAId -SymbolName $Symbol -PeriodName $Period -YearValue $Year -SetFilePath $SetFile -DispatchPhaseValue $DispatchPhase -DispatchVersionValue $DispatchVersion -DispatchSubGateHashValue $DispatchSubGateHash

if ($effectiveTerminal -ieq "DEV1") {
    Write-Output "run_smoke.stage=post_run_pump_skipped (DEV1 isolation)"
} elseif ($effectiveTerminal -ieq "DEV2") {
    Write-Output "run_smoke.stage=post_run_pump_skipped (DEV2 isolation)"
} elseif (Test-Path 'D:\QM\strategy_farm\state\FACTORY_OFF.flag') {
    Write-Output "run_smoke.stage=post_run_pump_skipped (FACTORY_OFF.flag)"
} else {
    try {
        $pumpExe = (Get-Command pythonw.exe -ErrorAction SilentlyContinue).Source
        if (-not $pumpExe) { $pumpExe = (Get-Command python.exe).Source }
        $pumpRepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
        $pumpScript = Join-Path $pumpRepoRoot 'tools\strategy_farm\run_pump_task.py'
        Start-Process -FilePath $pumpExe -ArgumentList @(
            $pumpScript
        ) -WorkingDirectory $pumpRepoRoot -WindowStyle Hidden
        Write-Output "run_smoke.stage=post_run_pump_triggered"
    } catch {
        Write-Host "post-run pump trigger failed (non-fatal): $_"
    }
}

if (-not $passed) {
    exit 1
}

exit 0
