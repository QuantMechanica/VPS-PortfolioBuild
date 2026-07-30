<#
.SYNOPSIS
  Refresh the QM news calendars with real weekly event data.

.DESCRIPTION
  Fetches the Forex Factory weekly JSON feed, converts events into both
  production CSV layouts, appends only unseen events in an isolated staging
  directory, and publishes one manifest/hash-bound generation to the shared
  source plus every configured MetaTrader Common\Files root. The publisher
  holds the global Factory mutation lock and is safe in both Factory OFF and
  Factory ON generations.

  Network/parse failures are fail-soft and non-publishing: existing valid seeds
  and their mtimes are retained byte-for-byte. Missing or malformed seed
  headers are never synthesized or appended to. Output stays ASCII, CRLF, and
  BOM-free for MT5 FILE_ANSI reads.
#>
[CmdletBinding()]
param(
  [string]$FeedUrl = 'https://nfs.faireconomy.media/ff_calendar_thisweek.json',
  [string]$FeedPath = '',
  [int]$CoverageDays = 2,
  [datetime]$NowUtc = [DateTime]::UtcNow,
  [switch]$ReconciliationPlanOnly
)

$ErrorActionPreference = 'Stop'
$base = 'D:\QM\data\news_calendar'
$stateDir = 'D:\QM\reports\state'
$pythonExe = 'C:\Python311\python.exe'
$factoryOffFlag = 'D:\QM\strategy_farm\state\FACTORY_OFF.flag'
$nowUtcValue = $NowUtc.ToUniversalTime()
$nowLocal = $nowUtcValue.ToLocalTime()
$activePrimaryPath = Join-Path $Base 'news_calendar_2015_2025.csv'
$activeSecondaryPath = Join-Path $Base 'forex_factory_calendar_clean.csv'
$staleFlag = Join-Path $StateDir 'news_calendar_stale.flag'
$gateScript = Join-Path $PSScriptRoot 'news_calendar_gate.py'
$commonTargets = @(
  'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files',
  'C:\Windows\System32\config\systemprofile\AppData\Roaming\MetaQuotes\Terminal\Common\Files',
  'C:\Users\QMDev1\AppData\Roaming\MetaQuotes\Terminal\Common\Files'
)
$primaryHeader = 'datetime,currency,event_name,impact,actual,forecast,previous,impact_numeric,is_high_impact,is_nfp,is_fomc,is_ecb,is_boe,is_gdp,is_cpi,is_pmi,day_of_week,hour,day,is_first_friday'
$secondaryHeader = 'Date,DateTime_UTC,DateTime_EET,Currency,Impact,Event,Actual,Forecast,Previous'
$asciiNoBom = New-Object System.Text.ASCIIEncoding

if (-not [IO.Path]::IsPathRooted($PythonExe) -or -not (Test-Path -LiteralPath $PythonExe -PathType Leaf)) {
  throw "absolute Python interpreter is missing: $PythonExe"
}
if (-not (Test-Path -LiteralPath $gateScript -PathType Leaf)) {
  throw "news-calendar gate script is missing: $gateScript"
}

