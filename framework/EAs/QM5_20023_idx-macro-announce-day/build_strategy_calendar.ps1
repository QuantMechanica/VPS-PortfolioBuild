[CmdletBinding()]
param(
    [string]$SharedCalendarPath = 'D:\QM\data\news_calendar\news_calendar_2015_2025.csv',
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'data'),
    [switch]$VerifyBlsArchiveIndexes
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$coverageStart = [datetime]'2015-01-01'
$coverageEnd = [datetime]'2025-04-04'
$expectedSharedCalendarSha256 = '8e898ca1c4aed5fbc4cbe43fc176e8d8595c2e6f5f05c2984c2468527d4f5b0d'
$calendarName = 'QM5_20023_announcement_calendar_20150101_20250404.csv'
$provenanceName = 'QM5_20023_announcement_calendar_provenance.csv'
$calendarPath = Join-Path $OutputDirectory $calendarName
$provenancePath = Join-Path $OutputDirectory $provenanceName
$culture = [Globalization.CultureInfo]::InvariantCulture
$webHeaders = @{
    'User-Agent' = 'Mozilla/5.0 (compatible; QuantMechanica calendar verification)'
}

function Get-EasternTimeZone {
    foreach ($id in @('Eastern Standard Time', 'America/New_York')) {
        try {
            return [TimeZoneInfo]::FindSystemTimeZoneById($id)
        }
        catch {
            continue
        }
    }
    throw 'Unable to resolve the US Eastern time zone.'
}

function Convert-EasternReleaseToUtc {
    param(
        [Parameter(Mandatory = $true)]
        [datetime]$Date,
        [Parameter(Mandatory = $true)]
        [int]$Hour,
        [Parameter(Mandatory = $true)]
        [int]$Minute,
        [Parameter(Mandatory = $true)]
        [TimeZoneInfo]$EasternTimeZone
    )

    $local = [datetime]::SpecifyKind(
        $Date.Date.AddHours($Hour).AddMinutes($Minute),
        [DateTimeKind]::Unspecified
    )
    return [TimeZoneInfo]::ConvertTimeToUtc($local, $EasternTimeZone)
}

function Convert-RowsToCsvText {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Rows
    )

    return (($Rows | ConvertTo-Csv -NoTypeInformation -UseQuotes AsNeeded) -join "`n") + "`n"
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

function Get-BlsReleaseDates {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Slug,
        [Parameter(Mandatory = $true)]
        [string]$IndexUrl
    )

    $response = Invoke-WebRequest -Uri $IndexUrl -Headers $webHeaders -UseBasicParsing -TimeoutSec 60
    if ($response.StatusCode -ne 200) {
        throw "BLS archive request failed: $IndexUrl returned HTTP $($response.StatusCode)."
    }

    $pattern = "(?:https?://www\.bls\.gov)?/news\.release/archives/$Slug" + '_(\d{8})\.htm'
    return @(
        [regex]::Matches($response.Content, $pattern, 'IgnoreCase') |
            ForEach-Object {
                [datetime]::ParseExact($_.Groups[1].Value, 'MMddyyyy', $culture)
            } |
            Where-Object { $_ -ge $coverageStart -and $_ -le $coverageEnd } |
            Sort-Object -Unique
    )
}

