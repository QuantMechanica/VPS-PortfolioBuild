[CmdletBinding()]
param(
    [switch]$Strict = $true,
    [string]$RepoRoot,
    [string]$CompileScriptPath,
    [string]$ReportRoot = "D:\QM\reports\framework\21",
    [string]$LoggerSamplePath,
    [switch]$SkipCompile,
    [switch]$SkipMagicCheck,
    [switch]$SkipSetValidation,
    [switch]$SkipLoggerSchema,
    [switch]$SkipForbiddenScan,
    [switch]$SkipInputGroupCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:GateFailures = New-Object System.Collections.Generic.List[string]
$script:GateWarnings = New-Object System.Collections.Generic.List[string]
$script:TimestampUtc = (Get-Date).ToUniversalTime().ToString("o")
$script:RunTag = (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss")

function Add-Failure {
    param([Parameter(Mandatory = $true)][string]$Message)
    $script:GateFailures.Add($Message)
    Write-Output "ERROR: $Message"
}

function Add-Warning {
    param([Parameter(Mandatory = $true)][string]$Message)
    $script:GateWarnings.Add($Message)
    Write-Warning $Message
}

function Resolve-RepoRoot {
    if ($RepoRoot) {
        return (Resolve-Path -LiteralPath $RepoRoot).Path
    }

    $resolved = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    return $resolved.Path
}

function Get-CompileCandidates {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResolvedRepoRoot
    )

    $candidates = New-Object System.Collections.Generic.List[string]
    $easRoot = Join-Path $ResolvedRepoRoot "framework\EAs"
    if (Test-Path -LiteralPath $easRoot) {
        $eaFiles = Get-ChildItem -LiteralPath $easRoot -Recurse -File -Filter "*.mq5" | Sort-Object FullName
        foreach ($eaFile in $eaFiles) {
            $candidates.Add($eaFile.FullName)
        }
    }

    # Step 21 must run on the framework skeleton even before EA folders exist.
    if ($candidates.Count -eq 0) {
        $skeletonPath = Join-Path $ResolvedRepoRoot "framework\templates\EA_Skeleton.mq5"
        if (Test-Path -LiteralPath $skeletonPath) {
            $candidates.Add((Resolve-Path -LiteralPath $skeletonPath).Path)
        }
    }

    return $candidates
}

function Parse-CompileOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$OutputLines
    )

    $map = @{}
    foreach ($line in $OutputLines) {
        if ($line -match '^\s*([^=]+)=(.*)$') {
            $key = $Matches[1].Trim()
            $value = $Matches[2].Trim()
            $map[$key] = $value
        }
    }

    return $map
}

function Get-AllowedWarningCodes {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Mq5Path
    )

    $dir = Split-Path -Parent $Mq5Path
    $allowPath = Join-Path $dir ".compile-warnings-allowed"
    if (-not (Test-Path -LiteralPath $allowPath)) {
        return @{
            codes = @()
            path = $allowPath
            exists = $false
        }
    }

    $codes = New-Object System.Collections.Generic.List[int]
    $lines = Get-Content -LiteralPath $allowPath
    foreach ($rawLine in $lines) {
        $line = $rawLine.Trim()
        if (-not $line -or $line.StartsWith("#")) {
            continue
        }

        if ($line -notmatch '^\d+$') {
            Add-Failure "BUILD_CHECK_ALLOWLIST_FORMAT_INVALID: $allowPath has non-numeric warning code '$line'."
            continue
        }

        $codes.Add([int]$line)
    }

    return @{
        codes = $codes.ToArray()
        path = $allowPath
        exists = $true
    }
}

function Get-WarningCodesFromCompileLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CompileLogPath
    )

    if (-not (Test-Path -LiteralPath $CompileLogPath)) {
        return @()
    }

    $logContent = Get-Content -Raw -LiteralPath $CompileLogPath
    $matches = [regex]::Matches($logContent, '(?im)\bwarning\s+(?<code>\d+)\b')
    $codes = New-Object System.Collections.Generic.List[int]
    foreach ($m in $matches) {
        $codes.Add([int]$m.Groups["code"].Value)
    }
    return $codes.ToArray()
}

