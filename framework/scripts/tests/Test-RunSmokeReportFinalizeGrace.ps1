[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Regression guard for the durable report-capture-race fix (2026-09-03,
# QM5_12580 AUDUSD Q03 false zero). A run that finished naturally can still
# expose MT5's modeling-phase report shell (Symbols=0 / Total Deals=0 /
# Initial Deposit=0.00 with Bars>0) on disk while terminal64 flushes the final
# report during its ShutdownTerminal=1 exit. The harness must not grade that
# shell's 0 trades as a strategy result: it re-checks the tester journal, and if
# real deals were executed it is an infra REPORT_CAPTURE_INCOMPLETE, not a
# zero-trade strategy FAIL. A genuine zero (shell with no journal deals) and a
# populated report both keep the unchanged path.

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$scriptPath = Join-Path $repoRoot "framework\scripts\run_smoke.ps1"

$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
if (@($errors).Count -gt 0) {
    throw "run_smoke.ps1 parse errors: $($errors | Out-String)"
}

$neededFunctions = @(
    "Convert-HtmlEntityText",
    "Get-ReportMetricValue",
    "Convert-ReportNumber",
    "Test-TesterReportIsShell",
    "Test-TesterJournalHasDeals",
    "Test-TerminalProcessAlive",
    "Wait-ForTesterReportFinalization"
)

foreach ($name in $neededFunctions) {
    $functionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq $name
    }, $true)

    if (-not $functionAst) {
        throw "$name function not found."
    }

    Invoke-Expression $functionAst.Extent.Text
}

# Wait-ForTesterReportFinalization's default -GraceSeconds reads this script var.
$script:ReportFinalizeGraceSec = 180

$tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("qm-run-smoke-finalize-{0}" -f [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmpRoot -Force | Out-Null

$shellReport = Join-Path $tmpRoot "shell-report.htm"
$genuineZeroReport = Join-Path $tmpRoot "genuine-zero-report.htm"
$fullReport = Join-Path $tmpRoot "full-report.htm"
$dealsJournal = Join-Path $tmpRoot "20260903_deals.log"
$noDealsJournal = Join-Path $tmpRoot "20260903_nodeals.log"

try {
    # MT5 modeling-phase shell: real bar/tick context, but account not yet
    # consolidated (Symbols=0 / Total Deals=0 / Initial Deposit=0.00).
    @"
<html><body><table>
<tr><td>Expert:</td><td><b>QM5_12580_fx-usd-exhaustion-reversal</b></td></tr>
<tr><td>Symbol:</td><td><b>AUDUSD.DWX</b></td></tr>
<tr><td>Period:</td><td><b>Daily (2018.07.02 - 2022.12.31)</b></td></tr>
<tr><td>Bars:</td><td><b>958</b></td></tr>
<tr><td>Initial Deposit:</td><td><b>0.00</b></td></tr>
<tr><td>Symbols:</td><td><b>0</b></td></tr>
<tr><td>Total Deals:</td><td><b>0</b></td></tr>
<tr><td>Profit Factor:</td><td><b>0.00</b></td></tr>
<tr><td>Equity Drawdown Maximal:</td><td><b>0 (0%)</b></td></tr>
<tr><td>Total Trades:</td><td><b>0</b></td></tr>
</table></body></html>
"@ | Set-Content -LiteralPath $shellReport -Encoding UTF8

    # Genuine zero-trade COMPLETE report: deposit settled, symbols loaded, no trades.
    @"
<html><body><table>
<tr><td>Expert:</td><td><b>QM5_12580_fx-usd-exhaustion-reversal</b></td></tr>
<tr><td>Symbol:</td><td><b>AUDUSD.DWX</b></td></tr>
<tr><td>Period:</td><td><b>Daily (2018.07.02 - 2022.12.31)</b></td></tr>
<tr><td>Bars:</td><td><b>958</b></td></tr>
<tr><td>Initial Deposit:</td><td><b>100000.00</b></td></tr>
<tr><td>Symbols:</td><td><b>1</b></td></tr>
<tr><td>Total Deals:</td><td><b>0</b></td></tr>
<tr><td>Profit Factor:</td><td><b>0.00</b></td></tr>
<tr><td>Equity Drawdown Maximal:</td><td><b>0 (0%)</b></td></tr>
<tr><td>Total Trades:</td><td><b>0</b></td></tr>
</table></body></html>
"@ | Set-Content -LiteralPath $genuineZeroReport -Encoding UTF8

    # Fully consolidated report with real trading activity.
    @"
<html><body><table>
<tr><td>Expert:</td><td><b>QM5_12580_fx-usd-exhaustion-reversal</b></td></tr>
<tr><td>Symbol:</td><td><b>AUDUSD.DWX</b></td></tr>
<tr><td>Period:</td><td><b>Daily (2018.07.02 - 2022.12.31)</b></td></tr>
<tr><td>Bars:</td><td><b>958</b></td></tr>
<tr><td>Initial Deposit:</td><td><b>100000.00</b></td></tr>
<tr><td>Symbols:</td><td><b>7</b></td></tr>
<tr><td>Total Deals:</td><td><b>138</b></td></tr>
<tr><td>Profit Factor:</td><td><b>1.71</b></td></tr>
<tr><td>Equity Drawdown Maximal:</td><td><b>4186.86 (4.19%)</b></td></tr>
<tr><td>Total Trades:</td><td><b>47</b></td></tr>
</table></body></html>
"@ | Set-Content -LiteralPath $fullReport -Encoding UTF8

    # Tester journal (UTF-16 with BOM, as MT5 writes it) recording real deals.
    @"
2018.07.02 00:00:00   Tester  AUDUSD.DWX,Daily: testing of Experts\QM\QM5_12580_fx-usd-exhaustion-reversal.ex5 from 2018.07.02 00:00 to 2022.12.31 00:00 started
2018.07.10 00:05:00   Trades  2018.07.10 00:05:00   deal #2 sell 1.1 AUDUSD.DWX at 0.74642 done
2018.07.11 00:05:00   Trades  2018.07.11 00:05:00   deal #3 buy 1.1 AUDUSD.DWX at 0.74100 done
2022.12.31 00:00:00   Tester  AUDUSD.DWX,Daily: 119049418 ticks, 958 bars generated. Environment synchronized in 0:00:01.000
2022.12.31 00:00:00   Tester  AUDUSD.DWX,Daily: Test passed in 0:10:25.184
"@ | Set-Content -LiteralPath $dealsJournal -Encoding Unicode

    # Tester journal for a genuinely quiet run: passed, but zero deals.
    @"
2018.07.02 00:00:00   Tester  AUDUSD.DWX,Daily: testing of Experts\QM\QM5_12580_fx-usd-exhaustion-reversal.ex5 from 2018.07.02 00:00 to 2022.12.31 00:00 started
2022.12.31 00:00:00   Tester  AUDUSD.DWX,Daily: 119049418 ticks, 958 bars generated. Environment synchronized in 0:00:01.000
2022.12.31 00:00:00   Tester  AUDUSD.DWX,Daily: Test passed in 0:10:25.184
final balance 100000.00 USD
"@ | Set-Content -LiteralPath $noDealsJournal -Encoding Ascii

    # --- Shell signature detection -------------------------------------------
    if (-not (Test-TesterReportIsShell -ReportPath $shellReport)) {
        throw "Shell report (Symbols=0/Total Deals=0/Initial Deposit=0.00, Bars>0) was not detected as a shell."
    }
    if (Test-TesterReportIsShell -ReportPath $genuineZeroReport) {
        throw "Genuine zero-trade complete report (settled deposit, symbols>0) was wrongly detected as a shell."
    }
    if (Test-TesterReportIsShell -ReportPath $fullReport) {
        throw "Fully consolidated report was wrongly detected as a shell."
    }

    # --- Journal deal cross-check --------------------------------------------
    if (-not (Test-TesterJournalHasDeals -JournalPath $dealsJournal)) {
        throw "UTF-16 tester journal with 'deal #N' fills was not detected as having deals."
    }
    if (Test-TesterJournalHasDeals -JournalPath $noDealsJournal) {
        throw "Tester journal without any 'deal #N' line was wrongly detected as having deals."
    }
    if (Test-TesterJournalHasDeals -JournalPath (Join-Path $tmpRoot "does-not-exist.log")) {
        throw "Missing journal path was treated as having deals."
    }

    # Case 1: shell + journal deals -> REPORT_CAPTURE_INCOMPLETE decision.
    if (-not ((Test-TesterReportIsShell -ReportPath $shellReport) -and (Test-TesterJournalHasDeals -JournalPath $dealsJournal))) {
        throw "shell + journal-deals did not compose to the REPORT_CAPTURE_INCOMPLETE decision."
    }
    # Case 2: shell + no deals -> genuine zero (falls through to normal grading).
    if (-not ((Test-TesterReportIsShell -ReportPath $shellReport) -and -not (Test-TesterJournalHasDeals -JournalPath $noDealsJournal))) {
        throw "shell + no-journal-deals did not compose to the genuine-zero decision."
    }
    # Case 3: full report -> unchanged path (guard never fires).
    if (Test-TesterReportIsShell -ReportPath $fullReport) {
        throw "Full report incorrectly diverted into the finalize-grace guard."
    }

    # --- Terminal liveness helper --------------------------------------------
    if (Test-TerminalProcessAlive -TerminalPid 0) {
        throw "PID 0 was reported alive."
    }
    if (Test-TerminalProcessAlive -TerminalPid -1) {
        throw "Negative PID was reported alive."
    }
    # The current pwsh process is alive but is not terminal64, so it must read
    # as 'not the run's terminal' (i.e. writer gone from the report's standpoint).
    if (Test-TerminalProcessAlive -TerminalPid $PID) {
        throw "A live non-terminal64 process was misreported as the run's terminal64."
    }

    # --- Bounded finalization wait -------------------------------------------
    # Shell on disk, writer already gone (a non-terminal64 pid): the wait must
    # return immediately (no sleep) with shell_persisted, handing off to the
    # journal cross-check.
    $waitShell = Wait-ForTesterReportFinalization -ReportPath $shellReport -TerminalPid $PID
    if (-not $waitShell.shell_persisted) {
        throw "Persisting shell with no live writer did not report shell_persisted."
    }
    if ($waitShell.polls -ne 0) {
        throw "Finalization wait slept while the writer was already gone: polls=$($waitShell.polls)."
    }
    if (-not $waitShell.terminal_exited) {
        throw "Finalization wait did not observe the writer as exited."
    }

    # A settled report immediately reports not-a-shell.
    $waitFull = Wait-ForTesterReportFinalization -ReportPath $fullReport -TerminalPid $PID
    if ($waitFull.shell_persisted) {
        throw "Settled full report was misreported as a persisting shell."
    }
} finally {
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "PASS Test-RunSmokeReportFinalizeGrace"
