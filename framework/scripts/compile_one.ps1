[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$EAPath,
    [switch]$Strict,
    [string]$MetaEditorPath,
    [string]$ReportRoot = "D:\QM\reports\compile",
    [string]$BuildRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-RepoRoot {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    return $repoRoot.Path
}

function Resolve-DefaultMetaEditorPath {
    $candidates = @(
        "D:\QM\mt5\T1\metaeditor64.exe",
        "D:\QM\mt5\T1\metaeditor.exe",
        "D:\QM\mt5\T2\metaeditor64.exe",
        "D:\QM\mt5\T2\metaeditor.exe",
        "C:\Program Files\MetaTrader 5\metaeditor64.exe",
        "C:\Program Files\MetaTrader 5\metaeditor.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "metaeditor.exe not found. Provide -MetaEditorPath explicitly."
}

function Resolve-TerminalIncludeTargets {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MetaEditorPath
    )

    $targets = New-Object System.Collections.Generic.List[string]

    $installInclude = Join-Path (Split-Path -Parent $MetaEditorPath) "MQL5\Include"
    if (Test-Path -LiteralPath $installInclude) {
        [void]$targets.Add((Resolve-Path -LiteralPath $installInclude).Path)
    }

    $terminalRoot = Join-Path $env:APPDATA "MetaQuotes\Terminal"
    if (Test-Path -LiteralPath $terminalRoot) {
        $dirs = Get-ChildItem -LiteralPath $terminalRoot -Directory -ErrorAction SilentlyContinue
        foreach ($dir in $dirs) {
            $includePath = Join-Path $dir.FullName "MQL5\Include"
            if (Test-Path -LiteralPath $includePath) {
                [void]$targets.Add((Resolve-Path -LiteralPath $includePath).Path)
            }
        }
    }

    $unique = $targets | Select-Object -Unique
    return @($unique)
}

function Resolve-Mq5Path {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputPath
    )

    $resolved = Resolve-Path -LiteralPath $InputPath
    $targetPath = $resolved.Path

    if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
        if ([System.IO.Path]::GetExtension($targetPath).ToLowerInvariant() -ne ".mq5") {
            throw "EAPath must point to a .mq5 file or a directory containing one .mq5 file. Got file: $targetPath"
        }
        return $targetPath
    }

    $mq5Files = Get-ChildItem -LiteralPath $targetPath -Filter "*.mq5" -File
    if ($mq5Files.Count -eq 1) {
        return $mq5Files[0].FullName
    }

    if ($mq5Files.Count -eq 0) {
        $folderName = Split-Path -Leaf $targetPath
        $namedCandidate = Join-Path $targetPath "$folderName.mq5"
        if (Test-Path -LiteralPath $namedCandidate) {
            return (Resolve-Path -LiteralPath $namedCandidate).Path
        }
        throw "No .mq5 file found in EAPath directory: $targetPath"
    }

    throw "EAPath directory contains multiple .mq5 files; pass a single file path explicitly: $targetPath"
}

function Parse-CompileCounts {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogContent
    )

    $summaryRegex = [regex]'(?im)\b(?<errors>\d+)\s+errors?\b.*?\b(?<warnings>\d+)\s+warnings?\b'
    $summaryMatch = $summaryRegex.Match($LogContent)
    if ($summaryMatch.Success) {
        return @{
            errors = [int]$summaryMatch.Groups["errors"].Value
            warnings = [int]$summaryMatch.Groups["warnings"].Value
        }
    }

    $errorCount = ([regex]::Matches($LogContent, '(?im)\berror\b')).Count
    $warningCount = ([regex]::Matches($LogContent, '(?im)\bwarning\b')).Count
    return @{
        errors = $errorCount
        warnings = $warningCount
    }
}

function Resolve-IncludeRootFromLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogContent
    )

    $missingIncludeRegex = [regex]"(?im)file\s+'(?<path>[^']+\\MQL5\\Include\\QM\\QM_Common\.mqh)'\s+not found"
    $match = $missingIncludeRegex.Match($LogContent)
    if (-not $match.Success) {
        return $null
    }

    $qmCommonPath = $match.Groups["path"].Value
    return (Split-Path -Parent (Split-Path -Parent $qmCommonPath))
}

function Sync-FrameworkIncludes {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceIncludeRoot,
        [Parameter(Mandatory = $true)]
        [string]$TargetIncludeRoot
    )

    if (-not (Test-Path -LiteralPath $SourceIncludeRoot -PathType Container)) {
        throw "Source include root not found: $SourceIncludeRoot"
    }

    New-Item -ItemType Directory -Path $TargetIncludeRoot -Force | Out-Null
    Copy-Item -Path (Join-Path $SourceIncludeRoot "*") -Destination $TargetIncludeRoot -Recurse -Force
}

function Write-SummaryRow {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SummaryCsvPath,
        [Parameter(Mandatory = $true)]
        [hashtable]$Row
    )

    $rowObject = [pscustomobject]$Row
    if (-not (Test-Path -LiteralPath $SummaryCsvPath)) {
        $rowObject | Export-Csv -LiteralPath $SummaryCsvPath -NoTypeInformation -Encoding utf8
    } else {
        $rowObject | Export-Csv -LiteralPath $SummaryCsvPath -NoTypeInformation -Encoding utf8 -Append
    }
}

$repoRoot = Resolve-RepoRoot
if (-not $BuildRoot) {
    $BuildRoot = Join-Path $repoRoot "framework\build"
}