function Invoke-CompileGate {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResolvedRepoRoot,
        [Parameter(Mandatory = $true)]
        [string]$ResolvedCompileScriptPath
    )

    $targets = @(Get-CompileCandidates -ResolvedRepoRoot $ResolvedRepoRoot)
    if ($targets.Count -eq 0) {
        Add-Failure "BUILD_CHECK_COMPILE_TARGETS_EMPTY: No .mq5 files found in framework/EAs or framework/templates/EA_Skeleton.mq5."
        return
    }

    foreach ($target in $targets) {
        Write-Output "build_check.compile.target=$target"
        $outputLines = & $ResolvedCompileScriptPath -EAPath $target 2>&1
        $compileExit = $LASTEXITCODE
        foreach ($line in $outputLines) {
            Write-Output $line
        }

        $outputMap = Parse-CompileOutput -OutputLines $outputLines
        $summaryPath = $null
        if ($outputMap.ContainsKey("compile_one.summary")) {
            $summaryPath = $outputMap["compile_one.summary"]
        }

        $errors = 0
        $warnings = 0
        $compileLogPath = $null
        $reasonClass = "UNKNOWN"
        if ($summaryPath -and (Test-Path -LiteralPath $summaryPath)) {
            $rows = @(Import-Csv -LiteralPath $summaryPath)
            if ($rows.Count -gt 0) {
                $row = $rows[-1]
                $errors = [int]$row.errors
                $warnings = [int]$row.warnings
                $compileLogPath = $row.compile_log_path
                $reasonClass = [string]$row.reason_class
            }
        } else {
            Add-Failure "BUILD_CHECK_COMPILE_SUMMARY_MISSING: compile_one did not emit a readable summary for $target."
        }

        if ($compileExit -ne 0 -or $errors -gt 0) {
            Add-Failure "BUILD_CHECK_COMPILE_FAILED: $target failed compile. reason=$reasonClass errors=$errors warnings=$warnings."
            continue
        }

        if ($Strict.IsPresent -and $warnings -gt 0) {
            $allow = Get-AllowedWarningCodes -Mq5Path $target
            $allowedSet = @{}
            foreach ($code in $allow.codes) {
                $allowedSet[[int]$code] = $true
            }

            $seenCodes = Get-WarningCodesFromCompileLog -CompileLogPath $compileLogPath
            $unexpected = New-Object System.Collections.Generic.List[int]
            foreach ($code in $seenCodes) {
                if (-not $allowedSet.ContainsKey([int]$code)) {
                    $unexpected.Add([int]$code)
                }
            }

            if ($allow.exists -and $unexpected.Count -eq 0) {
                Add-Warning "BUILD_CHECK_WARNINGS_WAIVED: $target has $warnings warning(s) allowed by $($allow.path). CEO+CTO sign-off is required by V5 policy."
            } elseif ($allow.exists -and $unexpected.Count -gt 0) {
                $codesText = ($unexpected | Select-Object -Unique | Sort-Object | ForEach-Object { $_.ToString() }) -join ","
                Add-Failure "BUILD_CHECK_STRICT_WARNINGS: $target has non-allowlisted warning codes: $codesText."
            } elseif (-not $allow.exists) {
                Add-Failure "BUILD_CHECK_STRICT_WARNINGS: $target has $warnings warning(s) and no .compile-warnings-allowed file."
            }
        }
    }
}

