[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Contract {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Contains {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Needle,
        [Parameter(Mandatory)][string]$Message
    )
    Assert-Contract ($Text.Contains($Needle, [StringComparison]::Ordinal)) $Message
}

function Assert-Regex {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$Message
    )
    Assert-Contract ([regex]::IsMatch($Text, $Pattern, [Text.RegularExpressions.RegexOptions]::Multiline)) $Message
}

function Get-QuotedDefine {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Name
    )
    $pattern = '(?m)^#define\s+' + [regex]::Escape($Name) + '\s+"([^"]+)"\s*$'
    $match = [regex]::Match($Text, $pattern)
    Assert-Contract $match.Success "Missing quoted MQL define: $Name"
    return $match.Groups[1].Value
}

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$loaderPath = Join-Path $repoRoot 'framework\include\QM\QM_XetraCashCalendar.mqh'
$manifestPath = Join-Path $PSScriptRoot 'data\QM5_XETRA_cash_session_exceptions_manifest.json'
$ea20032Path = Join-Path $repoRoot 'framework\EAs\QM5_20032_macro0830-brk\QM5_20032_macro0830-brk.mq5'
$ea20033Path = Join-Path $repoRoot 'framework\EAs\QM5_20033_moc-imom\QM5_20033_moc-imom.mq5'
$ea20041Path = Join-Path $repoRoot 'framework\EAs\QM5_20041_postclose-cont\QM5_20041_postclose-cont.mq5'

foreach ($path in @($loaderPath, $manifestPath, $ea20032Path, $ea20033Path, $ea20041Path)) {
    Assert-Contract (Test-Path -LiteralPath $path -PathType Leaf) "Missing integration artifact: $path"
}

$loader = Get-Content -Raw -LiteralPath $loaderPath
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$ea20032 = Get-Content -Raw -LiteralPath $ea20032Path
$ea20033 = Get-Content -Raw -LiteralPath $ea20033Path
$ea20041 = Get-Content -Raw -LiteralPath $ea20041Path

$runtimePath = Join-Path (Split-Path -Parent $manifestPath) $manifest.runtime_file
Assert-Contract (Test-Path -LiteralPath $runtimePath -PathType Leaf) 'Manifest runtime file is missing.'
$runtimeHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $runtimePath).Hash
$manifestHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $manifestPath).Hash
$loaderRuntimeFile = Get-QuotedDefine $loader 'QM_XETRA_CASH_CALENDAR_RUNTIME_FILE'
$loaderRuntimeHash = Get-QuotedDefine $loader 'QM_XETRA_CASH_CALENDAR_RUNTIME_SHA256'
$loaderManifestHash = Get-QuotedDefine $loader 'QM_XETRA_CASH_CALENDAR_MANIFEST_SHA256'

Assert-Contract ($loaderRuntimeFile -eq $manifest.runtime_file) 'Loader runtime filename is not manifest-bound.'
Assert-Contract ($loaderRuntimeHash -eq $runtimeHash) 'Loader runtime SHA-256 is not byte-exact.'
Assert-Contract ($manifest.runtime_sha256.ToUpperInvariant() -eq $runtimeHash) 'Manifest runtime SHA-256 is not byte-exact.'
Assert-Contract ($loaderManifestHash -eq $manifestHash) 'Loader manifest SHA-256 is not byte-exact.'
Assert-Contract ($manifest.runtime_rows -eq 66 -and $manifest.full_close_rows -eq 58 -and $manifest.early_close_rows -eq 8) 'Manifest row-count contract changed.'

