[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'data'),
    [switch]$VerifyOfficialSources
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$holidayName = 'QM5_GOVUK_England_Wales_public_holidays_20180101_20251231.csv'
$holidayProvenanceName = 'QM5_GOVUK_England_Wales_public_holidays_provenance.csv'
$lseName = 'QM5_LSE_cash_session_exceptions_20180101_20251231.csv'
$lseProvenanceName = 'QM5_LSE_cash_session_exceptions_provenance.csv'
$wmrName = 'QM5_WMR_1600_London_service_exceptions_20250101_20251231.csv'
$wmrProvenanceName = 'QM5_WMR_1600_London_service_exceptions_provenance.csv'
$sourcesName = 'QM5_London_calendar_sources.csv'
$manifestName = 'QM5_London_calendar_manifest.json'

$coverageStart = [datetime]::ParseExact('2018-01-01', 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
$coverageEnd = [datetime]::ParseExact('2025-12-31', 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)

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

function Assert-CsvSafe {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value,
        [Parameter(Mandatory)][string]$FieldName
    )

    if ($Value -match '[,\r\n"]') {
        throw "Unsafe CSV value in ${FieldName}: $Value"
    }
    return $Value
}

$sources = @(
    [pscustomobject]@{
        Id = 'ALPHAGOV_CALENDARS_2018'
        Issuer = 'UK Government Digital Service'
        DocumentDate = '2020-05-04'
        RetrievedDate = '2026-07-22'
        Url = 'https://raw.githubusercontent.com/alphagov/calendars/0c95949629ea454f4c9d40a189b5f992bd6dee08/lib/data/bank-holidays.json'
        Sha256 = 'a122a103a6213cd93b68c25586a6e0d0e42bacb3867f803f7aa3dda196344ae6'
        MinimumBytes = 30000
        ExpectedHost = 'raw.githubusercontent.com'
        Scope = 'Commit-pinned official GOV.UK calendar data including England and Wales 2018 public holidays'
    }
    [pscustomobject]@{
        Id = 'GOVUK_BANK_HOLIDAYS_2019_2025'
        Issuer = 'UK Government Digital Service'
        DocumentDate = '2026-07-22'
        RetrievedDate = '2026-07-22'
        Url = 'https://www.gov.uk/bank-holidays.json'
        Sha256 = '538b3482c28b85ecd2db606a0d5ae6ad17248900b6498700ce0a48d26a3ecde6'
        MinimumBytes = 15000
        ExpectedHost = 'www.gov.uk'
        Scope = 'Official GOV.UK England and Wales public-holiday feed snapshot used for 2019 through 2025'
    }
    [pscustomobject]@{
        Id = 'UK_BANKING_FINANCIAL_DEALINGS_ACT_1971'
        Issuer = 'UK Legislation'
        DocumentDate = '1971-12-16'
        RetrievedDate = '2026-07-22'
        Url = 'https://www.legislation.gov.uk/ukpga/1971/80/pdfs/ukpga_19710080_en.pdf'
        Sha256 = '891603873a6fd4a80ce6d6f37b768cfb12498c811ba9cbbc54ac6f979ce32e00'
        MinimumBytes = 100000
        ExpectedHost = 'www.legislation.gov.uk'
        Scope = 'Primary statutory basis cited by the official GOV.UK calendar implementation'
    }
    [pscustomobject]@{
        Id = 'LONDON_GAZETTE_62002_2018_PROCLAMATION'
        Issuer = 'The London Gazette'
        DocumentDate = '2017-07-21'
        RetrievedDate = '2026-07-22'
        Url = 'https://www.thegazette.co.uk/London/issue/62002'
        Sha256 = 'd7ca8e17e2b675f78cfae2b6eddb6bf9acdb41ec016f5028dd777bfddefea2a7'
        MinimumBytes = 1000000
        ExpectedHost = 'www.thegazette.co.uk'
        Scope = 'Primary proclamation evidence for 2018 New Year and Early May bank holidays'
    }
    [pscustomobject]@{
        Id = 'LSE_N15_2022_RECOGNITION_RULE'
        Issuer = 'London Stock Exchange'
        DocumentDate = '2022-09-09'
        RetrievedDate = '2026-07-22'
        Url = 'https://docs.londonstockexchange.com/sites/default/files/documents/n1522.pdf'
        Sha256 = 'eab50a7c1098e4e6df221a70acdb63c9c4a5efee93b7eb1d294916e6a34fb80e'
        MinimumBytes = 50000
        ExpectedHost = 'docs.londonstockexchange.com'
        Scope = 'Official rule that LSE recognises Public and Bank Holidays of England and Wales'
    }
    [pscustomobject]@{
        Id = 'LSE_N16_2022_STATE_FUNERAL'
        Issuer = 'London Stock Exchange'
        DocumentDate = '2022-09-12'
        RetrievedDate = '2026-07-22'
        Url = 'https://docs.londonstockexchange.com/sites/default/files/documents/n1622.pdf'
        Sha256 = 'e6023cf1a8aeb4669ff8fa6c5b83153ed203991cf1c36d810c930c01bd582a46'
        MinimumBytes = 50000
        ExpectedHost = 'docs.londonstockexchange.com'
        Scope = 'Official explicit LSE closure notice for 19 September 2022'
    }
    [pscustomobject]@{
        Id = 'LSE_SETS_TRADING_CYCLE'
        Issuer = 'London Stock Exchange'
        DocumentDate = '2013-10-25'
        RetrievedDate = '2026-07-22'
        Url = 'https://docs.londonstockexchange.com/sites/default/files/documents/service-and-technical-description-icsd-settlement.pdf'
        Sha256 = '398462d3b76a4141708b8b9c1d01b9fa0f5d4b7ca58a89c62402e537c49ce89e'
        MinimumBytes = 500000
        ExpectedHost = 'docs.londonstockexchange.com'
        Scope = 'Official SETS cycle with 0800 to 1630 normal trading and 1230 Christmas and year-end early close'
    }
    [pscustomobject]@{
        Id = 'WMR_FX_METHODOLOGY_V30'
        Issuer = 'FTSE Russell LSEG'
        DocumentDate = '2026-01-01'
        RetrievedDate = '2026-07-22'
        Url = 'https://www.lseg.com/content/dam/ftse-russell/en_us/documents/ground-rules/wmr-fx-methodology.pdf'
        Sha256 = '28237fd5266f2d71318d394916f37138b77c32be685fb28a00f0d6139b06dc69'
        MinimumBytes = 400000
        ExpectedHost = 'www.lseg.com'
        Scope = 'Official national-holiday policy for WMR Spot Forward NDF and Metal Rates'
    }
    [pscustomobject]@{
        Id = 'WMR_SERVICE_ALTERATIONS_2025_2030'
        Issuer = 'FTSE Russell LSEG'
        DocumentDate = '2025-08-01'
        RetrievedDate = '2026-07-22'
        Url = 'https://www.lseg.com/content/dam/ftse-russell/en_us/documents/methodology/wmr-service-alterations.pdf'
        Sha256 = '3d4c5f5a9aa4a6c3867a940fcb46e379454b537739ac3803e150e245a0608f7b'
        MinimumBytes = 300000
        ExpectedHost = 'www.lseg.com'
        Scope = 'Official WMR service-alteration schedule with byte-pinnable coverage beginning in 2025'
    }
)

