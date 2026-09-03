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

# --- Marker attribution (fail-closed) -------------------------------------
#
# The tester day-log is a SHARED terminal artifact: every expert that ran on
# that terminal on that calendar day prints into it - including EARLIER RUNS OF
# THIS SAME EA ON THIS SAME SYMBOL. A raw text scan for
# QM_PATTERN_FIRST_TRADABLE_BAR therefore returns markers that belong to other
# runs, and consuming one silently rewrites this run's Q02 coverage window and
# with it the frequency floor:
#
#   * 2026-09-03 cross-EA leak: QM5_41321 / NDX.DWX adopted a QM5_41195 /
#     XAGUSD marker, moving coverage start 2021.01.01 -> 2022.01.12 and the
#     floor from 10 to 5 trades (work item 95e706ea-...-79134).
#   * 2026-09-03 cross-RUN leak (same EA, same symbol): the day-log of
#     QM5_41196 / XAUUSD.DWX holds four markers from four DL089 census cells
#     (1-year windows) plus the canonical 2018.07.02-2022.12.31 Q02 run. An
#     (EA, symbol)-only rule adopts the latest census marker (2022.01.03) and
#     understates the floor 25 -> 5.
#
# A marker may only be used when it is provably THIS RUN's own:
#   * its day-log clock lies inside this run's own tester window - the window
#     is anchored on the tester's own run-start line
#     "<symbol>,<tf>: testing of Experts\<expert>.ex5 from <from> to <to>
#      started with inputs:", required to match this run's expert, symbol AND
#     requested window, and closed by the next run boundary; AND
#   * the day-log source column names this expert (layout 1), or - for the
#     tester-core layout that carries no EA identity at all (layout 2,
#     "IE<TAB>0<TAB>03:27:52.986<TAB>Core 01<TAB>...", 139 of 2,921 retained
#     production marker lines = 4.8%) - the run window plus the run symbol
#     carry the scoping; AND
#   * the marker belongs to this run's symbol scope (marker symbol == run
#     symbol, or - for multi-symbol baskets - the emitting chart is this run's
#     own chart symbol).
#
# When the run window cannot be established the markers are rejected outright
# (distinct reason `run_window_unresolved`). Every rejection falls back to the
# documented test-window start, which is the CONSERVATIVE direction: more
# coverage, more scored years, a stricter floor.

