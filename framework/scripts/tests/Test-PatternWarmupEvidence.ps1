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

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("qm-pattern-warmup-{0}" -f [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    $logger = Join-Path $tmp 'logger.jsonl'
    $row = [ordered]@{
        event = 'PATTERN_FIRST_TRADABLE_BAR'
        payload = [ordered]@{
            marker_schema = 'qm.pattern-first-tradable-bar/v1'
            symbol = 'EURUSD.DWX'
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
        -RatePerYear 5
    Assert-Equal $present.marker_status 'present_consistent' 'logger marker status'
    Assert-Equal $present.coverage_start_source 'pattern_first_tradable_bar' 'logger marker source'
    Assert-Equal $present.coverage_start '2019.07.01' 'logger marker date'
    Assert-Equal $present.year_count 4 'marker-adjusted year count'
    Assert-Equal $present.min_trades_required 20 'marker-adjusted Q02 floor'

    $multiScope = Join-Path $tmp 'logger-multi-scope.jsonl'
    $row | ConvertTo-Json -Compress -Depth 6 | Set-Content -LiteralPath $multiScope -Encoding utf8
    $row.payload.tradable_bar_date = '2020.01.02'
    $row.payload.tradable_bar_time = 1577923200
    $row.payload.profile_key = 'BUG4_DEEPER_SLOT|0|16408|1|B:90|S'
    $row | ConvertTo-Json -Compress -Depth 6 | Add-Content -LiteralPath $multiScope -Encoding utf8
    $latestScope = Get-QmPatternFrequencyFloorEvidence `
        -LoggerSamplePaths @($multiScope) `
        -FallbackStartDate '2018.07.02' `
        -EndDate '2022.12.31'
    Assert-Equal $latestScope.coverage_start '2020.01.02' 'latest active profile scope controls run start'
    Assert-Equal $latestScope.effective_run_marker_count 1 'multiple scopes collapse to one run marker'

    $tester = Join-Path $tmp 'tester.log'
    @'
line before
QM_PATTERN_FIRST_TRADABLE_BAR schema=qm.pattern-first-tradable-bar/v1 symbol=EURUSD.DWX reference_timeframe=16408 tradable_bar_date=2020.01.02 tradable_bar_time=1577923200 reference_bar_time=1577836800 required_bars=101 profile_key=BUG4_MAX_DEPTH|0|16408|1|B:90|S
'@ | Set-Content -LiteralPath $tester -Encoding utf8
    $fromTester = Get-QmPatternFrequencyFloorEvidence `
        -TesterLogPaths @($tester) `
        -FallbackStartDate '2018.07.02' `
        -EndDate '2022.12.31'
    Assert-Equal $fromTester.first_tradable_bar.source_kind 'tester_log' 'tester marker source kind'
    Assert-Equal $fromTester.coverage_start '2020.01.02' 'tester marker date'

    $missing = Get-QmPatternFrequencyFloorEvidence `
        -FallbackStartDate '2018.07.02' `
        -EndDate '2022.12.31'
    Assert-Equal $missing.marker_status 'absent' 'missing marker status'
    Assert-Equal $missing.coverage_start_source 'test_window_start_fallback_marker_absent' 'visible fallback source'
    Assert-Equal $missing.min_trades_required 25 'historical fallback floor'
    Assert-Equal $missing.fallback_visible $true 'fallback visibility flag'

    $conflict = Get-QmPatternFrequencyFloorEvidence `
        -LoggerSamplePaths @($logger) `
        -TesterLogPaths @($tester) `
        -FallbackStartDate '2018.07.02' `
        -EndDate '2022.12.31'
    Assert-Equal $conflict.marker_status 'present_conflict_conservative_earliest' 'conflict status'
    Assert-Equal $conflict.coverage_start '2019.07.01' 'conflict chooses stricter earliest marker'

    Write-Host 'PASS: pattern warm-up marker parsing and visible Q02 fallback'
} finally {
    if (Test-Path -LiteralPath $tmp) {
        Remove-Item -LiteralPath $tmp -Recurse -Force
    }
}