function Get-FomcStatementLinks {
    $links = [ordered]@{}

    foreach ($year in 2015..2019) {
        $indexUrl = "https://www.federalreserve.gov/monetarypolicy/fomchistorical$year.htm"
        $response = Invoke-WebRequest -Uri $indexUrl -Headers $webHeaders -UseBasicParsing -TimeoutSec 60
        if ($response.StatusCode -ne 200) {
            throw "Federal Reserve archive request failed: $indexUrl returned HTTP $($response.StatusCode)."
        }
        $pattern = '(?:https?://www\.federalreserve\.gov)?/newsevents/pressreleases/monetary(\d{8})a\.htm'
        foreach ($match in [regex]::Matches($response.Content, $pattern, 'IgnoreCase')) {
            $token = $match.Groups[1].Value
            $date = [datetime]::ParseExact($token, 'yyyyMMdd', $culture)
            if ($date -ge $coverageStart -and $date -le $coverageEnd) {
                $links[$token] = [pscustomobject]@{
                    Date = $date
                    Url = "https://www.federalreserve.gov/newsevents/pressreleases/monetary${token}a.htm"
                    IndexUrl = $indexUrl
                }
            }
        }
    }

    foreach ($year in 2020..2025) {
        $indexUrl = "https://www.federalreserve.gov/newsevents/pressreleases/$year-press-fomc.htm"
        $response = Invoke-WebRequest -Uri $indexUrl -Headers $webHeaders -UseBasicParsing -TimeoutSec 60
        if ($response.StatusCode -ne 200) {
            throw "Federal Reserve press-release request failed: $indexUrl returned HTTP $($response.StatusCode)."
        }
        $pattern = '<a[^>]+href="([^"]*monetary(\d{8})a\.htm)"[^>]*>(.*?)</a>'
        foreach ($match in [regex]::Matches($response.Content, $pattern, 'IgnoreCase,Singleline')) {
            $title = ([regex]::Replace($match.Groups[3].Value, '<[^>]+>', '') -replace '\s+', ' ').Trim()
            if ($title -ne 'Federal Reserve issues FOMC statement') {
                continue
            }
            $token = $match.Groups[2].Value
            $date = [datetime]::ParseExact($token, 'yyyyMMdd', $culture)
            if ($date -ge $coverageStart -and $date -le $coverageEnd) {
                $links[$token] = [pscustomobject]@{
                    Date = $date
                    Url = "https://www.federalreserve.gov/newsevents/pressreleases/monetary${token}a.htm"
                    IndexUrl = $indexUrl
                }
            }
        }
    }

    return $links
}

if (-not (Test-Path -LiteralPath $SharedCalendarPath -PathType Leaf)) {
    throw "Shared calendar not found: $SharedCalendarPath"
}
$sharedCalendarSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $SharedCalendarPath).Hash.ToLowerInvariant()
if ($sharedCalendarSha256 -ne $expectedSharedCalendarSha256) {
    throw "Shared calendar hash mismatch: expected $expectedSharedCalendarSha256, found $sharedCalendarSha256."
}

$shared = @(Import-Csv -LiteralPath $SharedCalendarPath)
$eastern = Get-EasternTimeZone
$calendarRows = [Collections.Generic.List[object]]::new()
$provenanceRows = [Collections.Generic.List[object]]::new()

$blsFamilies = [ordered]@{
    'Non-Farm Employment Change' = @{
        Slug = 'empsit'
        IndexUrl = 'https://www.bls.gov/bls/news-release/empsit.htm'
    }
    'CPI m/m' = @{
        Slug = 'cpi'
        IndexUrl = 'https://www.bls.gov/bls/news-release/cpi.htm'
    }
    'PPI m/m' = @{
        Slug = 'ppi'
        IndexUrl = 'https://www.bls.gov/bls/news-release/ppi.htm'
    }
}