function Invoke-MagicCollisionCheck {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResolvedRepoRoot
    )

    $registryPath = Join-Path $ResolvedRepoRoot "framework\registry\magic_numbers.csv"
    if (-not (Test-Path -LiteralPath $registryPath)) {
        Add-Failure "BUILD_CHECK_MAGIC_REGISTRY_MISSING: $registryPath."
        return
    }

    $rows = @(Import-Csv -LiteralPath $registryPath)
    if (-not $rows -or $rows.Count -eq 0) {
        Add-Failure "BUILD_CHECK_MAGIC_REGISTRY_EMPTY: $registryPath contains no rows."
        return
    }

    $magicToRows = @{}
    $slotToRows = @{}
    foreach ($row in $rows) {
        $status = ([string]$row.status).Trim().ToLowerInvariant()
        if ($status -eq "retired") {
            continue
        }

        if ($row.ea_id -notmatch '^\d+$' -or $row.symbol_slot -notmatch '^\d+$' -or $row.magic -notmatch '^\d+$') {
            Add-Failure "BUILD_CHECK_MAGIC_REGISTRY_INVALID_NUMERIC: row ea_id=$($row.ea_id) symbol_slot=$($row.symbol_slot) magic=$($row.magic)."
            continue
        }

        $eaId = [int]$row.ea_id
        $symbolSlot = [int]$row.symbol_slot
        $magic = [int64]$row.magic
        $expectedMagic = ([int64]$eaId * 10000) + [int64]$symbolSlot
        if ($expectedMagic -ne $magic) {
            Add-Failure "BUILD_CHECK_MAGIC_FORMULA_VIOLATION: ea_id=$eaId symbol_slot=$symbolSlot magic=$magic expected=$expectedMagic."
        }

        $symbol = ([string]$row.symbol).Trim()
        if ($symbol -and -not $symbol.EndsWith(".DWX")) {
            Add-Failure "BUILD_CHECK_SYMBOL_SUFFIX_VIOLATION: '$symbol' must use .DWX in registry/backtest context."
        }

        if (-not $magicToRows.ContainsKey($magic)) {
            $magicToRows[$magic] = New-Object System.Collections.Generic.List[string]
        }
        $magicToRows[$magic].Add("$($row.ea_slug)#$status")

        $slotKey = "$eaId`:$symbolSlot"
        if (-not $slotToRows.ContainsKey($slotKey)) {
            $slotToRows[$slotKey] = New-Object System.Collections.Generic.List[string]
        }
        $slotToRows[$slotKey].Add("$($row.ea_slug)#$status")
    }

    foreach ($magicKey in $magicToRows.Keys) {
        if ($magicToRows[$magicKey].Count -gt 1) {
            $owners = ($magicToRows[$magicKey].ToArray()) -join ";"
            Add-Failure "BUILD_CHECK_MAGIC_COLLISION: magic=$magicKey owners=$owners."
        }
    }

    foreach ($slotKey in $slotToRows.Keys) {
        if ($slotToRows[$slotKey].Count -gt 1) {
            $owners = ($slotToRows[$slotKey].ToArray()) -join ";"
            Add-Failure "BUILD_CHECK_SLOT_COLLISION: ea_id:symbol_slot=$slotKey owners=$owners."
        }
    }
}

function Update-SetFileBuildHash {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SetFilePath
    )

    $lines = Get-Content -LiteralPath $SetFilePath
    $hashLineIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*;\s*build_hash\s*:') {
            $hashLineIdx = $i
            break
        }
    }

    if ($hashLineIdx -lt 0) {
        Add-Failure "BUILD_CHECK_SETFILE_HEADER_MISSING_BUILD_HASH: $SetFilePath."
        return
    }

    $normalized = ($lines -join "`r`n") + "`r`n"
    $hash = [System.BitConverter]::ToString(
        [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($normalized))
    ).Replace("-", "").ToLowerInvariant()

    $lines[$hashLineIdx] = "; build_hash:   $hash"
    Set-Content -LiteralPath $SetFilePath -Value $lines -Encoding utf8
}