function Invoke-NewsCalendarGate([string[]]$Arguments) {
  $output = @(& $PythonExe $gateScript @Arguments 2>&1)
  $exitCode = $LASTEXITCODE
  $text = (@($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine)
  if ($exitCode -ne 0) {
    throw "news-calendar gate failed (exit=$exitCode): $text"
  }
  return $text
}

function New-MultiPlanArguments(
  [string]$PrimaryCandidate,
  [string]$SecondaryCandidate
) {
  $arguments = New-Object 'System.Collections.Generic.List[string]'
  foreach ($value in @(
      'multi-plan',
      '--primary-candidate', $PrimaryCandidate,
      '--secondary-candidate', $SecondaryCandidate,
      '--generated-at', $nowUtcValue.ToString('yyyy-MM-ddTHH:mm:ssZ'))) {
    $arguments.Add([string]$value)
  }
  return @($arguments.ToArray())
}

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

if ($ReconciliationPlanOnly) {
  $planArguments = New-MultiPlanArguments $activePrimaryPath $activeSecondaryPath
  $planJson = Invoke-NewsCalendarGate $planArguments
  Write-Output $planJson
  return
}

$primaryValid = Test-SeedHeader $activePrimaryPath $primaryHeader
$secondaryValid = Test-SeedHeader $activeSecondaryPath $secondaryHeader
$seedsValid = $primaryValid -and $secondaryValid
$events = @()

if (-not $seedsValid) {
  Write-Warning 'calendar refresh skipped because both active seed headers are not valid'
  return
}

if ($seedsValid) {
  try {
    if (-not [string]::IsNullOrWhiteSpace($FeedPath)) {
      $feedJson = [IO.File]::ReadAllText($FeedPath)
    }
    else {
      $response = Invoke-WebRequest -Uri $FeedUrl -UseBasicParsing -TimeoutSec 40 -ErrorAction Stop
      $feedJson = $response.Content
    }
    # Parameter form + re-wrap: PS 5.1 pipeline emits a JSON array as ONE object,
    # which @(pipeline) wraps into a single pseudo-event. Assignment + @() keeps
    # element count correct on both PS 5.1 and pwsh 7.
    $parsedFeed = ConvertFrom-Json -InputObject $feedJson -ErrorAction Stop
    $events = @($parsedFeed)
    Write-Host "feed OK: $($events.Count) events"
  }
  catch {
    Write-Warning "feed fetch/parse failed ($_) -- no publication; source/Common bytes and mtimes retained"
    return
  }
}
else {
  Write-Warning 'calendar append skipped because both seed headers are not valid'
}

if (-not (Test-Path -LiteralPath $StateDir -PathType Container)) {
  New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
}
$stagingDir = Join-Path $StateDir ('news-calendar-staging-' + [Guid]::NewGuid().ToString('N'))
$primaryPath = Join-Path $stagingDir 'news_calendar_2015_2025.csv'
$secondaryPath = Join-Path $stagingDir 'forex_factory_calendar_clean.csv'

try {
New-Item -ItemType Directory -Path $stagingDir -ErrorAction Stop | Out-Null
[IO.File]::WriteAllBytes($primaryPath, [IO.File]::ReadAllBytes($activePrimaryPath))
[IO.File]::WriteAllBytes($secondaryPath, [IO.File]::ReadAllBytes($activeSecondaryPath))
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

$operationStamp = $nowUtcValue.ToString('yyyyMMddTHHmmssZ') + '-' + [Guid]::NewGuid().ToString('N')
$planPath = Join-Path $StateDir ("news_calendar_publication_plan_$operationStamp.json")
$planArguments = New-Object 'System.Collections.Generic.List[string]'
foreach ($argument in @(New-MultiPlanArguments $primaryPath $secondaryPath)) {
  $planArguments.Add([string]$argument)
}
$planArguments.Add('--output')
$planArguments.Add($planPath)
$planJson = Invoke-NewsCalendarGate @($planArguments.ToArray())
$planObject = ConvertFrom-Json -InputObject $planJson -ErrorAction Stop
$planSha = [string]$planObject.plan_sha256
if ($planSha -notmatch '^[0-9a-f]{64}$') {
  throw 'news-calendar multi-plan did not return a valid plan_sha256'
}
if (-not (Test-Path -LiteralPath $planPath -PathType Leaf)) {
  throw "news-calendar multi-plan output is missing: $planPath"
}
$persistedPlan = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($planPath)) -ErrorAction Stop
if ([string]$persistedPlan.plan_sha256 -cne $planSha) {
  throw 'persisted news-calendar plan does not match stdout plan_sha256'
}

$publishArguments = New-Object 'System.Collections.Generic.List[string]'
$journalPath = Join-Path $StateDir ("news_calendar_publication_journal_$operationStamp.json")
$receiptPath = Join-Path $StateDir ("news_calendar_publication_receipt_$operationStamp.json")
foreach ($value in @(
    'multi-publish', '--plan', $planPath,
    '--expected-plan-sha256', $planSha,
    '--apply', '--journal-output', $journalPath,
    '--receipt-output', $receiptPath)) {
  $publishArguments.Add([string]$value)
}
if (Test-Path -LiteralPath $factoryOffFlag -PathType Leaf) {
  $flagHash = (Get-FileHash -LiteralPath $factoryOffFlag -Algorithm SHA256).Hash.ToLowerInvariant()
  $publishArguments.Add('--expected-factory-off-sha256')
  $publishArguments.Add($flagHash)
}
elseif (Test-Path -LiteralPath $factoryOffFlag) {
  throw "FACTORY_OFF path exists but is not a file: $factoryOffFlag"
}
else {
  $publishArguments.Add('--allow-factory-on')
}

$receiptJson = Invoke-NewsCalendarGate @($publishArguments.ToArray())
$receiptObject = ConvertFrom-Json -InputObject $receiptJson -ErrorAction Stop
if (
  -not $receiptObject.ok -or
  [string]$receiptObject.status -cne 'committed' -or
  -not $receiptObject.published -or
  [string]$receiptObject.plan_sha256 -cne $planSha
) {
  throw 'news-calendar publication receipt is not bound to the planned apply'
}
if (-not (Test-Path -LiteralPath $journalPath -PathType Leaf)) {
  throw "news-calendar publication journal output is missing: $journalPath"
}
if (-not (Test-Path -LiteralPath $receiptPath -PathType Leaf)) {
  throw "news-calendar publication receipt output is missing: $receiptPath"
}
$persistedReceipt = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($receiptPath)) -ErrorAction Stop
if (
  -not $persistedReceipt.ok -or
  [string]$persistedReceipt.status -cne 'committed' -or
  -not $persistedReceipt.published -or
  [string]$persistedReceipt.plan_sha256 -cne $planSha
) {
  throw 'persisted news-calendar receipt is not bound to the planned apply'
}
$persistedJournal = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($journalPath)) -ErrorAction Stop
if (-not $persistedJournal.committed -or [string]$persistedJournal.state -cne 'COMMITTED_RECEIPTED') {
  throw 'persisted news-calendar journal does not record a receipted commit'
}
Write-Host "publication OK: plan=$planSha targets=$($commonTargets.Count) journal=$journalPath receipt=$receiptPath"

$primaryRowsForCoverage = @(Read-Rows $activePrimaryPath)
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
}
finally {
  foreach ($knownPath in @($primaryPath, $secondaryPath)) {
    if (Test-Path -LiteralPath $knownPath -PathType Leaf) {
      Remove-Item -LiteralPath $knownPath -Force -ErrorAction SilentlyContinue
    }
  }
  if (Test-Path -LiteralPath $stagingDir -PathType Container) {
    Remove-Item -LiteralPath $stagingDir -Force -ErrorAction SilentlyContinue
  }
}
