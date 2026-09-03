$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$helper = Join-Path $repoRoot 'framework\scripts\pattern_warmup_evidence.ps1'
. $helper

function Assert-Equal {
    param($Actual, $Expected, [string]$Message)
    if ($Actual -ne $Expected) {
        throw "$Message (expected='$Expected' actual='$Actual')"
    }
}

# Identity of the run under test. Every marker must be provably its own - own
# EA, own symbol AND printed inside this run's own tester window.
$runExpert = 'QM\QM5_1234_bug4-pattern-demo'
$runExpertLeaf = 'QM5_1234_bug4-pattern-demo'
$runEaId = 1234
$runSymbol = 'EURUSD.DWX'

function New-RunStartLine {
    param(
        [string]$Clock,
        [string]$ExpertLeaf,
        [string]$Symbol,
        [string]$Period = 'H1',
        [string]$From,
        [string]$To,
        [string]$Source = 'Tester'
    )
    return "CS`t0`t$Clock`t$Source`t${Symbol},${Period}: testing of Experts\QM\$ExpertLeaf.ex5 from $From 00:00 to $To 00:00 started with inputs:"
}

function New-ExpertAddedLine {
    param([string]$Clock, [string]$ExpertLeaf, [string]$Source = 'Tester')
    return "CS`t0`t$Clock`t$Source`texpert file added: Experts\QM\$ExpertLeaf.ex5. 425604 bytes loaded"
}