function Invoke-SetValidation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResolvedRepoRoot
    )

    $setFiles = @()
    $easRoot = Join-Path $ResolvedRepoRoot "framework\EAs"
    if (Test-Path -LiteralPath $easRoot) {
        $setFiles = @(Get-ChildItem -LiteralPath $easRoot -Recurse -File -Filter "*.set" | Sort-Object FullName)
    }
    if (-not $setFiles -or $setFiles.Count -eq 0) {
        Add-Warning "BUILD_CHECK_SETFILE_NONE_FOUND: no .set files found."
        return
    }

    $requiredHeaderKeys = @(
        "ea_id",
        "ea_slug",
        "ea_version",
        "set_version",
        "symbol",
        "timeframe",
        "environment",
        "magic_slot",
        "risk_mode",
        "portfolio_weight",
        "build_hash",
        "author",
        "date"
    )

    foreach ($setFile in $setFiles) {
        $lines = Get-Content -LiteralPath $setFile.FullName
        $headerMap = @{}
        foreach ($line in $lines) {
            if ($line -match '^\s*;\s*(?<key>[a-zA-Z0-9_]+)\s*:\s*(?<value>.*)$') {
                $key = $Matches["key"].Trim().ToLowerInvariant()
                $value = $Matches["value"].Trim()
                $headerMap[$key] = $value
            } elseif ($line -notmatch '^\s*;') {
                break
            }
        }

        foreach ($requiredKey in $requiredHeaderKeys) {
            if (-not $headerMap.ContainsKey($requiredKey) -or -not $headerMap[$requiredKey]) {
                Add-Failure "BUILD_CHECK_SETFILE_HEADER_INCOMPLETE: $($setFile.FullName) missing '$requiredKey'."
            }
        }

        Update-SetFileBuildHash -SetFilePath $setFile.FullName
    }
}

function ConvertFrom-JsonSafe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Line,
        [Parameter(Mandatory = $true)]
        [string]$PathForError,
        [Parameter(Mandatory = $true)]
        [int]$LineNumber
    )

    try {
        return $Line | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Add-Failure "BUILD_CHECK_LOGGER_JSON_INVALID: $PathForError line $LineNumber is not valid JSON."
        return $null
    }
}

function Validate-LoggerRecord {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Record,
        [Parameter(Mandatory = $true)]
        [string]$PathForError,
        [Parameter(Mandatory = $true)]
        [int]$LineNumber
    )

    $requiredFields = @("ts_utc", "ts_broker", "level", "ea_id", "slug", "symbol", "tf", "magic", "event", "payload")
    foreach ($field in $requiredFields) {
        if (-not ($Record.PSObject.Properties.Name -contains $field)) {
            Add-Failure "BUILD_CHECK_LOGGER_SCHEMA_MISSING_FIELD: $PathForError line $LineNumber missing '$field'."
        }
    }

    if ($Record.PSObject.Properties.Name -contains "level") {
        $allowedLevels = @("TRACE", "INFO", "WARN", "ERROR", "FATAL")
        if ($allowedLevels -notcontains [string]$Record.level) {
            Add-Failure "BUILD_CHECK_LOGGER_SCHEMA_LEVEL_INVALID: $PathForError line $LineNumber level=$($Record.level)."
        }
    }

    if ($Record.PSObject.Properties.Name -contains "ts_utc") {
        $ignored = [System.DateTimeOffset]::MinValue
        if (-not [System.DateTimeOffset]::TryParse([string]$Record.ts_utc, [ref]$ignored)) {
            Add-Failure "BUILD_CHECK_LOGGER_SCHEMA_TS_UTC_INVALID: $PathForError line $LineNumber ts_utc=$($Record.ts_utc)."
        }
    }

    if ($Record.PSObject.Properties.Name -contains "payload") {
        if ($null -eq $Record.payload) {
            Add-Failure "BUILD_CHECK_LOGGER_SCHEMA_PAYLOAD_NULL: $PathForError line $LineNumber."
        }
    }
}

