<#
.SYNOPSIS
  Refresh the QM news calendars with real weekly event data.

.DESCRIPTION
  Fetches the Forex Factory weekly JSON feed, converts events into both
  production CSV layouts, appends only unseen events, and synchronizes the
  seeds to MetaTrader Common\Files. A content-coverage flag is maintained
  separately from file mtime freshness.

  Network failures are fail-soft: existing valid seeds are retained and
  synchronized. Missing or malformed seed headers are never synthesized or
  appended to. Output stays ASCII, CRLF, and BOM-free for MT5 FILE_ANSI reads.
#>
[CmdletBinding()]
param(
  [string]$Base = 'D:\QM\data\news_calendar',
  [string]$Common = 'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files',
  [string]$FeedUrl = 'https://nfs.faireconomy.media/ff_calendar_thisweek.json',
  [string]$FeedPath = '',
  [string]$StateDir = 'D:\QM\reports\state',
  [int]$CoverageDays = 2,
  [datetime]$NowUtc = [DateTime]::UtcNow
)

$ErrorActionPreference = 'Continue'
$nowUtcValue = $NowUtc.ToUniversalTime()
$nowLocal = $nowUtcValue.ToLocalTime()
$primaryPath = Join-Path $Base 'news_calendar_2015_2025.csv'
$secondaryPath = Join-Path $Base 'forex_factory_calendar_clean.csv'
$staleFlag = Join-Path $StateDir 'news_calendar_stale.flag'
$primaryHeader = 'datetime,currency,event_name,impact,actual,forecast,previous,impact_numeric,is_high_impact,is_nfp,is_fomc,is_ecb,is_boe,is_gdp,is_cpi,is_pmi,day_of_week,hour,day,is_first_friday'
$secondaryHeader = 'Date,DateTime_UTC,DateTime_EET,Currency,Impact,Event,Actual,Forecast,Previous'
$asciiNoBom = New-Object System.Text.ASCIIEncoding

