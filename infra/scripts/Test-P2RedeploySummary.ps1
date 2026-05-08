param(
    [Parameter(Mandatory = $true)]
    [string]$StrategyId,
    [Parameter(Mandatory = $true)]
    [string]$Symbol,
    [string[]]$Timeframes = @("H1", "H4", "D1"),
    [string[]]$Terminals = @("T1", "T2", "T3", "T4", "T5"),
    [string]$Mt5Root = "D:\QM\mt5",
    [string]$ReportRoot = "D:\QM\reports",
    [int]$MinReportsPerTimeframe = 1,
    [string]$JsonOut
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-CustomSymbolPresence {
    param(
        [Parameter(Mandatory = $true)] [string]$Mt5RootPath,
        [Parameter(Mandatory = $true)] [string[]]$TerminalList,
        [Parameter(Mandatory = $true)] [string]$SymbolName
    )

    $rows = @()
    foreach ($terminal in $TerminalList) {
        $historyPath = Join-Path $Mt5RootPath "$terminal\Bases\Custom\history\$SymbolName"
        $ticksPath = Join-Path $Mt5RootPath "$terminal\Bases\Custom\ticks\$SymbolName"

        $historyCount = 0
        $ticksCount = 0
        $historyExists = Test-Path -LiteralPath $historyPath -PathType Container
        $ticksExists = Test-Path -LiteralPath $ticksPath -PathType Container

        if ($historyExists) {
            $historyCount = @(
                Get-ChildItem -LiteralPath $historyPath -File -ErrorAction SilentlyContinue
            ).Count
        }
        if ($ticksExists) {
            $ticksCount = @(
                Get-ChildItem -LiteralPath $ticksPath -File -ErrorAction SilentlyContinue
            ).Count
        }

        $rows += [pscustomobject]@{
            terminal = $terminal
            history_exists = $historyExists
            ticks_exists = $ticksExists
            history_file_count = $historyCount
            ticks_file_count = $ticksCount
            status = if ($historyExists -and $ticksExists -and $historyCount -gt 0 -and $ticksCount -gt 0) { "present" } else { "missing" }
            history_path = $historyPath
            ticks_path = $ticksPath
        }
    }

    return $rows
}

function Get-ReportCoverage {
    param(
        [Parameter(Mandatory = $true)] [string]$ReportRootPath,
        [Parameter(Mandatory = $true)] [string]$Strategy,
        [Parameter(Mandatory = $true)] [string]$SymbolName,
        [Parameter(Mandatory = $true)] [string[]]$TfList,
        [Parameter(Mandatory = $true)] [int]$MinReports
    )

    $safeSymbol = $SymbolName -replace '\.', '_'
    $allReports = @()
    if (Test-Path -LiteralPath $ReportRootPath -PathType Container) {
        $allReports = Get-ChildItem -LiteralPath $ReportRootPath -Filter *.htm -Recurse -File -ErrorAction SilentlyContinue
    }

    $tfRows = @()
    foreach ($tf in $TfList) {
        $tokenTf = [regex]::Escape($tf.ToUpperInvariant())
        $tokenStrategy = [regex]::Escape($Strategy.ToUpperInvariant())
        $tokenSymbolA = [regex]::Escape($SymbolName.ToUpperInvariant())
        $tokenSymbolB = [regex]::Escape($safeSymbol.ToUpperInvariant())

        $hits = @(
            $allReports | Where-Object {
                $subject = ($_.FullName + " " + $_.Name).ToUpperInvariant()
                $subject -match $tokenStrategy -and
                ($subject -match $tokenSymbolA -or $subject -match $tokenSymbolB) -and
                $subject -match "(^|[^A-Z0-9])$tokenTf([^A-Z0-9]|$)"
            }
        )

        $latest = $null
        if ($hits.Count -gt 0) {
            $latest = $hits | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
        }

        $tfRows += [pscustomobject]@{
            timeframe = $tf
            reports_found = $hits.Count
            min_required = $MinReports
            status = if ($hits.Count -ge $MinReports) { "ok" } else { "REPORT_MISSING" }
            latest_report_path = if ($latest) { $latest.FullName } else { $null }
            latest_report_utc = if ($latest) { $latest.LastWriteTimeUtc.ToString("o") } else { $null }
        }
    }

    return $tfRows
}

$presence = Get-CustomSymbolPresence -Mt5RootPath $Mt5Root -TerminalList $Terminals -SymbolName $Symbol
$coverage = Get-ReportCoverage -ReportRootPath $ReportRoot -Strategy $StrategyId -SymbolName $Symbol -TfList $Timeframes -MinReports $MinReportsPerTimeframe

$missingSymbolChecks = @($presence | Where-Object { $_.status -eq "missing" }).Count
$missingTfChecks = @($coverage | Where-Object { $_.status -eq "REPORT_MISSING" }).Count

$flags = @()
if ($missingTfChecks -gt 0) { $flags += "REPORT_MISSING" }
if ($missingTfChecks -gt 0 -or $missingSymbolChecks -gt 0) { $flags += "INCOMPLETE_RUNS" }

$summary = [pscustomobject]@{
    generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    strategy_id = $StrategyId
    symbol = $Symbol
    timeframes = $Timeframes
    terminals = $Terminals
    mt5_root = $Mt5Root
    report_root = $ReportRoot
    min_reports_per_timeframe = $MinReportsPerTimeframe
    verdict = if ($flags.Count -eq 0) { "PASS" } else { "FAIL" }
    failure_flags = $flags
    custom_symbol_presence = $presence
    report_coverage = $coverage
}

$json = $summary | ConvertTo-Json -Depth 8
if ($JsonOut) {
    $outDir = Split-Path -Parent $JsonOut
    if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }
    Set-Content -LiteralPath $JsonOut -Value $json -Encoding UTF8
}

$summary
