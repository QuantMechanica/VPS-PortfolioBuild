param(
    [ValidateRange(30, 300)]
    [int]$TimeoutSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$terminalRoot = "D:\QM\mt5\T_Export"
$reportRoot = "D:\QM\reports\state"
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path
$sourceFixture = (Resolve-Path -LiteralPath (
    Join-Path $repoRoot "framework\tests\QM_framework_p1_evidence_compile_test.mq5"
)).Path
$sourceInclude = (Resolve-Path -LiteralPath (Join-Path $repoRoot "framework\include")).Path
$metaEditor = (Resolve-Path -LiteralPath (Join-Path $terminalRoot "MetaEditor64.exe")).Path
$stockInclude = (Resolve-Path -LiteralPath (Join-Path $terminalRoot "MQL5\Include")).Path

function Get-TExportProcesses {
    $root = [System.IO.Path]::GetFullPath($terminalRoot).TrimEnd("\") + "\"
    return @(
        Get-CimInstance Win32_Process -ErrorAction Stop |
            Where-Object {
                $_.Name -in @("terminal64.exe", "metaeditor64.exe", "metatester64.exe") -and
                (($_.ExecutablePath -and $_.ExecutablePath.StartsWith(
                    $root, [System.StringComparison]::OrdinalIgnoreCase
                )) -or ($_.CommandLine -and $_.CommandLine.Contains(
                    $root, [System.StringComparison]::OrdinalIgnoreCase
                )))
            }
    )
}

function Set-Utf8NoBomText {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Text
    )
    [System.IO.File]::WriteAllText(
        $Path,
        $Text,
        [System.Text.UTF8Encoding]::new($false)
    )
}

if (@(Get-Process metaeditor64 -ErrorAction SilentlyContinue).Count -ne 0) {
    throw "Another MetaEditor process is active; serial compile contract requires an idle compiler lane."
}
if (@(Get-TExportProcesses).Count -ne 0) {
    throw "T_Export is not parked."
}

$runTag = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ") + "_" +
    ([guid]::NewGuid().ToString("N").Substring(0, 8))
$workRoot = Join-Path $reportRoot ".framework_p1_compile_$runTag"
$stageRoot = Join-Path $workRoot "source"
$stageInclude = Join-Path $stageRoot "include"
$stageFixture = Join-Path $stageRoot "QM_framework_p1_evidence_compile_test.mq5"
$compileLog = Join-Path $workRoot "compile.log"
$finalLog = Join-Path $reportRoot "framework_p1_include_compile_20260720.log"
$finalManifest = Join-Path $reportRoot "framework_p1_include_compile_20260720.json"
$process = $null
$published = $false

try {
    if ((Test-Path -LiteralPath $finalLog) -or (Test-Path -LiteralPath $finalManifest)) {
        throw "Refusing to overwrite existing P1 compile evidence."
    }

    New-Item -ItemType Directory -Path $stageInclude -Force | Out-Null
    Copy-Item -Path (Join-Path $sourceInclude "*") -Destination $stageInclude -Recurse
    Copy-Item -LiteralPath (Join-Path $stockInclude "Trade") -Destination $stageInclude -Recurse
    Copy-Item -LiteralPath (Join-Path $stockInclude "Object.mqh") -Destination $stageInclude
    Copy-Item -LiteralPath (Join-Path $stockInclude "StdLibErr.mqh") -Destination $stageInclude
    Copy-Item -LiteralPath $sourceFixture -Destination $stageFixture

    # MetaEditor resolves angle-bracket includes against an AppData data path even
    # for /portable compiles. Rewrite only disposable staged copies so this test is
    # hermetic and never syncs framework files into a terminal Include directory.
    $fixtureText = (Get-Content -Raw -LiteralPath $stageFixture).Replace(
        '#include <QM/QM_Common.mqh>', '#include "include/QM/QM_Common.mqh"'
    )
    Set-Utf8NoBomText -Path $stageFixture -Text $fixtureText

    foreach ($relative in @("QM\QM_Common.mqh", "QM\QM_KillSwitch.mqh")) {
        $path = Join-Path $stageInclude $relative
        $text = (Get-Content -Raw -LiteralPath $path).Replace(
            '#include <Trade/Trade.mqh>', '#include "../Trade/Trade.mqh"'
        )
        Set-Utf8NoBomText -Path $path -Text $text
    }
    $signalsPath = Join-Path $stageInclude "QM\QM_Signals.mqh"
    $signalsText = (Get-Content -Raw -LiteralPath $signalsPath).Replace(
        '#include <QM/QM_Indicators.mqh>', '#include "QM_Indicators.mqh"'
    )
    Set-Utf8NoBomText -Path $signalsPath -Text $signalsText

    foreach ($tradeHeader in Get-ChildItem -LiteralPath (Join-Path $stageInclude "Trade") -Filter "*.mqh") {
        $tradeText = (Get-Content -Raw -LiteralPath $tradeHeader.FullName).Replace(
            '#include <Object.mqh>', '#include "../Object.mqh"'
        )
        Set-Utf8NoBomText -Path $tradeHeader.FullName -Text $tradeText
    }

    $compileStarted = (Get-Date).ToUniversalTime()
    $process = Start-Process -FilePath $metaEditor -ArgumentList @(
        "/compile:$stageFixture", "/log:$compileLog"
    ) -PassThru -WindowStyle Hidden
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $identity = Get-CimInstance Win32_Process -Filter "ProcessId=$($process.Id)" -ErrorAction SilentlyContinue
        if ($identity -and $identity.ExecutablePath -eq $metaEditor) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        }
        throw "P1 isolated compile timed out after $TimeoutSeconds seconds."
    }
    if (-not (Test-Path -LiteralPath $compileLog -PathType Leaf)) {
        throw "MetaEditor produced no compile log."
    }

    $logText = Get-Content -Raw -LiteralPath $compileLog
    $matches = [regex]::Matches(
        $logText, "(?im)(?<errors>\d+)\s+errors?\s*,\s*(?<warnings>\d+)\s+warnings?"
    )
    if ($matches.Count -eq 0) {
        throw "Compile log has no errors/warnings summary."
    }
    $counts = $matches[$matches.Count - 1]
    $errors = [int]$counts.Groups["errors"].Value
    $warnings = [int]$counts.Groups["warnings"].Value
    $stageEx5 = [System.IO.Path]::ChangeExtension($stageFixture, ".ex5")
    # MetaEditor64 commonly returns process exit code 1 after a successful CLI
    # compile. The canonical compile_one.ps1 therefore trusts the compiler's
    # parsed counts plus a fresh EX5, while retaining the exit code as evidence.
    if ($errors -ne 0 -or $warnings -ne 0) {
        throw "P1 isolated compile failed: exit=$($process.ExitCode) errors=$errors warnings=$warnings."
    }
    if (-not (Test-Path -LiteralPath $stageEx5 -PathType Leaf)) {
        throw "P1 isolated compile produced no EX5."
    }
    if ((Get-Item -LiteralPath $stageEx5).LastWriteTimeUtc -lt $compileStarted.AddSeconds(-2)) {
        throw "P1 isolated compile EX5 predates this run."
    }

    Copy-Item -LiteralPath $compileLog -Destination $finalLog
    $manifest = [ordered]@{
        schema_version = 1
        generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
        result = "PASS"
        errors = $errors
        warnings = $warnings
        metaeditor_exit_code = $process.ExitCode
        terminal = "T_Export"
        terminal_root = $terminalRoot
        isolated = $true
        terminal_include_modified = $false
        fixture = $sourceFixture
        fixture_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourceFixture).Hash.ToLowerInvariant()
        include_sha256 = [ordered]@{
            "QM_Common.mqh" = (Get-FileHash -Algorithm SHA256 -LiteralPath (
                Join-Path $sourceInclude "QM\QM_Common.mqh"
            )).Hash.ToLowerInvariant()
            "QM_NewsFilter.mqh" = (Get-FileHash -Algorithm SHA256 -LiteralPath (
                Join-Path $sourceInclude "QM\QM_NewsFilter.mqh"
            )).Hash.ToLowerInvariant()
            "QM_Logger.mqh" = (Get-FileHash -Algorithm SHA256 -LiteralPath (
                Join-Path $sourceInclude "QM\QM_Logger.mqh"
            )).Hash.ToLowerInvariant()
            "QM_EquityStream.mqh" = (Get-FileHash -Algorithm SHA256 -LiteralPath (
                Join-Path $sourceInclude "QM\QM_EquityStream.mqh"
            )).Hash.ToLowerInvariant()
        }
        compile_log = $finalLog
        compile_log_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $finalLog).Hash.ToLowerInvariant()
    }
    Set-Utf8NoBomText -Path $finalManifest -Text (($manifest | ConvertTo-Json -Depth 4) + "`n")
    $published = $true

    Write-Output "PASS: P1 isolated include compile (0 errors, 0 warnings)"
    Write-Output "compile_log=$finalLog"
    Write-Output "manifest=$finalManifest"
}
finally {
    if ($process -and -not $process.HasExited) {
        $identity = Get-CimInstance Win32_Process -Filter "ProcessId=$($process.Id)" -ErrorAction SilentlyContinue
        if ($identity -and $identity.ExecutablePath -eq $metaEditor) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        }
    }
    if (Test-Path -LiteralPath $workRoot) {
        $resolvedWork = [System.IO.Path]::GetFullPath($workRoot)
        $resolvedReports = [System.IO.Path]::GetFullPath($reportRoot).TrimEnd("\") + "\"
        if ($resolvedWork.StartsWith($resolvedReports, [System.StringComparison]::OrdinalIgnoreCase) -and
            [System.IO.Path]::GetFileName($resolvedWork).StartsWith(".framework_p1_compile_")) {
            Remove-Item -LiteralPath $resolvedWork -Recurse -Force
        }
    }
    if (-not $published) {
        foreach ($path in @($finalLog, $finalManifest)) {
            if (Test-Path -LiteralPath $path) {
                Remove-Item -LiteralPath $path -Force
            }
        }
    }
}