function Read-Rows([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
  $raw = [IO.File]::ReadAllText($Path, $asciiNoBom)
  return @(($raw -split "`r?`n") | Where-Object { $_ -ne '' })
}

function Test-SeedHeader([string]$Path, [string]$ExpectedHeader) {
  $rows = @(Read-Rows $Path)
  if ($rows.Count -eq 0) {
    Write-Warning "seed missing or empty: $Path"
    return $false
  }
  if ($rows[0] -cne $ExpectedHeader) {
    Write-Warning "seed header mismatch: $Path"
    return $false
  }
  return $true
}

function Append-Lines([string]$Path, [string[]]$Lines) {
  if ($null -eq $Lines -or $Lines.Count -eq 0) { return }
  $builder = New-Object System.Text.StringBuilder
  foreach ($line in $Lines) {
    [void]$builder.Append($line)
    [void]$builder.Append("`r`n")
  }
  [IO.File]::AppendAllText($Path, $builder.ToString(), $asciiNoBom)
}

function ConvertTo-CalendarAscii([object]$Value) {
  if ($null -eq $Value) { return '' }
  $text = ([string]$Value).Trim()
  $text = $text.Replace([string][char]0x2013, '-')
  $text = $text.Replace([string][char]0x2014, '-')
  $text = $text.Replace([string][char]0x2018, "'")
  $text = $text.Replace([string][char]0x2019, "'")
  $text = $text.Replace([string][char]0x201C, '"')
  $text = $text.Replace([string][char]0x201D, '"')
  $text = $text.Replace(',', '').Replace("`r", '').Replace("`n", '')
  return $asciiNoBom.GetString($asciiNoBom.GetBytes($text)).Trim()
}

function ConvertTo-PrimaryImpact([string]$Impact) {
  switch ($Impact) {
    'High' { return 'high' }
    'Medium' { return 'medium' }
    'Low' { return 'low' }
    'Holiday' { return 'low' }
    default { return 'low' }
  }
}

function ConvertTo-SecondaryImpact([string]$Impact) {
  if ($Impact -in @('High', 'Medium', 'Low', 'Holiday')) { return $Impact }
  return 'Low'
}

function Get-ImpactNumber([string]$Impact) {
  switch ($Impact) {
    'high' { return 3 }
    'medium' { return 2 }
    default { return 1 }
  }
}

function Get-TitleFlag([string]$Title, [string[]]$Needles) {
  $lower = $Title.ToLowerInvariant()
  foreach ($needle in $Needles) {
    if ($lower.Contains($needle)) { return 1 }
  }
  return 0
}

function Get-FirstFridayFlag([datetime]$Date) {
  if ($Date.DayOfWeek -eq [DayOfWeek]::Friday -and $Date.Day -le 7) { return 1 }
  return 0
}

function Get-MondayZeroDay([datetime]$Date) {
  return (([int]$Date.DayOfWeek + 6) % 7)
}

$primaryValid = Test-SeedHeader $primaryPath $primaryHeader
$secondaryValid = Test-SeedHeader $secondaryPath $secondaryHeader
$seedsValid = $primaryValid -and $secondaryValid
$events = @()

if ($seedsValid) {
  try {
    if (-not [string]::IsNullOrWhiteSpace($FeedPath)) {
      $feedJson = [IO.File]::ReadAllText($FeedPath)
    }
    else {
      $response = Invoke-WebRequest -Uri $FeedUrl -UseBasicParsing -TimeoutSec 40 -ErrorAction Stop
      $feedJson = $response.Content
    }
    $events = @($feedJson | ConvertFrom-Json -ErrorAction Stop)
    Write-Host "feed OK: $($events.Count) events"
  }
  catch {
    Write-Warning "feed fetch failed ($_) -- falling back to mtime-only refresh"
    $events = @()
  }
}
else {
  Write-Warning 'calendar append skipped because both seed headers are not valid'
}

$appendedPrimary = 0
$appendedSecondary = 0
if ($seedsValid -and $events.Count -gt 0) {
  $primaryRows = @(Read-Rows $primaryPath)
  $secondaryRows = @(Read-Rows $secondaryPath)
  $primaryKeys = New-Object 'System.Collections.Generic.HashSet[string]'
  foreach ($row in @($primaryRows | Select-Object -Skip 1)) {
    $columns = $row -split ','
    if ($columns.Count -ge 3) {
      [void]$primaryKeys.Add(('{0}|{1}|{2}' -f $columns[0], $columns[1], $columns[2]))
    }
  }
  $secondaryKeys = New-Object 'System.Collections.Generic.HashSet[string]'
  foreach ($row in @($secondaryRows | Select-Object -Skip 1)) {
    $columns = $row -split ','
    if ($columns.Count -ge 6) {
      [void]$secondaryKeys.Add(('{0}|{1}|{2}' -f $columns[1], $columns[3], $columns[5]))
    }
  }

  $normalized = @()
  foreach ($event in $events) {
    try {
      if ($event.date -is [DateTime]) {
        $utc = ([DateTime]$event.date).ToUniversalTime()
      }
      elseif ($event.date -is [DateTimeOffset]) {
        $utc = ([DateTimeOffset]$event.date).UtcDateTime
      }
      else {
        $utc = ([DateTimeOffset]::Parse([string]$event.date)).UtcDateTime
      }
    }
    catch {
      Write-Warning "event skipped: invalid date '$($event.date)'"
      continue
    }
    $normalized += [pscustomobject]@{
      Utc = $utc
      Title = ConvertTo-CalendarAscii $event.title
      Currency = (ConvertTo-CalendarAscii $event.country).ToUpperInvariant()
      Impact = ConvertTo-CalendarAscii $event.impact
      Forecast = ConvertTo-CalendarAscii $event.forecast
      Previous = ConvertTo-CalendarAscii $event.previous
    }
  }
  $normalized = @($normalized | Sort-Object Utc, Currency, Title)
  $eetZone = [System.TimeZoneInfo]::FindSystemTimeZoneById('E. Europe Standard Time')
  $newPrimary = New-Object 'System.Collections.Generic.List[string]'
  $newSecondary = New-Object 'System.Collections.Generic.List[string]'

  foreach ($event in $normalized) {
    $utc = $event.Utc
    $primaryImpact = ConvertTo-PrimaryImpact $event.Impact
    $primaryKey = '{0}|{1}|{2}' -f $utc.ToString('yyyy-MM-dd HH:mm:ss'), $event.Currency, $event.Title
    if (-not $primaryKeys.Contains($primaryKey)) {
      [void]$primaryKeys.Add($primaryKey)
      $isHigh = if ($primaryImpact -eq 'high') { 1 } else { 0 }
      $columns = @(
        $utc.ToString('yyyy-MM-dd HH:mm:ss'), $event.Currency, $event.Title,
        $primaryImpact, '', $event.Forecast, $event.Previous,
        (Get-ImpactNumber $primaryImpact), $isHigh,
        (Get-TitleFlag $event.Title @('non-farm', 'nonfarm')),
        (Get-TitleFlag $event.Title @('fomc', 'federal funds')),
        (Get-TitleFlag $event.Title @('ecb', 'main refinancing')),
        (Get-TitleFlag $event.Title @('boe', 'mpc', 'official bank rate')),
        (Get-TitleFlag $event.Title @('gdp')),
        (Get-TitleFlag $event.Title @('cpi')),
        (Get-TitleFlag $event.Title @('pmi')),
        (Get-MondayZeroDay $utc), $utc.Hour, $utc.Day,
        (Get-FirstFridayFlag $utc.Date)
      )
      $newPrimary.Add(($columns -join ','))
    }

    $eet = [System.TimeZoneInfo]::ConvertTimeFromUtc($utc, $eetZone)
    $secondaryKey = '{0}|{1}|{2}' -f $utc.ToString('yyyy.MM.dd HH:mm'), $event.Currency, $event.Title
    if (-not $secondaryKeys.Contains($secondaryKey)) {
      [void]$secondaryKeys.Add($secondaryKey)
      $columns = @(
        $eet.ToString('yyyy.MM.dd'), $utc.ToString('yyyy.MM.dd HH:mm'),
        $eet.ToString('yyyy.MM.dd HH:mm'), $event.Currency,
        (ConvertTo-SecondaryImpact $event.Impact), $event.Title, '',
        $event.Forecast, $event.Previous
      )
      $newSecondary.Add(($columns -join ','))
    }
  }

  Append-Lines $primaryPath $newPrimary.ToArray()
  Append-Lines $secondaryPath $newSecondary.ToArray()
  $appendedPrimary = $newPrimary.Count
  $appendedSecondary = $newSecondary.Count
  Write-Host "appended: primary +$appendedPrimary, secondary +$appendedSecondary"
}

if (-not (Test-Path -LiteralPath $Common -PathType Container)) {
  New-Item -ItemType Directory -Path $Common -Force | Out-Null
}
foreach ($pair in @(
    @{ Seed = $primaryPath; Name = 'news_calendar_2015_2025.csv' },
    @{ Seed = $secondaryPath; Name = 'forex_factory_calendar_clean.csv' })) {
  if (Test-Path -LiteralPath $pair.Seed -PathType Leaf) {
    try {
      (Get-Item -LiteralPath $pair.Seed).LastWriteTime = $nowLocal
    }
    catch {
      Write-Warning "touch seed failed: $($pair.Seed): $_"
    }
    $destination = Join-Path $Common $pair.Name
    try {
      Copy-Item -LiteralPath $pair.Seed -Destination $destination -Force -ErrorAction Stop
    }
    catch {
      Write-Warning "Common copy skipped: $($pair.Name): $_"
    }
    if (Test-Path -LiteralPath $destination) {
      try {
        (Get-Item -LiteralPath $destination).LastWriteTime = $nowLocal
      }
      catch {
        Write-Warning "touch Common failed: $destination : $_"
      }
    }
  }
  else {
    Write-Warning "seed MISSING: $($pair.Seed)"
  }
}

$primaryRowsForCoverage = @(Read-Rows $primaryPath)
$newest = [DateTime]::MinValue
foreach ($row in @($primaryRowsForCoverage | Select-Object -Skip 1)) {
  $firstColumn = ($row -split ',')[0]
  [DateTime]$parsed = [DateTime]::MinValue
  if ([DateTime]::TryParseExact(
      $firstColumn,
      'yyyy-MM-dd HH:mm:ss',
      [Globalization.CultureInfo]::InvariantCulture,
      [Globalization.DateTimeStyles]::None,
      [ref]$parsed)) {
    if ($parsed -gt $newest) { $newest = $parsed }
  }
}

$required = $nowUtcValue.AddDays($CoverageDays)
if ($newest -lt $required) {
  $message = "STALE: newest event $($newest.ToString('u')) < required $($required.ToString('u')) (now+$CoverageDays d)"
  Write-Warning $message
  if (-not (Test-Path -LiteralPath $StateDir -PathType Container)) {
    New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
  }
  Set-Content -LiteralPath $staleFlag -Value $message -Encoding ascii
}
else {
  if (Test-Path -LiteralPath $staleFlag) {
    Remove-Item -LiteralPath $staleFlag -Force -ErrorAction SilentlyContinue
  }
  Write-Host "coverage OK: newest event $($newest.ToString('u')) >= now+$CoverageDays d"
}

Write-Host "news-calendar refresh v2 done @ $nowLocal (primary +$appendedPrimary, secondary +$appendedSecondary)"
