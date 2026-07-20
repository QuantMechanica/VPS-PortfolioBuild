Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-QmSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required file is missing: $Path"
    }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
}

function Get-QmFileBinding {
    param([Parameter(Mandatory = $true)][string]$Path)
    $resolved = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path)
    $item = Get-Item -LiteralPath $resolved -Force -ErrorAction Stop
    if ($item.PSIsContainer) { throw "File binding target is a directory: $resolved" }
    return [ordered]@{
        path = $resolved
        size = [int64]$item.Length
        sha256 = Get-QmSha256 -Path $resolved
    }
}

function Test-QmPathWithin {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root,
        [switch]$AllowRoot
    )
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    if ($AllowRoot -and $fullPath.Equals($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }
    return $fullPath.StartsWith(
        $fullRoot + [System.IO.Path]::DirectorySeparatorChar,
        [System.StringComparison]::OrdinalIgnoreCase
    )
}

function Get-QmStrictIntegerField {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Map,
        [Parameter(Mandatory = $true)][string]$Name,
        [int64]$Minimum = 0
    )
    if (-not $Map.Contains($Name)) { throw "Missing integer field: $Name" }
    $value = $Map[$Name]
    $isInteger = (
        $value -is [byte] -or $value -is [sbyte] -or
        $value -is [int16] -or $value -is [uint16] -or
        $value -is [int32] -or $value -is [uint32] -or
        $value -is [int64] -or $value -is [uint64]
    )
    if (-not $isInteger) { throw "Integer field $Name is not an integer" }
    try { $parsed = [int64]$value } catch { throw "Integer field $Name is out of range" }
    if ($parsed -lt $Minimum) { throw "Integer field $Name is below $Minimum" }
    return $parsed
}

function Test-QmSamePath {
    param(
        [Parameter(Mandatory = $true)][string]$First,
        [Parameter(Mandatory = $true)][string]$Second
    )
    return [System.IO.Path]::GetFullPath($First).Equals(
        [System.IO.Path]::GetFullPath($Second),
        [System.StringComparison]::OrdinalIgnoreCase
    )
}

