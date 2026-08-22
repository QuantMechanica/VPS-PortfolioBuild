[CmdletBinding()]
param(
    [string]$EAPath,
    [string]$EALabel,
    [switch]$Strict,
    [string]$MetaEditorPath,
    [string]$ReportRoot = "D:\QM\reports\compile",
    [string]$BuildRoot,
    [string]$CompileWorkItemId,
    [ValidatePattern('^T(?:10|[1-9])$')]
    [string]$ClaimedTerminal
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
        [string]$MetaEditorPath,
        [string[]]$AdditionalTerminalRoots = @()
    )

    $targets = New-Object System.Collections.Generic.List[string]
    $metaEditorRoot = (Resolve-Path -LiteralPath (Split-Path -Parent $MetaEditorPath)).Path.TrimEnd("\")

    $installInclude = Join-Path $metaEditorRoot "MQL5\Include"
    if (Test-Path -LiteralPath $installInclude) {
        [void]$targets.Add((Resolve-Path -LiteralPath $installInclude).Path)
    }

    $currentTerminalRoot = $null
    if (-not [string]::IsNullOrWhiteSpace($env:APPDATA)) {
        $candidate = Join-Path $env:APPDATA "MetaQuotes\Terminal"
        if (Test-Path -LiteralPath $candidate) {
            $currentTerminalRoot = (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    # Preserve the existing behaviour for the account running compile_one:
    # sync every materialized terminal include tree in that account's profile.
    if ($currentTerminalRoot) {
        $dirs = Get-ChildItem -LiteralPath $currentTerminalRoot -Directory -ErrorAction SilentlyContinue
        foreach ($dir in $dirs) {
            $includePath = Join-Path $dir.FullName "MQL5\Include"
            if (Test-Path -LiteralPath $includePath) {
                [void]$targets.Add((Resolve-Path -LiteralPath $includePath).Path)
            }
        }
    }

    # MetaEditor can resolve its data folder from a different Windows profile
    # than the caller (for example, SYSTEM launching an installation registered
    # under Administrator). Discover those profile roots, but sync only terminal
    # hashes whose origin.txt points at this MetaEditor installation. This avoids
    # copying build-time includes into unrelated live or FTMO terminal profiles.
    $profileTerminalRoots = New-Object System.Collections.Generic.List[string]
    foreach ($terminalRoot in @($AdditionalTerminalRoots)) {
        if (-not [string]::IsNullOrWhiteSpace($terminalRoot)) {
            [void]$profileTerminalRoots.Add($terminalRoot)
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($env:SystemDrive)) {
        $usersRoot = Join-Path $env:SystemDrive "Users"
        if (Test-Path -LiteralPath $usersRoot) {
            $profiles = Get-ChildItem -LiteralPath $usersRoot -Directory -ErrorAction SilentlyContinue
            foreach ($profile in $profiles) {
                $terminalRoot = Join-Path $profile.FullName "AppData\Roaming\MetaQuotes\Terminal"
                if (Test-Path -LiteralPath $terminalRoot) {
                    [void]$profileTerminalRoots.Add($terminalRoot)
                }
            }
        }
    }

    foreach ($terminalRoot in @($profileTerminalRoots | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $terminalRoot)) {
            continue
        }

        $resolvedTerminalRoot = (Resolve-Path -LiteralPath $terminalRoot).Path
        if ($currentTerminalRoot -and
            [string]::Equals($resolvedTerminalRoot, $currentTerminalRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        $dirs = Get-ChildItem -LiteralPath $resolvedTerminalRoot -Directory -ErrorAction SilentlyContinue
        foreach ($dir in $dirs) {
            $includePath = Join-Path $dir.FullName "MQL5\Include"
            $originPath = Join-Path $dir.FullName "origin.txt"
            if (-not (Test-Path -LiteralPath $includePath) -or -not (Test-Path -LiteralPath $originPath)) {
                continue
            }

            try {
                $originRoot = [System.IO.Path]::GetFullPath(
                    (Get-Content -LiteralPath $originPath -Raw -ErrorAction Stop).Trim()
                ).TrimEnd("\")
            }
            catch {
                continue
            }

            if ([string]::Equals($originRoot, $metaEditorRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                [void]$targets.Add((Resolve-Path -LiteralPath $includePath).Path)
            }
        }
    }

    $unique = $targets | Select-Object -Unique
    return @($unique)
}

function Test-IncludeTargetOwnedByTerminalRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$IncludeTarget,
        [Parameter(Mandatory = $true)]
        [string]$TerminalRoot
    )

    $target = [System.IO.Path]::GetFullPath($IncludeTarget).TrimEnd("\")
    $root = [System.IO.Path]::GetFullPath($TerminalRoot).TrimEnd("\")
    if ($target.StartsWith($root + "\", [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    $mql5Root = Split-Path -Parent $target
    $dataRoot = Split-Path -Parent $mql5Root
    $originPath = Join-Path $dataRoot "origin.txt"
    if (-not (Test-Path -LiteralPath $originPath)) {
        return $false
    }
    try {
        $origin = [System.IO.Path]::GetFullPath(
            (Get-Content -LiteralPath $originPath -Raw -ErrorAction Stop).Trim()
        ).TrimEnd("\")
        return [string]::Equals(
            $origin,
            $root,
            [System.StringComparison]::OrdinalIgnoreCase
        )
    }
    catch {
        return $false
    }
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

    $mq5Files = @(Get-ChildItem -LiteralPath $targetPath -Filter "*.mq5" -File)
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

function Resolve-EAPathFromLabel {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,
        [Parameter(Mandatory = $true)]
        [string]$ResolvedRepoRoot
    )

    $candidate = Join-Path $ResolvedRepoRoot "framework\EAs\$Label"
    if (Test-Path -LiteralPath $candidate) {
        return (Resolve-Path -LiteralPath $candidate).Path
    }

    throw "EALabel '$Label' does not resolve under framework\EAs."
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

if (-not $EAPath) {
    if (-not $EALabel) {
        throw "Provide -EAPath or -EALabel."
    }
    $EAPath = Resolve-EAPathFromLabel -Label $EALabel -ResolvedRepoRoot $repoRoot
}

$mq5Path = Resolve-Mq5Path -InputPath $EAPath
$eaName = [System.IO.Path]::GetFileNameWithoutExtension($mq5Path)
$runTag = (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss")

$claimedTerminalRoot = $null
if ($CompileWorkItemId) {
    if (-not $EALabel -or -not $ClaimedTerminal) {
        throw "COMPILE_EA requires -EALabel, -CompileWorkItemId, and -ClaimedTerminal."
    }
    if ($env:QM_COMPILE_WORK_ITEM_ID -ne $CompileWorkItemId -or
        $env:QM_COMPILE_CLAIMED_TERMINAL -ne $ClaimedTerminal) {
        throw "COMPILE_EA environment binding does not match the claimed work item/terminal. Use the governed pipeline path: python tools/strategy_farm/farmctl.py enqueue-compile <EA label>."
    }
    $claimedTerminalRoot = (Resolve-Path -LiteralPath ("D:\QM\mt5\" + $ClaimedTerminal)).Path
    if (-not $MetaEditorPath) {
        foreach ($candidateName in @("metaeditor64.exe", "metaeditor.exe")) {
            $candidatePath = Join-Path $claimedTerminalRoot $candidateName
            if (Test-Path -LiteralPath $candidatePath) {
                $MetaEditorPath = (Resolve-Path -LiteralPath $candidatePath).Path
                break
            }
        }
        if (-not $MetaEditorPath) {
            throw "COMPILE_EA claimed terminal has no MetaEditor executable: $claimedTerminalRoot"
        }
    }
}

if (-not $MetaEditorPath) {
    $MetaEditorPath = Resolve-DefaultMetaEditorPath
} else {
    $MetaEditorPath = (Resolve-Path -LiteralPath $MetaEditorPath).Path
}

if ($claimedTerminalRoot) {
    $metaEditorRoot = (Resolve-Path -LiteralPath (Split-Path -Parent $MetaEditorPath)).Path.TrimEnd("\")
    if (-not [string]::Equals(
        $metaEditorRoot,
        $claimedTerminalRoot.TrimEnd("\"),
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw "COMPILE_EA MetaEditor must belong to claimed terminal $ClaimedTerminal. expected=$claimedTerminalRoot actual=$metaEditorRoot"
    }
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
$includeDeferredTargets = @()
$includeMirrorEvidence = $null

try {
    $sourceIncludeRoot = Join-Path $repoRoot "framework\include"
    $allIncludeTargets = @(Resolve-TerminalIncludeTargets -MetaEditorPath $MetaEditorPath)
    if ($claimedTerminalRoot) {
        $includeTargets = @(
            $allIncludeTargets | Where-Object {
                Test-IncludeTargetOwnedByTerminalRoot `
                    -IncludeTarget $_ `
                    -TerminalRoot $claimedTerminalRoot
            }
        )
        $includeDeferredTargets = @(
            $allIncludeTargets | Where-Object { $includeTargets -notcontains $_ }
        )
    }
    else {
        $includeTargets = $allIncludeTargets
    }
    if ($includeTargets.Count -eq 0) {
        $reasonClass = "INCLUDE_TARGETS_EMPTY"
        throw "No include target belongs to the claimed/quiescent terminal."
    }

    $mirrorHelper = Join-Path $repoRoot "tools\strategy_farm\include_mirror.py"
    $mirrorArgs = @(
        $mirrorHelper,
        "mirror",
        "--source", $sourceIncludeRoot
    )
    foreach ($includeTarget in $includeTargets) {
        $mirrorArgs += @("--target", $includeTarget)
    }
    if ($CompileWorkItemId) {
        $mirrorArgs += @(
            "--pipeline-work-item-id", $CompileWorkItemId,
            "--claimed-terminal", $ClaimedTerminal
        )
    }
    $savedErrorActionPreference = $ErrorActionPreference
    try {
        # Preserve the helper's structured failure class on Windows PowerShell;
        # otherwise native stderr becomes a terminating NativeCommandError.
        $ErrorActionPreference = "Continue"
        $mirrorOutput = @(& python @mirrorArgs 2>&1)
        $mirrorExit = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $savedErrorActionPreference
    }
    if ($mirrorExit -ne 0) {
        $reasonClass = "INCLUDE_MIRROR_REFUSED"
        throw "Include mirror refused without retry: $($mirrorOutput -join ' ')"
    }
    try {
        $includeMirrorEvidence = $mirrorOutput[-1] | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        $reasonClass = "INCLUDE_MIRROR_EVIDENCE_INVALID"
        throw "Include mirror returned invalid evidence: $($mirrorOutput -join ' ')"
    }
    $includeSyncTargets = $includeTargets

    while ($true) {
        # FORCE-REBUILD (2026-07-12): MetaEditor /compile skips the build silently when the
        # target .ex5 already exists (it does NOT check include mtimes) — it even touches the
        # file mtime and reports success. Every framework-include fix rollout ("recompile all
        # EAs") was therefore a farm-wide NO-OP for EAs whose .mq5 was unchanged. Deleting the
        # target first forces a true rebuild. Evidence: docs/ops/evidence/, DXZ-23 verify sweep.
        if (Test-Path -LiteralPath $ex5Path) {
            Remove-Item -LiteralPath $ex5Path -Force
        }

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
        if ($errorCount -gt 0 -and $includeRootFromLog) {
            $includeSyncRoot = $includeRootFromLog
            if ($includeTargets -notcontains $includeRootFromLog) {
                $reasonClass = "INCLUDE_TARGET_NOT_CLAIMED"
                throw "MetaEditor requested an include target outside claimed terminal $ClaimedTerminal; target is deferred, not mirrored or retried: $includeRootFromLog"
            }
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

    # The structured receipt is emitted from finally and is the authoritative
    # worker contract. Do not let this diagnostic terminate the output stream
    # before those fields are written for the parent build check.
    Write-Error $_ -ErrorAction Continue
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
        include_sync_deferred_targets = ($includeDeferredTargets -join ";")
        include_mirror_mutex = "D:\QM\strategy_farm\state\locks\include_mirror.lock"
        include_mirror_atomic_replace = if ($includeMirrorEvidence) { [bool]$includeMirrorEvidence.atomic_replace } else { $false }
        compile_work_item_id = $CompileWorkItemId
        claimed_terminal = $ClaimedTerminal
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
    Write-Output ("compile_one.include_sync_deferred_targets=" + ($includeDeferredTargets -join ";"))
    Write-Output "compile_one.include_mirror_mutex=D:\QM\strategy_farm\state\locks\include_mirror.lock"
    Write-Output ("compile_one.include_mirror_atomic_replace=" + $(if ($includeMirrorEvidence) { [bool]$includeMirrorEvidence.atomic_replace } else { $false }))
    Write-Output "compile_one.compile_work_item_id=$CompileWorkItemId"
    Write-Output "compile_one.claimed_terminal=$ClaimedTerminal"
    Write-Output "compile_one.log=$compileLogPath"
    Write-Output "compile_one.summary=$summaryCsvPath"
    Write-Output "compile_one.ex5=$ex5Path"
}

if ($result -ne "PASS") {
    exit 1
}

exit 0