foreach ($eventName in $blsFamilies.Keys) {
    $meta = $blsFamilies[$eventName]
    $sourceRows = @(
        $shared |
            Where-Object { $_.currency -eq 'USD' -and $_.event_name -eq $eventName } |
            Sort-Object datetime
    )
    $officialDates = @()
    if ($VerifyBlsArchiveIndexes) {
        $officialDates = @(Get-BlsReleaseDates -Slug $meta.Slug -IndexUrl $meta.IndexUrl)
        if ($officialDates.Count -ne $sourceRows.Count) {
            throw "$eventName row-count mismatch: official=$($officialDates.Count), shared=$($sourceRows.Count)."
        }
    }

    $correctedCount = 0
    for ($index = 0; $index -lt $sourceRows.Count; $index++) {
        $source = $sourceRows[$index]
        $old = [datetime]::ParseExact($source.datetime, 'yyyy-MM-dd HH:mm:ss', $culture)
        # The source-hash audit against the three BLS release archives found a
        # non-uniform timezone serialization defect: all 19:30/20:30 rows are
        # one day early, while all 12:30/13:30 rows already have the true date.
        # Keep this conditional and hash-pinned; never apply an unconditional
        # +1-day transform to the shared file.
        $officialDate = switch ($old.ToString('HH:mm', $culture)) {
            { $_ -in @('19:30', '20:30') } { $old.Date.AddDays(1); break }
            { $_ -in @('12:30', '13:30') } { $old.Date; break }
            default { throw "$eventName has an unaudited source time at $($source.datetime)." }
        }
        if ($VerifyBlsArchiveIndexes -and $officialDate.Date -ne $officialDates[$index].Date) {
            throw "$eventName archive mismatch at $($source.datetime): mapped=$($officialDate.ToString('yyyy-MM-dd')), archive=$($officialDates[$index].ToString('yyyy-MM-dd'))."
        }
        $dayDelta = [int]($officialDate.Date - $old.Date).TotalDays
        if ($dayDelta -notin @(0, 1)) {
            throw "$eventName unexpected source-date delta at $($source.datetime): $dayDelta days."
        }
        if ($dayDelta -eq 1) {
            $correctedCount++
        }

        $releaseUtc = Convert-EasternReleaseToUtc `
            -Date $officialDate `
            -Hour 8 `
            -Minute 30 `
            -EasternTimeZone $eastern
        $dateToken = $officialDate.ToString('MMddyyyy', $culture)
        $sourceUrl = "https://www.bls.gov/news.release/archives/$($meta.Slug)_$dateToken.htm"
        $newTimestamp = $releaseUtc.ToString('yyyy-MM-dd HH:mm:ss', $culture)
        $calendarRows.Add([pscustomobject][ordered]@{
            datetime = $newTimestamp
            currency = 'USD'
            event_name = $eventName
            impact = 'high'
        })
        $provenanceRows.Add([pscustomobject][ordered]@{
            datetime = $newTimestamp
            event_name = $eventName
            source_row_1 = "$($source.datetime)|$($source.event_name)"
            source_row_2 = ''
            action = $(if ($dayDelta -eq 0) { 'DATE_VERIFIED' } else { 'DATE_CORRECTED' })
            source_url = $sourceUrl
            source_index_url = $meta.IndexUrl
        })
    }

    $expectedCorrectedCount = switch ($eventName) {
        'Non-Farm Employment Change' { 122 }
        'CPI m/m' { 122 }
        'PPI m/m' { 100 }
        default { throw "No expected correction count for $eventName." }
    }
    if ($correctedCount -ne $expectedCorrectedCount) {
        throw "$eventName correction-count mismatch: expected=$expectedCorrectedCount, found=$correctedCount."
    }
}

$fomcRows = @(
    $shared |
        Where-Object {
            $_.currency -eq 'USD' -and
            $_.event_name -in @('FOMC Statement', 'Federal Funds Rate')
        } |
        Sort-Object datetime, event_name
)
if (($fomcRows.Count % 2) -ne 0) {
    throw "Expected an even number of FOMC alias rows; found $($fomcRows.Count)."
}