$mq5Path = Resolve-Mq5Path -InputPath $EAPath
$eaName = [System.IO.Path]::GetFileNameWithoutExtension($mq5Path)
$runTag = (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss")

if (-not $MetaEditorPath) {
    $MetaEditorPath = Resolve-DefaultMetaEditorPath
} else {
    $MetaEditorPath = (Resolve-Path -LiteralPath $MetaEditorPath).Path
}

$compileOutputDir = Join-Path $BuildRoot "compile\$runTag"
$reportDir = Join-Path $ReportRoot $runTag
New-Item -ItemType Directory -Path $compileOutputDir -Force | Out-Null
New-Item -ItemType Directory -Path $reportDir -Force | Out-Null

$compileLogPath = Join-Path $compileOutputDir "$eaName.compile.log"
$summaryCsvPath = Join-Path $reportDir "summary.csv"
$ex5Path = [System.IO.Path]::ChangeExtension($mq5Path, ".ex5")
if (Test-Path -LiteralPath $compileLogPath) {
    Remove-Item -LiteralPath $compileLogPath -Force
}

$result = "FAIL"
$reasonClass = "UNKNOWN"
$errorCount = -1
$warningCount = -1
$metaEditorExitCode = 0
$includeSyncRoot = ""
$includeSyncTargets = @()

try {
    $didRetryAfterIncludeSync = $false
    $sourceIncludeRoot = Join-Path $repoRoot "framework\include"
    $includeTargets = Resolve-TerminalIncludeTargets -MetaEditorPath $MetaEditorPath
    foreach ($includeTarget in $includeTargets) {
        Sync-FrameworkIncludes -SourceIncludeRoot $sourceIncludeRoot -TargetIncludeRoot $includeTarget
    }
    $includeSyncTargets = $includeTargets

    while ($true) {
        $arguments = @(
            "/compile:$mq5Path",
            "/log:$compileLogPath"
        )

        $proc = Start-Process -FilePath $MetaEditorPath -ArgumentList $arguments -PassThru -Wait -NoNewWindow
        $metaEditorExitCode = $proc.ExitCode
        if (-not (Test-Path -LiteralPath $compileLogPath)) {
            throw "MetaEditor did not produce a compile log at $compileLogPath"
        }

        $logContent = Get-Content -Raw -LiteralPath $compileLogPath
        $counts = Parse-CompileCounts -LogContent $logContent
        $errorCount = $counts.errors
        $warningCount = $counts.warnings

        $includeRootFromLog = Resolve-IncludeRootFromLog -LogContent $logContent
        if ($errorCount -gt 0 -and -not $didRetryAfterIncludeSync -and $includeRootFromLog) {
            Sync-FrameworkIncludes -SourceIncludeRoot $sourceIncludeRoot -TargetIncludeRoot $includeRootFromLog
            $includeSyncRoot = $includeRootFromLog
            $didRetryAfterIncludeSync = $true
            continue
        }

        if ($errorCount -gt 0) {
            $reasonClass = "COMPILE_ERRORS"
            throw "Compile failed with $errorCount errors."
        }

        if ($Strict.IsPresent -and $warningCount -gt 0) {
            $reasonClass = "STRICT_WARNINGS"
            throw "Strict compile failed with $warningCount warnings."
        }

        if (-not (Test-Path -LiteralPath $ex5Path)) {
            $reasonClass = "NO_REPORT_EX5_MISSING"
            throw "Compile did not produce expected output file: $ex5Path"
        }

        $ex5File = Get-Item -LiteralPath $ex5Path
        if ($ex5File.Length -le 0) {
            $reasonClass = "NO_REPORT_EX5_EMPTY"
            throw "Compile produced empty output file: $ex5Path"
        }

        break
    }

    $result = "PASS"
    $reasonClass = "OK"
} catch {
    if ($reasonClass -eq "UNKNOWN") {
        $reasonClass = "RUNTIME_EXCEPTION"
    }

    Write-Error $_
} finally {
    $summaryRow = @{
        run_tag = $runTag
        timestamp_utc = (Get-Date).ToUniversalTime().ToString("o")
        ea_name = $eaName
        ea_path = $EAPath
        mq5_path = $mq5Path
        metaeditor_path = $MetaEditorPath
        compile_log_path = $compileLogPath
        ex5_path = $ex5Path
        strict = [bool]$Strict.IsPresent
        errors = $errorCount
        warnings = $warningCount
        metaeditor_exit_code = $metaEditorExitCode
        include_sync_root = $includeSyncRoot
        include_sync_targets = ($includeSyncTargets -join ";")
        result = $result
        reason_class = $reasonClass
    }
    Write-SummaryRow -SummaryCsvPath $summaryCsvPath -Row $summaryRow

    Write-Output "compile_one.result=$result"
    Write-Output "compile_one.reason_class=$reasonClass"
    Write-Output "compile_one.errors=$errorCount"
    Write-Output "compile_one.warnings=$warningCount"
    Write-Output "compile_one.metaeditor_exit_code=$metaEditorExitCode"
    Write-Output "compile_one.include_sync_root=$includeSyncRoot"
    Write-Output ("compile_one.include_sync_targets=" + ($includeSyncTargets -join ";"))
    Write-Output "compile_one.log=$compileLogPath"
    Write-Output "compile_one.summary=$summaryCsvPath"
    Write-Output "compile_one.ex5=$ex5Path"
}

if ($result -ne "PASS") {
    exit 1
}

exit 0