function Invoke-LoggerSchemaValidation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResolvedRepoRoot,
        [string]$SamplePath
    )

    $effectivePath = $null
    $lines = @()

    if ($SamplePath) {
        if (-not (Test-Path -LiteralPath $SamplePath)) {
            Add-Failure "BUILD_CHECK_LOGGER_SAMPLE_MISSING: $SamplePath."
            return
        }
        $effectivePath = (Resolve-Path -LiteralPath $SamplePath).Path
        $lines = Get-Content -LiteralPath $effectivePath
    } else {
        $candidate = Get-ChildItem -LiteralPath $ResolvedRepoRoot -Recurse -File -Filter "*.jsonl" |
            Where-Object { $_.FullName -match '(?i)log|logger|smoke' } |
            Select-Object -First 1

        if ($candidate) {
            $effectivePath = $candidate.FullName
            $lines = Get-Content -LiteralPath $effectivePath
        } else {
            $effectivePath = "<embedded-sample>"
            $lines = @(
                '{"ts_utc":"2026-04-26T14:23:01.234Z","ts_broker":"2026-04-26T16:23:01","level":"INFO","ea_id":1001,"slug":"build-check-sample","symbol":"EURUSD.DWX","tf":"H1","magic":10010000,"event":"ENTRY","payload":{"side":"BUY","lot":0.12}}'
            )
            Add-Warning "BUILD_CHECK_LOGGER_SAMPLE_FALLBACK: no .jsonl sample found; validating embedded schema sample."
        }
    }

    if (-not $lines -or $lines.Count -eq 0) {
        Add-Failure "BUILD_CHECK_LOGGER_SAMPLE_EMPTY: $effectivePath has no lines."
        return
    }

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].Trim()
        if (-not $line) {
            continue
        }

        $record = ConvertFrom-JsonSafe -Line $line -PathForError $effectivePath -LineNumber ($i + 1)
        if ($null -ne $record) {
            Validate-LoggerRecord -Record $record -PathForError $effectivePath -LineNumber ($i + 1)
        }
    }
}

function Invoke-ForbiddenScan {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResolvedRepoRoot
    )

    $scanRoots = @(
        (Join-Path $ResolvedRepoRoot "framework\include"),
        (Join-Path $ResolvedRepoRoot "framework\templates"),
        (Join-Path $ResolvedRepoRoot "framework\tests"),
        (Join-Path $ResolvedRepoRoot "framework\EAs")
    ) | Where-Object { Test-Path -LiteralPath $_ }

    $mqlFiles = New-Object System.Collections.Generic.List[string]
    foreach ($scanRoot in $scanRoots) {
        $files = Get-ChildItem -LiteralPath $scanRoot -Recurse -File -Include *.mq5,*.mqh
        foreach ($f in $files) {
            $mqlFiles.Add($f.FullName)
        }
    }

    if ($mqlFiles.Count -eq 0) {
        Add-Warning "BUILD_CHECK_FORBIDDEN_SCAN_EMPTY: no framework MQL files found."
        return
    }

    $mlPattern = '(?i)\b(tensorflow|torch|pytorch|sklearn|keras|onnx|xgboost|lightgbm|catboost|mlpack|dlib)\b|\.onnx\b|\.pb\b|\.pt\b|\.pth\b'
    $externalPattern = '(?i)\bWebRequest\s*\(|https?://'

    $mlHits = Select-String -Path $mqlFiles.ToArray() -Pattern $mlPattern
    foreach ($hit in $mlHits) {
        Add-Failure "EA_ML_FORBIDDEN: $($hit.Path):$($hit.LineNumber) contains '$($hit.Matches[0].Value)'."
    }

    $externalHits = Select-String -Path $mqlFiles.ToArray() -Pattern $externalPattern
    foreach ($hit in $externalHits) {
        Add-Failure "BUILD_CHECK_EXTERNAL_DATA_API_FORBIDDEN: $($hit.Path):$($hit.LineNumber) contains '$($hit.Matches[0].Value)'. Darwinex MT5 native data only."
    }
}