$fomcLinks = Get-FomcStatementLinks
$usedFomcTokens = [Collections.Generic.HashSet[string]]::new()
$unscheduledFomcTokens = @('20200303', '20200315')
for ($index = 0; $index -lt $fomcRows.Count; $index += 2) {
    $pair = @($fomcRows[$index], $fomcRows[$index + 1])
    $pairNames = @($pair.event_name | Sort-Object -Unique)
    if ($pairNames.Count -ne 2 -or
        'FOMC Statement' -notin $pairNames -or
        'Federal Funds Rate' -notin $pairNames) {
        throw "FOMC alias pair malformed at source indexes $index/$($index + 1)."
    }

    $pairDates = @(
        $pair | ForEach-Object {
            [datetime]::ParseExact($_.datetime, 'yyyy-MM-dd HH:mm:ss', $culture)
        }
    )
    $lower = ($pairDates | Sort-Object | Select-Object -First 1).Date.AddDays(-1)
    $upper = ($pairDates | Sort-Object | Select-Object -Last 1).Date.AddDays(1)
    $candidates = @(
        $fomcLinks.GetEnumerator() |
            Where-Object {
                $_.Value.Date -ge $lower -and
                $_.Value.Date -le $upper -and
                -not $usedFomcTokens.Contains($_.Key)
            }
    )
    if ($candidates.Count -ne 1) {
        $sourceText = ($pair.datetime -join ', ')
        throw "Expected one official FOMC statement near [$sourceText]; found $($candidates.Count)."
    }

    $candidate = $candidates[0]
    [void]$usedFomcTokens.Add($candidate.Key)
    $officialDate = $candidate.Value.Date
    $localHour = 14
    if ($candidate.Key -eq '20200303') {
        $localHour = 10
    }
    elseif ($candidate.Key -eq '20200315') {
        $localHour = 17
    }
    $releaseUtc = Convert-EasternReleaseToUtc `
        -Date $officialDate `
        -Hour $localHour `
        -Minute 0 `
        -EasternTimeZone $eastern
    $newTimestamp = $releaseUtc.ToString('yyyy-MM-dd HH:mm:ss', $culture)
    $sourceDatesCorrect = @($pairDates | Where-Object { $_.Date -eq $officialDate.Date }).Count
    $isUnscheduled = $candidate.Key -in $unscheduledFomcTokens
    $action = if ($isUnscheduled) {
        'EXCLUDED_UNSCHEDULED_FOMC'
    }
    elseif ($sourceDatesCorrect -eq $pairDates.Count) {
        'ALIASES_COLLAPSED_DATE_VERIFIED'
    }
    else {
        'DATE_CORRECTED_AND_ALIASES_COLLAPSED'
    }

    if (-not $isUnscheduled) {
        $calendarRows.Add([pscustomobject][ordered]@{
            datetime = $newTimestamp
            currency = 'USD'
            event_name = 'FOMC Statement'
            impact = 'high'
        })
    }
    $sourceIndexUrl = if ($isUnscheduled) {
        'https://www.federalreserve.gov/monetarypolicy/fomchistorical2020.htm'
    }
    else {
        $candidate.Value.IndexUrl
    }
    $provenanceRows.Add([pscustomobject][ordered]@{
        datetime = $newTimestamp
        event_name = 'FOMC Statement'
        source_row_1 = "$($pair[0].datetime)|$($pair[0].event_name)"
        source_row_2 = "$($pair[1].datetime)|$($pair[1].event_name)"
        action = $action
        source_url = $candidate.Value.Url
        source_index_url = $sourceIndexUrl
    })
}

$unusedFomcTokens = @(
    $fomcLinks.Keys |
        Where-Object { -not $usedFomcTokens.Contains($_) } |
        Sort-Object
)
$expectedUnusedFomcTokens = @('20191011', '20200323')
if (($unusedFomcTokens -join ',') -ne ($expectedUnusedFomcTokens -join ',')) {
    throw "Unexpected unmatched FOMC statement dates: $($unusedFomcTokens -join ',')."
}

$calendarRows = @($calendarRows | Sort-Object datetime, event_name)
$provenanceRows = @($provenanceRows | Sort-Object datetime, event_name)
if ($calendarRows.Count -ne 451) {
    throw "Expected 451 scheduled scoped calendar rows; generated $($calendarRows.Count)."
}
if ($provenanceRows.Count -ne 453) {
    throw "Expected 453 provenance rows (including two unscheduled exclusions); generated $($provenanceRows.Count)."
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
Write-Utf8NoBom -Path $calendarPath -Content (Convert-RowsToCsvText -Rows $calendarRows)
Write-Utf8NoBom -Path $provenancePath -Content (Convert-RowsToCsvText -Rows $provenanceRows)

$calendarHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $calendarPath).Hash.ToLowerInvariant()
$provenanceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $provenancePath).Hash.ToLowerInvariant()
[pscustomobject]@{
    status = 'PASS'
    shared_calendar = $SharedCalendarPath
    shared_calendar_sha256 = $sharedCalendarSha256
    calendar_path = $calendarPath
    calendar_rows = $calendarRows.Count
    calendar_sha256 = $calendarHash
    provenance_path = $provenancePath
    provenance_rows = $provenanceRows.Count
    provenance_sha256 = $provenanceHash
    coverage_start = $coverageStart.ToString('yyyy-MM-dd', $culture)
    coverage_end = $coverageEnd.ToString('yyyy-MM-dd', $culture)
    bls_archive_indexes_verified_live = [bool]$VerifyBlsArchiveIndexes
    excluded_unscheduled_fomc_statements = $unscheduledFomcTokens
    unused_nondecision_fomc_statements = $unusedFomcTokens
}