function Get-QmAttemptArtifactBinding {
    param([Parameter(Mandatory = $true)][string]$Path)
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if ($item.PSIsContainer -or
        [bool]($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
        throw "Attempt artifact is not a regular file: $Path"
    }
    return Get-QmFileBinding -Path $item.FullName
}

function Get-QmResearchContract {
    param(
        [Parameter(Mandatory = $true)][string]$Phase,
        [Parameter(Mandatory = $true)][string]$Symbol,
        [Parameter(Mandatory = $true)][string]$Timeframe,
        [Parameter(Mandatory = $true)][string]$Variant,
        [Parameter(Mandatory = $true)][string]$FromDate,
        [Parameter(Mandatory = $true)][string]$ToDate,
        [Parameter(Mandatory = $true)][int]$Runs
    )
    $markets = @{
        'NDX.DWX'    = [ordered]@{ timeframe = 'M1'; kind = 'index'; dev_from = '2021-01-01'; dev_to = '2022-12-31' }
        'GDAXI.DWX'  = [ordered]@{ timeframe = 'M1'; kind = 'index'; dev_from = '2021-01-01'; dev_to = '2022-12-31' }
        'GBPUSD.DWX' = [ordered]@{ timeframe = 'M5'; kind = 'fx'; dev_from = '2017-10-01'; dev_to = '2022-12-31' }
        'EURUSD.DWX' = [ordered]@{ timeframe = 'M5'; kind = 'fx'; dev_from = '2017-10-01'; dev_to = '2022-12-31' }
    }
    if (-not $markets.ContainsKey($Symbol)) { throw "Unsupported EA20009 research symbol: $Symbol" }
    $market = $markets[$Symbol]
    if ($Timeframe -cne [string]$market.timeframe) {
        throw "Timeframe contract mismatch: $Timeframe != $($market.timeframe)"
    }

    $windows = @{
        'OOS_2023_H1' = @('2023-01-01', '2023-06-30')
        'OOS_2023_H2' = @('2023-07-01', '2023-12-31')
        'OOS_2024_H1' = @('2024-01-01', '2024-06-30')
        'OOS_2024_H2' = @('2024-07-01', '2024-12-31')
        'OOS_2025_H1' = @('2025-01-01', '2025-06-30')
        'OOS_2025_H2' = @('2025-07-01', '2025-12-31')
        'RETRO_HOLDOUT_2026_H1' = @('2026-01-01', '2026-06-30')
    }
    $binding = $true
    $requiresResolvedCosts = $false
    if ($Phase -ceq 'DEV') {
        $expectedFrom = [string]$market.dev_from
        $expectedTo = [string]$market.dev_to
    } elseif ($Phase -ceq 'DEV_SMOKE_2022') {
        $binding = $false
        if ($Symbol -notin @('NDX.DWX', 'GBPUSD.DWX', 'EURUSD.DWX')) {
            throw "DEV_SMOKE_2022 only permits NDX.DWX, GBPUSD.DWX and EURUSD.DWX"
        }
        $expectedFrom = '2022-01-01'
        $expectedTo = '2022-12-31'
    } elseif ($windows.ContainsKey($Phase)) {
        $expectedFrom = [string]$windows[$Phase][0]
        $expectedTo = [string]$windows[$Phase][1]
        $requiresResolvedCosts = $true
    } else {
        throw "Unsupported or non-tester EA20009 phase: $Phase"
    }
    if ($FromDate -cne $expectedFrom -or $ToDate -cne $expectedTo) {
        throw "Phase window mismatch: $FromDate..$ToDate != $expectedFrom..$expectedTo"
    }
    $variants = @(
        'center', 'pivot_low', 'pivot_high', 'reclaim_low', 'reclaim_high',
        'mss_low', 'mss_high', 'fvg_low', 'fvg_high', 'stop_low', 'stop_high',
        'rr_low', 'rr_high'
    )
    if ($Variant -notin $variants) { throw "Unknown preregistered variant: $Variant" }
    if ($Phase -cne 'DEV' -and $Variant -cne 'center') {
        throw "$Phase is CENTER_ONLY"
    }
    if ($binding -and $Runs -ne 2) { throw "Binding $Phase requires exactly two runs" }
    if (-not $binding -and $Runs -ne 1) {
        throw "DEV_SMOKE_2022 requires exactly one non-binding infrastructure run"
    }
    return [ordered]@{
        phase = $Phase
        symbol = $Symbol
        timeframe = $Timeframe
        kind = [string]$market.kind
        variant = $Variant
        from = $expectedFrom
        to = $expectedTo
        runs = $Runs
        binding = $binding
        infrastructure_only = (-not $binding)
        requires_resolved_cost_axes = $requiresResolvedCosts
    }
}

function Read-QmSetInputs {
    param([Parameter(Mandatory = $true)][string]$Path)
    $inputs = [ordered]@{}
    foreach ($line in Get-Content -LiteralPath $Path -Encoding ascii -ErrorAction Stop) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith(';') -or -not $line.Contains('=')) {
            continue
        }
        $parts = $line.Split('=', 2)
        $key = $parts[0]
        if ($key -notmatch '^[A-Za-z_][A-Za-z0-9_]*$' -or $inputs.Contains($key)) {
            throw "Invalid or duplicate input assignment in set: $key"
        }
        $inputs[$key] = $parts[1]
    }
    if ($inputs.Count -ne 35) { throw "Frozen set must contain exactly 35 visible inputs, found $($inputs.Count)" }
    if (-not $inputs.Contains('InpQMSimCommissionPerLot')) {
        throw 'Frozen set lacks InpQMSimCommissionPerLot'
    }
    $simulated = [decimal]::Zero
    if (-not [decimal]::TryParse(
        [string]$inputs['InpQMSimCommissionPerLot'],
        [System.Globalization.NumberStyles]::Float,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [ref]$simulated
    ) -or $simulated -ne [decimal]::Zero) {
        throw 'Frozen set must keep InpQMSimCommissionPerLot exactly zero'
    }
    return $inputs
}