$sourceById = @{}
foreach ($source in $sources) {
    if ($sourceById.ContainsKey($source.Id)) {
        throw "Duplicate source id: $($source.Id)"
    }
    $uri = [Uri]$source.Url
    if ($uri.Scheme -ne 'https' -or $uri.Host -ne $source.ExpectedHost) {
        throw "Unexpected source origin for $($source.Id): $($source.Url)"
    }
    if ($source.Sha256 -notmatch '^[0-9a-f]{64}$') {
        throw "Invalid source SHA-256 for $($source.Id)."
    }
    $sourceById[$source.Id] = $source
}

if ($VerifyOfficialSources) {
    Add-Type -AssemblyName System.Net.Http
    $handler = [Net.Http.HttpClientHandler]::new()
    $handler.AllowAutoRedirect = $true
    $http = [Net.Http.HttpClient]::new($handler)
    $http.DefaultRequestHeaders.UserAgent.ParseAdd('Mozilla/5.0 (Windows NT 10.0; Win64; x64) QM-Calendar-Source-Verifier/1.0')
    $http.DefaultRequestHeaders.Accept.ParseAdd('application/pdf,application/json,text/plain;q=0.9,*/*;q=0.8')
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        foreach ($source in $sources) {
            $response = $http.GetAsync($source.Url).GetAwaiter().GetResult()
            if (-not $response.IsSuccessStatusCode) {
                throw "Official source download failed for $($source.Id): HTTP $([int]$response.StatusCode)."
            }
            $bytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
            if ($bytes.Length -lt $source.MinimumBytes) {
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
        $handler.Dispose()
    }
}

$holidayRows = [Collections.Generic.List[object]]::new()

function Add-HolidayRows {
    param(
        [Parameter(Mandatory)][string]$SourceId,
        [Parameter(Mandatory)][string[]]$Entries
    )

    if (-not $sourceById.ContainsKey($SourceId)) {
        throw "Unknown holiday source id: $SourceId"
    }
    foreach ($entry in $Entries) {
        $parts = $entry.Split('|')
        if ($parts.Count -ne 3) {
            throw "Invalid holiday entry: $entry"
        }
        $date = [datetime]::ParseExact($parts[0], 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
        if ($date -lt $coverageStart -or $date -gt $coverageEnd) {
            throw "Holiday outside coverage: $entry"
        }
        $holidayRows.Add([pscustomobject]@{
            Date = $date
            EventName = $parts[1]
            Notes = $parts[2]
            SourceId = $SourceId
        })
    }
}

Add-HolidayRows -SourceId 'ALPHAGOV_CALENDARS_2018' -Entries @(
    '2018-01-01|New Years Day|',
    '2018-03-30|Good Friday|',
    '2018-04-02|Easter Monday|',
    '2018-05-07|Early May bank holiday|',
    '2018-05-28|Spring bank holiday|',
    '2018-08-27|Summer bank holiday|',
    '2018-12-25|Christmas Day|',
    '2018-12-26|Boxing Day|'
)

Add-HolidayRows -SourceId 'GOVUK_BANK_HOLIDAYS_2019_2025' -Entries @(
    '2019-01-01|New Years Day|',
    '2019-04-19|Good Friday|',
    '2019-04-22|Easter Monday|',
    '2019-05-06|Early May bank holiday|',
    '2019-05-27|Spring bank holiday|',
    '2019-08-26|Summer bank holiday|',
    '2019-12-25|Christmas Day|',
    '2019-12-26|Boxing Day|',
    '2020-01-01|New Years Day|',
    '2020-04-10|Good Friday|',
    '2020-04-13|Easter Monday|',
    '2020-05-08|Early May bank holiday VE day|',
    '2020-05-25|Spring bank holiday|',
    '2020-08-31|Summer bank holiday|',
    '2020-12-25|Christmas Day|',
    '2020-12-28|Boxing Day|Substitute day',
    '2021-01-01|New Years Day|',
    '2021-04-02|Good Friday|',
    '2021-04-05|Easter Monday|',
    '2021-05-03|Early May bank holiday|',
    '2021-05-31|Spring bank holiday|',
    '2021-08-30|Summer bank holiday|',
    '2021-12-27|Christmas Day|Substitute day',
    '2021-12-28|Boxing Day|Substitute day',
    '2022-01-03|New Years Day|Substitute day',
    '2022-04-15|Good Friday|',
    '2022-04-18|Easter Monday|',
    '2022-05-02|Early May bank holiday|',
    '2022-06-02|Spring bank holiday|',
    '2022-06-03|Platinum Jubilee bank holiday|',
    '2022-08-29|Summer bank holiday|',
    '2022-09-19|State Funeral of Queen Elizabeth II|Special bank holiday',
    '2022-12-26|Boxing Day|',
    '2022-12-27|Christmas Day|Substitute day',
    '2023-01-02|New Years Day|Substitute day',
    '2023-04-07|Good Friday|',
    '2023-04-10|Easter Monday|',
    '2023-05-01|Early May bank holiday|',
    '2023-05-08|Coronation of King Charles III|Special bank holiday',
    '2023-05-29|Spring bank holiday|',
    '2023-08-28|Summer bank holiday|',
    '2023-12-25|Christmas Day|',
    '2023-12-26|Boxing Day|',
    '2024-01-01|New Years Day|',
    '2024-03-29|Good Friday|',
    '2024-04-01|Easter Monday|',
    '2024-05-06|Early May bank holiday|',
    '2024-05-27|Spring bank holiday|',
    '2024-08-26|Summer bank holiday|',
    '2024-12-25|Christmas Day|',
    '2024-12-26|Boxing Day|',
    '2025-01-01|New Years Day|',
    '2025-04-18|Good Friday|',
    '2025-04-21|Easter Monday|',
    '2025-05-05|Early May bank holiday|',
    '2025-05-26|Spring bank holiday|',
    '2025-08-25|Summer bank holiday|',
    '2025-12-25|Christmas Day|',
    '2025-12-26|Boxing Day|'
)

$holidayRows = @($holidayRows | Sort-Object Date)
if ($holidayRows.Count -ne 67) {
    throw "Holiday row contract mismatch: expected 67 and found $($holidayRows.Count)."
}
$duplicateHolidays = @($holidayRows | Group-Object { $_.Date.ToString('yyyy-MM-dd') } | Where-Object Count -ne 1)
if ($duplicateHolidays.Count -ne 0) {
    throw "Duplicate holiday dates: $($duplicateHolidays.Name -join ', ')"
}
$weekendHolidays = @($holidayRows | Where-Object { $_.Date.DayOfWeek -in @([DayOfWeek]::Saturday, [DayOfWeek]::Sunday) })
if ($weekendHolidays.Count -ne 0) {
    throw "Runtime calendar must contain observed weekdays only: $($weekendHolidays.Date -join ', ')"
}

$expectedHolidayCounts = @{ 2018 = 8; 2019 = 8; 2020 = 8; 2021 = 8; 2022 = 10; 2023 = 9; 2024 = 8; 2025 = 8 }
foreach ($year in 2018..2025) {
    $actual = @($holidayRows | Where-Object { $_.Date.Year -eq $year }).Count
    if ($actual -ne $expectedHolidayCounts[$year]) {
        throw "Holiday count mismatch for ${year}: expected $($expectedHolidayCounts[$year]) and found $actual."
    }
}

$holidayByDate = @{}
foreach ($row in $holidayRows) {
    $holidayByDate[$row.Date.ToString('yyyy-MM-dd')] = $row
}

function Test-LseOpenDate {
    param([Parameter(Mandatory)][datetime]$Date)

    if ($Date.DayOfWeek -in @([DayOfWeek]::Saturday, [DayOfWeek]::Sunday)) {
        return $false
    }
    return -not $holidayByDate.ContainsKey($Date.ToString('yyyy-MM-dd'))
}

function Get-LseOpenDateOnOrBefore {
    param([Parameter(Mandatory)][datetime]$Date)

    $candidate = $Date.Date
    while (-not (Test-LseOpenDate -Date $candidate)) {
        $candidate = $candidate.AddDays(-1)
        if ($candidate -lt $coverageStart) {
            throw "Could not resolve an LSE open date on or before $($Date.ToString('yyyy-MM-dd'))."
        }
    }
    return $candidate
}

function Get-LseOpenDateBefore {
    param([Parameter(Mandatory)][datetime]$Date)

    return Get-LseOpenDateOnOrBefore -Date $Date.Date.AddDays(-1)
}

$lseRows = [Collections.Generic.List[object]]::new()
foreach ($holiday in $holidayRows) {
    $sourceIds = "$($holiday.SourceId)|LSE_N15_2022_RECOGNITION_RULE"
    $qualification = 'OFFICIAL_FULL_CLOSE_FROM_ENGLAND_WALES_HOLIDAY_RECOGNITION'
    if ($holiday.Date.ToString('yyyy-MM-dd') -eq '2022-09-19') {
        $sourceIds = "$($holiday.SourceId)|LSE_N16_2022_STATE_FUNERAL"
        $qualification = 'OFFICIAL_EXPLICIT_FULL_CLOSE_NOTICE'
    }
    $lseRows.Add([pscustomobject]@{
        Date = $holiday.Date
        SessionType = 'FULL_CLOSE'
        OpenTime = ''
        CloseTime = ''
        EventName = $holiday.EventName
        Qualification = $qualification
        SourceIds = $sourceIds
    })
}

foreach ($year in 2018..2025) {
    $christmasEarlyClose = Get-LseOpenDateBefore -Date ([datetime]"$year-12-25")
    $yearEndEarlyClose = Get-LseOpenDateOnOrBefore -Date ([datetime]"$year-12-31")
    foreach ($earlyClose in @(
        [pscustomobject]@{ Date = $christmasEarlyClose; Name = 'Final trading day before Christmas' },
        [pscustomobject]@{ Date = $yearEndEarlyClose; Name = 'Final trading day of calendar year' }
    )) {
        if ($holidayByDate.ContainsKey($earlyClose.Date.ToString('yyyy-MM-dd'))) {
            throw "Derived LSE early close is also a full-close holiday: $($earlyClose.Date.ToString('yyyy-MM-dd'))."
        }
        $lseRows.Add([pscustomobject]@{
            Date = $earlyClose.Date
            SessionType = 'EARLY_CLOSE'
            OpenTime = '08:00'
            CloseTime = '12:30'
            EventName = $earlyClose.Name
            Qualification = 'OFFICIAL_RULE_DERIVED_1230_LONDON_CLOSE'
            SourceIds = 'LSE_SETS_TRADING_CYCLE'
        })
    }
}

$lseRows = @($lseRows | Sort-Object Date, SessionType)
$duplicateLseDates = @($lseRows | Group-Object { $_.Date.ToString('yyyy-MM-dd') } | Where-Object Count -ne 1)
if ($duplicateLseDates.Count -ne 0) {
    throw "Duplicate LSE exception dates: $($duplicateLseDates.Name -join ', ')"
}
$fullCloseRows = @($lseRows | Where-Object SessionType -eq 'FULL_CLOSE')
$earlyCloseRows = @($lseRows | Where-Object SessionType -eq 'EARLY_CLOSE')
if ($fullCloseRows.Count -ne 67 -or $earlyCloseRows.Count -ne 16) {
    throw "LSE row contract mismatch: expected FULL_CLOSE=67/EARLY_CLOSE=16 and found FULL_CLOSE=$($fullCloseRows.Count)/EARLY_CLOSE=$($earlyCloseRows.Count)."
}

$wmrRows = @(
    [pscustomobject]@{ Date = [datetime]'2025-01-01'; Status = 'NO_1600_FIX'; Schedule = 'First published spot fix 2200 London' },
    [pscustomobject]@{ Date = [datetime]'2025-04-18'; Status = 'NO_1600_FIX'; Schedule = 'No service' },
    [pscustomobject]@{ Date = [datetime]'2025-05-26'; Status = 'NORMAL_1600_FIX_AVAILABLE'; Schedule = 'Last spot fix 1800 then resume 2300 London' },
    [pscustomobject]@{ Date = [datetime]'2025-12-24'; Status = 'NORMAL_1600_FIX_AVAILABLE'; Schedule = 'Last spot fix 1800 London due low liquidity' },
    [pscustomobject]@{ Date = [datetime]'2025-12-25'; Status = 'NO_1600_FIX'; Schedule = 'No service' },
    [pscustomobject]@{ Date = [datetime]'2025-12-26'; Status = 'ONLY_1600_FIX_AVAILABLE'; Schedule = '1600 London spot fix only' },
    [pscustomobject]@{ Date = [datetime]'2025-12-31'; Status = 'NORMAL_1600_FIX_AVAILABLE'; Schedule = 'Last spot fix 2100 London due low liquidity' }
)

if (@($wmrRows | Where-Object Status -eq 'NO_1600_FIX').Count -ne 3) {
    throw 'WMR 2025 no-fix row contract changed.'
}
if (@($wmrRows | Where-Object Status -ne 'NO_1600_FIX').Count -ne 4) {
    throw 'WMR 2025 available-fix row contract changed.'
}

$holidayLines = [Collections.Generic.List[string]]::new()
$holidayLines.Add('date_london,day_type')
$holidayProvenanceLines = [Collections.Generic.List[string]]::new()
$holidayProvenanceLines.Add('date_london,day_type,event_name,notes,qualification,source_ids')
foreach ($row in $holidayRows) {
    $date = $row.Date.ToString('yyyy-MM-dd')
    $holidayLines.Add("$date,PUBLIC_OR_BANK_HOLIDAY")
    $sourceIds = $row.SourceId
    if ($row.Date.Year -eq 2018) {
        $sourceIds = "$sourceIds|UK_BANKING_FINANCIAL_DEALINGS_ACT_1971|LONDON_GAZETTE_62002_2018_PROCLAMATION"
    }
    $holidayProvenanceLines.Add(('{0},PUBLIC_OR_BANK_HOLIDAY,{1},{2},OFFICIAL_ENGLAND_WALES_HOLIDAY,{3}' -f
        $date,
        (Assert-CsvSafe -Value $row.EventName -FieldName 'holiday event_name'),
        (Assert-CsvSafe -Value $row.Notes -FieldName 'holiday notes'),
        $sourceIds))
}

$lseLines = [Collections.Generic.List[string]]::new()
$lseLines.Add('date_london,session_type,regular_open_london,regular_close_london')
$lseProvenanceLines = [Collections.Generic.List[string]]::new()
$lseProvenanceLines.Add('date_london,session_type,event_name,qualification,source_ids')
foreach ($row in $lseRows) {
    $date = $row.Date.ToString('yyyy-MM-dd')
    $lseLines.Add(('{0},{1},{2},{3}' -f $date, $row.SessionType, $row.OpenTime, $row.CloseTime))
    $lseProvenanceLines.Add(('{0},{1},{2},{3},{4}' -f
        $date,
        $row.SessionType,
        (Assert-CsvSafe -Value $row.EventName -FieldName 'LSE event_name'),
        $row.Qualification,
        $row.SourceIds))
}

$wmrLines = [Collections.Generic.List[string]]::new()
$wmrLines.Add('date_london,wmr_1600_spot_status')
$wmrProvenanceLines = [Collections.Generic.List[string]]::new()
$wmrProvenanceLines.Add('date_london,wmr_1600_spot_status,service_schedule,qualification,source_ids')
foreach ($row in $wmrRows) {
    $date = $row.Date.ToString('yyyy-MM-dd')
    $wmrLines.Add("$date,$($row.Status)")
    $wmrProvenanceLines.Add(('{0},{1},{2},OFFICIAL_WMR_SERVICE_ALTERATION,{3}' -f
        $date,
        $row.Status,
        (Assert-CsvSafe -Value $row.Schedule -FieldName 'WMR service_schedule'),
        'WMR_SERVICE_ALTERATIONS_2025_2030|WMR_FX_METHODOLOGY_V30'))
}

$sourceLines = [Collections.Generic.List[string]]::new()
$sourceLines.Add('source_id,issuer,document_date,retrieved_date,document_url,official_document_sha256,scope')
foreach ($source in ($sources | Sort-Object Id)) {
    $sourceLines.Add(('{0},{1},{2},{3},{4},{5},{6}' -f
        $source.Id,
        (Assert-CsvSafe -Value $source.Issuer -FieldName 'source issuer'),
        $source.DocumentDate,
        $source.RetrievedDate,
        $source.Url,
        $source.Sha256,
        (Assert-CsvSafe -Value $source.Scope -FieldName 'source scope')))
}

$holidayPath = Join-Path $OutputDirectory $holidayName
$holidayProvenancePath = Join-Path $OutputDirectory $holidayProvenanceName
$lsePath = Join-Path $OutputDirectory $lseName
$lseProvenancePath = Join-Path $OutputDirectory $lseProvenanceName
$wmrPath = Join-Path $OutputDirectory $wmrName
$wmrProvenancePath = Join-Path $OutputDirectory $wmrProvenanceName
$sourcesPath = Join-Path $OutputDirectory $sourcesName
$manifestPath = Join-Path $OutputDirectory $manifestName

Write-Utf8NoBom -Path $holidayPath -Content (($holidayLines -join "`n") + "`n")
Write-Utf8NoBom -Path $holidayProvenancePath -Content (($holidayProvenanceLines -join "`n") + "`n")
Write-Utf8NoBom -Path $lsePath -Content (($lseLines -join "`n") + "`n")
Write-Utf8NoBom -Path $lseProvenancePath -Content (($lseProvenanceLines -join "`n") + "`n")
Write-Utf8NoBom -Path $wmrPath -Content (($wmrLines -join "`n") + "`n")
Write-Utf8NoBom -Path $wmrProvenancePath -Content (($wmrProvenanceLines -join "`n") + "`n")
Write-Utf8NoBom -Path $sourcesPath -Content (($sourceLines -join "`n") + "`n")

$holidaySha = Get-Sha256Lower -Path $holidayPath
$holidayProvenanceSha = Get-Sha256Lower -Path $holidayProvenancePath
$lseSha = Get-Sha256Lower -Path $lsePath
$lseProvenanceSha = Get-Sha256Lower -Path $lseProvenancePath
$wmrSha = Get-Sha256Lower -Path $wmrPath
$wmrProvenanceSha = Get-Sha256Lower -Path $wmrProvenancePath
$sourcesSha = Get-Sha256Lower -Path $sourcesPath

$manifestLines = @(
    '{',
    '  "schema_version": 1,',
    '  "bundle_id": "QM5_LONDON_CALENDARS",',
    '  "timezone": "Europe/London",',
    '  "outside_coverage_policy": "FAIL_CLOSED",',
    '  "consumer_policy": {',
    '    "jurisdictional_holiday_is_not_fx_closure": true,',
    '    "lse_cash_calendar_must_not_gate_fx_routes": true,',
    '    "wmr_calendar_must_not_be_inferred_from_uk_holidays": true,',
    '    "broker_session_calendar_still_required_for_fx": true',
    '  },',
    '  "england_wales_public_holidays": {',
    '    "coverage_start": "2018-01-01",',
    '    "coverage_end": "2025-12-31",',
    '    "coverage_status": "COMPLETE",',
    ('    "runtime_file": "{0}",' -f $holidayName),
    ('    "runtime_rows": {0},' -f $holidayRows.Count),
    ('    "runtime_sha256": "{0}",' -f $holidaySha),
    ('    "provenance_file": "{0}",' -f $holidayProvenanceName),
    ('    "provenance_rows": {0},' -f $holidayRows.Count),
    ('    "provenance_sha256": "{0}"' -f $holidayProvenanceSha),
    '  },',
    '  "lse_cash_sessions": {',
    '    "coverage_start": "2018-01-01",',
    '    "coverage_end": "2025-12-31",',
    '    "coverage_status": "COMPLETE_SCHEDULED_EXCEPTIONS",',
    '    "normal_open_london": "08:00",',
    '    "normal_close_london": "16:30",',
    '    "early_close_london": "12:30",',
    ('    "runtime_file": "{0}",' -f $lseName),
    ('    "runtime_rows": {0},' -f $lseRows.Count),
    ('    "runtime_sha256": "{0}",' -f $lseSha),
    ('    "full_close_rows": {0},' -f $fullCloseRows.Count),
    ('    "early_close_rows": {0},' -f $earlyCloseRows.Count),
    ('    "provenance_file": "{0}",' -f $lseProvenanceName),
    ('    "provenance_rows": {0},' -f $lseRows.Count),
    ('    "provenance_sha256": "{0}"' -f $lseProvenanceSha),
    '  },',
    '  "wmr_1600_london_spot_service": {',
    '    "requested_study_start": "2018-01-01",',
    '    "requested_study_end": "2025-12-31",',
    '    "coverage_start": "2025-01-01",',
    '    "coverage_end": "2025-12-31",',
    '    "coverage_status": "PARTIAL_FAIL_CLOSED",',
    '    "uncovered_period": "2018-01-01/2024-12-31",',
    '    "ordinary_weekday_policy_within_coverage": "NORMAL_1600_FIX_AVAILABLE_UNLESS_LISTED",',
    ('    "runtime_file": "{0}",' -f $wmrName),
    ('    "runtime_rows": {0},' -f $wmrRows.Count),
    ('    "runtime_sha256": "{0}",' -f $wmrSha),
    ('    "no_1600_fix_rows": {0},' -f @($wmrRows | Where-Object Status -eq 'NO_1600_FIX').Count),
    ('    "available_1600_fix_rows": {0},' -f @($wmrRows | Where-Object Status -ne 'NO_1600_FIX').Count),
    ('    "provenance_file": "{0}",' -f $wmrProvenanceName),
    ('    "provenance_rows": {0},' -f $wmrRows.Count),
    ('    "provenance_sha256": "{0}"' -f $wmrProvenanceSha),
    '  },',
    ('  "sources_file": "{0}",' -f $sourcesName),
    ('  "source_rows": {0},' -f $sources.Count),
    ('  "sources_sha256": "{0}",' -f $sourcesSha),
    '  "source_policy": "GOVUK_LSE_LSEG_PRIMARY_ONLY"',
    '}'
)
Write-Utf8NoBom -Path $manifestPath -Content (($manifestLines -join "`n") + "`n")

[pscustomobject]@{
    holiday_path = $holidayPath
    holiday_rows = $holidayRows.Count
    holiday_sha256 = $holidaySha
    holiday_provenance_path = $holidayProvenancePath
    holiday_provenance_sha256 = $holidayProvenanceSha
    lse_path = $lsePath
    lse_rows = $lseRows.Count
    lse_full_close_rows = $fullCloseRows.Count
    lse_early_close_rows = $earlyCloseRows.Count
    lse_sha256 = $lseSha
    lse_provenance_path = $lseProvenancePath
    lse_provenance_sha256 = $lseProvenanceSha
    wmr_path = $wmrPath
    wmr_rows = $wmrRows.Count
    wmr_sha256 = $wmrSha
    wmr_provenance_path = $wmrProvenancePath
    wmr_provenance_sha256 = $wmrProvenanceSha
    sources_path = $sourcesPath
    source_rows = $sources.Count
    sources_sha256 = $sourcesSha
    manifest_path = $manifestPath
    manifest_sha256 = Get-Sha256Lower -Path $manifestPath
    official_sources_verified = [bool]$VerifyOfficialSources
}