function New-MarkerLine {
    param(
        [string]$Clock,
        [string]$SourceColumn,
        [string]$Symbol,
        [string]$Date,
        [long]$TradableTime = 1577923200,
        [long]$ReferenceTime = 1577836800,
        [int]$RequiredBars = 5,
        [string]$ProfileKey = 'DL089_OPT|0|16408|1|B|S:12'
    )
    return "CS`t0`t$Clock`t$SourceColumn`t$Date 01:01:00   QM_PATTERN_FIRST_TRADABLE_BAR schema=qm.pattern-first-tradable-bar/v1 symbol=$Symbol reference_timeframe=16408 tradable_bar_date=$Date tradable_bar_time=$TradableTime reference_bar_time=$ReferenceTime required_bars=$RequiredBars profile_key=$ProfileKey"
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("qm-pattern-warmup-{0}" -f [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    # --- structured logger sample (per-run delta capture, not shared) ------
    $logger = Join-Path $tmp 'logger.jsonl'
    $row = [ordered]@{
        event = 'PATTERN_FIRST_TRADABLE_BAR'
        ea_id = $runEaId
        magic = ($runEaId * 10000)
        symbol = $runSymbol
        payload = [ordered]@{
            marker_schema = 'qm.pattern-first-tradable-bar/v1'
            symbol = $runSymbol
            reference_timeframe = 16408
            closed_shift = 1
            tradable_bar_date = '2019.07.01'
            tradable_bar_time = 1561939200
            reference_bar_time = 1561852800
            required_bars = 101
            profile_key = 'BUG4_MAX_DEPTH|0|16408|1|B:90|S'
        }
    }
    $row | ConvertTo-Json -Compress -Depth 6 | Set-Content -LiteralPath $logger -Encoding utf8

    $present = Get-QmPatternFrequencyFloorEvidence `
        -LoggerSamplePaths @($logger) `
        -FallbackStartDate '2018.07.02' `
        -EndDate '2022.12.31' `
        -RatePerYear 5 `
        -ExpectedExpert $runExpert `
        -ExpectedEaId $runEaId `
        -RunSymbol $runSymbol
    Assert-Equal $present.schema 'qm.q02-frequency-coverage/v2' 'evidence schema'
    Assert-Equal $present.marker_status 'present_consistent' 'logger marker status'
    Assert-Equal $present.coverage_start_source 'pattern_first_tradable_bar' 'logger marker source'
    Assert-Equal $present.coverage_start '2019.07.01' 'logger marker date'
    Assert-Equal $present.year_count 4 'marker-adjusted year count'
    Assert-Equal $present.min_trades_required 20 'marker-adjusted Q02 floor'
    Assert-Equal $present.attributed_marker_count 1 'own logger marker attributed'
    Assert-Equal $present.rejected_marker_count 0 'no rejected logger markers'
    Assert-Equal $present.first_tradable_bar.attribution_reason 'own_ea_run_symbol' 'logger attribution reason'
    Assert-Equal $present.run_scope.logger_sample_scope 'per_run_delta_capture' 'logger sample run scope'
    Assert-Equal $present.attributed_profile_key_count 1 'distinct attributed profile keys'

    $multiScope = Join-Path $tmp 'logger-multi-scope.jsonl'
    $row | ConvertTo-Json -Compress -Depth 6 | Set-Content -LiteralPath $multiScope -Encoding utf8
    $row.payload.tradable_bar_date = '2020.01.02'
    $row.payload.tradable_bar_time = 1577923200
    $row.payload.profile_key = 'BUG4_DEEPER_SLOT|0|16408|1|B:90|S'
    $row | ConvertTo-Json -Compress -Depth 6 | Add-Content -LiteralPath $multiScope -Encoding utf8
    $latestScope = Get-QmPatternFrequencyFloorEvidence `
        -LoggerSamplePaths @($multiScope) `
        -FallbackStartDate '2018.07.02' `
        -EndDate '2022.12.31' `
        -ExpectedExpert $runExpert `
        -ExpectedEaId $runEaId `
        -RunSymbol $runSymbol
    Assert-Equal $latestScope.coverage_start '2020.01.02' 'latest active profile scope controls run start'
    Assert-Equal $latestScope.effective_run_marker_count 1 'multiple scopes collapse to one run marker'
    Assert-Equal $latestScope.attributed_profile_key_count 2 'both slots stay visible in the evidence'

    # A logger row emitted by a DIFFERENT EA (shared sample file) must never
    # move this run's coverage start.
    $foreignLogger = Join-Path $tmp 'logger-foreign.jsonl'
    $foreignRow = [ordered]@{
        event = 'PATTERN_FIRST_TRADABLE_BAR'
        ea_id = 41195
        magic = 411950000
        symbol = 'XAGUSD.DWX'
        payload = [ordered]@{
            marker_schema = 'qm.pattern-first-tradable-bar/v1'
            symbol = 'XAGUSD.DWX'
            reference_timeframe = 16408
            closed_shift = 1
            tradable_bar_date = '2022.01.12'
            tradable_bar_time = 1641945600
            reference_bar_time = 1641859200
            required_bars = 3
            profile_key = 'DL089_OPT|0|16408|1|B|S:99'
        }
    }
    $foreignRow | ConvertTo-Json -Compress -Depth 6 | Set-Content -LiteralPath $foreignLogger -Encoding utf8
    $foreignLoggerEvidence = Get-QmPatternFrequencyFloorEvidence `
        -LoggerSamplePaths @($foreignLogger) `
        -FallbackStartDate '2021.01.01' `
        -EndDate '2022.12.31' `
        -ExpectedExpert $runExpert `
        -ExpectedEaId $runEaId `
        -RunSymbol $runSymbol
    Assert-Equal $foreignLoggerEvidence.marker_status 'present_not_attributable' 'foreign logger marker status'
    Assert-Equal $foreignLoggerEvidence.coverage_start '2021.01.01' 'foreign logger marker cannot shorten window'
    Assert-Equal $foreignLoggerEvidence.min_trades_required 10 'foreign logger marker keeps full floor'
    Assert-Equal $foreignLoggerEvidence.rejected_marker_reasons['foreign_ea'] 1 'foreign logger rejection reason'

    # --- shared tester day-log: own run, own window -----------------------
    $tester = Join-Path $tmp 'tester.log'
    @(
        "CS`t0`t01:00:00.000`tStartup`tMetaTester 5 build 6140",
        (New-ExpertAddedLine -Clock '01:20:00.000' -ExpertLeaf $runExpertLeaf),
        (New-RunStartLine -Clock '01:20:00.100' -ExpertLeaf $runExpertLeaf -Symbol $runSymbol -From '2018.07.02' -To '2022.12.31'),
        (New-MarkerLine -Clock '01:20:33.391' -SourceColumn "$runExpertLeaf ($runSymbol,D1)" -Symbol $runSymbol -Date '2020.01.02' -RequiredBars 101 -ProfileKey 'BUG4_MAX_DEPTH|0|16408|1|B:90|S')
    ) | Set-Content -LiteralPath $tester -Encoding utf8
    $fromTester = Get-QmPatternFrequencyFloorEvidence `
        -TesterLogPaths @($tester) `
        -FallbackStartDate '2018.07.02' `
        -EndDate '2022.12.31' `
        -ExpectedExpert $runExpert `
        -ExpectedEaId $runEaId `
        -RunSymbol $runSymbol
    Assert-Equal $fromTester.first_tradable_bar.source_kind 'tester_log' 'tester marker source kind'
    Assert-Equal $fromTester.coverage_start '2020.01.02' 'tester marker date'
    Assert-Equal $fromTester.first_tradable_bar.emitting_expert $runExpertLeaf 'tester marker emitting expert'
    Assert-Equal $fromTester.first_tradable_bar.run_window_state 'inside' 'tester marker inside own run window'
    Assert-Equal $fromTester.first_tradable_bar.source_line_time '01:20:33.391' 'tester marker source line time published'
    Assert-Equal $fromTester.run_scope.tester_log_windows[0].window_source 'tester_log_run_start_exact' 'window anchored on own run start'
    Assert-Equal $fromTester.run_scope.tester_log_window_resolved_count 1 'window resolved count'

    # --- cross-RUN leak: same EA, same symbol, different run windows ------
    # The DL089 census cells run the SAME EA on the SAME symbol with 1-year
    # windows into the same day-log. An (EA, symbol)-only rule adopts the last
    # census marker and understates the floor 25 -> 5 (2026-09-03 refutation).
    $crossRun = Join-Path $tmp 'tester-cross-run.log'
    @(
        (New-ExpertAddedLine -Clock '01:19:46.217' -ExpertLeaf $runExpertLeaf),
        (New-RunStartLine -Clock '01:19:46.353' -ExpertLeaf $runExpertLeaf -Symbol $runSymbol -Period 'Daily' -From '2021.01.01' -To '2021.12.31'),
        (New-MarkerLine -Clock '01:20:33.391' -SourceColumn "$runExpertLeaf ($runSymbol,D1)" -Symbol $runSymbol -Date '2021.01.04' -ProfileKey 'DL089_OPT|0|16408|1|B|S:93'),
        (New-ExpertAddedLine -Clock '02:16:19.044' -ExpertLeaf $runExpertLeaf),
        (New-RunStartLine -Clock '02:16:19.164' -ExpertLeaf $runExpertLeaf -Symbol $runSymbol -Period 'Daily' -From '2022.01.01' -To '2022.12.31'),
        (New-MarkerLine -Clock '02:17:03.458' -SourceColumn "$runExpertLeaf ($runSymbol,D1)" -Symbol $runSymbol -Date '2022.01.03' -ProfileKey 'DL089_OPT|0|16408|1|B:9|S')
    ) | Set-Content -LiteralPath $crossRun -Encoding utf8
    $crossRunEvidence = Get-QmPatternFrequencyFloorEvidence `
        -TesterLogPaths @($crossRun) `
        -FallbackStartDate '2018.07.02' `
        -EndDate '2022.12.31' `
        -ExpectedExpert $runExpert `
        -ExpectedEaId $runEaId `
        -RunSymbol $runSymbol
    Assert-Equal $crossRunEvidence.marker_status 'present_not_attributable' 'cross-run markers are not attributable'
    Assert-Equal $crossRunEvidence.coverage_start_source 'test_window_start_fallback_marker_not_attributable' 'cross-run fallback source'
    Assert-Equal $crossRunEvidence.coverage_start '2018.07.02' 'cross-run marker cannot shorten window'
    Assert-Equal $crossRunEvidence.year_count 5 'cross-run keeps all scored years'
    Assert-Equal $crossRunEvidence.min_trades_required 25 'cross-run keeps the full floor'
    Assert-Equal $crossRunEvidence.rejected_marker_reasons['run_window_unresolved'] 2 'cross-run rejection reason'
    Assert-Equal $crossRunEvidence.run_scope.tester_log_windows[0].own_ea_symbol_run_start_count 2 'both own-EA runs are counted'
    Assert-Equal $crossRunEvidence.run_scope.tester_log_windows[0].exact_run_start_count 0 'no run start matches this window'

    # Same file, but now this run IS the 2022 census cell: only the marker
    # printed inside its own window may be used.
    $censusCell = Get-QmPatternFrequencyFloorEvidence `
        -TesterLogPaths @($crossRun) `
        -FallbackStartDate '2022.01.01' `
        -EndDate '2022.12.31' `
        -ExpectedExpert $runExpert `
        -ExpectedEaId $runEaId `
        -RunSymbol $runSymbol
    Assert-Equal $censusCell.coverage_start '2022.01.03' 'own-window marker is used'
    Assert-Equal $censusCell.attributed_marker_count 1 'exactly the own-run marker is attributed'
    Assert-Equal $censusCell.rejected_marker_reasons['outside_run_window'] 1 'the earlier run marker is out of window'
    Assert-Equal $censusCell.min_trades_required 5 'own-window floor'

    # --- cross-EA leak, the original 95e706ea shape -----------------------
    $foreignTester = Join-Path $tmp 'tester-foreign.log'
    @(
        (New-RunStartLine -Clock '01:19:46.353' -ExpertLeaf 'QM5_41196_qs-kama-trend-xau-opt' -Symbol 'XAUUSD.DWX' -Period 'Daily' -From '2021.01.01' -To '2022.12.31'),
        (New-MarkerLine -Clock '01:20:33.391' -SourceColumn 'QM5_41196_qs-kama-trend-xau-opt (XAUUSD.DWX,D1)' -Symbol 'XAUUSD.DWX' -Date '2021.01.04' -ProfileKey 'DL089_OPT|0|16408|1|B|S:93'),
        (New-RunStartLine -Clock '02:42:38.294' -ExpertLeaf 'QM5_41195_aa-vol-sma10-opt' -Symbol 'XAGUSD.DWX' -Period 'Daily' -From '2021.01.01' -To '2022.12.31'),
        (New-MarkerLine -Clock '02:43:27.869' -SourceColumn 'QM5_41195_aa-vol-sma10-opt (XAGUSD.DWX,D1)' -Symbol 'XAGUSD.DWX' -Date '2022.01.12' -ProfileKey 'DL089_OPT|0|16408|1|B|S:99'),
        (New-RunStartLine -Clock '03:30:39.592' -ExpertLeaf 'QM5_41321_grimes-trendday-v2-opt' -Symbol 'NDX.DWX' -Period 'M15' -From '2021.01.01' -To '2022.12.31')
    ) | Set-Content -LiteralPath $foreignTester -Encoding utf8
    $foreignEvidence = Get-QmPatternFrequencyFloorEvidence `
        -TesterLogPaths @($foreignTester) `
        -FallbackStartDate '2021.01.01' `
        -EndDate '2022.12.31' `
        -ExpectedExpert 'QM\QM5_41321_grimes-trendday-v2-opt' `
        -ExpectedEaId 41321 `
        -RunSymbol 'NDX.DWX'
    Assert-Equal $foreignEvidence.marker_status 'present_not_attributable' 'foreign day-log marker status'
    Assert-Equal $foreignEvidence.coverage_start_source 'test_window_start_fallback_marker_not_attributable' 'foreign day-log fallback source'
    Assert-Equal $foreignEvidence.coverage_start '2021.01.01' 'foreign day-log cannot shorten window'
    Assert-Equal $foreignEvidence.year_count 2 'foreign day-log keeps both scored years'
    Assert-Equal $foreignEvidence.min_trades_required 10 'foreign day-log keeps full floor'
    Assert-Equal $foreignEvidence.attributed_marker_count 0 'no foreign marker attributed'
    Assert-Equal $foreignEvidence.rejected_marker_count 2 'both foreign markers rejected'
    Assert-Equal $foreignEvidence.rejected_marker_reasons['outside_run_window'] 2 'foreign markers are outside the own run window'
    Assert-Equal ($null -eq $foreignEvidence.first_tradable_bar) $true 'no foreign marker published'

    # Own EA amid foreign traffic inside the own run window.
    $mixedTester = Join-Path $tmp 'tester-mixed.log'
    @(
        (New-RunStartLine -Clock '01:19:46.353' -ExpertLeaf 'QM5_41196_qs-kama-trend-xau-opt' -Symbol 'XAUUSD.DWX' -Period 'Daily' -From '2021.01.01' -To '2022.12.31'),
        (New-MarkerLine -Clock '01:20:33.391' -SourceColumn 'QM5_41196_qs-kama-trend-xau-opt (XAUUSD.DWX,D1)' -Symbol 'XAUUSD.DWX' -Date '2021.01.04' -ProfileKey 'DL089_OPT|0|16408|1|B|S:93'),
        (New-RunStartLine -Clock '01:32:00.000' -ExpertLeaf 'QM5_41321_grimes-trendday-v2-opt' -Symbol 'NDX.DWX' -Period 'M15' -From '2021.01.01' -To '2022.12.31'),
        (New-MarkerLine -Clock '01:33:00.000' -SourceColumn 'QM5_41321_grimes-trendday-v2-opt (NDX.DWX,M15)' -Symbol 'NDX.DWX' -Date '2021.02.01'),
        (New-MarkerLine -Clock '01:33:05.000' -SourceColumn 'QM5_41195_aa-vol-sma10-opt (XAGUSD.DWX,D1)' -Symbol 'XAGUSD.DWX' -Date '2022.01.12' -ProfileKey 'DL089_OPT|0|16408|1|B|S:99')
    ) | Set-Content -LiteralPath $mixedTester -Encoding utf8
    $mixedEvidence = Get-QmPatternFrequencyFloorEvidence `
        -TesterLogPaths @($mixedTester) `
        -FallbackStartDate '2021.01.01' `
        -EndDate '2022.12.31' `
        -ExpectedExpert 'QM\QM5_41321_grimes-trendday-v2-opt' `
        -ExpectedEaId 41321 `
        -RunSymbol 'NDX.DWX'
    Assert-Equal $mixedEvidence.coverage_start '2021.02.01' 'own marker survives foreign traffic'
    Assert-Equal $mixedEvidence.first_tradable_bar.symbol 'NDX.DWX' 'own marker symbol published'
    Assert-Equal $mixedEvidence.attributed_marker_count 1 'exactly the own marker is attributed'
    Assert-Equal $mixedEvidence.rejected_marker_count 2 'foreign markers rejected in mixed log'
    Assert-Equal $mixedEvidence.rejected_marker_reasons['outside_run_window'] 1 'pre-window foreign marker'
    Assert-Equal $mixedEvidence.rejected_marker_reasons['foreign_ea'] 1 'in-window foreign EA marker'
    Assert-Equal $mixedEvidence.min_trades_required 10 'mixed log keeps both scored years'

    # ea_id-only anchor (no -ExpectedExpert): the QM5_<id> label token in the
    # day-log source column and the run-start line is enough to attribute.
    $eaIdOnly = Get-QmPatternFrequencyFloorEvidence `
        -TesterLogPaths @($mixedTester) `
        -FallbackStartDate '2021.01.01' `
        -EndDate '2022.12.31' `
        -ExpectedEaId 41321 `
        -RunSymbol 'NDX.DWX'
    Assert-Equal $eaIdOnly.coverage_start '2021.02.01' 'ea_id anchor attributes own marker'

    # Multi-symbol basket: own EA, own chart, member-symbol marker.
    $basketTester = Join-Path $tmp 'tester-basket.log'
    @(
        (New-RunStartLine -Clock '01:32:00.000' -ExpertLeaf 'QM5_41321_grimes-trendday-v2-opt' -Symbol 'NDX.DWX' -Period 'M15' -From '2021.01.01' -To '2022.12.31'),
        (New-MarkerLine -Clock '01:33:00.000' -SourceColumn 'QM5_41321_grimes-trendday-v2-opt (NDX.DWX,M15)' -Symbol 'GDAXI.DWX' -Date '2021.03.01')
    ) | Set-Content -LiteralPath $basketTester -Encoding utf8
    $basketEvidence = Get-QmPatternFrequencyFloorEvidence `
        -TesterLogPaths @($basketTester) `
        -FallbackStartDate '2021.01.01' `
        -EndDate '2022.12.31' `
        -ExpectedExpert 'QM\QM5_41321_grimes-trendday-v2-opt' `
        -ExpectedEaId 41321 `
        -RunSymbol 'NDX.DWX'
    Assert-Equal $basketEvidence.coverage_start '2021.03.01' 'basket member marker on own chart is attributable'
    Assert-Equal $basketEvidence.first_tradable_bar.symbol_scope 'member_symbol' 'basket marker scope'

    # --- day-log layout 2: the source column is the tester core -----------
    # "IE<TAB>0<TAB>03:27:52.986<TAB>Core 01<TAB>..." carries no EA identity at
    # all (5.3% of production marker lines). The run window plus the run symbol
    # is then the scoping, reason `core_source_window`.
    $coreTester = Join-Path $tmp 'tester-core.log'
    @(
        "FF`t0`t02:24:24.187`tCore 01`t2021.01.21 01:00:01   QM_PATTERN_FIRST_TRADABLE_BAR schema=qm.pattern-first-tradable-bar/v1 symbol=XAGUSD.DWX reference_timeframe=16408 tradable_bar_date=2021.01.21 tradable_bar_time=1611187200 reference_bar_time=1611100800 required_bars=3 profile_key=DL089_OPT|0|16408|1|B|S:25",
        (New-ExpertAddedLine -Clock '19:38:17.966' -ExpertLeaf 'QM5_41097_balke-gmt3-range-breakout-opt' -Source 'Core 01'),
        (New-RunStartLine -Clock '19:38:17.966' -ExpertLeaf 'QM5_41097_balke-gmt3-range-breakout-opt' -Symbol 'USDJPY.DWX' -From '2022.01.01' -To '2022.12.31' -Source 'Core 01'),
        "IE`t0`t19:38:54.630`tCore 01`t2022.01.03 01:01:00   QM_PATTERN_FIRST_TRADABLE_BAR schema=qm.pattern-first-tradable-bar/v1 symbol=USDJPY.DWX reference_timeframe=16408 tradable_bar_date=2022.01.03 tradable_bar_time=1641168000 reference_bar_time=1640908800 required_bars=3 profile_key=DL089_OPT|0|16408|1|B|S:39",
        "IE`t0`t19:38:55.630`tCore 01`t2022.02.03 01:01:00   QM_PATTERN_FIRST_TRADABLE_BAR schema=qm.pattern-first-tradable-bar/v1 symbol=XAUUSD.DWX reference_timeframe=16408 tradable_bar_date=2022.02.03 tradable_bar_time=1643846400 reference_bar_time=1643760000 required_bars=3 profile_key=DL089_OPT|0|16408|1|B|S:41"
    ) | Set-Content -LiteralPath $coreTester -Encoding utf8
    $coreEvidence = Get-QmPatternFrequencyFloorEvidence `
        -TesterLogPaths @($coreTester) `
        -FallbackStartDate '2022.01.01' `
        -EndDate '2022.12.31' `
        -ExpectedExpert 'QM\QM5_41097_balke-gmt3-range-breakout-opt' `
        -ExpectedEaId 41097 `
        -RunSymbol 'USDJPY.DWX'
    Assert-Equal $coreEvidence.coverage_start '2022.01.03' 'core-layout marker inside own window is used'
    Assert-Equal $coreEvidence.first_tradable_bar.attribution_reason 'core_source_window' 'core-layout attribution reason'
    Assert-Equal $coreEvidence.first_tradable_bar.source_column_kind 'tester_core' 'core-layout source column kind'
    Assert-Equal $coreEvidence.rejected_marker_reasons['outside_run_window'] 1 'pre-window core marker rejected'
    Assert-Equal $coreEvidence.rejected_marker_reasons['foreign_symbol'] 1 'in-window core marker on a foreign symbol rejected'

    # Core layout without an anchorable run window stays fail-closed.
    $coreNoWindow = Join-Path $tmp 'tester-core-nowindow.log'
    @(
        (New-RunStartLine -Clock '19:38:17.966' -ExpertLeaf 'QM5_41097_balke-gmt3-range-breakout-opt' -Symbol 'USDJPY.DWX' -From '2021.01.01' -To '2021.12.31' -Source 'Core 01'),
        "IE`t0`t19:38:54.630`tCore 01`t2022.01.03 01:01:00   QM_PATTERN_FIRST_TRADABLE_BAR schema=qm.pattern-first-tradable-bar/v1 symbol=USDJPY.DWX reference_timeframe=16408 tradable_bar_date=2022.01.03 tradable_bar_time=1641168000 reference_bar_time=1640908800 required_bars=3 profile_key=DL089_OPT|0|16408|1|B|S:39"
    ) | Set-Content -LiteralPath $coreNoWindow -Encoding utf8
    $coreNoWindowEvidence = Get-QmPatternFrequencyFloorEvidence `
        -TesterLogPaths @($coreNoWindow) `
        -FallbackStartDate '2022.01.01' `
        -EndDate '2022.12.31' `
        -ExpectedExpert 'QM\QM5_41097_balke-gmt3-range-breakout-opt' `
        -ExpectedEaId 41097 `
        -RunSymbol 'USDJPY.DWX'
    Assert-Equal $coreNoWindowEvidence.marker_status 'present_not_attributable' 'core layout without a window fails closed'
    Assert-Equal $coreNoWindowEvidence.rejected_marker_reasons['run_window_unresolved'] 1 'core layout unresolved-window reason'

    # --- midnight rollover: day-log with no run-start line at all ---------
    # run_smoke copies the CURRENT day-log; a run that started before 00:00
    # leaves its tail in a file carrying exactly one run's output.
    $rollover = Join-Path $tmp 'tester-rollover.log'
    @(
        "CS`t0`t00:00:00.196`tTrade`t2019.10.02 06:00:00   buy stop 7.47 $runSymbol at 107.787",
        (New-MarkerLine -Clock '00:00:12.500' -SourceColumn "$runExpertLeaf ($runSymbol,H1)" -Symbol $runSymbol -Date '2020.01.02'),
        "CS`t0`t00:01:05.288`tTester`tfinal balance 104146.76 USD"
    ) | Set-Content -LiteralPath $rollover -Encoding utf8
    $rolloverEvidence = Get-QmPatternFrequencyFloorEvidence `
        -TesterLogPaths @($rollover) `
        -FallbackStartDate '2018.07.02' `
        -EndDate '2022.12.31' `
        -ExpectedExpert $runExpert `
        -ExpectedEaId $runEaId `
        -RunSymbol $runSymbol
    Assert-Equal $rolloverEvidence.run_scope.tester_log_windows[0].window_source 'rollover_continuation_no_run_start' 'rollover window source'
    Assert-Equal $rolloverEvidence.coverage_start '2020.01.02' 'rollover marker is attributable'
    Assert-Equal $rolloverEvidence.first_tradable_bar.attribution_reason 'own_ea_run_symbol' 'rollover attribution reason'

    # A day-log line without the source column cannot be attributed even inside
    # a resolved window.
    $bareTester = Join-Path $tmp 'tester-bare.log'
    @(
        (New-RunStartLine -Clock '01:32:00.000' -ExpertLeaf 'QM5_41321_grimes-trendday-v2-opt' -Symbol 'NDX.DWX' -Period 'M15' -From '2021.01.01' -To '2022.12.31'),
        'QM_PATTERN_FIRST_TRADABLE_BAR schema=qm.pattern-first-tradable-bar/v1 symbol=NDX.DWX reference_timeframe=16408 tradable_bar_date=2021.02.01 tradable_bar_time=1612137600 reference_bar_time=1612051200 required_bars=5 profile_key=DL089_OPT|0|16408|1|B|S:12'
    ) | Set-Content -LiteralPath $bareTester -Encoding utf8
    $bareEvidence = Get-QmPatternFrequencyFloorEvidence `
        -TesterLogPaths @($bareTester) `
        -FallbackStartDate '2021.01.01' `
        -EndDate '2022.12.31' `
        -ExpectedExpert 'QM\QM5_41321_grimes-trendday-v2-opt' `
        -ExpectedEaId 41321 `
        -RunSymbol 'NDX.DWX'
    Assert-Equal $bareEvidence.marker_status 'present_not_attributable' 'unattributable line status'
    Assert-Equal $bareEvidence.rejected_marker_reasons['marker_line_without_timestamp'] 1 'a marker line without a clock cannot be windowed'

    # No run identity supplied at all: no window anchor, nothing attributable.
    $noIdentity = Get-QmPatternFrequencyFloorEvidence `
        -TesterLogPaths @($tester) `
        -FallbackStartDate '2018.07.02' `
        -EndDate '2022.12.31'
    Assert-Equal $noIdentity.marker_status 'present_not_attributable' 'missing run identity fails closed'
    Assert-Equal $noIdentity.coverage_start '2018.07.02' 'missing run identity keeps full window'
    Assert-Equal $noIdentity.attribution.identity_anchor_available $false 'identity anchor flag'
    Assert-Equal $noIdentity.run_scope.tester_log_windows[0].window_source 'unresolved_no_expected_run_identity' 'window source without identity'

    $missing = Get-QmPatternFrequencyFloorEvidence `
        -FallbackStartDate '2018.07.02' `
        -EndDate '2022.12.31' `
        -ExpectedExpert $runExpert `
        -ExpectedEaId $runEaId `
        -RunSymbol $runSymbol
    Assert-Equal $missing.marker_status 'absent' 'missing marker status'
    Assert-Equal $missing.coverage_start_source 'test_window_start_fallback_marker_absent' 'visible fallback source'
    Assert-Equal $missing.min_trades_required 25 'historical fallback floor'
    Assert-Equal $missing.fallback_visible $true 'fallback visibility flag'

    $conflict = Get-QmPatternFrequencyFloorEvidence `
        -LoggerSamplePaths @($logger) `
        -TesterLogPaths @($tester) `
        -FallbackStartDate '2018.07.02' `
        -EndDate '2022.12.31' `
        -ExpectedExpert $runExpert `
        -ExpectedEaId $runEaId `
        -RunSymbol $runSymbol
    Assert-Equal $conflict.marker_status 'present_conflict_conservative_earliest' 'conflict status'
    Assert-Equal $conflict.coverage_start '2019.07.01' 'conflict chooses stricter earliest marker'

    Write-Host 'PASS: pattern warm-up per-run marker attribution, both day-log layouts, and visible Q02 fallback'
} finally {
    if (Test-Path -LiteralPath $tmp) {
        Remove-Item -LiteralPath $tmp -Recurse -Force
    }
}