function ConvertTo-QmComparableInputValue {
    param([AllowEmptyString()][string]$Value)
    $trimmed = $Value.Trim()
    if ($trimmed -match '^(?i:true|false)$') { return $trimmed.ToLowerInvariant() }
    $number = [decimal]::Zero
    if ([decimal]::TryParse(
        $trimmed,
        [System.Globalization.NumberStyles]::Float,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [ref]$number
    )) {
        return $number.ToString('G29', [System.Globalization.CultureInfo]::InvariantCulture)
    }
    return $trimmed
}

function Assert-QmInputMapMatchesSet {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Actual,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Expected
    )
    if ($Actual.Count -ne $Expected.Count) {
        throw "Report/set input count drift: $($Actual.Count) != $($Expected.Count)"
    }
    foreach ($key in $Expected.Keys) {
        if (-not $Actual.Contains($key)) { throw "Report lacks frozen set input: $key" }
        $actualValue = ConvertTo-QmComparableInputValue -Value ([string]$Actual[$key])
        $expectedValue = ConvertTo-QmComparableInputValue -Value ([string]$Expected[$key])
        if ($actualValue -cne $expectedValue) {
            throw "Report/set input drift for ${key}: $actualValue != $expectedValue"
        }
    }
}

function Assert-QmResearchSummary {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Summary,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Contract
    )
    $expectedExpert = 'QM\QM5_20009_ict-liquidity-portfolio'
    $exact = @{
        result = 'PASS'; ea_id = 20009; expert = $expectedExpert
        symbol = [string]$Contract.symbol; terminal = 'DEV1'; model = 4
        period = [string]$Contract.timeframe; requested_runs = [int]$Contract.runs
        min_trades_required = 0
    }
    foreach ($key in $exact.Keys) {
        if ([string]$Summary[$key] -cne [string]$exact[$key]) {
            throw "Runner summary contract drift for ${key}: $($Summary[$key]) != $($exact[$key])"
        }
    }
    foreach ($flag in @('deterministic', 'model4_log_marker_detected')) {
        if ($Summary[$flag] -isnot [bool] -or -not [bool]$Summary[$flag]) {
            throw "Runner summary requires ${flag}=true"
        }
    }
    foreach ($flag in @('oninit_failure_detected', 'log_bomb_detected')) {
        if ($Summary[$flag] -isnot [bool] -or [bool]$Summary[$flag]) {
            throw "Runner summary requires ${flag}=false"
        }
    }
    $commission = $Summary['commission_group']
    if ($commission -isnot [System.Collections.IDictionary]) { throw 'Runner summary lacks commission_group' }
    if ([double]$commission['commission_per_lot'] -ne 0.0 -or
        [double]$commission['commission_per_side_native'] -ne 0.0) {
        throw 'Research runner must use zero native tester commission inputs'
    }
    if ($commission['restored_to_canonical'] -isnot [bool] -or -not [bool]$commission['restored_to_canonical']) {
        throw 'Tester Groups were not restored to canonical'
    }
    $hashes = @(
        [string]$commission['injected_sha256'], [string]$commission['canonical_sha256'],
        [string]$commission['restored_sha256']
    )
    if (@($hashes | Where-Object { $_ -cnotmatch '^[0-9a-f]{64}$' }).Count -gt 0 -or
        @($hashes | Select-Object -Unique).Count -ne 1) {
        throw 'Zero-commission Groups hashes are missing or differ from canonical'
    }

    $requestedRuns = Get-QmStrictIntegerField -Map $Summary -Name 'requested_runs' -Minimum 1
    $maxRunAttempts = Get-QmStrictIntegerField -Map $Summary -Name 'max_run_attempts' -Minimum 1
    $attemptedRuns = Get-QmStrictIntegerField -Map $Summary -Name 'attempted_runs' -Minimum 1
    $nonOkAttempts = Get-QmStrictIntegerField -Map $Summary -Name 'non_ok_attempts' -Minimum 0
    $expectedMaximum = [Math]::Min(10, ([int]$requestedRuns + 2))
    if ($maxRunAttempts -ne $expectedMaximum) {
        throw "Runner retry budget drift: $maxRunAttempts != $expectedMaximum"
    }
    if ($attemptedRuns -gt $maxRunAttempts) {
        throw "Runner attempt count exceeds retry budget: $attemptedRuns > $maxRunAttempts"
    }

    $reportDir = [System.IO.Path]::GetFullPath([string]$Summary['report_dir'])
    if (-not (Test-Path -LiteralPath $reportDir -PathType Container)) {
        throw "Runner report directory is missing: $reportDir"
    }
    $rawRoot = [System.IO.Path]::GetFullPath((Join-Path $reportDir 'raw'))
    if (-not (Test-Path -LiteralPath $rawRoot -PathType Container)) {
        throw "Runner raw directory is missing: $rawRoot"
    }
    $runRows = @($Summary['runs'])
    if ($runRows.Count -ne $attemptedRuns) {
        throw "Runner summary/attempted run count drift: $($runRows.Count) != $attemptedRuns"
    }

    $rawChildren = @(Get-ChildItem -LiteralPath $rawRoot -Force -ErrorAction Stop)
    if (@($rawChildren | Where-Object { -not $_.PSIsContainer }).Count -ne 0) {
        throw 'Runner raw root contains unbound files'
    }
    $runDirectories = @($rawChildren | Where-Object { $_.PSIsContainer } | Sort-Object Name)
    if ($runDirectories.Count -ne $attemptedRuns) {
        throw "Runner raw attempt directory count drift: $($runDirectories.Count) != $attemptedRuns"
    }

    $attemptRows = New-Object System.Collections.Generic.List[object]
    $acceptedRunIds = New-Object System.Collections.Generic.List[string]
    $acceptedReports = New-Object System.Collections.Generic.List[string]
    $acceptedTesterInis = New-Object System.Collections.Generic.List[string]
    $acceptedTesterLogs = New-Object System.Collections.Generic.List[string]
    $observedNonOk = 0
    $allowedInvalidFailures = @(
        'ONINIT_FAILED', 'SETUP_DATA_MISSING', 'NO_HISTORY', 'NO_REAL_TICKS',
        'REPORT_EMPTY', 'BARS_ZERO', 'REPORT_FORMAT_DRIFT', 'INVALID_REPORT'
    )
    $allowedFailFailures = @('LOG_BOMB', 'TIMEOUT', 'REPORT_MISSING', 'REPORT_EMPTY')
    $allowedReasonPattern = '^(?:REPORT_EMPTY|EMPTY_EXPERT|EMPTY_SYMBOL|M0_1970_PERIOD|BARS_ZERO|ONINIT_FAILED|SETUP_DATA_MISSING|NO_HISTORY_LOG|HISTORY_CONTEXT_INVALID|NO_REAL_TICKS_MARKER_FAST_FINISH|REPORT_METRIC_(?:MISSING|UNPARSEABLE):[A-Za-z0-9_]+)$'

    for ($index = 0; $index -lt $runRows.Count; $index++) {
        $ordinal = $index + 1
        $expectedRun = 'run_{0:d2}' -f $ordinal
        $run = $runRows[$index]
        if ($run -isnot [System.Collections.IDictionary]) {
            throw "Runner summary attempt $expectedRun is malformed"
        }
        if ([string]$run['run'] -cne $expectedRun) {
            throw "Runner attempt ordinal drift: $($run['run']) != $expectedRun"
        }
        $runDirectory = [System.IO.Path]::GetFullPath((Join-Path $rawRoot $expectedRun))
        $diskDirectory = $runDirectories[$index]
        if ($diskDirectory.Name -cne $expectedRun -or
            -not (Test-QmSamePath -First $diskDirectory.FullName -Second $runDirectory) -or
            [bool]($diskDirectory.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
            throw "Runner raw attempt directory drift: $expectedRun"
        }

        $status = [string]$run['status']
        if ($status -notin @('OK', 'INVALID', 'FAIL')) {
            throw "Unknown runner attempt status for ${expectedRun}: $status"
        }
        $failure = $null
        if ($run.Contains('failure') -and $null -ne $run['failure'] -and
            -not [string]::IsNullOrWhiteSpace([string]$run['failure'])) {
            $failure = [string]$run['failure']
        }
        $invalidReasons = @()
        if ($run.Contains('invalid_report_reasons') -and $null -ne $run['invalid_report_reasons']) {
            $invalidReasons = @($run['invalid_report_reasons'])
        }
        foreach ($reason in $invalidReasons) {
            if ($reason -isnot [string] -or [string]$reason -cnotmatch $allowedReasonPattern) {
                throw "Unrecognized structural invalid reason for ${expectedRun}: $reason"
            }
        }

        $selected = $status -ceq 'OK'
        if ($selected) {
            if ($null -ne $failure -or $invalidReasons.Count -ne 0) {
                throw "Accepted attempt $expectedRun carries failure metadata"
            }
            if ($run['real_ticks_marker'] -isnot [bool] -or -not [bool]$run['real_ticks_marker']) {
                throw "Accepted attempt $expectedRun requires the Model-4 real-ticks marker"
            }
        } else {
            $observedNonOk++
            if ($null -eq $failure) { throw "Non-OK attempt $expectedRun lacks a failure reason" }
            if ($status -ceq 'INVALID') {
                if ($failure -notin $allowedInvalidFailures -or $invalidReasons.Count -eq 0) {
                    throw "INVALID attempt $expectedRun lacks recognized structural reasons"
                }
            } elseif ($failure -notin $allowedFailFailures) {
                throw "FAIL attempt $expectedRun has unrecognized failure: $failure"
            }
        }

        $reportPath = [System.IO.Path]::GetFullPath([string]$run['report_canonical_path'])
        $expectedReportPath = [System.IO.Path]::GetFullPath((Join-Path $runDirectory 'report.htm'))
        if (-not (Test-QmSamePath -First $reportPath -Second $expectedReportPath)) {
            throw "Runner report path is not canonical for ${expectedRun}: $reportPath"
        }
        $reportSize = Get-QmStrictIntegerField -Map $run -Name 'report_size_bytes' -Minimum 0
        $reportBinding = $null
        $reportExists = Test-Path -LiteralPath $expectedReportPath -PathType Leaf
        if ($reportExists) {
            $reportBinding = Get-QmAttemptArtifactBinding -Path $expectedReportPath
            if ([int64]$reportBinding.size -ne $reportSize) {
                throw "Runner report size drift for ${expectedRun}: $($reportBinding.size) != $reportSize"
            }
        } elseif ($reportSize -ne 0) {
            throw "Runner report is absent with non-zero recorded size for $expectedRun"
        }
        if (($selected -or $status -ceq 'INVALID') -and $null -eq $reportBinding) {
            throw "$status attempt $expectedRun lacks its canonical report artifact"
        }
        if ($selected -and [int64]$reportBinding.size -le 0) {
            throw "Accepted attempt $expectedRun has an empty report artifact"
        }
        if ($status -ceq 'FAIL' -and $failure -in @('REPORT_MISSING', 'LOG_BOMB', 'TIMEOUT') -and
            $null -ne $reportBinding) {
            throw "$failure attempt $expectedRun unexpectedly has a canonical report"
        }
        if ($status -ceq 'FAIL' -and $failure -ceq 'REPORT_EMPTY' -and
            $null -ne $reportBinding -and [int64]$reportBinding.size -ne 0) {
            throw "REPORT_EMPTY attempt $expectedRun has a non-empty report"
        }

        $testerIniPath = [System.IO.Path]::GetFullPath((Join-Path $runDirectory 'tester.ini'))
        if (-not (Test-Path -LiteralPath $testerIniPath -PathType Leaf)) {
            throw "Runner attempt lacks tester.ini: $expectedRun"
        }
        $testerIniBinding = Get-QmAttemptArtifactBinding -Path $testerIniPath
        if ([int64]$testerIniBinding.size -le 0) { throw "Runner tester.ini is empty: $expectedRun" }

        $testerLogBinding = $null
        if ($run.Contains('tester_log_path') -and $null -ne $run['tester_log_path'] -and
            -not [string]::IsNullOrWhiteSpace([string]$run['tester_log_path'])) {
            $testerLogPath = [System.IO.Path]::GetFullPath([string]$run['tester_log_path'])
            if (-not (Test-QmSamePath -First (Split-Path -Parent $testerLogPath) -Second $runDirectory) -or
                -not (Test-Path -LiteralPath $testerLogPath -PathType Leaf)) {
                throw "Runner tester log is missing/outside its exact attempt directory: $testerLogPath"
            }
            $testerLogBinding = Get-QmAttemptArtifactBinding -Path $testerLogPath
            if ([int64]$testerLogBinding.size -le 0) { throw "Runner tester log is empty: $expectedRun" }
        }
        if ($selected -and $null -eq $testerLogBinding) {
            throw "Accepted attempt $expectedRun lacks its tester log artifact"
        }

        $expectedFiles = New-Object System.Collections.Generic.List[string]
        $expectedFiles.Add($testerIniBinding.path.ToLowerInvariant())
        if ($null -ne $reportBinding) { $expectedFiles.Add($reportBinding.path.ToLowerInvariant()) }
        if ($null -ne $testerLogBinding) { $expectedFiles.Add($testerLogBinding.path.ToLowerInvariant()) }
        $attemptChildren = @(Get-ChildItem -LiteralPath $runDirectory -Force -ErrorAction Stop)
        if (@($attemptChildren | Where-Object { $_.PSIsContainer }).Count -ne 0) {
            throw "Runner attempt directory contains nested directories: $expectedRun"
        }
        $actualFiles = @($attemptChildren | ForEach-Object {
            if ([bool]($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                throw "Runner attempt directory contains a reparse-point artifact: $($_.FullName)"
            }
            $_.FullName.ToLowerInvariant()
        })
        if ([string]::Join('|', @($actualFiles | Sort-Object)) -cne
            [string]::Join('|', @($expectedFiles | Sort-Object))) {
            throw "Runner attempt directory contains missing or unbound artifacts: $expectedRun"
        }

        $explicitAbsences = New-Object System.Collections.Generic.List[string]
        if ($null -eq $reportBinding) { $explicitAbsences.Add('report') }
        if ($null -eq $testerLogBinding) { $explicitAbsences.Add('tester_log') }
        $attemptRows.Add([ordered]@{
            ordinal = $ordinal
            run = $expectedRun
            status = $status
            failure = $failure
            invalid_report_reasons = @($invalidReasons)
            selected_for_cost_audit = $selected
            report = $reportBinding
            tester_ini = $testerIniBinding
            tester_log = $testerLogBinding
            explicit_absences = @($explicitAbsences)
        })

        if ($selected) {
            $acceptedRunIds.Add($expectedRun)
            $acceptedReports.Add([string]$reportBinding.path)
            $acceptedTesterInis.Add([string]$testerIniBinding.path)
            $acceptedTesterLogs.Add([string]$testerLogBinding.path)
        }
    }

    if ($observedNonOk -ne $nonOkAttempts -or
        $attemptedRuns -ne ($requestedRuns + $nonOkAttempts)) {
        throw 'Runner requested/attempted/non-OK count algebra drift'
    }
    if ($acceptedReports.Count -ne $requestedRuns -or $requestedRuns -ne [int]$Contract.runs) {
        throw "Runner accepted OK count drift: $($acceptedReports.Count) != $requestedRuns"
    }

    $attemptAudit = [ordered]@{
        schema_version = 1
        artifact_type = 'QM5_20009_RESEARCH_ATTEMPT_AUDIT'
        status = 'PASS'
        report_dir = $reportDir
        raw_root = $rawRoot
        selection_policy = [ordered]@{
            rule = 'SNAPSHOT_RUNNER_STATUS_OK_STRUCTURAL_ONLY'
            performance_fields_consulted = $false
            cost_deal_audit_uses_only_selected = $true
        }
        count_algebra = [ordered]@{
            requested_runs = [int]$requestedRuns
            max_run_attempts = [int]$maxRunAttempts
            attempted_runs = [int]$attemptedRuns
            non_ok_attempts = [int]$nonOkAttempts
            ok_runs = [int]$acceptedReports.Count
        }
        accepted_run_ids = @($acceptedRunIds)
        attempts = @($attemptRows)
        unbound_files = @()
    }
    return [ordered]@{
        report_dir = $reportDir
        reports = @($acceptedReports)
        tester_inis = @($acceptedTesterInis)
        tester_logs = @($acceptedTesterLogs)
        attempt_audit = $attemptAudit
    }
}

function Assert-QmAttemptAuditUnchanged {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Expected,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Summary,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Contract
    )
    $current = (Assert-QmResearchSummary -Summary $Summary -Contract $Contract)['attempt_audit']
    $expectedJson = $Expected | ConvertTo-Json -Depth 100 -Compress
    $currentJson = $current | ConvertTo-Json -Depth 100 -Compress
    if ($currentJson -cne $expectedJson) {
        throw 'Runner attempt inventory changed after its initial audit'
    }
}

