[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'data'),
    [switch]$VerifyOfficialSources
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$runtimeName = 'QM5_LBMA_Gold_PM_schedule_20200101_20251231.csv'
$provenanceName = 'QM5_LBMA_Gold_PM_schedule_provenance.csv'
$sourcesName = 'QM5_LBMA_Gold_PM_schedule_sources.csv'
$transitionsName = 'QM5_Europe_London_transitions_20180101_20251231.csv'
$gapsName = 'QM5_LBMA_Gold_PM_schedule_gaps.csv'
$manifestName = 'QM5_LBMA_Gold_PM_schedule_manifest.json'
$coverageStart = [datetime]::ParseExact('2020-01-01', 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
$coverageEnd = [datetime]::ParseExact('2025-12-31', 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
$retrievedDate = '2026-07-22'
$expectedRuntimeRows = 2192
$expectedScheduledRows = 1503
$expectedHolidayRows = 63
$expectedWeekendRows = 626
$expectedSourceRows = 9
$expectedTransitionRows = 16
$expectedGapRows = 3

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

function Get-Sha256Lower {
    param([Parameter(Mandatory)][string]$Path)

    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Assert-SafeCsvField {
    param(
        [Parameter(Mandatory)][string]$Value,
        [Parameter(Mandatory)][string]$FieldName
    )

    if ($Value.Contains(',') -or $Value.Contains("`r") -or $Value.Contains("`n")) {
        throw "Unsafe unquoted CSV value in ${FieldName}: $Value"
    }
}

$annualSources = @(
    [pscustomobject]@{
        Id = 'IBA_LBMA_GOLD_CALENDAR_2020'
        Year = 2020
        Url = 'https://www.ice.com/publicdocs/Gold_Holiday_Calendar_2020.pdf'
        Sha256 = 'a91bd02d018b7add5a4401be01843d496145ce269a2d55983dd9f3c0dfba6056'
        Scope = 'Official LBMA Gold Price AM and PM holiday calendar for 2020'
    }
    [pscustomobject]@{
        Id = 'IBA_LBMA_GOLD_CALENDAR_2021'
        Year = 2021
        Url = 'https://www.ice.com/publicdocs/Gold_Holiday_Calendar_2021.pdf'
        Sha256 = 'c6eaa601ae788ba2ea9658d3fe40afb714b1c7aec8bcc8186a4a6edb99e2213d'
        Scope = 'Official LBMA Gold Price AM and PM holiday calendar for 2021'
    }
    [pscustomobject]@{
        Id = 'IBA_LBMA_GOLD_CALENDAR_2022'
        Year = 2022
        Url = 'https://www.ice.com/publicdocs/Gold_Holiday_Calendar_2022.pdf'
        Sha256 = '995dc0239c40d726def923590067a4f19615ddfa32fa19f1cb5c5d23f12815fe'
        Scope = 'Official LBMA Gold Price AM and PM holiday calendar for 2022'
    }
    [pscustomobject]@{
        Id = 'IBA_LBMA_GOLD_CALENDAR_2023'
        Year = 2023
        Url = 'https://www.ice.com/publicdocs/Gold_Holiday_Calendar_2023.pdf'
        Sha256 = 'f0e3da337c665d9033852d992447841a08ee1015d7abce3f4151be644269fc4c'
        Scope = 'Official LBMA Gold Price AM and PM holiday calendar for 2023'
    }
    [pscustomobject]@{
        Id = 'IBA_LBMA_GOLD_CALENDAR_2024'
        Year = 2024
        Url = 'https://www.ice.com/publicdocs/Gold_Holiday_Calendar_2024.pdf'
        Sha256 = '94c205c28462b036924059bb2118d27c74a0a0983307fb91035bee8074a2c6ef'
        Scope = 'Official LBMA Gold Price AM and PM holiday calendar for 2024'
    }
    [pscustomobject]@{
        Id = 'IBA_LBMA_GOLD_CALENDAR_2025'
        Year = 2025
        Url = 'https://www.ice.com/publicdocs/Gold_Holiday_Calendar_2025.pdf'
        Sha256 = '4f5ab78dcc514cbc7b7f318e5b7558fd968711d209a41428e74236f782bc16ff'
        Scope = 'Official LBMA Gold Price AM and PM holiday calendar for 2025'
    }
)

$sources = [Collections.Generic.List[object]]::new()
foreach ($source in $annualSources) {
    $sources.Add([pscustomobject]@{
        Id = $source.Id
        Type = 'ICE_IBA_OFFICIAL_ANNUAL_PDF'
        Retrieved = $retrievedDate
        Url = $source.Url
        Sha256 = $source.Sha256
        Scope = $source.Scope
    })
}
$sources.Add([pscustomobject]@{
    Id = 'IBA_PRECIOUS_METALS_METHODOLOGY_2026'
    Type = 'ICE_IBA_OFFICIAL_METHODOLOGY_PDF'
    Retrieved = $retrievedDate
    Url = 'https://www.ice.com/publicdocs/Precious_Metals_Methodology_ESG_Annex.pdf'
    Sha256 = '64a0ec801e11c2942a81c78242a2b4bac7943fc56e7121e46e4b8f53c308df03'
    Scope = 'Expected LBMA Gold Price auction start times and official holiday-calendar linkage'
})
$sources.Add([pscustomobject]@{
    Id = 'IBA_PRECIOUS_METALS_ERROR_POLICY_2026'
    Type = 'ICE_IBA_OFFICIAL_ERROR_POLICY_PDF'
    Retrieved = $retrievedDate
    Url = 'https://www.ice.com/publicdocs/Precious_Metals_Error_Policy.pdf'
    Sha256 = '4042e22871a78dadd4fdeb2ed462f4fd778ff33bc96f1dbd87c3f1b1b7c8767d'
    Scope = 'Official No Publication and auction-error semantics; not a historical incident ledger'
})
$sources.Add([pscustomobject]@{
    Id = 'IANA_TZDATA_2026C'
    Type = 'CARD_AUTHORIZED_IANA_TZDATA_ARCHIVE'
    Retrieved = $retrievedDate
    Url = 'https://data.iana.org/time-zones/releases/tzdata2026c.tar.gz'
    Sha256 = 'e4a178a4477f3d0ea77cc31828ff72aa38feff8d61aa13e7e99e142e9d902be4'
    Scope = 'Europe/London UTC offset and daylight-saving transitions for 2018 through 2025'
})

if ($sources.Count -ne $expectedSourceRows) {
    throw "Source contract mismatch: expected $expectedSourceRows sources, found $($sources.Count)."
}

$sourceIds = @{}
foreach ($source in $sources) {
    if ($sourceIds.ContainsKey($source.Id)) {
        throw "Duplicate source id: $($source.Id)"
    }
    $uri = [Uri]$source.Url
    $hostAllowed = ($uri.Scheme -eq 'https' -and
        (($uri.Host -eq 'www.ice.com') -or ($uri.Host -eq 'data.iana.org')))
    if (-not $hostAllowed) {
        throw "Non-authorized source URL for $($source.Id): $($source.Url)"
    }
    if ($source.Sha256 -notmatch '^[0-9a-f]{64}$') {
        throw "Invalid source SHA-256 for $($source.Id)."
    }
    foreach ($field in @('Id', 'Type', 'Retrieved', 'Url', 'Sha256', 'Scope')) {
        Assert-SafeCsvField -Value ([string]$source.$field) -FieldName "$($source.Id).$field"
    }
    $sourceIds[$source.Id] = $true
}

if ($VerifyOfficialSources) {
    $http = [Net.Http.HttpClient]::new()
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        foreach ($source in $sources) {
            $bytes = $http.GetByteArrayAsync($source.Url).GetAwaiter().GetResult()
            if ($bytes.Length -lt 1000) {
                throw "Official source is unexpectedly small for $($source.Id): $($bytes.Length) bytes."
            }
            $actual = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant()
            if ($actual -ne $source.Sha256) {
                throw "Official source hash mismatch for $($source.Id): expected $($source.Sha256), found $actual."
            }
        }
    }
    finally {
        $sha.Dispose()
        $http.Dispose()
    }
}

$transitionSpecs = @(
    '2018-03-25T01:00:00Z|0|60|BST',
    '2018-10-28T01:00:00Z|60|0|GMT',
    '2019-03-31T01:00:00Z|0|60|BST',
    '2019-10-27T01:00:00Z|60|0|GMT',
    '2020-03-29T01:00:00Z|0|60|BST',
    '2020-10-25T01:00:00Z|60|0|GMT',
    '2021-03-28T01:00:00Z|0|60|BST',
    '2021-10-31T01:00:00Z|60|0|GMT',
    '2022-03-27T01:00:00Z|0|60|BST',
    '2022-10-30T01:00:00Z|60|0|GMT',
    '2023-03-26T01:00:00Z|0|60|BST',
    '2023-10-29T01:00:00Z|60|0|GMT',
    '2024-03-31T01:00:00Z|0|60|BST',
    '2024-10-27T01:00:00Z|60|0|GMT',
    '2025-03-30T01:00:00Z|0|60|BST',
    '2025-10-26T01:00:00Z|60|0|GMT'
)
$transitions = [Collections.Generic.List[object]]::new()
foreach ($spec in $transitionSpecs) {
    $parts = $spec.Split('|')
    if ($parts.Count -ne 4) {
        throw "Malformed transition specification: $spec"
    }
    $instant = [datetimeoffset]::ParseExact(
        $parts[0],
        'yyyy-MM-ddTHH:mm:ssZ',
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::AssumeUniversal
    )
    $transitions.Add([pscustomobject]@{
        Instant = $instant
        Before = [int]$parts[1]
        After = [int]$parts[2]
        Abbreviation = $parts[3]
    })
}
if ($transitions.Count -ne $expectedTransitionRows) {
    throw "Transition contract mismatch: expected $expectedTransitionRows rows, found $($transitions.Count)."
}

$dstBoundsByYear = @{}
foreach ($year in 2018..2025) {
    $yearTransitions = @($transitions | Where-Object { $_.Instant.Year -eq $year } | Sort-Object Instant)
    if ($yearTransitions.Count -ne 2 -or $yearTransitions[0].After -ne 60 -or $yearTransitions[1].After -ne 0) {
        throw "Europe/London transition contract is incomplete for $year."
    }
    $dstBoundsByYear[$year] = [pscustomobject]@{
        StartDate = $yearTransitions[0].Instant.UtcDateTime.Date
        EndDate = $yearTransitions[1].Instant.UtcDateTime.Date
    }
}

$annualSourceByYear = @{}
foreach ($source in $annualSources) {
    $annualSourceByYear[$source.Year] = $source.Id
}

$exceptions = [Collections.Generic.List[object]]::new()
function Add-PmNoAuctionDates {
    param(
        [Parameter(Mandatory)][int]$Year,
        [Parameter(Mandatory)][string[]]$Entries
    )

    if (-not $annualSourceByYear.ContainsKey($Year)) {
        throw "Missing annual source for exception year $Year."
    }
    foreach ($entry in $Entries) {
        $parts = $entry.Split('|', 2)
        if ($parts.Count -ne 2) {
            throw "Malformed PM no-auction entry: $entry"
        }
        $date = [datetime]::ParseExact($parts[0], 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
        if ($date.Year -ne $Year -or $date.DayOfWeek -in @([DayOfWeek]::Saturday, [DayOfWeek]::Sunday)) {
            throw "Invalid annual PM no-auction date: $entry"
        }
        Assert-SafeCsvField -Value $parts[1] -FieldName "event_name.$($parts[0])"
        $exceptions.Add([pscustomobject]@{
            Date = $date
            EventName = $parts[1]
            SourceId = $annualSourceByYear[$Year]
        })
    }
}

Add-PmNoAuctionDates -Year 2020 -Entries @(
    '2020-01-01|New Years Day',
    '2020-04-10|Good Friday',
    '2020-04-13|Easter Monday',
    '2020-05-08|VE Day 75th Anniversary',
    '2020-05-25|Spring Bank Holiday',
    '2020-08-31|Summer Bank Holiday',
    '2020-12-24|Christmas Eve PM auction closed',
    '2020-12-25|Christmas Day',
    '2020-12-28|Boxing Day substitute day',
    '2020-12-31|New Years Eve PM auction closed'
)
Add-PmNoAuctionDates -Year 2021 -Entries @(
    '2021-01-01|New Years Day',
    '2021-04-02|Good Friday',
    '2021-04-05|Easter Monday',
    '2021-05-03|Early May Bank Holiday',
    '2021-05-31|Spring Bank Holiday',
    '2021-08-30|Summer Bank Holiday',
    '2021-12-24|Christmas Eve PM auction closed',
    '2021-12-27|Christmas Day UK observed',
    '2021-12-28|Boxing Day UK observed',
    '2021-12-31|New Years Eve PM auction closed'
)
Add-PmNoAuctionDates -Year 2022 -Entries @(
    '2022-01-03|New Years Day UK observed',
    '2022-04-15|Good Friday',
    '2022-04-18|Easter Monday',
    '2022-05-02|Early May Bank Holiday',
    '2022-06-02|Spring Bank Holiday',
    '2022-06-03|Platinum Jubilee Bank Holiday',
    '2022-08-29|Summer Bank Holiday',
    '2022-09-19|State Funeral of Her Majesty the Queen UK observed',
    '2022-12-23|Business day before Christmas Eve PM auction closed',
    '2022-12-26|Boxing Day',
    '2022-12-27|Christmas Day UK observed',
    '2022-12-30|Business day before New Years Eve PM auction closed'
)
Add-PmNoAuctionDates -Year 2023 -Entries @(
    '2023-01-02|New Years Day UK observed',
    '2023-04-07|Good Friday',
    '2023-04-10|Easter Monday',
    '2023-05-01|Early May Bank Holiday',
    '2023-05-08|Coronation Bank Holiday',
    '2023-05-29|Spring Bank Holiday',
    '2023-08-28|Summer Bank Holiday',
    '2023-12-22|Business day before Christmas Eve PM auction closed',
    '2023-12-25|Christmas Day',
    '2023-12-26|Boxing Day',
    '2023-12-29|Business day before New Years Eve PM auction closed'
)
Add-PmNoAuctionDates -Year 2024 -Entries @(
    '2024-01-01|New Years Day',
    '2024-03-29|Good Friday',
    '2024-04-01|Easter Monday',
    '2024-05-06|Early May Bank Holiday',
    '2024-05-27|Spring Bank Holiday',
    '2024-08-26|Summer Bank Holiday',
    '2024-12-24|Christmas Eve PM auction closed',
    '2024-12-25|Christmas Day',
    '2024-12-26|Boxing Day',
    '2024-12-31|New Years Eve PM auction closed'
)
Add-PmNoAuctionDates -Year 2025 -Entries @(
    '2025-01-01|New Years Day',
    '2025-04-18|Good Friday',
    '2025-04-21|Easter Monday',
    '2025-05-05|Early May Bank Holiday',
    '2025-05-26|Spring Bank Holiday',
    '2025-08-25|Summer Bank Holiday',
    '2025-12-24|Christmas Eve PM auction closed',
    '2025-12-25|Christmas Day',
    '2025-12-26|Boxing Day',
    '2025-12-31|New Years Eve PM auction closed'
)

if ($exceptions.Count -ne $expectedHolidayRows) {
    throw "Holiday contract mismatch: expected $expectedHolidayRows PM no-auction rows, found $($exceptions.Count)."
}
$exceptionByDate = @{}
foreach ($exception in $exceptions) {
    $key = $exception.Date.ToString('yyyy-MM-dd')
    if ($exceptionByDate.ContainsKey($key)) {
        throw "Duplicate PM no-auction date: $key"
    }
    $exceptionByDate[$key] = $exception
}

$runtimeLines = [Collections.Generic.List[string]]::new()
$runtimeLines.Add('date_london,pm_auction_status,auction_start_london,auction_start_utc,london_utc_offset_minutes')
$provenanceLines = [Collections.Generic.List[string]]::new()
$provenanceLines.Add('date_london,pm_auction_status,event_name,qualification,schedule_source_ids,clock_source_id')
$statusCounts = @{
    SCHEDULED_PM_AUCTION = 0
    NO_PM_AUCTION_HOLIDAY = 0
    NO_PM_AUCTION_WEEKEND = 0
}

for ($date = $coverageStart; $date -le $coverageEnd; $date = $date.AddDays(1)) {
    $dateText = $date.ToString('yyyy-MM-dd')
    $bounds = $dstBoundsByYear[$date.Year]
    $offsetMinutes = if ($date -ge $bounds.StartDate -and $date -lt $bounds.EndDate) { 60 } else { 0 }
    $annualSourceId = $annualSourceByYear[$date.Year]
    $status = ''
    $auctionLocal = ''
    $auctionUtc = ''
    $eventName = ''
    $qualification = ''
    $scheduleSourceIds = ''

    if ($date.DayOfWeek -in @([DayOfWeek]::Saturday, [DayOfWeek]::Sunday)) {
        $status = 'NO_PM_AUCTION_WEEKEND'
        $eventName = 'Weekend'
        $qualification = 'OFFICIAL_LONDON_BUSINESS_DAY_RULE'
        $scheduleSourceIds = 'IBA_PRECIOUS_METALS_METHODOLOGY_2026'
    }
    elseif ($exceptionByDate.ContainsKey($dateText)) {
        $exception = $exceptionByDate[$dateText]
        $status = 'NO_PM_AUCTION_HOLIDAY'
        $eventName = $exception.EventName
        $qualification = 'OFFICIAL_ANNUAL_PM_NO_AUCTION_ROW'
        $scheduleSourceIds = $exception.SourceId
    }
    else {
        $status = 'SCHEDULED_PM_AUCTION'
        $auctionLocal = '15:00:00'
        $utcHour = 15 - ($offsetMinutes / 60)
        $auctionUtc = '{0}T{1:00}:00:00Z' -f $dateText, $utcHour
        $eventName = 'Regular London business day'
        $qualification = 'OFFICIAL_DAILY_METHOD_PLUS_ANNUAL_CALENDAR_COMPLEMENT'
        $scheduleSourceIds = "$annualSourceId;IBA_PRECIOUS_METALS_METHODOLOGY_2026"
    }
    $statusCounts[$status]++
    $runtimeLines.Add(('{0},{1},{2},{3},{4}' -f $dateText, $status, $auctionLocal, $auctionUtc, $offsetMinutes))
    $provenanceLines.Add(('{0},{1},{2},{3},{4},{5}' -f
        $dateText,
        $status,
        $eventName,
        $qualification,
        $scheduleSourceIds,
        'IANA_TZDATA_2026C'))
}

if (($runtimeLines.Count - 1) -ne $expectedRuntimeRows -or
    $statusCounts.SCHEDULED_PM_AUCTION -ne $expectedScheduledRows -or
    $statusCounts.NO_PM_AUCTION_HOLIDAY -ne $expectedHolidayRows -or
    $statusCounts.NO_PM_AUCTION_WEEKEND -ne $expectedWeekendRows) {
    throw ('Runtime row contract mismatch: total={0}, scheduled={1}, holiday={2}, weekend={3}.' -f
        ($runtimeLines.Count - 1),
        $statusCounts.SCHEDULED_PM_AUCTION,
        $statusCounts.NO_PM_AUCTION_HOLIDAY,
        $statusCounts.NO_PM_AUCTION_WEEKEND)
}

$sourceLines = [Collections.Generic.List[string]]::new()
$sourceLines.Add('source_id,source_type,retrieved_date,official_url,official_sha256,governed_scope')
foreach ($source in ($sources | Sort-Object Id)) {
    $sourceLines.Add(('{0},{1},{2},{3},{4},{5}' -f
        $source.Id, $source.Type, $source.Retrieved, $source.Url, $source.Sha256, $source.Scope))
}

$transitionLines = [Collections.Generic.List[string]]::new()
$transitionLines.Add('transition_utc,offset_before_minutes,offset_after_minutes,abbreviation_after,source_id')
foreach ($transition in ($transitions | Sort-Object Instant)) {
    $transitionLines.Add(('{0},{1},{2},{3},{4}' -f
        $transition.Instant.UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ssZ'),
        $transition.Before,
        $transition.After,
        $transition.Abbreviation,
        'IANA_TZDATA_2026C'))
}

$gapLines = [Collections.Generic.List[string]]::new()
$gapLines.Add('gap_start,gap_end,gap_code,official_url,resolution_required')
$gapLines.Add('2018-01-01,2018-12-31,OFFICIAL_ANNUAL_PDF_NOT_BYTE_RETRIEVABLE,https://www.ice.com/publicdocs/Gold_Holiday_Calendar_2018.pdf,Obtain a byte-retrievable LBMA or ICE IBA primary document and pin its hash')
$gapLines.Add('2019-01-01,2019-12-31,OFFICIAL_ANNUAL_PDF_NOT_BYTE_RETRIEVABLE,https://www.ice.com/publicdocs/LBMA_Gold_Price_Holiday_Calendar_2019.pdf,Obtain a byte-retrievable LBMA or ICE IBA primary document and pin its hash')
$gapLines.Add('2020-01-01,2025-12-31,NO_HISTORICAL_OPERATIONAL_CANCELLATION_LEDGER,https://www.ice.com/publicdocs/Precious_Metals_Error_Policy.pdf,Bind an official date-level No Publication or cancellation history if actual occurrence rather than scheduled status is required')
if (($gapLines.Count - 1) -ne $expectedGapRows) {
    throw "Gap contract mismatch: expected $expectedGapRows rows, found $($gapLines.Count - 1)."
}

$runtimePath = Join-Path $OutputDirectory $runtimeName
$provenancePath = Join-Path $OutputDirectory $provenanceName
$sourcesPath = Join-Path $OutputDirectory $sourcesName
$transitionsPath = Join-Path $OutputDirectory $transitionsName
$gapsPath = Join-Path $OutputDirectory $gapsName
$manifestPath = Join-Path $OutputDirectory $manifestName
Write-Utf8NoBom -Path $runtimePath -Content (($runtimeLines -join "`n") + "`n")
Write-Utf8NoBom -Path $provenancePath -Content (($provenanceLines -join "`n") + "`n")
Write-Utf8NoBom -Path $sourcesPath -Content (($sourceLines -join "`n") + "`n")
Write-Utf8NoBom -Path $transitionsPath -Content (($transitionLines -join "`n") + "`n")
Write-Utf8NoBom -Path $gapsPath -Content (($gapLines -join "`n") + "`n")

$runtimeSha = Get-Sha256Lower -Path $runtimePath
$provenanceSha = Get-Sha256Lower -Path $provenancePath
$sourcesSha = Get-Sha256Lower -Path $sourcesPath
$transitionsSha = Get-Sha256Lower -Path $transitionsPath
$gapsSha = Get-Sha256Lower -Path $gapsPath
$manifestLines = @(
    '{',
    '  "schema_version": 1,',
    '  "calendar_id": "ICE_IBA_LBMA_GOLD_PRICE_PM",',
    '  "calendar_status": "PARTIAL_BLOCKED",',
    '  "calendar_semantics": "OFFICIAL_SCHEDULE_NOT_ACTUAL_PUBLICATION_LEDGER",',
    '  "timezone": "Europe/London",',
    '  "tzdb_release": "2026c",',
    '  "requested_coverage_start": "2018-01-01",',
    '  "requested_coverage_end": "2025-12-31",',
    '  "verified_schedule_start": "2020-01-01",',
    '  "verified_schedule_end": "2025-12-31",',
    '  "normal_pm_auction_start_london": "15:00:00",',
    '  "outside_verified_coverage_policy": "FAIL_CLOSED",',
    '  "verified_schedule_eligibility_policy": "SCHEDULED_PM_AUCTION_ROWS_ELIGIBLE",',
    '  "unexpected_cancellation_policy": "KNOWN_OFFICIAL_CANCELLATION_OR_NO_PUBLICATION_FAILS_CLOSED",',
    '  "historical_actual_occurrence_evidence": "PROMOTION_GAP_NONBLOCKING_FOR_TECHNICAL_SCHEDULE_ELIGIBILITY",',
    ('  "runtime_file": "{0}",' -f $runtimeName),
    ('  "runtime_rows": {0},' -f $expectedRuntimeRows),
    ('  "scheduled_pm_auction_rows": {0},' -f $expectedScheduledRows),
    ('  "no_pm_auction_holiday_rows": {0},' -f $expectedHolidayRows),
    ('  "no_pm_auction_weekend_rows": {0},' -f $expectedWeekendRows),
    ('  "runtime_sha256": "{0}",' -f $runtimeSha),
    ('  "provenance_file": "{0}",' -f $provenanceName),
    ('  "provenance_rows": {0},' -f $expectedRuntimeRows),
    ('  "provenance_sha256": "{0}",' -f $provenanceSha),
    ('  "sources_file": "{0}",' -f $sourcesName),
    ('  "source_rows": {0},' -f $expectedSourceRows),
    ('  "sources_sha256": "{0}",' -f $sourcesSha),
    ('  "timezone_transitions_file": "{0}",' -f $transitionsName),
    ('  "timezone_transition_rows": {0},' -f $expectedTransitionRows),
    ('  "timezone_transitions_sha256": "{0}",' -f $transitionsSha),
    ('  "gaps_file": "{0}",' -f $gapsName),
    ('  "gap_rows": {0},' -f $expectedGapRows),
    ('  "gaps_sha256": "{0}",' -f $gapsSha),
    '  "source_policy": "LBMA_ICE_IBA_PRIMARY_PLUS_CARD_AUTHORIZED_IANA_ONLY"',
    '}'
)
Write-Utf8NoBom -Path $manifestPath -Content (($manifestLines -join "`n") + "`n")

[pscustomobject]@{
    status = 'PARTIAL_BLOCKED'
    runtime_path = $runtimePath
    runtime_rows = $expectedRuntimeRows
    scheduled_pm_auction_rows = $expectedScheduledRows
    no_pm_auction_holiday_rows = $expectedHolidayRows
    no_pm_auction_weekend_rows = $expectedWeekendRows
    runtime_sha256 = $runtimeSha
    provenance_path = $provenancePath
    provenance_sha256 = $provenanceSha
    sources_path = $sourcesPath
    source_rows = $expectedSourceRows
    sources_sha256 = $sourcesSha
    timezone_transitions_path = $transitionsPath
    timezone_transition_rows = $expectedTransitionRows
    timezone_transitions_sha256 = $transitionsSha
    gaps_path = $gapsPath
    gap_rows = $expectedGapRows
    gaps_sha256 = $gapsSha
    manifest_path = $manifestPath
    manifest_sha256 = Get-Sha256Lower -Path $manifestPath
    official_sources_verified = [bool]$VerifyOfficialSources
}