# Shared fail-closed loader contracts.
Assert-Contains $loader 'FILE_SHARE_READ | FILE_COMMON' 'Loader does not hash the FILE_COMMON runtime artifact.'
Assert-Contains $loader 'FILE_SHARE_READ | FILE_COMMON,' 'Loader does not parse the FILE_COMMON runtime artifact.'
Assert-Contains $loader 'header_date != "date_berlin"' 'Loader does not validate the date header.'
Assert-Contains $loader 'header_type != "session_type"' 'Loader does not validate the session-type header.'
Assert-Contains $loader 'header_open != "open_time_berlin"' 'Loader does not validate the open-time header.'
Assert-Contains $loader 'header_close != "close_time_berlin"' 'Loader does not validate the close-time header.'
Assert-Contains $loader 'date_key <= previous_date_key' 'Loader does not enforce strict date sorting/uniqueness.'
Assert-Contains $loader '!QM_XetraCashIsWeekday(date_key)' 'Loader does not reject weekend exception rows.'
Assert-Contains $loader 'open_text != "09:00" || close_text != "14:00"' 'Loader early-close schema changed.'
Assert-Contains $loader 'open_text != "" || close_text != ""' 'Loader does not require empty FULL_CLOSE times.'
Assert-Contains $loader 'rows != QM_XETRA_CASH_EXPECTED_ROWS' 'Loader does not enforce total row count.'
Assert-Contains $loader 'full_close_rows != QM_XETRA_CASH_EXPECTED_FULL_CLOSE_ROWS' 'Loader does not enforce FULL_CLOSE count.'
Assert-Contains $loader 'early_close_rows != QM_XETRA_CASH_EXPECTED_EARLY_CLOSE_ROWS' 'Loader does not enforce EARLY_CLOSE count.'
Assert-Contains $loader 'return QM_XETRA_CASH_OUT_OF_COVERAGE;' 'Loader does not fail closed outside governed coverage.'
Assert-Contains $loader 'QM_XetraCashCalendarFindException' 'Loader does not use the sorted exception lookup.'
Assert-Contains $loader 'for(int offset_hours = 1; offset_hours <= 2; ++offset_hours)' 'Berlin wall-clock conversion does not test CET and CEST candidates.'
Assert-Contains $loader 'if(valid_candidates != 1)' 'Berlin wall-clock conversion does not reject ambiguous/nonexistent labels.'

foreach ($ea in @($ea20032, $ea20033, $ea20041)) {
    Assert-Contains $ea '#include <QM/QM_XetraCashCalendar.mqh>' 'An integrated EA is missing the shared Xetra loader include.'
    Assert-Contains $ea 'QM_XetraCashCalendarLoad(QM_XETRA_CASH_CALENDAR_RUNTIME_FILE,' 'An integrated EA does not load the hash-bound Xetra runtime.'
    Assert-Contains $ea 'QM_XETRA_CASH_CALENDAR_RUNTIME_SHA256' 'An integrated EA does not pass the governed runtime SHA-256.'
}

# 20033: Xetra session times are Europe/Berlin-derived; fixed Xetra broker
# inputs remain declarations only for setfile compatibility.
Assert-Contains $ea20033 'QM_XetraCashBerlinDateKeyFromUTC(QM_BrokerToUTC(broker_time))' '20033 does not derive the Xetra cash date in Europe/Berlin.'
Assert-Contains $ea20033 'QM_XetraCashCalendarClassify(date_key)' '20033 does not classify the Xetra session.'
Assert-Regex $ea20033 'QM_XETRA_CASH_EARLY_CLOSE\s*\?\s*13\s*:\s*17' '20033 early-close entry hour is not 13:30 Berlin.'
Assert-Regex $ea20033 'QM_XETRA_CASH_EARLY_CLOSE\s*\?\s*30\s*:\s*0' '20033 early-close entry minute is not 30.'
Assert-Regex $ea20033 'QM_XETRA_CASH_EARLY_CLOSE\s*\?\s*14\s*:\s*17' '20033 early-close exit hour is not 14:00 Berlin.'
Assert-Contains $ea20033 'if(RouteIndex(_Symbol) == 3)' '20033 does not separate GDAXI input validation from US clocks.'
Assert-Contains $ea20033 'legacy_xetra_broker_inputs_ignored\":true' '20033 does not disclose ignored legacy Xetra broker inputs.'
foreach ($name in @(
    'strategy_xetra_open_hour_broker',
    'strategy_xetra_open_minute_broker',
    'strategy_xetra_entry_hour_broker',
    'strategy_xetra_entry_minute_broker',
    'strategy_xetra_close_hour_broker',
    'strategy_xetra_close_minute_broker'
)) {
    Assert-Contract ([regex]::Matches($ea20033, '\b' + [regex]::Escape($name) + '\b').Count -eq 1) "20033 still consumes legacy fixed Xetra input: $name"
}