function Assert-QmCostAudit {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Audit,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Contract,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$SetInputs,
        [Parameter(Mandatory = $true)][string[]]$ExpectedReports
    )
    if ([string]$Audit['artifact_type'] -cne 'QM5_20009_DEV1_MT5_REPORT_AUDIT_RECEIPT' -or
        [string]$Audit['status'] -cne 'PASS' -or
        [string]$Audit['duplicate_fingerprint_check'] -cne 'PASS' -or
        [int]$Audit['duplicate_count'] -ne [int]$Contract.runs) {
        throw 'Cost audit receipt status/count/fingerprint contract failed'
    }
    $dealHash = [string]$Audit['canonical_deal_sequence_sha256']
    $runHash = [string]$Audit['run_fingerprint_sha256']
    if ($dealHash -cnotmatch '^[0-9a-f]{64}$' -or $runHash -cnotmatch '^[0-9a-f]{64}$') {
        throw 'Cost audit lacks canonical deal/run fingerprints'
    }
    $reports = @($Audit['reports'])
    if ($reports.Count -ne [int]$Contract.runs) { throw 'Cost audit report count drift' }
    $observedPaths = New-Object System.Collections.Generic.List[string]
    $zeroTradeReports = New-Object System.Collections.Generic.List[string]
    $sameDayStatuses = New-Object System.Collections.Generic.List[string]
    foreach ($report in $reports) {
        if ($report -isnot [System.Collections.IDictionary] -or [string]$report['status'] -cne 'PASS') {
            throw 'Per-report cost audit did not PASS'
        }
        $header = $report['header']
        $identity = $report['identity']
        $native = $report['native_integrity']
        $metrics = $report['metrics']
        foreach ($pair in @(
            @('symbol', [string]$Contract.symbol), @('timeframe', [string]$Contract.timeframe),
            @('from_date', [string]$Contract.from), @('to_date', [string]$Contract.to),
            @('initial_deposit', '100000.00'), @('currency', 'USD')
        )) {
            if ([string]$header[$pair[0]] -cne [string]$pair[1]) {
                throw "Audited report header drift for $($pair[0])"
            }
        }
        if ([string]$identity['canonical_deal_sequence_sha256'] -cne $dealHash -or
            [string]$identity['run_fingerprint_sha256'] -cne $runHash) {
            throw 'Duplicate report semantic fingerprint drift'
        }
        if ($native['commission_exactly_zero'] -isnot [bool] -or
            -not [bool]$native['commission_exactly_zero'] -or
            $native['simulated_commission_input_exactly_zero'] -isnot [bool] -or
            -not [bool]$native['simulated_commission_input_exactly_zero']) {
            throw 'Native/simulated commission double-count guard failed'
        }
        Assert-QmInputMapMatchesSet -Actual $header['inputs'] -Expected $SetInputs
        if ([int]$metrics['closed_positions'] -le 0) {
            $zeroTradeReports.Add([string]$report['report']['path'])
        }
        $sameDayStatuses.Add([string]$report['same_day_swap_proof']['status'])
        $observedPaths.Add(([System.IO.Path]::GetFullPath([string]$report['report']['path'])).ToLowerInvariant())
    }
    $expectedPaths = @($ExpectedReports | ForEach-Object { ([System.IO.Path]::GetFullPath($_)).ToLowerInvariant() })
    if ([string]::Join('|', @($observedPaths | Sort-Object)) -cne
        [string]::Join('|', @($expectedPaths | Sort-Object))) {
        throw 'Cost audit report paths differ from runner raw artifacts'
    }
    $sameDayFailures = @($sameDayStatuses | Where-Object { $_ -cne 'PASS' })
    $candidateReasons = New-Object System.Collections.Generic.List[string]
    if (-not [bool]$Contract.binding) { $candidateReasons.Add('NONBINDING_INFRASTRUCTURE_ONLY') }
    if ($zeroTradeReports.Count -gt 0) { $candidateReasons.Add('ZERO_TRADES_OBSERVED') }
    if ($sameDayFailures.Count -gt 0) { $candidateReasons.Add('SAME_DAY_ZERO_SWAP_PROOF_NOT_PASS') }
    return [ordered]@{
        pass_candidate = (
            [bool]$Contract.binding -and
            $zeroTradeReports.Count -eq 0 -and
            $sameDayFailures.Count -eq 0
        )
        candidate_block_reasons = @($candidateReasons)
        zero_trade_report_paths = @($zeroTradeReports)
        same_day_swap_statuses = @($sameDayStatuses)
        adjudication_required = $true
    }
}

