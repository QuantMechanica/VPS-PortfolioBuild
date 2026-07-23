[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'data'),
    [switch]$VerifyOfficialSources
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$calendarName = 'QM5_NYSE_US_cash_session_exceptions_20180101_20251231.csv'
$provenanceName = 'QM5_NYSE_US_cash_session_exceptions_provenance.csv'
$sourcesName = 'QM5_NYSE_US_cash_session_exceptions_sources.csv'
$manifestName = 'QM5_NYSE_US_cash_session_exceptions_manifest.json'
$coverageStart = [datetime]::ParseExact('2018-01-01', 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
$coverageEnd = [datetime]::ParseExact('2025-12-31', 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
$expectedFullCloseRows = 77
$expectedEarlyCloseRows = 18
$expectedSourceRows = 10

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

$sources = @(
    [pscustomobject]@{
        Id = 'NYSE_2018_CALENDAR'
        Published = '2017-11-27'
        ReleaseUrl = 'https://ir.theice.com/press/news-details/2017/NYSE-Group-Announces-2018-2019-and-2020-Holiday-and-Early-Closings-Calendar/default.aspx'
        PdfUrl = 'https://s2.q4cdn.com/154085107/files/doc_news/archive/27aaa58b-ebcb-4f53-b505-aee992f54968.pdf'
        PdfSha256 = 'b13c0181091b10164319992cb537e948e2d4ee8ceff71f61fdfe7989ccd89812'
        Scope = 'NYSE Group cash equity holiday and early-close calendar for 2018'
    }
    [pscustomobject]@{
        Id = 'NYSE_2019_CALENDAR'
        Published = '2018-12-04'
        ReleaseUrl = 'https://ir.theice.com/press/news-details/2018/NYSE-Group-Announces-2019-2020-and-2021-Holiday-and-Early-Closings-Calendar/default.aspx'
        PdfUrl = 'https://s2.q4cdn.com/154085107/files/doc_news/archive/15638cee-2935-4422-bcb4-a3733587eb8b.pdf'
        PdfSha256 = 'bfc91ff0fef5ecbdce022898e1ae622579c06257918a0bb9995750dc5bafb58a'
        Scope = 'NYSE Group cash equity holiday and early-close calendar for 2019'
    }
    [pscustomobject]@{
        Id = 'NYSE_2020_CALENDAR'
        Published = '2019-12-09'
        ReleaseUrl = 'https://ir.theice.com/press/news-details/2019/NYSE-Group-Announces-2020-2021-and-2022-Holiday-and-Early-Closings-Calendar/default.aspx'
        PdfUrl = 'https://s2.q4cdn.com/154085107/files/doc_news/archive/91a5230f-7233-4a93-b30a-79c9411ebdbe.pdf'
        PdfSha256 = '685a189e56b95efda98e8c7cbcb17a661de6e4aa49b9f78b1aa943925a0ac9c2'
        Scope = 'NYSE Group cash equity holiday and early-close calendar for 2020'
    }
    [pscustomobject]@{
        Id = 'NYSE_2021_CALENDAR'
        Published = '2020-12-28'
        ReleaseUrl = 'https://ir.theice.com/press/news-details/2020/NYSE-Group-Announces-2021-2022-and-2023-Holiday-and-Early-Closings-Calendar/default.aspx'
        PdfUrl = 'https://s2.q4cdn.com/154085107/files/doc_news/NYSE-Group-Announces-2021-2022-and-2023-Holiday-and-Early-Closings-Calendar-2020.pdf'
        PdfSha256 = '4419cb783586369dc58003e630d81095a23991eec1cb31308c7b2e6099ceeb49'
        Scope = 'NYSE Group cash equity holiday and early-close calendar for 2021'
    }
    [pscustomobject]@{
        Id = 'NYSE_2022_CALENDAR'
        Published = '2021-12-27'
        ReleaseUrl = 'https://ir.theice.com/press/news-details/2021/NYSE-Group-Announces-2022-2023-and-2024-Holiday-and-Early-Closings-Calendar/default.aspx'
        PdfUrl = 'https://s2.q4cdn.com/154085107/files/doc_news/NYSE-Group-Announces-2022-2023-and-2024-Holiday-and-Early-Closings-Calendar-2021.pdf'
        PdfSha256 = 'b8537e458aa0f7123c014056da9260d08f3e874b32f7f617d99451f36e049e90'
        Scope = 'NYSE Group cash equity holiday and early-close calendar for 2022 including Juneteenth'
    }
    [pscustomobject]@{
        Id = 'NYSE_2023_CALENDAR'
        Published = '2022-12-21'
        ReleaseUrl = 'https://ir.theice.com/press/news-details/2022/NYSE-Group-Announces-2023-2024-and-2025-Holiday-and-Early-Closings-Calendar/default.aspx'
        PdfUrl = 'https://s2.q4cdn.com/154085107/files/doc_news/NYSE-Group-Announces-2023-2024-and-2025-Holiday-and-Early-Closings-Calendar-2022.pdf'
        PdfSha256 = '8092099cfc8c408089257004d61da3fba4ca6b7161ed722aac1189fe83a67186'
        Scope = 'NYSE Group cash equity holiday and early-close calendar for 2023'
    }
    [pscustomobject]@{
        Id = 'NYSE_2024_CALENDAR'
        Published = '2023-11-10'
        ReleaseUrl = 'https://ir.theice.com/press/news-details/2023/NYSE-Group-Announces-2024-2025-and-2026-Holiday-and-Early-Closings-Calendar/default.aspx'
        PdfUrl = 'https://s2.q4cdn.com/154085107/files/doc_news/NYSE-Group-Announces-2024-2025-and-2026-Holiday-and-Early-Closings-Calendar-2023.pdf'
        PdfSha256 = 'a379433b12a84c1b898075be0c04343ffaef45b6d47a2fd4283747cdcd2bd64f'
        Scope = 'NYSE Group cash equity holiday and early-close calendar for 2024'
    }
    [pscustomobject]@{
        Id = 'NYSE_2025_CALENDAR'
        Published = '2024-11-08'
        ReleaseUrl = 'https://ir.theice.com/press/news-details/2024/NYSE-Group-Announces-2025-2026-and-2027-Holiday-and-Early-Closings-Calendar/default.aspx'
        PdfUrl = 'https://s2.q4cdn.com/154085107/files/doc_news/NYSE-Group-Announces-2025-2026-and-2027-Holiday-and-Early-Closings-Calendar-2024.pdf'
        PdfSha256 = '6d719aaaf827c909f362725293c8e932f1b879687e4705eeb8a16f7201fe3355'
        Scope = 'NYSE Group cash equity holiday and early-close calendar for 2025'
    }
    [pscustomobject]@{
        Id = 'NYSE_2018_BUSH_MOURNING'
        Published = '2018-12-01'
        ReleaseUrl = 'https://ir.theice.com/press/news-details/2018/New-York-Stock-Exchange-to-Honor-President-George-H-W-Bush/default.aspx'
        PdfUrl = 'https://s2.q4cdn.com/154085107/files/doc_news/archive/266fafb2-a85c-433a-8350-0760d895b49c.pdf'
        PdfSha256 = '46e28f7864ed20dac04b3acfc51a4cbea6937f57ba01d427226e6837c8785b7c'
        Scope = 'NYSE Group full closure on 2018-12-05 for National Day of Mourning'
    }
    [pscustomobject]@{
        Id = 'NYSE_2025_CARTER_MOURNING'
        Published = '2024-12-30'
        ReleaseUrl = 'https://ir.theice.com/press/news-details/2024/The-New-York-Stock-Exchange-Will-Close-Markets-on-January-9-to-Honor-the-Passing-of-Former-President-Jimmy-Carter-on-National-Day-of-Mourning/default.aspx'
        PdfUrl = 'https://s2.q4cdn.com/154085107/files/doc_news/The-New-York-Stock-Exchange-Will-Close-Markets-on-January-9-to-Honor-the-Passing-of-Former-President-Jimmy-Carter-on-National-Day-of--IGCRS.pdf'
        PdfSha256 = 'b83882b2f29554a969c30f5a48c37eff3b6baab449273bfdb3d8c3df62244c69'
        Scope = 'NYSE Group full closure on 2025-01-09 for National Day of Mourning'
    }
)

if ($sources.Count -ne $expectedSourceRows) {
    throw "Source contract mismatch: expected $expectedSourceRows sources, found $($sources.Count)."
}

$sourceById = @{}
foreach ($source in $sources) {
    if ($sourceById.ContainsKey($source.Id)) {
        throw "Duplicate source id: $($source.Id)"
    }
    $releaseUri = [Uri]$source.ReleaseUrl
    $pdfUri = [Uri]$source.PdfUrl
    if ($releaseUri.Scheme -ne 'https' -or $releaseUri.Host -ne 'ir.theice.com') {
        throw "Non-official release URL for $($source.Id): $($source.ReleaseUrl)"
    }
    if ($pdfUri.Scheme -ne 'https' -or $pdfUri.Host -ne 's2.q4cdn.com') {
        throw "Unexpected official-document host for $($source.Id): $($source.PdfUrl)"
    }
    if ($source.PdfSha256 -notmatch '^[0-9a-f]{64}$') {
        throw "Invalid pinned PDF SHA-256 for $($source.Id)."
    }
    $sourceById[$source.Id] = $source
}

if ($VerifyOfficialSources) {
    $http = [Net.Http.HttpClient]::new()
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        foreach ($source in $sources) {
            # ir.theice.com intentionally returns HTTP 403 to non-browser
            # clients.  The immutable PDF linked by that official release is
            # the byte-level evidence artifact and is therefore the object we
            # verify.  Release URL origin/host validation is performed above.
            $pdfBytes = $http.GetByteArrayAsync($source.PdfUrl).GetAwaiter().GetResult()
            if ($pdfBytes.Length -lt 1000) {
                throw "Official PDF is unexpectedly small for $($source.Id): $($pdfBytes.Length) bytes."
            }
            $actual = [BitConverter]::ToString($sha.ComputeHash($pdfBytes)).Replace('-', '').ToLowerInvariant()
            if ($actual -ne $source.PdfSha256) {
                throw "Official PDF hash mismatch for $($source.Id): expected $($source.PdfSha256), found $actual."
            }
        }
    }
    finally {
        $sha.Dispose()
        $http.Dispose()
    }
}

$rows = [Collections.Generic.List[object]]::new()

function Add-CalendarRows {
    param(
        [Parameter(Mandatory)][string]$SourceId,
        [Parameter(Mandatory)][ValidateSet('FULL_CLOSE', 'EARLY_CLOSE')][string]$SessionType,
        [Parameter(Mandatory)][string[]]$Entries,
        [Parameter(Mandatory)][string]$Qualification
    )

    if (-not $sourceById.ContainsKey($SourceId)) {
        throw "Unknown source id: $SourceId"
    }
    foreach ($entry in $Entries) {
        $parts = $entry.Split('|', 2)
        if ($parts.Count -ne 2) {
            throw "Malformed curated calendar entry: $entry"
        }
        $date = [datetime]::ParseExact($parts[0], 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
        if ($date -lt $coverageStart -or $date -gt $coverageEnd) {
            throw "Calendar entry is outside the governed coverage window: $entry"
        }
        $rows.Add([pscustomobject]@{
            Date = $date
            SessionType = $SessionType
            OpenTime = if ($SessionType -eq 'EARLY_CLOSE') { '09:30' } else { '' }
            CloseTime = if ($SessionType -eq 'EARLY_CLOSE') { '13:00' } else { '' }
            EventName = $parts[1]
            SourceId = $SourceId
            Qualification = $Qualification
        })
    }
}

Add-CalendarRows -SourceId 'NYSE_2018_CALENDAR' -SessionType FULL_CLOSE -Qualification 'OFFICIAL_SCHEDULED_FULL_CLOSE' -Entries @(
    '2018-01-01|New Years Day',
    '2018-01-15|Martin Luther King Jr Day',
    '2018-02-19|Washingtons Birthday',
    '2018-03-30|Good Friday',
    '2018-05-28|Memorial Day',
    '2018-07-04|Independence Day',
    '2018-09-03|Labor Day',
    '2018-11-22|Thanksgiving Day',
    '2018-12-25|Christmas Day'
)
Add-CalendarRows -SourceId 'NYSE_2018_CALENDAR' -SessionType EARLY_CLOSE -Qualification 'OFFICIAL_SCHEDULED_1300_ET_CLOSE' -Entries @(
    '2018-07-03|Independence Day early close',
    '2018-11-23|Day after Thanksgiving early close',
    '2018-12-24|Christmas Eve early close'
)
Add-CalendarRows -SourceId 'NYSE_2018_BUSH_MOURNING' -SessionType FULL_CLOSE -Qualification 'OFFICIAL_UNSCHEDULED_FULL_CLOSE' -Entries @(
    '2018-12-05|National Day of Mourning for President George H W Bush'
)

Add-CalendarRows -SourceId 'NYSE_2019_CALENDAR' -SessionType FULL_CLOSE -Qualification 'OFFICIAL_SCHEDULED_FULL_CLOSE' -Entries @(
    '2019-01-01|New Years Day',
    '2019-01-21|Martin Luther King Jr Day',
    '2019-02-18|Washingtons Birthday',
    '2019-04-19|Good Friday',
    '2019-05-27|Memorial Day',
    '2019-07-04|Independence Day',
    '2019-09-02|Labor Day',
    '2019-11-28|Thanksgiving Day',
    '2019-12-25|Christmas Day'
)
Add-CalendarRows -SourceId 'NYSE_2019_CALENDAR' -SessionType EARLY_CLOSE -Qualification 'OFFICIAL_SCHEDULED_1300_ET_CLOSE' -Entries @(
    '2019-07-03|Independence Day early close',
    '2019-11-29|Day after Thanksgiving early close',
    '2019-12-24|Christmas Eve early close'
)

Add-CalendarRows -SourceId 'NYSE_2020_CALENDAR' -SessionType FULL_CLOSE -Qualification 'OFFICIAL_SCHEDULED_FULL_CLOSE' -Entries @(
    '2020-01-01|New Years Day',
    '2020-01-20|Martin Luther King Jr Day',
    '2020-02-17|Washingtons Birthday',
    '2020-04-10|Good Friday',
    '2020-05-25|Memorial Day',
    '2020-07-03|Independence Day observed',
    '2020-09-07|Labor Day',
    '2020-11-26|Thanksgiving Day',
    '2020-12-25|Christmas Day'
)
Add-CalendarRows -SourceId 'NYSE_2020_CALENDAR' -SessionType EARLY_CLOSE -Qualification 'OFFICIAL_SCHEDULED_1300_ET_CLOSE' -Entries @(
    '2020-11-27|Day after Thanksgiving early close',
    '2020-12-24|Christmas Eve early close'
)

Add-CalendarRows -SourceId 'NYSE_2021_CALENDAR' -SessionType FULL_CLOSE -Qualification 'OFFICIAL_SCHEDULED_FULL_CLOSE' -Entries @(
    '2021-01-01|New Years Day',
    '2021-01-18|Martin Luther King Jr Day',
    '2021-02-15|Washingtons Birthday',
    '2021-04-02|Good Friday',
    '2021-05-31|Memorial Day',
    '2021-07-05|Independence Day observed',
    '2021-09-06|Labor Day',
    '2021-11-25|Thanksgiving Day',
    '2021-12-24|Christmas Day observed'
)
Add-CalendarRows -SourceId 'NYSE_2021_CALENDAR' -SessionType EARLY_CLOSE -Qualification 'OFFICIAL_SCHEDULED_1300_ET_CLOSE' -Entries @(
    '2021-11-26|Day after Thanksgiving early close'
)

Add-CalendarRows -SourceId 'NYSE_2022_CALENDAR' -SessionType FULL_CLOSE -Qualification 'OFFICIAL_SCHEDULED_FULL_CLOSE' -Entries @(
    '2022-01-17|Martin Luther King Jr Day',
    '2022-02-21|Washingtons Birthday',
    '2022-04-15|Good Friday',
    '2022-05-30|Memorial Day',
    '2022-06-20|Juneteenth National Independence Day observed',
    '2022-07-04|Independence Day',
    '2022-09-05|Labor Day',
    '2022-11-24|Thanksgiving Day',
    '2022-12-26|Christmas Day observed'
)
Add-CalendarRows -SourceId 'NYSE_2022_CALENDAR' -SessionType EARLY_CLOSE -Qualification 'OFFICIAL_SCHEDULED_1300_ET_CLOSE' -Entries @(
    '2022-11-25|Day after Thanksgiving early close'
)

Add-CalendarRows -SourceId 'NYSE_2023_CALENDAR' -SessionType FULL_CLOSE -Qualification 'OFFICIAL_SCHEDULED_FULL_CLOSE' -Entries @(
    '2023-01-02|New Years Day observed',
    '2023-01-16|Martin Luther King Jr Day',
    '2023-02-20|Washingtons Birthday',
    '2023-04-07|Good Friday',
    '2023-05-29|Memorial Day',
    '2023-06-19|Juneteenth National Independence Day',
    '2023-07-04|Independence Day',
    '2023-09-04|Labor Day',
    '2023-11-23|Thanksgiving Day',
    '2023-12-25|Christmas Day'
)
Add-CalendarRows -SourceId 'NYSE_2023_CALENDAR' -SessionType EARLY_CLOSE -Qualification 'OFFICIAL_SCHEDULED_1300_ET_CLOSE' -Entries @(
    '2023-07-03|Independence Day early close',
    '2023-11-24|Day after Thanksgiving early close'
)

Add-CalendarRows -SourceId 'NYSE_2024_CALENDAR' -SessionType FULL_CLOSE -Qualification 'OFFICIAL_SCHEDULED_FULL_CLOSE' -Entries @(
    '2024-01-01|New Years Day',
    '2024-01-15|Martin Luther King Jr Day',
    '2024-02-19|Washingtons Birthday',
    '2024-03-29|Good Friday',
    '2024-05-27|Memorial Day',
    '2024-06-19|Juneteenth National Independence Day',
    '2024-07-04|Independence Day',
    '2024-09-02|Labor Day',
    '2024-11-28|Thanksgiving Day',
    '2024-12-25|Christmas Day'
)
Add-CalendarRows -SourceId 'NYSE_2024_CALENDAR' -SessionType EARLY_CLOSE -Qualification 'OFFICIAL_SCHEDULED_1300_ET_CLOSE' -Entries @(
    '2024-07-03|Independence Day early close',
    '2024-11-29|Day after Thanksgiving early close',
    '2024-12-24|Christmas Eve early close'
)

Add-CalendarRows -SourceId 'NYSE_2025_CALENDAR' -SessionType FULL_CLOSE -Qualification 'OFFICIAL_SCHEDULED_FULL_CLOSE' -Entries @(
    '2025-01-01|New Years Day',
    '2025-01-20|Martin Luther King Jr Day',
    '2025-02-17|Washingtons Birthday',
    '2025-04-18|Good Friday',
    '2025-05-26|Memorial Day',
    '2025-06-19|Juneteenth National Independence Day',
    '2025-07-04|Independence Day',
    '2025-09-01|Labor Day',
    '2025-11-27|Thanksgiving Day',
    '2025-12-25|Christmas Day'
)
Add-CalendarRows -SourceId 'NYSE_2025_CALENDAR' -SessionType EARLY_CLOSE -Qualification 'OFFICIAL_SCHEDULED_1300_ET_CLOSE' -Entries @(
    '2025-07-03|Independence Day early close',
    '2025-11-28|Day after Thanksgiving early close',
    '2025-12-24|Christmas Eve early close'
)
Add-CalendarRows -SourceId 'NYSE_2025_CARTER_MOURNING' -SessionType FULL_CLOSE -Qualification 'OFFICIAL_UNSCHEDULED_FULL_CLOSE' -Entries @(
    '2025-01-09|National Day of Mourning for President Jimmy Carter'
)

$sortedRows = @($rows | Sort-Object Date, SessionType)
$duplicateDates = @($sortedRows | Group-Object { $_.Date.ToString('yyyy-MM-dd') } | Where-Object Count -ne 1)
if ($duplicateDates.Count -ne 0) {
    throw "Calendar contains duplicate dates: $($duplicateDates.Name -join ', ')"
}

$fullCloseRows = @($sortedRows | Where-Object SessionType -eq 'FULL_CLOSE')
$earlyCloseRows = @($sortedRows | Where-Object SessionType -eq 'EARLY_CLOSE')
if ($fullCloseRows.Count -ne $expectedFullCloseRows -or $earlyCloseRows.Count -ne $expectedEarlyCloseRows) {
    throw "Calendar contract mismatch: expected FULL_CLOSE=$expectedFullCloseRows/EARLY_CLOSE=$expectedEarlyCloseRows, found FULL_CLOSE=$($fullCloseRows.Count)/EARLY_CLOSE=$($earlyCloseRows.Count)."
}

$expectedPerYear = @{
    2018 = @{ Full = 10; Early = 3 }
    2019 = @{ Full = 9; Early = 3 }
    2020 = @{ Full = 9; Early = 2 }
    2021 = @{ Full = 9; Early = 1 }
    2022 = @{ Full = 9; Early = 1 }
    2023 = @{ Full = 10; Early = 2 }
    2024 = @{ Full = 10; Early = 3 }
    2025 = @{ Full = 11; Early = 3 }
}
foreach ($year in 2018..2025) {
    $full = @($fullCloseRows | Where-Object Date -ge ([datetime]"$year-01-01") | Where-Object Date -le ([datetime]"$year-12-31")).Count
    $early = @($earlyCloseRows | Where-Object Date -ge ([datetime]"$year-01-01") | Where-Object Date -le ([datetime]"$year-12-31")).Count
    if ($full -ne $expectedPerYear[$year].Full -or $early -ne $expectedPerYear[$year].Early) {
        throw "Year $year contract mismatch: expected FULL_CLOSE=$($expectedPerYear[$year].Full)/EARLY_CLOSE=$($expectedPerYear[$year].Early), found FULL_CLOSE=$full/EARLY_CLOSE=$early."
    }
}

$calendarLines = [Collections.Generic.List[string]]::new()
$calendarLines.Add('date_new_york,session_type,open_time_new_york,close_time_new_york')
foreach ($row in $sortedRows) {
    $calendarLines.Add(('{0},{1},{2},{3}' -f
        $row.Date.ToString('yyyy-MM-dd'), $row.SessionType, $row.OpenTime, $row.CloseTime))
}

$provenanceLines = [Collections.Generic.List[string]]::new()
$provenanceLines.Add('date_new_york,session_type,event_name,qualification,source_id')
foreach ($row in $sortedRows) {
    $provenanceLines.Add(('{0},{1},{2},{3},{4}' -f
        $row.Date.ToString('yyyy-MM-dd'), $row.SessionType, $row.EventName, $row.Qualification, $row.SourceId))
}

$sourceLines = [Collections.Generic.List[string]]::new()
$sourceLines.Add('source_id,published_date,release_url,official_pdf_url,official_pdf_sha256,scope')
foreach ($source in ($sources | Sort-Object Id)) {
    $sourceLines.Add(('{0},{1},{2},{3},{4},{5}' -f
        $source.Id, $source.Published, $source.ReleaseUrl, $source.PdfUrl, $source.PdfSha256, $source.Scope))
}

$calendarPath = Join-Path $OutputDirectory $calendarName
$provenancePath = Join-Path $OutputDirectory $provenanceName
$sourcesPath = Join-Path $OutputDirectory $sourcesName
$manifestPath = Join-Path $OutputDirectory $manifestName
Write-Utf8NoBom -Path $calendarPath -Content (($calendarLines -join "`n") + "`n")
Write-Utf8NoBom -Path $provenancePath -Content (($provenanceLines -join "`n") + "`n")
Write-Utf8NoBom -Path $sourcesPath -Content (($sourceLines -join "`n") + "`n")

$calendarSha = Get-Sha256Lower -Path $calendarPath
$provenanceSha = Get-Sha256Lower -Path $provenancePath
$sourcesSha = Get-Sha256Lower -Path $sourcesPath
$manifestLines = @(
    '{',
    '  "schema_version": 1,',
    '  "calendar_id": "NYSE_GROUP_US_CASH_EQUITIES",',
    '  "timezone": "America/New_York",',
    '  "coverage_start": "2018-01-01",',
    '  "coverage_end": "2025-12-31",',
    '  "normal_open_new_york": "09:30",',
    '  "normal_close_new_york": "16:00",',
    '  "outside_coverage_policy": "FAIL_CLOSED",',
    ('  "runtime_file": "{0}",' -f $calendarName),
    ('  "runtime_rows": {0},' -f $sortedRows.Count),
    ('  "runtime_sha256": "{0}",' -f $calendarSha),
    ('  "full_close_rows": {0},' -f $fullCloseRows.Count),
    ('  "early_close_rows": {0},' -f $earlyCloseRows.Count),
    ('  "provenance_file": "{0}",' -f $provenanceName),
    ('  "provenance_rows": {0},' -f $sortedRows.Count),
    ('  "provenance_sha256": "{0}",' -f $provenanceSha),
    ('  "sources_file": "{0}",' -f $sourcesName),
    ('  "source_rows": {0},' -f $sources.Count),
    ('  "sources_sha256": "{0}",' -f $sourcesSha),
    '  "source_policy": "NYSE_ICE_PRIMARY_ONLY"',
    '}'
)
Write-Utf8NoBom -Path $manifestPath -Content (($manifestLines -join "`n") + "`n")

[pscustomobject]@{
    calendar_path = $calendarPath
    calendar_rows = $sortedRows.Count
    full_close_rows = $fullCloseRows.Count
    early_close_rows = $earlyCloseRows.Count
    calendar_sha256 = $calendarSha
    provenance_path = $provenancePath
    provenance_rows = $sortedRows.Count
    provenance_sha256 = $provenanceSha
    sources_path = $sourcesPath
    source_rows = $sources.Count
    sources_sha256 = $sourcesSha
    manifest_path = $manifestPath
    manifest_sha256 = Get-Sha256Lower -Path $manifestPath
    official_sources_verified = [bool]$VerifyOfficialSources
}