# 20032: preserve partial issuer-ledger execution, while exchange full/early
# closes are deterministic and the unresolved issuer coverage stays explicit.
Assert-Contains $ea20032 'bool ResolveEventExitUtc(' '20032 does not resolve event exits against the Xetra calendar.'
Assert-Contains $ea20032 'session_type == QM_XETRA_CASH_FULL_CLOSE' '20032 does not exclude German full-close dates.'
Assert-Contains $ea20032 'session_type == QM_XETRA_CASH_EARLY_CLOSE ? 14 : 17' '20032 does not map German early closes to 14:00 Berlin.'
Assert-Contains $ea20032 'QM_XetraCashBerlinDateKeyFromUTC(open_utc)' '20032 recovery exit does not derive the GDAXI date in Europe/Berlin.'
Assert-Contains $ea20032 'issuer_ledger_complete\":false' '20032 no longer discloses the incomplete issuer ledger.'
Assert-Contains $ea20032 'return true;' '20032 must retain the admitted partial issuer subset instead of a synthetic permanent blocker.'
Assert-Contract (-not $ea20032.Contains('early_close_calendar\":\"unavailable', [StringComparison]::Ordinal)) '20032 still reports the now-governed Xetra early-close calendar as unavailable.'
Assert-Contract (-not [regex]::IsMatch($ea20032, '(?i)bool\s+\w*(issuer|ledger|calendar)\w*complete\w*\s*=\s*false')) '20032 contains a synthetic completeness blocker instead of partial-subset execution.'

# 20041: Xetra governs the German cash-session mapping and the separate London
# loader governs UK/LSE sessions. Broker break, rollover, and financing evidence
# remain explicitly unresolved, with no hardcoded metadata-completeness gate.
Assert-Contains $ea20041 'QM_XetraCashBerlinDateKeyFromUTC(QM_BrokerToUTC(broker_time))' '20041 does not derive the GDAXI cash date in Europe/Berlin.'
Assert-Contains $ea20041 'QM_XetraCashCalendarClassify(date_key)' '20041 does not classify the Xetra cash session.'
Assert-Contains $ea20041 'session_type == QM_XETRA_CASH_EARLY_CLOSE ? 14 : 17' '20041 does not map Xetra early closes to 14:00 Berlin.'
Assert-Contains $ea20041 'broker_symbol_session_metadata\":\"unavailable' '20041 does not disclose missing broker session metadata.'
Assert-Contains $ea20041 'daily_break_rollover_metadata\":\"unavailable' '20041 does not disclose the daily break/rollover gap.'
Assert-Contains $ea20041 'financing_metadata\":\"unavailable' '20041 does not disclose the financing gap.'
Assert-Contains $ea20041 'lse_calendar\":\"%s' '20041 does not disclose the UK/LSE calendar state.'
Assert-Contains $ea20041 'broker_safety_metadata_gap_logged_no_synthetic_runtime_gate' '20041 broker-safety evidence-gap semantics changed.'
Assert-Contains $ea20041 'QM_LondonLseCashCalendarLoad()' '20041 does not load the governed LSE calendar for UK100.'
Assert-Contains $ea20041 'LSE_EUROPE_LONDON_TO_UTC_TO_BROKER' '20041 does not disclose the governed UK100 clock source.'
$inputsValidMatch = [regex]::Match(
    $ea20041,
    '(?s)bool\s+Strategy_InputsValid\s*\(\s*\)\s*\{(?<body>.*?)\}\s*bool\s+Strategy_WideSpread'
)
Assert-Contract $inputsValidMatch.Success '20041 Strategy_InputsValid could not be isolated.'
Assert-Contract (-not $inputsValidMatch.Groups['body'].Value.Contains('strategy_cash_', [StringComparison]::Ordinal)) '20041 input validation still depends on legacy broker-clock fields.'
Assert-Contract (-not [regex]::IsMatch($ea20041, '(?i)if\s*\([^\r\n]*(metadata|financing|rollover|lse)[^\r\n]*false')) '20041 contains a synthetic evidence-metadata runtime blocker.'

[pscustomobject]@{
    status = 'PASS'
    runtime_sha256 = $runtimeHash.ToLowerInvariant()
    manifest_sha256 = $manifestHash.ToLowerInvariant()
    loader_contract = 'STRICT_FAIL_CLOSED'
    ea_20032 = 'XETRA_GUARD_WITH_PARTIAL_ISSUER_LEDGER'
    ea_20033 = 'BERLIN_SESSION_AND_1330_EARLY_ENTRY'
    ea_20041 = 'XETRA_AND_LSE_WITH_BROKER_SAFETY_GAPS_LOGGED'
    builds_run = $false
}