function Invoke-QmCapturedProcess {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory
    )
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FilePath
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.WorkingDirectory = $WorkingDirectory
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        if (-not $process.Start()) { throw "Failed to start fixed research tool: $FilePath" }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        return [ordered]@{
            exit_code = $process.ExitCode
            stdout = $stdoutTask.GetAwaiter().GetResult()
            stderr = $stderrTask.GetAwaiter().GetResult()
        }
    } finally {
        $process.Dispose()
    }
}

function Write-QmAtomicText {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text
    )
    $full = [System.IO.Path]::GetFullPath($Path)
    $parent = Split-Path -Parent $full
    New-Item -ItemType Directory -Path $parent -Force -ErrorAction Stop | Out-Null
    $temporary = Join-Path $parent ('.{0}.{1}.tmp' -f (Split-Path -Leaf $full), [guid]::NewGuid().ToString('N'))
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Text)
    $stream = $null
    try {
        $stream = [System.IO.File]::Open(
            $temporary,
            [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None
        )
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
        $stream.Dispose()
        $stream = $null
        [System.IO.File]::Move($temporary, $full, $true)
    } finally {
        if ($null -ne $stream) { $stream.Dispose() }
        if (Test-Path -LiteralPath $temporary -PathType Leaf) {
            Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
        }
    }
}

function Write-QmAtomicJson {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Payload
    )
    $json = $Payload | ConvertTo-Json -Depth 100
    Write-QmAtomicText -Path $Path -Text ($json + "`n")
}

function Write-QmDetachedJsonReceipt {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Payload
    )
    Write-QmAtomicJson -Path $Path -Payload $Payload
    $hash = Get-QmSha256 -Path $Path
    Write-QmAtomicText -Path ($Path + '.sha256') -Text ($hash + "`n")
    return Get-QmFileBinding -Path $Path
}

Export-ModuleMember -Function @(
    'Get-QmSha256', 'Get-QmFileBinding', 'Test-QmPathWithin', 'Get-QmResearchContract',
    'Read-QmSetInputs', 'Assert-QmInputMapMatchesSet', 'Assert-QmResearchSummary',
    'Assert-QmAttemptAuditUnchanged', 'Assert-QmCostAudit', 'Invoke-QmCapturedProcess', 'Write-QmAtomicText',
    'Write-QmAtomicJson', 'Write-QmDetachedJsonReceipt'
)
