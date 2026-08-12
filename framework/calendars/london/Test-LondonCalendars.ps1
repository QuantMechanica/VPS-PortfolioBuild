[CmdletBinding()]
param(
    [switch]$VerifyOfficialSources
)

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

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$testRoot = [IO.Path]::GetFullPath((Join-Path $tempBase ('qm_london_calendars_' + [guid]::NewGuid().ToString('N'))))
if (-not $testRoot.StartsWith($tempBase + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing unsafe test root: $testRoot"
}

$dataDirectory = Join-Path $PSScriptRoot 'data'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$runtimeLoaderPath = Join-Path $repoRoot 'framework\include\QM\QM_LondonCalendars.mqh'
$generatedDirectory = Join-Path $testRoot 'generated'
$provisionRoot = Join-Path $testRoot 'Common\Files'
$holidayName = 'QM5_GOVUK_England_Wales_public_holidays_20180101_20251231.csv'
$holidayProvenanceName = 'QM5_GOVUK_England_Wales_public_holidays_provenance.csv'
$lseName = 'QM5_LSE_cash_session_exceptions_20180101_20251231.csv'
$lseProvenanceName = 'QM5_LSE_cash_session_exceptions_provenance.csv'
$wmrName = 'QM5_WMR_1600_London_service_exceptions_20250101_20251231.csv'
$wmrProvenanceName = 'QM5_WMR_1600_London_service_exceptions_provenance.csv'
$sourcesName = 'QM5_London_calendar_sources.csv'
$manifestName = 'QM5_London_calendar_manifest.json'
$artifactNames = @(
    $holidayName,
    $holidayProvenanceName,
    $lseName,
    $lseProvenanceName,
    $wmrName,
    $wmrProvenanceName,
    $sourcesName,
    $manifestName
)

try {
    $buildArgs = @{
        OutputDirectory = $generatedDirectory
        VerifyOfficialSources = $VerifyOfficialSources
    }
    $build = & (Join-Path $PSScriptRoot 'build_london_calendars.ps1') @buildArgs

    Assert-Contract ($build.holiday_rows -eq 67) 'Expected 67 England and Wales public-holiday rows.'
    Assert-Contract ($build.lse_rows -eq 83) 'Expected 83 LSE cash-session exceptions.'
    Assert-Contract ($build.lse_full_close_rows -eq 67) 'Expected 67 LSE full closes.'
    Assert-Contract ($build.lse_early_close_rows -eq 16) 'Expected 16 LSE early closes.'
    Assert-Contract ($build.wmr_rows -eq 7) 'Expected seven WMR 2025 service-alteration rows.'
    Assert-Contract ($build.source_rows -eq 9) 'Expected nine official source records.'

    foreach ($name in $artifactNames) {
        $checkedIn = Join-Path $dataDirectory $name
        $generated = Join-Path $generatedDirectory $name
        Assert-Contract (Test-Path -LiteralPath $checkedIn -PathType Leaf) "Missing checked-in artifact: $checkedIn"
        Assert-Contract (Test-Path -LiteralPath $generated -PathType Leaf) "Missing generated artifact: $generated"
        $checkedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $checkedIn).Hash
        $generatedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $generated).Hash
        Assert-Contract ($checkedHash -eq $generatedHash) "Generated artifact differs from checked-in artifact: $name"
    }

    $holidays = @(Import-Csv -LiteralPath (Join-Path $generatedDirectory $holidayName))
    $holidayProvenance = @(Import-Csv -LiteralPath (Join-Path $generatedDirectory $holidayProvenanceName))
    $lse = @(Import-Csv -LiteralPath (Join-Path $generatedDirectory $lseName))
    $lseProvenance = @(Import-Csv -LiteralPath (Join-Path $generatedDirectory $lseProvenanceName))
    $wmr = @(Import-Csv -LiteralPath (Join-Path $generatedDirectory $wmrName))
    $wmrProvenance = @(Import-Csv -LiteralPath (Join-Path $generatedDirectory $wmrProvenanceName))
    $sources = @(Import-Csv -LiteralPath (Join-Path $generatedDirectory $sourcesName))
    $manifest = Get-Content -Raw -LiteralPath (Join-Path $generatedDirectory $manifestName) | ConvertFrom-Json

    Assert-Contract ($holidays.Count -eq 67) 'Holiday runtime row count changed.'
    Assert-Contract (($holidays.date_london | Sort-Object -Unique).Count -eq 67) 'Holiday dates are not unique.'
    Assert-Contract (@($holidays | Where-Object day_type -ne 'PUBLIC_OR_BANK_HOLIDAY').Count -eq 0) 'Unexpected jurisdictional day type.'
    Assert-Contract ($holidayProvenance.Count -eq 67) 'Holiday provenance row count changed.'

    Assert-Contract ($lse.Count -eq 83) 'LSE runtime row count changed.'
    Assert-Contract (($lse.date_london | Sort-Object -Unique).Count -eq 83) 'LSE exception dates are not unique.'
    Assert-Contract (@($lse | Where-Object session_type -eq 'FULL_CLOSE').Count -eq 67) 'LSE full-close count changed.'
    Assert-Contract (@($lse | Where-Object session_type -eq 'EARLY_CLOSE').Count -eq 16) 'LSE early-close count changed.'
    Assert-Contract (@($lse | Where-Object {
        $_.session_type -eq 'EARLY_CLOSE' -and
        ($_.regular_open_london -ne '08:00' -or $_.regular_close_london -ne '12:30')
    }).Count -eq 0) 'An LSE early-close row is not 08:00-12:30 London.'
    Assert-Contract (@($lse | Where-Object {
        $_.session_type -eq 'FULL_CLOSE' -and
        ($_.regular_open_london -ne '' -or $_.regular_close_london -ne '')
    }).Count -eq 0) 'An LSE full-close row contains trading hours.'
    Assert-Contract ($lseProvenance.Count -eq 83) 'LSE provenance row count changed.'

    foreach ($date in @(
        '2018-12-24', '2018-12-31',
        '2019-12-24', '2019-12-31',
        '2020-12-24', '2020-12-31',
        '2021-12-24', '2021-12-31',
        '2022-12-23', '2022-12-30',
        '2023-12-22', '2023-12-29',
        '2024-12-24', '2024-12-31',
        '2025-12-24', '2025-12-31'
    )) {
        $match = @($lse | Where-Object date_london -eq $date)
        Assert-Contract ($match.Count -eq 1 -and $match[0].session_type -eq 'EARLY_CLOSE') "Expected LSE early close is missing: $date"
    }

    $stateFuneral = @($lseProvenance | Where-Object date_london -eq '2022-09-19')
    Assert-Contract ($stateFuneral.Count -eq 1 -and $stateFuneral[0].source_ids -match 'LSE_N16_2022_STATE_FUNERAL') 'Explicit State Funeral LSE source binding is missing.'
    $coronation = @($lse | Where-Object date_london -eq '2023-05-08')
    Assert-Contract ($coronation.Count -eq 1 -and $coronation[0].session_type -eq 'FULL_CLOSE') 'Coronation LSE full close is missing.'

    Assert-Contract ($wmr.Count -eq 7) 'WMR runtime row count changed.'
    Assert-Contract (($wmr.date_london | Sort-Object -Unique).Count -eq 7) 'WMR dates are not unique.'
    Assert-Contract (@($wmr | Where-Object wmr_1600_spot_status -eq 'NO_1600_FIX').Count -eq 3) 'WMR no-16:00-fix count changed.'
    Assert-Contract ($wmrProvenance.Count -eq 7) 'WMR provenance row count changed.'

    $may26Lse = @($lse | Where-Object date_london -eq '2025-05-26')
    $may26Wmr = @($wmr | Where-Object date_london -eq '2025-05-26')
    Assert-Contract ($may26Lse.Count -eq 1 -and $may26Lse[0].session_type -eq 'FULL_CLOSE') 'LSE 2025 Spring Bank Holiday closure is missing.'
    Assert-Contract ($may26Wmr.Count -eq 1 -and $may26Wmr[0].wmr_1600_spot_status -eq 'NORMAL_1600_FIX_AVAILABLE') 'WMR/LSE non-equivalence proof for 2025-05-26 changed.'

    $dec26Lse = @($lse | Where-Object date_london -eq '2025-12-26')
    $dec26Wmr = @($wmr | Where-Object date_london -eq '2025-12-26')
    Assert-Contract ($dec26Lse.Count -eq 1 -and $dec26Lse[0].session_type -eq 'FULL_CLOSE') 'LSE Boxing Day closure is missing.'
    Assert-Contract ($dec26Wmr.Count -eq 1 -and $dec26Wmr[0].wmr_1600_spot_status -eq 'ONLY_1600_FIX_AVAILABLE') 'WMR 2025 Boxing Day 16:00-only status changed.'

    Assert-Contract ($manifest.outside_coverage_policy -eq 'FAIL_CLOSED') 'Bundle must remain fail-closed.'
    Assert-Contract ($manifest.timezone -eq 'Europe/London') 'Bundle timezone changed.'
    Assert-Contract ($manifest.england_wales_public_holidays.coverage_status -eq 'COMPLETE') 'Jurisdictional coverage status changed.'
    Assert-Contract ($manifest.lse_cash_sessions.coverage_status -eq 'COMPLETE_SCHEDULED_EXCEPTIONS') 'LSE coverage status changed.'
    Assert-Contract ($manifest.wmr_1600_london_spot_service.coverage_status -eq 'PARTIAL_FAIL_CLOSED') 'WMR partial-coverage guard changed.'
    Assert-Contract ($manifest.wmr_1600_london_spot_service.uncovered_period -eq '2018-01-01/2024-12-31') 'WMR uncovered period changed.'
    Assert-Contract ([bool]$manifest.consumer_policy.jurisdictional_holiday_is_not_fx_closure) 'Holiday/FX separation guard changed.'
    Assert-Contract ([bool]$manifest.consumer_policy.lse_cash_calendar_must_not_gate_fx_routes) 'LSE/FX separation guard changed.'
    Assert-Contract ([bool]$manifest.consumer_policy.wmr_calendar_must_not_be_inferred_from_uk_holidays) 'WMR/holiday separation guard changed.'

    $knownSources = @{}
    foreach ($source in $sources) {
        Assert-Contract ($source.official_document_sha256 -match '^[0-9a-f]{64}$') "Invalid source hash for $($source.source_id)."
        Assert-Contract (-not $knownSources.ContainsKey($source.source_id)) "Duplicate source id: $($source.source_id)"
        $knownSources[$source.source_id] = $true
    }
    foreach ($row in @($holidayProvenance + $lseProvenance + $wmrProvenance)) {
        foreach ($sourceId in $row.source_ids.Split('|')) {
            Assert-Contract ($knownSources.ContainsKey($sourceId)) "Unknown row-provenance source id: $sourceId"
        }
    }

    Assert-Contract ($manifest.england_wales_public_holidays.runtime_sha256 -eq $build.holiday_sha256) 'Manifest/holiday runtime hash binding changed.'
    Assert-Contract ($manifest.lse_cash_sessions.runtime_sha256 -eq $build.lse_sha256) 'Manifest/LSE runtime hash binding changed.'
    Assert-Contract ($manifest.wmr_1600_london_spot_service.runtime_sha256 -eq $build.wmr_sha256) 'Manifest/WMR runtime hash binding changed.'
    Assert-Contract ($manifest.sources_sha256 -eq $build.sources_sha256) 'Manifest/source registry hash binding changed.'

    Assert-Contract (Test-Path -LiteralPath $runtimeLoaderPath -PathType Leaf) 'Shared MQL5 London calendar loader is missing.'
    $runtimeLoader = Get-Content -Raw -LiteralPath $runtimeLoaderPath
    $manifestHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $dataDirectory $manifestName)).Hash
    $holidayHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $dataDirectory $holidayName)).Hash
    $wmrHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $dataDirectory $wmrName)).Hash
    foreach ($binding in @(
        @{ Name = $manifestName; Hash = $manifestHash },
        @{ Name = $holidayName; Hash = $holidayHash },
        @{ Name = $lseName; Hash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $dataDirectory $lseName)).Hash },
        @{ Name = $wmrName; Hash = $wmrHash }
    )) {
        Assert-Contract ($runtimeLoader.Contains($binding.Name)) "Runtime loader is not bound to $($binding.Name)."
        Assert-Contract ($runtimeLoader.Contains($binding.Hash)) "Runtime loader hash binding changed for $($binding.Name)."
    }
    Assert-Contract ($runtimeLoader -match 'QM_LONDON_WMR_1600_COVERAGE_START\s*=\s*20250101') 'Runtime WMR coverage start is not fail-closed at 2025.'
    Assert-Contract ($runtimeLoader -match 'QM_LONDON_PUBLIC_DAY_PUBLIC_OR_BANK_HOLIDAY') 'Runtime loader lost the jurisdictional-holiday distinction.'
    Assert-Contract ($runtimeLoader -match 'QM_LONDON_LSE_CASH_COVERAGE_START\s*=\s*20180101') 'Runtime LSE coverage start changed.'
    Assert-Contract ($runtimeLoader -match 'QM_LONDON_LSE_CASH_EXPECTED_FULL_CLOSE_ROWS\s*=\s*67') 'Runtime LSE full-close row contract changed.'
    Assert-Contract ($runtimeLoader -match 'QM_LONDON_LSE_CASH_EXPECTED_EARLY_CLOSE_ROWS\s*=\s*16') 'Runtime LSE early-close row contract changed.'
    Assert-Contract ($runtimeLoader -match 'QM_LondonLseCashSessionUTC') 'Runtime loader lost London-local to UTC LSE session resolution.'
    Assert-Contract ($runtimeLoader -match 'QM_LONDON_WMR_1600_OUT_OF_COVERAGE') 'Runtime loader lost the WMR out-of-coverage verdict.'

    $ea20031 = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'framework\EAs\QM5_20031_asia-fx-fade\QM5_20031_asia-fx-fade.mq5')
    $ea20034 = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'framework\EAs\QM5_20034_wmr-postfix\QM5_20034_wmr-postfix.mq5')
    $ea20045 = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'framework\EAs\QM5_20045_london-box\QM5_20045_london-box.mq5')
    $ea20041 = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'framework\EAs\QM5_20041_postclose-cont\QM5_20041_postclose-cont.mq5')
    Assert-Contract ($ea20031 -match 'QM_LondonPublicHolidayClassify' -and $ea20031 -match 'fx_closure_inferred\\":false') 'QM5_20031 London holiday context gate is missing or implies FX closure.'
    Assert-Contract ($ea20034 -match 'QM_LondonWmr1600Classify' -and $ea20034 -notmatch 'QM_LondonPublicHolidayClassify' -and $ea20034 -notmatch 'QM_LondonLseCash') 'QM5_20034 is not isolated to the WMR service contract.'
    Assert-Contract ($ea20045 -match 'QM_LondonPublicHolidayClassify' -and $ea20045 -match 'lse_calendar_used\\":false') 'QM5_20045 London context gate is missing or uses LSE as an FX proxy.'
    Assert-Contract ($ea20041 -match 'QM_XetraCashCalendarClassify' -and $ea20041 -match 'QM_XetraCashBerlinLocalToUTC') 'QM5_20041 Xetra/GDAXI route changed or disappeared.'
    Assert-Contract ($ea20041 -match 'QM_LondonLseCashSessionUTC' -and $ea20041 -match 'LSE_EUROPE_LONDON_CALENDAR') 'QM5_20041 UK100 route is not bound to the LSE London-local session API.'
    Assert-Contract ($ea20041 -notmatch 'LEGACY_UK_BROKER_CLOCK') 'QM5_20041 still advertises the fixed broker-clock UK100 fallback.'
    Assert-Contract ($ea20041 -notmatch 'Strategy_BrokerDateTime') 'QM5_20041 still contains the fixed broker-date session resolver.'

    $firstProvision = @(& (Join-Path $PSScriptRoot 'provision_london_calendars.ps1') -CommonFilesRoot $provisionRoot -Confirm:$false)
    Assert-Contract ($firstProvision.Count -eq 8) 'Provisioner did not emit eight artifact results.'
    Assert-Contract (@($firstProvision | Where-Object status -ne 'PROVISIONED').Count -eq 0) 'First provision was not fully PROVISIONED.'

    $secondProvision = @(& (Join-Path $PSScriptRoot 'provision_london_calendars.ps1') -CommonFilesRoot $provisionRoot -Confirm:$false)
    Assert-Contract ($secondProvision.Count -eq 8) 'Idempotent provision did not emit eight artifact results.'
    Assert-Contract (@($secondProvision | Where-Object status -ne 'ALREADY_PROVISIONED').Count -eq 0) 'Second provision was not fully ALREADY_PROVISIONED.'

    $liveGuarded = $false
    try {
        & (Join-Path $PSScriptRoot 'provision_london_calendars.ps1') -CommonFilesRoot (Join-Path $testRoot 'T_Live\Common\Files') -WhatIf | Out-Null
    }
    catch {
        $liveGuarded = $_.Exception.Message -match 'Refusing to provision inside T_Live'
    }
    Assert-Contract $liveGuarded 'Provisioner T_Live refusal guard did not fire.'

    [pscustomobject]@{
        status = 'PASS'
        holiday_rows = $holidays.Count
        lse_rows = $lse.Count
        lse_full_close_rows = @($lse | Where-Object session_type -eq 'FULL_CLOSE').Count
        lse_early_close_rows = @($lse | Where-Object session_type -eq 'EARLY_CLOSE').Count
        wmr_rows = $wmr.Count
        wmr_coverage_status = $manifest.wmr_1600_london_spot_service.coverage_status
        wmr_uncovered_period = $manifest.wmr_1600_london_spot_service.uncovered_period
        official_source_rows = $sources.Count
        holiday_sha256 = $build.holiday_sha256
        lse_sha256 = $build.lse_sha256
        wmr_sha256 = $build.wmr_sha256
        manifest_sha256 = $build.manifest_sha256
        official_sources_verified = [bool]$VerifyOfficialSources
        runtime_loader_bound = $true
        ea_calendar_contracts_bound = $true
        ea_lse_contract_bound = $true
        provisioner_idempotent = $true
        t_live_refusal_guard = $true
    }
}
finally {
    $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
    if (-not $resolvedTestRoot.StartsWith($tempBase + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing unsafe recursive cleanup target: $resolvedTestRoot"
    }
    if (Test-Path -LiteralPath $resolvedTestRoot) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}
