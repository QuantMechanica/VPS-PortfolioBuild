[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'data'),
    [switch]$VerifyOfficialSources
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$calendarName = 'QM5_XETRA_cash_session_exceptions_20180101_20251231.csv'
$provenanceName = 'QM5_XETRA_cash_session_exceptions_provenance.csv'
$sourcesName = 'QM5_XETRA_cash_session_exceptions_sources.csv'
$manifestName = 'QM5_XETRA_cash_session_exceptions_manifest.json'
$coverageStart = [datetime]::ParseExact('2018-01-01', 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
$coverageEnd = [datetime]::ParseExact('2025-12-31', 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
$retrievedDate = '2026-07-22'
$expectedFullCloseRows = 58
$expectedEarlyCloseRows = 8
$expectedSourceRows = 16

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

$archiveUrl = 'https://www.cashmarket.deutsche-boerse.com/cash-en/trading/trading-calendar-and-trading-hours/trading-calendar'
$sources = @(
    [pscustomobject]@{ Id='XETRA_2018_TRADING_CALENDAR'; Type='TRADING_CALENDAR'; PdfUrl='https://www.cashmarket.deutsche-boerse.com/resource/blob/154430/366c1c9be4ce7cdb923bbf246db1d1bf/data/trading-calendar-2018.pdf'; PdfSha256='6109fc3a393a3f7aa848ee681cd6182aed267c1795585001d25dd7261f52d9b2'; Scope='Xetra and Boerse Frankfurt non-trading days for 2018' }
    [pscustomobject]@{ Id='XETRA_2018_FINAL_SESSION'; Type='FINAL_SESSION_NOTICE'; PdfUrl='https://www.cashmarket.deutsche-boerse.com/resource/blob/1406132/5de5c48d372f5e9e8e3e0a0be5f33954/data/Final-trading-session-2018.pdf'; PdfSha256='8973bd905528e98c4f9980789f1ec15bcbcce347d39d03809bde946bbf9757d5'; Scope='Xetra final session on 2018-12-28 with 14:00 CET closing-auction call' }
    [pscustomobject]@{ Id='XETRA_2019_TRADING_CALENDAR'; Type='TRADING_CALENDAR'; PdfUrl='https://www.cashmarket.deutsche-boerse.com/resource/blob/1406548/6de0eba301a5433abb110fa3c96a5778/data/xetra-trading-calendar-2019.pdf'; PdfSha256='14297839055d795ae9aa4c8a17f0428554710ffe6af9eb0ed10aa7534b553fca'; Scope='Xetra and Boerse Frankfurt non-trading days for 2019' }
    [pscustomobject]@{ Id='XETRA_2019_FINAL_SESSION'; Type='FINAL_SESSION_NOTICE'; PdfUrl='https://www.cashmarket.deutsche-boerse.com/resource/blob/1665540/dc15dce063fb57020665309b969af48f/data/Final-trading-session-2019.pdf'; PdfSha256='859bd0b0cf26b765166fc48f75023a034e1bf118e60dabe1ccd453aca06c1a1a'; Scope='Xetra final session on 2019-12-30 with 14:00 CET closing-auction call' }
    [pscustomobject]@{ Id='XETRA_2020_TRADING_CALENDAR'; Type='TRADING_CALENDAR'; PdfUrl='https://www.cashmarket.deutsche-boerse.com/resource/blob/1665534/112856375187d3e93671aa3d731d09d3/data/xetra-trading-calendar-2020.pdf'; PdfSha256='6d7fc1b53875541344bcf589dc667739cb521273148588040210cc487d782d06'; Scope='Xetra and Boerse Frankfurt non-trading days for 2020' }
    [pscustomobject]@{ Id='XETRA_2020_FINAL_SESSION'; Type='FINAL_SESSION_NOTICE'; PdfUrl='https://www.cashmarket.deutsche-boerse.com/resource/blob/2344984/7a707684270bd7eeb2bad7cc278033df/data/Final%20trading%20session%202020.pdf'; PdfSha256='5cf181c40978647a075f7b3e5a530d5345cf8702699af43c084201f3205e0c22'; Scope='Xetra final session on 2020-12-30 with 14:00 CET closing-auction call' }
    [pscustomobject]@{ Id='XETRA_2021_TRADING_CALENDAR'; Type='TRADING_CALENDAR'; PdfUrl='https://www.cashmarket.deutsche-boerse.com/resource/blob/2344982/ddbcd31a616628a7ffa09dc709467ec4/data/xetra-trading-calendar-2021.pdf'; PdfSha256='c74c7e9bc4ed1da058b42239c23c1fccba3a8bf473ede97761cb2a24fabcc59b'; Scope='Xetra and Boerse Frankfurt non-trading days for 2021' }
    [pscustomobject]@{ Id='XETRA_2021_FINAL_SESSION'; Type='FINAL_SESSION_NOTICE'; PdfUrl='https://www.cashmarket.deutsche-boerse.com/resource/blob/2833324/1209e3c0d43c27b69f223f70245dcd9a/data/Final%20trading%20session%202021.pdf'; PdfSha256='b732a589812feec35d49da9d88ea058d7b8fd86f304d3eb4b52913acad1c12d1'; Scope='Xetra final session on 2021-12-30 with 14:00 CET closing-auction call' }
    [pscustomobject]@{ Id='XETRA_2022_TRADING_CALENDAR'; Type='TRADING_CALENDAR'; PdfUrl='https://www.cashmarket.deutsche-boerse.com/resource/blob/2833162/2f53999770c09ce9c0bee8194c1fe60d/data/xetra-trading-calendar-2022.pdf'; PdfSha256='d009abe3947c99b0df78d7ac276a7653d1a871c4784e95afbd2888c431f0d4ac'; Scope='Xetra and Boerse Frankfurt non-trading days for 2022' }
    [pscustomobject]@{ Id='XETRA_2022_FINAL_SESSION'; Type='FINAL_SESSION_NOTICE'; PdfUrl='https://www.cashmarket.deutsche-boerse.com/resource/blob/3317552/ef392d7e63636f8cbb7bdb2093e8477e/data/Final%20trading%20session%202022.pdf'; PdfSha256='df089618676a5775303b135d7971e80ab39b580d280de5fc0e399c0b4abd66a5'; Scope='Xetra final session on 2022-12-30 with 14:00 CET closing-auction call' }
    [pscustomobject]@{ Id='XETRA_2023_TRADING_CALENDAR'; Type='TRADING_CALENDAR'; PdfUrl='https://www.cashmarket.deutsche-boerse.com/resource/blob/3317408/4c8fbfbfeea62fd44600f6fe3f14f84e/data/xetra-trading-calendar-2023.pdf'; PdfSha256='33a083ba124695c5793ddecafef34e9e717683b5ed761e832ee32f1e87ad509b'; Scope='Xetra and Boerse Frankfurt non-trading days for 2023' }
    [pscustomobject]@{ Id='XETRA_2023_FINAL_SESSION'; Type='FINAL_SESSION_NOTICE'; PdfUrl='https://www.cashmarket.deutsche-boerse.com/resource/blob/3735776/e53cb5552fd069e20dc3faaf343c9c2d/data/Final%20trading%20session%202023.pdf'; PdfSha256='92b4915e95e4da2a111e4c3e1502a9ec4a1ace58f01c14fb1ae093a994519220'; Scope='Xetra final session on 2023-12-29 with 14:00 CET closing-auction call' }
    [pscustomobject]@{ Id='XETRA_2024_TRADING_CALENDAR'; Type='TRADING_CALENDAR'; PdfUrl='https://www.cashmarket.deutsche-boerse.com/resource/blob/3559262/98ebe1fde231df56c9f116bc766533b2/data/xetra-trading-calendar-2024.pdf'; PdfSha256='05d70c3a23ecbb701aeeaa37aa84817eb20895c7952467ff3469720c239386d9'; Scope='Xetra and Boerse Frankfurt non-trading days for 2024' }
    [pscustomobject]@{ Id='XETRA_2024_FINAL_SESSION'; Type='FINAL_SESSION_NOTICE'; PdfUrl='https://www.cashmarket.deutsche-boerse.com/resource/blob/4064970/4beb98bd98c44f58e1fb68e3f3bb9746/data/Final%20trading%20session%202024.pdf'; PdfSha256='c5b4d1f07355f0f2800edfa428147f68b49dbe9636c03db12a21b627d19234ee'; Scope='Xetra final session on 2024-12-30 with 14:00 CET closing-auction call' }
    [pscustomobject]@{ Id='XETRA_2025_TRADING_CALENDAR'; Type='TRADING_CALENDAR'; PdfUrl='https://www.cashmarket.deutsche-boerse.com/resource/blob/4064968/4079a2d5a9fec324905942b807b398ed/data/xetra-trading-calendar-2025.pdf'; PdfSha256='84c71bed702dd753f4272939f9c65d87ebd9afdfc89ff7917d545b66c3f8a8e5'; Scope='Xetra and Boerse Frankfurt non-trading days for 2025' }
    [pscustomobject]@{ Id='XETRA_2025_FINAL_SESSION'; Type='FINAL_SESSION_NOTICE'; PdfUrl='https://www.cashmarket.deutsche-boerse.com/resource/blob/4580834/14d7f01321cb1d949020067efd2ee174/data/Final%20trading%20session%202025.pdf'; PdfSha256='0dfae9eaa3b027ae728a288b463b59acd79d0a6897aeafac16ec5078f347ac94'; Scope='Xetra final session on 2025-12-30 with 14:00 CET closing-auction call' }
)

if ($sources.Count -ne $expectedSourceRows) {
    throw "Source contract mismatch: expected $expectedSourceRows sources, found $($sources.Count)."
}

$sourceById = @{}
foreach ($source in $sources) {
    if ($sourceById.ContainsKey($source.Id)) {
        throw "Duplicate source id: $($source.Id)"
    }
    $pdfUri = [Uri]$source.PdfUrl
    if ($pdfUri.Scheme -ne 'https' -or $pdfUri.Host -ne 'www.cashmarket.deutsche-boerse.com') {
        throw "Non-primary Deutsche Boerse source URL for $($source.Id): $($source.PdfUrl)"
    }
    if ($source.Type -notin @('TRADING_CALENDAR', 'FINAL_SESSION_NOTICE')) {
        throw "Invalid source type for $($source.Id): $($source.Type)"
    }
    if ($source.PdfSha256 -notmatch '^[0-9a-f]{64}$') {
        throw "Invalid pinned PDF SHA-256 for $($source.Id)."
    }
    $sourceById[$source.Id] = $source
}

if ($VerifyOfficialSources) {
    $http = [Net.Http.HttpClient]::new()
    $http.DefaultRequestHeaders.UserAgent.ParseAdd('QuantMechanica-calendar-source-verifier/1.0')
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        foreach ($source in $sources) {
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
        if ($date.DayOfWeek -in @([DayOfWeek]::Saturday, [DayOfWeek]::Sunday)) {
            throw "Calendar exception must be a weekday: $entry"
        }
        $rows.Add([pscustomobject]@{
            Date = $date
            SessionType = $SessionType
            OpenTime = if ($SessionType -eq 'EARLY_CLOSE') { '09:00' } else { '' }
            CloseTime = if ($SessionType -eq 'EARLY_CLOSE') { '14:00' } else { '' }
            EventName = $parts[1]
            SourceId = $SourceId
            Qualification = $Qualification
        })
    }
}

Add-CalendarRows 'XETRA_2018_TRADING_CALENDAR' FULL_CLOSE @('2018-01-01|New Years Day','2018-03-30|Good Friday','2018-04-02|Easter Monday','2018-05-01|Labour Day','2018-05-21|Whit Monday','2018-10-03|German Unity Day','2018-12-24|Christmas Eve','2018-12-25|Christmas Day','2018-12-26|Boxing Day','2018-12-31|New Years Eve') 'OFFICIAL_SCHEDULED_FULL_CLOSE'
Add-CalendarRows 'XETRA_2018_FINAL_SESSION' EARLY_CLOSE @('2018-12-28|Final trading session') 'OFFICIAL_1400_CET_CLOSING_AUCTION_CALL'

Add-CalendarRows 'XETRA_2019_TRADING_CALENDAR' FULL_CLOSE @('2019-01-01|New Years Day','2019-04-19|Good Friday','2019-04-22|Easter Monday','2019-05-01|Labour Day','2019-06-10|Whit Monday','2019-10-03|German Unity Day','2019-12-24|Christmas Eve','2019-12-25|Christmas Day','2019-12-26|Boxing Day','2019-12-31|New Years Eve') 'OFFICIAL_SCHEDULED_FULL_CLOSE'
Add-CalendarRows 'XETRA_2019_FINAL_SESSION' EARLY_CLOSE @('2019-12-30|Final trading session') 'OFFICIAL_1400_CET_CLOSING_AUCTION_CALL'

Add-CalendarRows 'XETRA_2020_TRADING_CALENDAR' FULL_CLOSE @('2020-01-01|New Years Day','2020-04-10|Good Friday','2020-04-13|Easter Monday','2020-05-01|Labour Day','2020-06-01|Whit Monday','2020-12-24|Christmas Eve','2020-12-25|Christmas Day','2020-12-31|New Years Eve') 'OFFICIAL_SCHEDULED_FULL_CLOSE'
Add-CalendarRows 'XETRA_2020_FINAL_SESSION' EARLY_CLOSE @('2020-12-30|Final trading session') 'OFFICIAL_1400_CET_CLOSING_AUCTION_CALL'

Add-CalendarRows 'XETRA_2021_TRADING_CALENDAR' FULL_CLOSE @('2021-01-01|New Years Day','2021-04-02|Good Friday','2021-04-05|Easter Monday','2021-05-24|Whit Monday','2021-12-24|Christmas Eve','2021-12-31|New Years Eve') 'OFFICIAL_SCHEDULED_FULL_CLOSE'
Add-CalendarRows 'XETRA_2021_FINAL_SESSION' EARLY_CLOSE @('2021-12-30|Final trading session') 'OFFICIAL_1400_CET_CLOSING_AUCTION_CALL'

Add-CalendarRows 'XETRA_2022_TRADING_CALENDAR' FULL_CLOSE @('2022-04-15|Good Friday','2022-04-18|Easter Monday','2022-12-26|Boxing Day') 'OFFICIAL_SCHEDULED_FULL_CLOSE'
Add-CalendarRows 'XETRA_2022_FINAL_SESSION' EARLY_CLOSE @('2022-12-30|Final trading session') 'OFFICIAL_1400_CET_CLOSING_AUCTION_CALL'

Add-CalendarRows 'XETRA_2023_TRADING_CALENDAR' FULL_CLOSE @('2023-04-07|Good Friday','2023-04-10|Easter Monday','2023-05-01|Labour Day','2023-12-25|Christmas Day','2023-12-26|Boxing Day') 'OFFICIAL_SCHEDULED_FULL_CLOSE'
Add-CalendarRows 'XETRA_2023_FINAL_SESSION' EARLY_CLOSE @('2023-12-29|Final trading session') 'OFFICIAL_1400_CET_CLOSING_AUCTION_CALL'

Add-CalendarRows 'XETRA_2024_TRADING_CALENDAR' FULL_CLOSE @('2024-01-01|New Years Day','2024-03-29|Good Friday','2024-04-01|Easter Monday','2024-05-01|Labour Day','2024-12-24|Christmas Eve','2024-12-25|Christmas Day','2024-12-26|Boxing Day','2024-12-31|New Years Eve') 'OFFICIAL_SCHEDULED_FULL_CLOSE'
Add-CalendarRows 'XETRA_2024_FINAL_SESSION' EARLY_CLOSE @('2024-12-30|Final trading session') 'OFFICIAL_1400_CET_CLOSING_AUCTION_CALL'

Add-CalendarRows 'XETRA_2025_TRADING_CALENDAR' FULL_CLOSE @('2025-01-01|New Years Day','2025-04-18|Good Friday','2025-04-21|Easter Monday','2025-05-01|Labour Day','2025-12-24|Christmas Eve','2025-12-25|Christmas Day','2025-12-26|Boxing Day','2025-12-31|New Years Eve') 'OFFICIAL_SCHEDULED_FULL_CLOSE'
Add-CalendarRows 'XETRA_2025_FINAL_SESSION' EARLY_CLOSE @('2025-12-30|Final trading session') 'OFFICIAL_1400_CET_CLOSING_AUCTION_CALL'

$sortedRows = @($rows | Sort-Object Date, SessionType)
$duplicates = @($sortedRows | Group-Object { $_.Date.ToString('yyyy-MM-dd') } | Where-Object Count -ne 1)
if ($duplicates.Count -ne 0) {
    throw "Calendar contains duplicate dates: $($duplicates.Name -join ', ')"
}

$fullCloseRows = @($sortedRows | Where-Object SessionType -eq 'FULL_CLOSE')
$earlyCloseRows = @($sortedRows | Where-Object SessionType -eq 'EARLY_CLOSE')
if ($fullCloseRows.Count -ne $expectedFullCloseRows -or $earlyCloseRows.Count -ne $expectedEarlyCloseRows) {
    throw "Calendar contract mismatch: expected FULL_CLOSE=$expectedFullCloseRows/EARLY_CLOSE=$expectedEarlyCloseRows, found FULL_CLOSE=$($fullCloseRows.Count)/EARLY_CLOSE=$($earlyCloseRows.Count)."
}

$expectedFullPerYear = @{ 2018=10; 2019=10; 2020=8; 2021=6; 2022=3; 2023=5; 2024=8; 2025=8 }
foreach ($year in 2018..2025) {
    $yearFull = @($fullCloseRows | Where-Object { $_.Date.Year -eq $year }).Count
    $yearEarly = @($earlyCloseRows | Where-Object { $_.Date.Year -eq $year }).Count
    if ($yearFull -ne $expectedFullPerYear[$year] -or $yearEarly -ne 1) {
        throw "Year $year contract mismatch: expected FULL_CLOSE=$($expectedFullPerYear[$year])/EARLY_CLOSE=1, found FULL_CLOSE=$yearFull/EARLY_CLOSE=$yearEarly."
    }
}

$calendarLines = [Collections.Generic.List[string]]::new()
$calendarLines.Add('date_berlin,session_type,open_time_berlin,close_time_berlin')
foreach ($row in $sortedRows) {
    $calendarLines.Add(('{0},{1},{2},{3}' -f $row.Date.ToString('yyyy-MM-dd'), $row.SessionType, $row.OpenTime, $row.CloseTime))
}

$provenanceLines = [Collections.Generic.List[string]]::new()
$provenanceLines.Add('date_berlin,session_type,event_name,qualification,source_id')
foreach ($row in $sortedRows) {
    $provenanceLines.Add(('{0},{1},{2},{3},{4}' -f $row.Date.ToString('yyyy-MM-dd'), $row.SessionType, $row.EventName, $row.Qualification, $row.SourceId))
}

$sourceLines = [Collections.Generic.List[string]]::new()
$sourceLines.Add('source_id,document_type,archive_url,official_pdf_url,official_pdf_sha256,retrieved_date,scope')
foreach ($source in ($sources | Sort-Object Id)) {
    $sourceLines.Add(('{0},{1},{2},{3},{4},{5},{6}' -f $source.Id, $source.Type, $archiveUrl, $source.PdfUrl, $source.PdfSha256, $retrievedDate, $source.Scope))
}

$calendarPath = Join-Path $OutputDirectory $calendarName
$provenancePath = Join-Path $OutputDirectory $provenanceName
$sourcesPath = Join-Path $OutputDirectory $sourcesName
$manifestPath = Join-Path $OutputDirectory $manifestName
Write-Utf8NoBom $calendarPath (($calendarLines -join "`n") + "`n")
Write-Utf8NoBom $provenancePath (($provenanceLines -join "`n") + "`n")
Write-Utf8NoBom $sourcesPath (($sourceLines -join "`n") + "`n")

$calendarSha = Get-Sha256Lower $calendarPath
$provenanceSha = Get-Sha256Lower $provenancePath
$sourcesSha = Get-Sha256Lower $sourcesPath
$manifest = [ordered]@{
    schema_version = 1
    calendar_id = 'DEUTSCHE_BOERSE_XETRA_CASH_EQUITIES'
    venue_mic = 'XETR'
    trading_model = 'CONTINUOUS_TRADING'
    timezone = 'Europe/Berlin'
    coverage_start = '2018-01-01'
    coverage_end = '2025-12-31'
    normal_open_berlin = '09:00'
    normal_close_berlin = '17:30'
    early_close_semantics = 'START_OF_XETRA_CLOSING_AUCTION_CALL'
    early_close_berlin = '14:00'
    outside_coverage_policy = 'FAIL_CLOSED'
    runtime_file = $calendarName
    runtime_rows = $sortedRows.Count
    runtime_sha256 = $calendarSha
    full_close_rows = $fullCloseRows.Count
    early_close_rows = $earlyCloseRows.Count
    provenance_file = $provenanceName
    provenance_rows = $sortedRows.Count
    provenance_sha256 = $provenanceSha
    sources_file = $sourcesName
    source_rows = $sources.Count
    sources_sha256 = $sourcesSha
    source_policy = 'DEUTSCHE_BOERSE_XETRA_PRIMARY_PDFS_ONLY'
}
Write-Utf8NoBom $manifestPath (($manifest | ConvertTo-Json -Depth 4) + "`n")

[pscustomobject]@{
    status = 'BUILT'
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
    manifest_sha256 = Get-Sha256Lower $manifestPath
    official_sources_verified = [bool]$VerifyOfficialSources
}