function Invoke-InputGroupCheck {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResolvedRepoRoot
    )

    $eaRoot = Join-Path $ResolvedRepoRoot "framework\EAs"
    if (-not (Test-Path -LiteralPath $eaRoot)) {
        return
    }

    $eaFiles = Get-ChildItem -LiteralPath $eaRoot -Recurse -File -Include *.mq5 -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -notmatch 'smoke|unit|test' }

    $requiredGroups = @(
        'QuantMechanica V5 Framework',
        'Risk',
        'News',
        'Friday Close',
        'Strategy'
    )

    foreach ($file in $eaFiles) {
        $content = Get-Content -Raw -Path $file.FullName -ErrorAction SilentlyContinue
        if (-not $content) { continue }

        foreach ($group in $requiredGroups) {
            $pattern = [regex]::Escape("input group `"$group`"")
            if ($content -notmatch $pattern) {
                Add-Failure "EA_INPUT_GROUP_MISSING: $($file.Name) is missing required input group `"$group`"."
            }
        }
    }
}

function Write-GateEvidence {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResolvedReportRoot
    )

    New-Item -ItemType Directory -Path $ResolvedReportRoot -Force | Out-Null
    $reportPath = Join-Path $ResolvedReportRoot "build_check_$script:RunTag.json"
    $payload = [pscustomobject]@{
        run_tag = $script:RunTag
        timestamp_utc = $script:TimestampUtc
        strict = [bool]$Strict.IsPresent
        failures = $script:GateFailures
        warnings = $script:GateWarnings
        status = if ($script:GateFailures.Count -eq 0) { "PASS" } else { "FAIL" }
    }
    $json = $payload | ConvertTo-Json -Depth 8
    Set-Content -LiteralPath $reportPath -Value $json -Encoding utf8
    Write-Output "build_check.report=$reportPath"
}

$resolvedRepoRoot = Resolve-RepoRoot
if (-not $CompileScriptPath) {
    $CompileScriptPath = Join-Path $resolvedRepoRoot "framework\scripts\compile_one.ps1"
}
$resolvedCompileScriptPath = $null
if (-not $SkipCompile.IsPresent) {
    if (-not (Test-Path -LiteralPath $CompileScriptPath)) {
        Add-Failure "BUILD_CHECK_COMPILE_SCRIPT_MISSING: $CompileScriptPath."
    } else {
        $resolvedCompileScriptPath = (Resolve-Path -LiteralPath $CompileScriptPath).Path
    }
}

if (-not $SkipCompile.IsPresent -and $resolvedCompileScriptPath) {
    Invoke-CompileGate -ResolvedRepoRoot $resolvedRepoRoot -ResolvedCompileScriptPath $resolvedCompileScriptPath
}
if (-not $SkipMagicCheck.IsPresent) {
    Invoke-MagicCollisionCheck -ResolvedRepoRoot $resolvedRepoRoot
}
if (-not $SkipSetValidation.IsPresent) {
    Invoke-SetValidation -ResolvedRepoRoot $resolvedRepoRoot
}
if (-not $SkipLoggerSchema.IsPresent) {
    Invoke-LoggerSchemaValidation -ResolvedRepoRoot $resolvedRepoRoot -SamplePath $LoggerSamplePath
}
if (-not $SkipForbiddenScan.IsPresent) {
    Invoke-ForbiddenScan -ResolvedRepoRoot $resolvedRepoRoot
}
if (-not $SkipInputGroupCheck.IsPresent) {
    Invoke-InputGroupCheck -ResolvedRepoRoot $resolvedRepoRoot
}

Write-GateEvidence -ResolvedReportRoot $ReportRoot

if ($script:GateFailures.Count -gt 0) {
    Write-Output "build_check.result=FAIL"
    Write-Output "build_check.failures=$($script:GateFailures.Count)"
    Write-Output "build_check.warnings=$($script:GateWarnings.Count)"
    exit 1
}

Write-Output "build_check.result=PASS"
Write-Output "build_check.failures=0"
Write-Output "build_check.warnings=$($script:GateWarnings.Count)"
exit 0
