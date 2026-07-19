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
        if ($Symbol -notin @('NDX.DWX', 'GBPUSD.DWX')) {
            throw "DEV_SMOKE_2022 only permits NDX.DWX and GBPUSD.DWX"
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

    $reportDir = [System.IO.Path]::GetFullPath([string]$Summary['report_dir'])
    if (-not (Test-Path -LiteralPath $reportDir -PathType Container)) {
        throw "Runner report directory is missing: $reportDir"
    }
    $rawRoot = Join-Path $reportDir 'raw'
    $rawReports = @(
        Get-ChildItem -LiteralPath $rawRoot -Filter 'report.htm' -File -Recurse -ErrorAction Stop |
            Sort-Object FullName
    )
    if ($rawReports.Count -ne [int]$Contract.runs) {
        throw "Every binding/raw report must be audited; expected $($Contract.runs), found $($rawReports.Count)"
    }
    $runRows = @($Summary['runs'])
    if ($runRows.Count -ne [int]$Contract.runs) {
        throw "Runner summary run count drift: $($runRows.Count) != $($Contract.runs)"
    }
    $summaryPaths = New-Object System.Collections.Generic.List[string]
    foreach ($run in $runRows) {
        if ($run -isnot [System.Collections.IDictionary] -or [string]$run['status'] -cne 'OK') {
            throw 'All accepted raw research runs must have status OK'
        }
        if ($run['real_ticks_marker'] -isnot [bool] -or -not [bool]$run['real_ticks_marker']) {
            throw 'Each accepted run requires the Model-4 real-ticks log marker'
        }
        $report = [System.IO.Path]::GetFullPath([string]$run['report_canonical_path'])
        if (-not (Test-QmPathWithin -Path $report -Root $reportDir) -or
            -not (Test-Path -LiteralPath $report -PathType Leaf)) {
            throw "Runner summary report path is missing/outside report_dir: $report"
        }
        $summaryPaths.Add($report.ToLowerInvariant())
    }
    $diskPaths = @($rawReports | ForEach-Object { $_.FullName.ToLowerInvariant() })
    if ([string]::Join('|', @($summaryPaths | Sort-Object)) -cne
        [string]::Join('|', @($diskPaths | Sort-Object))) {
        throw 'Runner summary report list differs from raw report.htm files on disk'
    }
    return [ordered]@{
        report_dir = $reportDir
        reports = @($rawReports | ForEach-Object { $_.FullName })
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
    'Assert-QmCostAudit', 'Invoke-QmCapturedProcess', 'Write-QmAtomicText',
    'Write-QmAtomicJson', 'Write-QmDetachedJsonReceipt'
)