function Get-QmPatternExpertLeaf {
    param(
        [string]$Value = ''
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }
    $raw = $Value.Trim().Trim('"').Replace('/', '\')
    $parts = @($raw.Split('\') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $leaf = ''
    if ($parts.Count -gt 0) {
        $leaf = ([string]$parts[$parts.Count - 1]).Trim()
    }
    if ($leaf.EndsWith('.ex5', [System.StringComparison]::OrdinalIgnoreCase)) {
        $leaf = $leaf.Substring(0, $leaf.Length - 4)
    }
    return $leaf
}

function Convert-QmTesterLogClock {
    param(
        [string]$Line = ''
    )

    # MetaTester day-log line layout (both known variants):
    #   "CS<TAB>0<TAB>01:20:33.391<TAB><source><TAB><text>"
    # The third tab-separated field is the terminal wall clock of the print.
    if ([string]::IsNullOrEmpty($Line)) {
        return $null
    }
    $fields = $Line.Split([char]9)
    if ($fields.Length -lt 3) {
        return $null
    }
    $raw = ([string]$fields[2]).Trim()
    $parsed = [timespan]::Zero
    if ([timespan]::TryParseExact(
        $raw,
        'hh\:mm\:ss\.fff',
        [System.Globalization.CultureInfo]::InvariantCulture,
        [ref]$parsed
    )) {
        return $parsed
    }
    return $null
}

function Format-QmTesterLogClock {
    param(
        $Value = $null
    )

    if ($null -eq $Value) {
        return $null
    }
    $span = [timespan]$Value
    if ($span -eq [timespan]::MaxValue) {
        return 'end_of_log'
    }
    return $span.ToString('hh\:mm\:ss\.fff')
}

function New-QmPatternAttributionSpec {
    param(
        [string]$ExpectedExpert = '',
        [int]$ExpectedEaId = 0,
        [string]$RunSymbol = ''
    )

    $expertLeaf = Get-QmPatternExpertLeaf -Value $ExpectedExpert
    $symbol = if ([string]::IsNullOrWhiteSpace($RunSymbol)) { '' } else { $RunSymbol.Trim() }

    return [ordered]@{
        expected_expert = $expertLeaf
        expected_ea_id = [int]$ExpectedEaId
        expected_symbol = $symbol
        has_expert_anchor = ($expertLeaf -ne '')
        has_ea_id_anchor = ([int]$ExpectedEaId -gt 0)
        has_symbol_anchor = ($symbol -ne '')
    }
}

function Test-QmPatternSymbolEquals {
    param(
        [string]$Left = '',
        [string]$Right = ''
    )

    if ([string]::IsNullOrWhiteSpace($Left) -or [string]::IsNullOrWhiteSpace($Right)) {
        return $false
    }
    return [string]::Equals($Left.Trim(), $Right.Trim(), [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-QmPatternExpertMatchesSpec {
    param(
        [Parameter(Mandatory = $true)]$Spec,
        [string]$ExpertName = ''
    )

    if ([string]::IsNullOrWhiteSpace($ExpertName)) {
        return $false
    }
    $name = $ExpertName.Trim()
    if ($name.EndsWith('.ex5', [System.StringComparison]::OrdinalIgnoreCase)) {
        $name = $name.Substring(0, $name.Length - 4)
    }
    if ($Spec.has_expert_anchor -and
        [string]::Equals($name, [string]$Spec.expected_expert, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }
    if ($Spec.has_ea_id_anchor) {
        $pattern = '^QM5_0*{0}(?:_|$)' -f [int]$Spec.expected_ea_id
        if ([regex]::IsMatch($name, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
            return $true
        }
    }
    return $false
}

function New-QmTesterLogRunWindow {
    param(
        [bool]$Resolved = $false,
        [string]$WindowSource = 'unresolved_no_matching_run_start',
        $Start = $null,
        $End = $null,
        [int]$ExactRunStartCount = 0,
        [int]$RunStartCount = 0,
        [int]$OwnRunStartCount = 0
    )

    return [pscustomobject]@{
        resolved = $Resolved
        window_source = $WindowSource
        start = $(if ($null -eq $Start) { [timespan]::Zero } else { [timespan]$Start })
        end = $(if ($null -eq $End) { [timespan]::MaxValue } else { [timespan]$End })
        exact_run_start_count = $ExactRunStartCount
        run_start_count = $RunStartCount
        own_run_start_count = $OwnRunStartCount
    }
}

function Resolve-QmTesterLogRunWindow {
    <#
        Establish THIS run's own section of a shared tester day-log.

        Primary anchor: the tester's run-start line, required to match this
        run's expert leaf, this run's symbol AND the exact requested window -
        the same triple `Test-TesterLogHasNoHistoryForRun` in run_smoke.ps1
        already uses to scope history failures to the current run. The LAST
        such line is this run (run_smoke copies the day-log immediately after
        the run finishes); the window closes at the next run boundary
        ("expert file added:" or another run-start line) or at end of log.

        Secondary anchor (midnight rollover): a run that started before 00:00
        leaves its tail in a day-log that contains NO run-start line at all.
        Such a file carries exactly one run's output - this run's - so the whole
        file is the window. Measured 2026-09-03: 4 of 1,059 retained production
        day-logs (0.4%); 1,053 resolve on their own run-start line and 2 stay
        unresolved (fail-closed).

        Anything else is UNRESOLVED and every marker in the file is rejected.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]$Spec,
        [Parameter(Mandatory = $true)]
        [datetime]$WindowFrom,
        [Parameter(Mandatory = $true)]
        [datetime]$WindowTo
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return New-QmTesterLogRunWindow -WindowSource 'unresolved_log_missing'
    }
    if (-not ($Spec.has_expert_anchor -or $Spec.has_ea_id_anchor) -or -not $Spec.has_symbol_anchor) {
        return New-QmTesterLogRunWindow -WindowSource 'unresolved_no_expected_run_identity'
    }

    $runStart = [regex]'(?i)(?<symbol>[^\s,\t]+),[^:\t]*:\s+testing of\s+Experts\\(?<expert>\S+?)\.ex5\s+from\s+(?<from>\d{4}\.\d{2}\.\d{2})\s+\d{2}:\d{2}\s+to\s+(?<to>\d{4}\.\d{2}\.\d{2})\s+\d{2}:\d{2}\s+started with inputs'

    $start = $null
    $end = $null
    $exactCount = 0
    $runStartCount = 0
    $ownCount = 0

    foreach ($line in [System.IO.File]::ReadLines($Path)) {
        if ($line.IndexOf('testing of Experts', [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $match = $runStart.Match($line)
            if ($match.Success) {
                $runStartCount++
                $clock = Convert-QmTesterLogClock -Line $line
                $leaf = Get-QmPatternExpertLeaf -Value $match.Groups['expert'].Value
                $isOwn = (Test-QmPatternExpertMatchesSpec -Spec $Spec -ExpertName $leaf) -and
                    (Test-QmPatternSymbolEquals -Left $match.Groups['symbol'].Value -Right ([string]$Spec.expected_symbol))
                if ($isOwn) {
                    $ownCount++
                }
                $fromDate = Convert-QmPatternDate -Value $match.Groups['from'].Value
                $toDate = Convert-QmPatternDate -Value $match.Groups['to'].Value
                $isExact = $isOwn -and
                    ($null -ne $clock) -and
                    ($null -ne $fromDate) -and ($null -ne $toDate) -and
                    ($fromDate -eq $WindowFrom) -and ($toDate -eq $WindowTo)
                if ($isExact) {
                    # A later own run supersedes an earlier one: keep the LAST.
                    $exactCount++
                    $start = $clock
                    $end = $null
                    continue
                }
                if (($null -ne $start) -and ($null -eq $end) -and ($null -ne $clock)) {
                    $end = $clock
                }
                continue
            }
        }
        if ($line.IndexOf('expert file added:', [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            if (($null -ne $start) -and ($null -eq $end)) {
                $clock = Convert-QmTesterLogClock -Line $line
                if ($null -ne $clock) {
                    $end = $clock
                }
            }
        }
    }

    if ($null -ne $start) {
        $effectiveEnd = if ($null -eq $end) { [timespan]::MaxValue } else { [timespan]$end }
        if ($effectiveEnd -lt $start) {
            $effectiveEnd = [timespan]::MaxValue
        }
        return New-QmTesterLogRunWindow `
            -Resolved $true `
            -WindowSource 'tester_log_run_start_exact' `
            -Start $start `
            -End $effectiveEnd `
            -ExactRunStartCount $exactCount `
            -RunStartCount $runStartCount `
            -OwnRunStartCount $ownCount
    }

    if ($runStartCount -eq 0) {
        return New-QmTesterLogRunWindow `
            -Resolved $true `
            -WindowSource 'rollover_continuation_no_run_start' `
            -Start ([timespan]::Zero) `
            -End ([timespan]::MaxValue)
    }

    return New-QmTesterLogRunWindow `
        -WindowSource 'unresolved_no_matching_run_start' `
        -RunStartCount $runStartCount `
        -OwnRunStartCount $ownCount
}

function Resolve-QmPatternMarkerAttribution {
    param(
        [Parameter(Mandatory = $true)]$Spec,
        [string]$MarkerSymbol = '',
        [string]$HostSymbol = '',
        [bool]$EaIdentityPresent = $false,
        [bool]$EaIdentityMatched = $false,
        # 'run_scoped_capture' = the artifact itself is bounded by this run
        # (per-run structured-logger delta), so no clock filter is required.
        [ValidateSet('run_scoped_capture', 'inside', 'outside', 'unresolved', 'no_timestamp')]
        [string]$RunWindowState = 'run_scoped_capture',
        [ValidateSet('run_scoped_capture', 'expert_chart', 'tester_core', 'unrecognized', 'missing')]
        [string]$SourceColumnKind = 'run_scoped_capture'
    )

    if (-not ($Spec.has_expert_anchor -or $Spec.has_ea_id_anchor) -or -not $Spec.has_symbol_anchor) {
        return [pscustomobject]@{ attributed = $false; reason = 'no_expected_run_identity'; scope = 'unknown' }
    }
    if ($RunWindowState -ceq 'unresolved') {
        return [pscustomobject]@{ attributed = $false; reason = 'run_window_unresolved'; scope = 'unknown' }
    }
    if ($RunWindowState -ceq 'no_timestamp') {
        return [pscustomobject]@{ attributed = $false; reason = 'marker_line_without_timestamp'; scope = 'unknown' }
    }
    if ($RunWindowState -ceq 'outside') {
        return [pscustomobject]@{ attributed = $false; reason = 'outside_run_window'; scope = 'unknown' }
    }
    if ($SourceColumnKind -ceq 'tester_core') {
        # Layout 2: the source column is the tester core, not the expert, so the
        # line carries NO EA identity (4.8% of production marker lines). The run
        # window is then the only available scoping - and it is a real one: the
        # window belongs to exactly one dispatched run on this terminal.
        if (Test-QmPatternSymbolEquals -Left $MarkerSymbol -Right ([string]$Spec.expected_symbol)) {
            return [pscustomobject]@{ attributed = $true; reason = 'core_source_window'; scope = 'run_symbol' }
        }
        return [pscustomobject]@{ attributed = $false; reason = 'foreign_symbol'; scope = 'unknown' }
    }
    if (-not $EaIdentityPresent) {
        return [pscustomobject]@{ attributed = $false; reason = 'source_line_without_ea_identity'; scope = 'unknown' }
    }
    if (-not $EaIdentityMatched) {
        return [pscustomobject]@{ attributed = $false; reason = 'foreign_ea'; scope = 'unknown' }
    }
    if (Test-QmPatternSymbolEquals -Left $MarkerSymbol -Right ([string]$Spec.expected_symbol)) {
        return [pscustomobject]@{ attributed = $true; reason = 'own_ea_run_symbol'; scope = 'run_symbol' }
    }
    if (Test-QmPatternSymbolEquals -Left $HostSymbol -Right ([string]$Spec.expected_symbol)) {
        # Multi-symbol basket: the EA is this run's EA and it printed from this
        # run's own chart, but the marker scopes a member symbol.
        return [pscustomobject]@{ attributed = $true; reason = 'own_ea_member_symbol'; scope = 'member_symbol' }
    }
    return [pscustomobject]@{ attributed = $false; reason = 'foreign_symbol'; scope = 'unknown' }
}

function Get-QmPatternMarkerFromLoggerSample {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        $Attribution = $null
    )

    $markers = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $markers.ToArray()
    }
    $spec = if ($null -eq $Attribution) { New-QmPatternAttributionSpec } else { $Attribution }

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

        $rowNames = @($row.PSObject.Properties.Name)
        $rowEaId = $null
        if ($rowNames -contains 'ea_id') {
            try { $rowEaId = [int]$row.ea_id } catch { $rowEaId = $null }
        }
        $rowMagic = $null
        if ($rowNames -contains 'magic') {
            try { $rowMagic = [long]$row.magic } catch { $rowMagic = $null }
        }
        $rowSymbol = if ($rowNames -contains 'symbol') { [string]$row.symbol } else { '' }

        $identityPresent = (($null -ne $rowEaId) -and ($rowEaId -gt 0)) -or (($null -ne $rowMagic) -and ($rowMagic -gt 0))
        $identityMatched = $false
        if ($spec.has_ea_id_anchor) {
            if (($null -ne $rowEaId) -and ($rowEaId -eq [int]$spec.expected_ea_id)) {
                $identityMatched = $true
            } elseif (($null -ne $rowMagic) -and ($rowMagic -gt 0) -and
                      ([math]::Floor($rowMagic / 10000) -eq [int]$spec.expected_ea_id)) {
                # Magic-number contract: ea_id * 10000 + slot.
                $identityMatched = $true
            }
        }

        # The structured-logger sample is NOT a shared artifact: run_smoke.ps1
        # captures it as a per-run delta of this EA's logger files, bounded by
        # the run itself (Save-QmLoggerDelta -BeforeState/-EAIdValue). It is
        # therefore already run-scoped and needs no clock filter.
        $verdict = Resolve-QmPatternMarkerAttribution `
            -Spec $spec `
            -MarkerSymbol ([string]$payload.symbol) `
            -HostSymbol $rowSymbol `
            -EaIdentityPresent $identityPresent `
            -EaIdentityMatched $identityMatched `
            -RunWindowState 'run_scoped_capture' `
            -SourceColumnKind 'run_scoped_capture'

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
                source_column = ''
                source_column_kind = 'run_scoped_capture'
                source_line_time = $null
                emitting_expert = ''
                emitting_ea_id = $rowEaId
                emitting_host_symbol = $rowSymbol
                run_window_state = 'run_scoped_capture'
                run_window_source = 'per_run_delta_capture'
                attributed = [bool]$verdict.attributed
                attribution_reason = [string]$verdict.reason
                symbol_scope = [string]$verdict.scope
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
        [string]$Path,
        $Attribution = $null,
        # Resolved by Resolve-QmTesterLogRunWindow. Absent => fail closed.
        $RunWindow = $null
    )

    $markers = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $markers.ToArray()
    }
    $spec = if ($null -eq $Attribution) { New-QmPatternAttributionSpec } else { $Attribution }
    $window = if ($null -eq $RunWindow) {
        New-QmTesterLogRunWindow -WindowSource 'unresolved_window_not_supplied'
    } else {
        $RunWindow
    }

    $pattern = [regex]'QM_PATTERN_FIRST_TRADABLE_BAR\s+schema=qm\.pattern-first-tradable-bar/v1\s+symbol=(?<symbol>\S+)\s+reference_timeframe=(?<tf>-?\d+)\s+tradable_bar_date=(?<date>\d{4}\.\d{2}\.\d{2})\s+tradable_bar_time=(?<tradable>-?\d+)\s+reference_bar_time=(?<reference>-?\d+)\s+required_bars=(?<required>\d+)\s+profile_key=(?<profile>\S+)'
    # Day-log source column, layout 1 (2,782 of 2,921 retained production
    # marker lines = 95.2%):
    #   "QM5_41321_grimes-trendday-v2-opt (NDX.DWX,M15)".
    $sourceColumn = [regex]'^(?<expert>.+?)\s+\((?<symbol>[^,()]+),(?<tf>[^,()]+)\)$'
    # Layout 2 (139 lines = 4.8%): the tester core prints the EA's text itself,
    # e.g.
    #   "IE<TAB>0<TAB>03:27:52.986<TAB>Core 01<TAB>2021.01.04 ... QM_PATTERN_...".
    # No EA identity at all - only the run window plus symbol can scope it.
    $coreColumn = [regex]'^(?i:Core)\s+\d+$'

    foreach ($line in [System.IO.File]::ReadLines($Path)) {
        $match = $pattern.Match($line)
        if (-not $match.Success) {
            continue
        }
        $date = Convert-QmPatternDate -Value $match.Groups['date'].Value
        if ($null -eq $date) {
            continue
        }

        # Attribution comes from the tab-delimited column immediately before
        # the column carrying the print, plus the line's own terminal clock.
        $logExpert = ''
        $logHostSymbol = ''
        $sourceText = ''
        $sourceKind = 'missing'
        $fields = $line.Split([char]9)
        $markerField = -1
        for ($i = 0; $i -lt $fields.Length; $i++) {
            if (([string]$fields[$i]).IndexOf('QM_PATTERN_FIRST_TRADABLE_BAR', [System.StringComparison]::Ordinal) -ge 0) {
                $markerField = $i
                break
            }
        }
        if ($markerField -gt 0) {
            $sourceText = ([string]$fields[$markerField - 1]).Trim()
            $sourceMatch = $sourceColumn.Match($sourceText)
            if ($sourceMatch.Success) {
                $logExpert = $sourceMatch.Groups['expert'].Value.Trim()
                $logHostSymbol = $sourceMatch.Groups['symbol'].Value.Trim()
                $sourceKind = 'expert_chart'
            } elseif ($coreColumn.IsMatch($sourceText)) {
                $sourceKind = 'tester_core'
            } else {
                $sourceKind = 'unrecognized'
            }
        }

        $clock = Convert-QmTesterLogClock -Line $line
        $windowState = 'unresolved'
        if ([bool]$window.resolved) {
            if ($null -eq $clock) {
                $windowState = 'no_timestamp'
            } elseif (($clock -ge $window.start) -and ($clock -le $window.end)) {
                $windowState = 'inside'
            } else {
                $windowState = 'outside'
            }
        }

        $identityPresent = ($logExpert -ne '')
        $identityMatched = $identityPresent -and (Test-QmPatternExpertMatchesSpec -Spec $spec -ExpertName $logExpert)
        $verdict = Resolve-QmPatternMarkerAttribution `
            -Spec $spec `
            -MarkerSymbol $match.Groups['symbol'].Value `
            -HostSymbol $logHostSymbol `
            -EaIdentityPresent $identityPresent `
            -EaIdentityMatched $identityMatched `
            -RunWindowState $windowState `
            -SourceColumnKind $sourceKind

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
            source_column = $sourceText
            source_column_kind = $sourceKind
            source_line_time = (Format-QmTesterLogClock -Value $clock)
            emitting_expert = $logExpert
            emitting_ea_id = $null
            emitting_host_symbol = $logHostSymbol
            run_window_state = $windowState
            run_window_source = [string]$window.window_source
            attributed = [bool]$verdict.attributed
            attribution_reason = [string]$verdict.reason
            symbol_scope = [string]$verdict.scope
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
        [int]$RatePerYear = 5,
        # Run identity. Without it no run window can be anchored, no marker is
        # attributable, and the evidence falls back to the full test window
        # (fail-closed, stricter floor).
        [string]$ExpectedExpert = '',
        [int]$ExpectedEaId = 0,
        [string]$RunSymbol = ''
    )

    $fallback = Convert-QmPatternDate -Value $FallbackStartDate
    $end = Convert-QmPatternDate -Value $EndDate
    if ($null -eq $fallback -or $null -eq $end -or $fallback -gt $end) {
        throw "Invalid frequency-floor window: $FallbackStartDate..$EndDate"
    }

    $spec = New-QmPatternAttributionSpec -ExpectedExpert $ExpectedExpert -ExpectedEaId $ExpectedEaId -RunSymbol $RunSymbol

    $markers = New-Object System.Collections.Generic.List[object]
    foreach ($path in @($LoggerSamplePaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        foreach ($marker in @(Get-QmPatternMarkerFromLoggerSample -Path $path -Attribution $spec)) {
            $markers.Add($marker)
        }
    }

    $testerWindows = New-Object System.Collections.Generic.List[object]
    foreach ($path in @($TesterLogPaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        $window = Resolve-QmTesterLogRunWindow -Path $path -Spec $spec -WindowFrom $fallback -WindowTo $end
        $fileMarkers = @(Get-QmPatternMarkerFromTesterLog -Path $path -Attribution $spec -RunWindow $window)
        foreach ($marker in $fileMarkers) {
            $markers.Add($marker)
        }
        $testerWindows.Add([ordered]@{
            source_path = $(try { [System.IO.Path]::GetFullPath($path) } catch { [string]$path })
            resolved = [bool]$window.resolved
            window_source = [string]$window.window_source
            window_start = (Format-QmTesterLogClock -Value $window.start)
            window_end = (Format-QmTesterLogClock -Value $window.end)
            exact_run_start_count = [int]$window.exact_run_start_count
            own_ea_symbol_run_start_count = [int]$window.own_run_start_count
            run_start_count = [int]$window.run_start_count
            marker_count = @($fileMarkers).Count
            attributed_marker_count = @($fileMarkers | Where-Object { $_.attributed }).Count
        })
    }

    # Fail-closed: only this run's own markers may move the coverage start.
    $attributedMarkers = @($markers | Where-Object { $_.attributed })
    $rejectedMarkers = @($markers | Where-Object { -not $_.attributed })

    $valid = @($attributedMarkers | Where-Object {
        $date = Convert-QmPatternDate -Value ([string]$_.tradable_bar_date)
        $null -ne $date -and $date -ge $fallback -and $date -le $end
    })
    # A run may have several active pattern-profile slots. The EA is fully
    # tradable only when the LAST of those slots becomes history-valid, so take
    # the latest scope marker per evidence file. Because every tester-log marker
    # is now bounded by this run's own window, that grouping can no longer mix
    # runs; `attributed_profile_keys` makes the surviving slots auditable.
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
    } elseif ($attributedMarkers.Count -gt 0) {
        $coverageSource = 'test_window_start_fallback_marker_invalid_or_outside_window'
        $markerStatus = 'invalid_or_outside_window'
    } elseif ($markers.Count -gt 0) {
        # Markers exist in the scanned files but none of them belongs to this
        # run (shared terminal day-log). Never adopt them.
        $coverageSource = 'test_window_start_fallback_marker_not_attributable'
        $markerStatus = 'present_not_attributable'
    }

    $rejectionReasons = [ordered]@{}
    foreach ($group in @($rejectedMarkers | Group-Object attribution_reason | Sort-Object Name)) {
        $rejectionReasons[[string]$group.Name] = [int]$group.Count
    }
    $rejectionSamples = @($rejectedMarkers | Select-Object -First 3 | ForEach-Object {
        [ordered]@{
            attribution_reason = [string]$_.attribution_reason
            symbol = [string]$_.symbol
            tradable_bar_date = [string]$_.tradable_bar_date
            profile_key = [string]$_.profile_key
            source_kind = [string]$_.source_kind
            source_column = [string]$_.source_column
            source_line_time = $_.source_line_time
            run_window_state = [string]$_.run_window_state
            emitting_expert = [string]$_.emitting_expert
            emitting_ea_id = $_.emitting_ea_id
            emitting_host_symbol = [string]$_.emitting_host_symbol
        }
    })
    $attributedProfileKeys = @($attributedMarkers |
        ForEach-Object { [string]$_.profile_key } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique)

    $resolvedWindowCount = @($testerWindows | Where-Object { $_.resolved }).Count

    $yearCount = [Math]::Max(1, ($end.Year - $coverageStart.Year + 1))
    return [ordered]@{
        schema = 'qm.q02-frequency-coverage/v2'
        rate_per_year = $RatePerYear
        coverage_start = $coverageStart.ToString('yyyy.MM.dd')
        coverage_end = $end.ToString('yyyy.MM.dd')
        coverage_start_source = $coverageSource
        marker_status = $markerStatus
        marker_count = $markers.Count
        valid_marker_count = $valid.Count
        effective_run_marker_count = $effectiveMarkers.Count
        attribution_enforced = $true
        run_window_enforced = $true
        attributed_marker_count = $attributedMarkers.Count
        attributed_profile_key_count = $attributedProfileKeys.Count
        attributed_profile_keys = $attributedProfileKeys
        rejected_marker_count = $rejectedMarkers.Count
        rejected_marker_reasons = $rejectionReasons
        rejected_marker_samples = $rejectionSamples
        attribution = [ordered]@{
            expected_expert = [string]$spec.expected_expert
            expected_ea_id = [int]$spec.expected_ea_id
            expected_symbol = [string]$spec.expected_symbol
            identity_anchor_available = ([bool]$spec.has_expert_anchor -or [bool]$spec.has_ea_id_anchor)
            symbol_anchor_available = [bool]$spec.has_symbol_anchor
        }
        run_scope = [ordered]@{
            enforced = $true
            logger_sample_scope = 'per_run_delta_capture'
            tester_log_file_count = $testerWindows.Count
            tester_log_window_resolved_count = $resolvedWindowCount
            tester_log_window_unresolved_count = ($testerWindows.Count - $resolvedWindowCount)
            tester_log_windows = $testerWindows.ToArray()
        }
        first_tradable_bar = $selectedMarker
        year_count = $yearCount
        min_trades_required = [Math]::Max($RatePerYear, $RatePerYear * $yearCount)
        fallback_visible = $true
    }
}
