Set-StrictMode -Version Latest

function Convert-QmPatternDate {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $parsed = [datetime]::MinValue
    if (-not [datetime]::TryParseExact(
        $Value,
        'yyyy.MM.dd',
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::None,
        [ref]$parsed
    )) {
        return $null
    }
    return $parsed.Date
}

function Get-QmPatternMarkerFromLoggerSample {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $markers = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $markers.ToArray()
    }

    foreach ($line in [System.IO.File]::ReadLines($Path)) {
        if ($line.IndexOf('PATTERN_FIRST_TRADABLE_BAR', [System.StringComparison]::Ordinal) -lt 0) {
            continue
        }
        try {
            $row = $line | ConvertFrom-Json -ErrorAction Stop
        } catch {
            continue
        }
        if ([string]$row.event -cne 'PATTERN_FIRST_TRADABLE_BAR') {
            continue
        }
        $payload = $row.payload
        if ($null -eq $payload -or [string]$payload.marker_schema -cne 'qm.pattern-first-tradable-bar/v1') {
            continue
        }
        $date = Convert-QmPatternDate -Value ([string]$payload.tradable_bar_date)
        if ($null -eq $date) {
            continue
        }
        try {
            $markers.Add([pscustomobject]@{
                tradable_bar_date = $date.ToString('yyyy.MM.dd')
                tradable_bar_time = [long]$payload.tradable_bar_time
                reference_bar_time = [long]$payload.reference_bar_time
                required_bars = [int]$payload.required_bars
                symbol = [string]$payload.symbol
                reference_timeframe = [int]$payload.reference_timeframe
                profile_key = [string]$payload.profile_key
                source_kind = 'qm_logger_jsonl'
                source_path = [System.IO.Path]::GetFullPath($Path)
            })
        } catch {
            continue
        }
    }
    return $markers.ToArray()
}

function Get-QmPatternMarkerFromTesterLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $markers = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $markers.ToArray()
    }

    $pattern = [regex]'QM_PATTERN_FIRST_TRADABLE_BAR\s+schema=qm\.pattern-first-tradable-bar/v1\s+symbol=(?<symbol>\S+)\s+reference_timeframe=(?<tf>-?\d+)\s+tradable_bar_date=(?<date>\d{4}\.\d{2}\.\d{2})\s+tradable_bar_time=(?<tradable>-?\d+)\s+reference_bar_time=(?<reference>-?\d+)\s+required_bars=(?<required>\d+)\s+profile_key=(?<profile>\S+)'
    foreach ($line in [System.IO.File]::ReadLines($Path)) {
        $match = $pattern.Match($line)
        if (-not $match.Success) {
            continue
        }
        $date = Convert-QmPatternDate -Value $match.Groups['date'].Value
        if ($null -eq $date) {
            continue
        }
        $markers.Add([pscustomobject]@{
            tradable_bar_date = $date.ToString('yyyy.MM.dd')
            tradable_bar_time = [long]$match.Groups['tradable'].Value
            reference_bar_time = [long]$match.Groups['reference'].Value
            required_bars = [int]$match.Groups['required'].Value
            symbol = $match.Groups['symbol'].Value
            reference_timeframe = [int]$match.Groups['tf'].Value
            profile_key = $match.Groups['profile'].Value
            source_kind = 'tester_log'
            source_path = [System.IO.Path]::GetFullPath($Path)
        })
    }
    return $markers.ToArray()
}

function Get-QmPatternFrequencyFloorEvidence {
    param(
        [string[]]$LoggerSamplePaths = @(),
        [string[]]$TesterLogPaths = @(),
        [Parameter(Mandatory = $true)]
        [string]$FallbackStartDate,
        [Parameter(Mandatory = $true)]
        [string]$EndDate,
        [ValidateRange(1, 1000000)]
        [int]$RatePerYear = 5
    )

    $fallback = Convert-QmPatternDate -Value $FallbackStartDate
    $end = Convert-QmPatternDate -Value $EndDate
    if ($null -eq $fallback -or $null -eq $end -or $fallback -gt $end) {
        throw "Invalid frequency-floor window: $FallbackStartDate..$EndDate"
    }

    $markers = New-Object System.Collections.Generic.List[object]
    foreach ($path in @($LoggerSamplePaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        foreach ($marker in @(Get-QmPatternMarkerFromLoggerSample -Path $path)) {
            $markers.Add($marker)
        }
    }
    foreach ($path in @($TesterLogPaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        foreach ($marker in @(Get-QmPatternMarkerFromTesterLog -Path $path)) {
            $markers.Add($marker)
        }
    }

    $valid = @($markers | Where-Object {
        $date = Convert-QmPatternDate -Value ([string]$_.tradable_bar_date)
        $null -ne $date -and $date -ge $fallback -and $date -le $end
    })
    # A run may have several active pattern-profile slots. The EA is fully
    # tradable only when the LAST of those slots becomes history-valid, so take
    # the latest scope marker per evidence file. Independent run files should
    # then agree; if they do not, the conservative conflict policy below keeps
    # the earliest RUN-level value (more coverage, therefore a stricter floor).
    $effectiveMarkers = New-Object System.Collections.Generic.List[object]
    foreach ($group in @($valid | Group-Object source_path)) {
        $latestInRun = $group.Group | Sort-Object tradable_bar_date | Select-Object -Last 1
        if ($null -ne $latestInRun) {
            $effectiveMarkers.Add($latestInRun)
        }
    }
    $uniqueDates = @($effectiveMarkers | ForEach-Object { [string]$_.tradable_bar_date } | Sort-Object -Unique)

    $coverageStart = $fallback
    $coverageSource = 'test_window_start_fallback_marker_absent'
    $markerStatus = 'absent'
    $selectedMarker = $null
    if ($uniqueDates.Count -gt 0) {
        # More coverage means a stricter sample floor. If independent runs ever
        # disagree, choose the EARLIEST marker rather than letting a late marker
        # lower the floor, and make the inconsistency explicit in the evidence.
        $selectedDate = $uniqueDates[0]
        $coverageStart = Convert-QmPatternDate -Value $selectedDate
        $selectedMarker = $effectiveMarkers | Where-Object {
            [string]$_.tradable_bar_date -ceq $selectedDate
        } | Select-Object -First 1
        $coverageSource = 'pattern_first_tradable_bar'
        $markerStatus = if ($uniqueDates.Count -eq 1) { 'present_consistent' } else { 'present_conflict_conservative_earliest' }
    } elseif ($markers.Count -gt 0) {
        $coverageSource = 'test_window_start_fallback_marker_invalid_or_outside_window'
        $markerStatus = 'invalid_or_outside_window'
    }

    $yearCount = [Math]::Max(1, ($end.Year - $coverageStart.Year + 1))
    return [ordered]@{
        schema = 'qm.q02-frequency-coverage/v1'
        rate_per_year = $RatePerYear
        coverage_start = $coverageStart.ToString('yyyy.MM.dd')
        coverage_end = $end.ToString('yyyy.MM.dd')
        coverage_start_source = $coverageSource
        marker_status = $markerStatus
        marker_count = $markers.Count
        valid_marker_count = $valid.Count
        effective_run_marker_count = $effectiveMarkers.Count
        first_tradable_bar = $selectedMarker
        year_count = $yearCount
        min_trades_required = [Math]::Max($RatePerYear, $RatePerYear * $yearCount)
        fallback_visible = $true
    }
}
