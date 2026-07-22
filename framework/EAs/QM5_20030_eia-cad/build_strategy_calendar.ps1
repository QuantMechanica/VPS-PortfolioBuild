[CmdletBinding()]
param(
    [string]$ArchiveUrl = 'https://www.eia.gov/petroleum/supply/weekly/archive/',
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'data')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$calendarName = 'QM5_20030_eia_calendar_20180110_20251231.csv'
$provenanceName = 'QM5_20030_eia_calendar_provenance.csv'
$expectedArchiveRows = 416
$expectedEligibleRows = 352
$expectedExcludedShiftRows = 64
$firstYear = 2018
$lastYear = 2025
$scheduleUrl = 'https://www.eia.gov/petroleum/supply/weekly/schedule.php'

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

$archiveResponse = Invoke-WebRequest -UseBasicParsing -Uri $ArchiveUrl
$pattern = '/petroleum/supply/weekly/archive/(?<year>20\d\d)/(?<date>\d{4}_\d{2}_\d{2})/wpsr_\k<date>\.php'
$archiveMatches = [regex]::Matches([string]$archiveResponse.Content, $pattern)

$releaseRows = @(
    $archiveMatches |
        ForEach-Object {
            $year = [int]$_.Groups['year'].Value
            if ($year -lt $firstYear -or $year -gt $lastYear) {
                return
            }
            $dateToken = $_.Groups['date'].Value
            [pscustomobject]@{
                Date = [datetime]::ParseExact(
                    $dateToken,
                    'yyyy_MM_dd',
                    [Globalization.CultureInfo]::InvariantCulture
                )
                Url = [Uri]::new([Uri]$ArchiveUrl, $_.Value).AbsoluteUri
            }
        } |
        Sort-Object Date -Unique
)

if ($releaseRows.Count -ne $expectedArchiveRows) {
    throw "EIA archive contract mismatch: expected $expectedArchiveRows releases for 2018-2025, found $($releaseRows.Count)."
}

$newYork = [TimeZoneInfo]::FindSystemTimeZoneById('Eastern Standard Time')
$eligible = [Collections.Generic.List[object]]::new()
$excluded = [Collections.Generic.List[object]]::new()

foreach ($release in $releaseRows) {
    if ($release.Date.DayOfWeek -ne [DayOfWeek]::Wednesday) {
        $excluded.Add([pscustomobject]@{
            Date = $release.Date
            Url = $release.Url
            Reason = 'NON_STANDARD_RELEASE_EXACT_TIME_NOT_PROVEN'
        })
        continue
    }

    # EIA's official schedule defines 10:30 America/New_York as the standard
    # Wednesday release time. Holiday-shifted/non-Wednesday issues are excluded
    # above because their historical exact times are not present in the archive
    # index and must never be guessed.
    $localRelease = [datetime]::SpecifyKind(
        $release.Date.Date.AddHours(10).AddMinutes(30),
        [DateTimeKind]::Unspecified
    )
    $utcRelease = [TimeZoneInfo]::ConvertTimeToUtc($localRelease, $newYork)
    $eligible.Add([pscustomobject]@{
        DateTimeUtc = $utcRelease
        Url = $release.Url
    })
}

if ($eligible.Count -ne $expectedEligibleRows -or $excluded.Count -ne $expectedExcludedShiftRows) {
    throw "EIA eligibility contract mismatch: expected eligible=$expectedEligibleRows/excluded=$expectedExcludedShiftRows, found eligible=$($eligible.Count)/excluded=$($excluded.Count)."
}

$calendarLines = [Collections.Generic.List[string]]::new()
$calendarLines.Add('datetime,currency,event_name,impact')
foreach ($row in $eligible) {
    $calendarLines.Add(('{0},USD,Crude Oil Inventories,high' -f $row.DateTimeUtc.ToString('yyyy-MM-dd HH:mm:ss')))
}

$provenanceLines = [Collections.Generic.List[string]]::new()
$provenanceLines.Add('event_utc,event_type,qualification,official_release_url,official_schedule_url')
foreach ($row in $eligible) {
    $provenanceLines.Add(('{0},EIA,OFFICIAL_ARCHIVE_STANDARD_WEDNESDAY_1030_NY,{1},{2}' -f
        $row.DateTimeUtc.ToString('yyyy-MM-dd HH:mm:ss'), $row.Url, $scheduleUrl))
}
foreach ($row in $excluded) {
    $provenanceLines.Add(('{0},EIA_EXCLUDED,{1},{2},{3}' -f
        $row.Date.ToString('yyyy-MM-dd'), $row.Reason, $row.Url, $scheduleUrl))
}

$calendarPath = Join-Path $OutputDirectory $calendarName
$provenancePath = Join-Path $OutputDirectory $provenanceName
Write-Utf8NoBom -Path $calendarPath -Content (($calendarLines -join "`n") + "`n")
Write-Utf8NoBom -Path $provenancePath -Content (($provenanceLines -join "`n") + "`n")

[pscustomobject]@{
    calendar_path = $calendarPath
    calendar_rows = $eligible.Count
    calendar_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $calendarPath).Hash.ToLowerInvariant()
    provenance_path = $provenancePath
    provenance_rows = $eligible.Count + $excluded.Count
    provenance_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $provenancePath).Hash.ToLowerInvariant()
    excluded_shifted_releases = $excluded.Count
    api_status = 'DATA_GAP_NO_EXACT_HISTORICAL_TIMESTAMP_PROVENANCE'
}
