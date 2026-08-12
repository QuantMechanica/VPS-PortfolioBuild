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

function Get-OneRow {
    param(
        [Parameter(Mandatory)][object[]]$Rows,
        [Parameter(Mandatory)][string]$Date
    )

    $matches = @($Rows | Where-Object date_london -eq $Date)
    Assert-Contract ($matches.Count -eq 1) "Expected exactly one runtime row for $Date."
    return $matches[0]
}

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$testRoot = [IO.Path]::GetFullPath((Join-Path $tempBase ('qm_lbma_gold_pm_' + [guid]::NewGuid().ToString('N'))))
if (-not $testRoot.StartsWith($tempBase + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing unsafe test root: $testRoot"
}

$dataDirectory = Join-Path $PSScriptRoot 'data'
$generatedDirectory = Join-Path $testRoot 'generated'
$provisionRoot = Join-Path $testRoot 'Common\Files'
$runtimeName = 'QM5_LBMA_Gold_PM_schedule_20200101_20251231.csv'
$provenanceName = 'QM5_LBMA_Gold_PM_schedule_provenance.csv'
$sourcesName = 'QM5_LBMA_Gold_PM_schedule_sources.csv'
$transitionsName = 'QM5_Europe_London_transitions_20180101_20251231.csv'
$gapsName = 'QM5_LBMA_Gold_PM_schedule_gaps.csv'
$manifestName = 'QM5_LBMA_Gold_PM_schedule_manifest.json'
$artifactNames = @(
    $runtimeName,
    $provenanceName,
    $sourcesName,
    $transitionsName,
    $gapsName,
    $manifestName
)

try {
    $buildArgs = @{
        OutputDirectory = $generatedDirectory
        VerifyOfficialSources = $VerifyOfficialSources
    }
    $build = & (Join-Path $PSScriptRoot 'build_lbma_gold_pm_schedule.ps1') @buildArgs

    Assert-Contract ($build.status -eq 'PARTIAL_BLOCKED') 'The schedule must retain PARTIAL_BLOCKED status until declared gaps close.'
    Assert-Contract ($build.runtime_rows -eq 2192) 'Expected one runtime row per date in 2020-2025.'
    Assert-Contract ($build.scheduled_pm_auction_rows -eq 1503) 'Expected 1503 scheduled PM-auction dates.'
    Assert-Contract ($build.no_pm_auction_holiday_rows -eq 63) 'Expected 63 official PM no-auction holidays.'
    Assert-Contract ($build.no_pm_auction_weekend_rows -eq 626) 'Expected 626 weekend rows.'
    Assert-Contract ($build.source_rows -eq 9) 'Expected nine pinned official/card-authorized sources.'
    Assert-Contract ($build.timezone_transition_rows -eq 16) 'Expected 16 Europe/London transition rows for 2018-2025.'
    Assert-Contract ($build.gap_rows -eq 3) 'Expected three explicit coverage/status gaps.'

    foreach ($name in $artifactNames) {
        $checkedIn = Join-Path $dataDirectory $name
        $generated = Join-Path $generatedDirectory $name
        Assert-Contract (Test-Path -LiteralPath $checkedIn -PathType Leaf) "Missing checked-in artifact: $checkedIn"
        Assert-Contract (Test-Path -LiteralPath $generated -PathType Leaf) "Missing generated artifact: $generated"
        $checkedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $checkedIn).Hash
        $generatedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $generated).Hash
        Assert-Contract ($checkedHash -eq $generatedHash) "Generated artifact differs from checked-in artifact: $name"
    }

    $runtime = @(Import-Csv -LiteralPath (Join-Path $generatedDirectory $runtimeName))
    $provenance = @(Import-Csv -LiteralPath (Join-Path $generatedDirectory $provenanceName))
    $sources = @(Import-Csv -LiteralPath (Join-Path $generatedDirectory $sourcesName))
    $transitions = @(Import-Csv -LiteralPath (Join-Path $generatedDirectory $transitionsName))
    $gaps = @(Import-Csv -LiteralPath (Join-Path $generatedDirectory $gapsName))
    $manifest = Get-Content -Raw -LiteralPath (Join-Path $generatedDirectory $manifestName) | ConvertFrom-Json

    Assert-Contract ($runtime.Count -eq 2192) 'Runtime row count changed.'
    Assert-Contract (($runtime.date_london | Sort-Object -Unique).Count -eq 2192) 'Runtime dates are not unique.'
    Assert-Contract ($runtime[0].date_london -eq '2020-01-01') 'Runtime start date changed.'
    Assert-Contract ($runtime[-1].date_london -eq '2025-12-31') 'Runtime end date changed.'
    Assert-Contract (@($runtime | Where-Object pm_auction_status -eq 'SCHEDULED_PM_AUCTION').Count -eq 1503) 'Scheduled count changed.'
    Assert-Contract (@($runtime | Where-Object pm_auction_status -eq 'NO_PM_AUCTION_HOLIDAY').Count -eq 63) 'Holiday count changed.'
    Assert-Contract (@($runtime | Where-Object pm_auction_status -eq 'NO_PM_AUCTION_WEEKEND').Count -eq 626) 'Weekend count changed.'
    Assert-Contract ($provenance.Count -eq $runtime.Count) 'Runtime/provenance row counts differ.'
    Assert-Contract ($sources.Count -eq 9) 'Source row count changed.'
    Assert-Contract ($transitions.Count -eq 16) 'Timezone-transition row count changed.'
    Assert-Contract ($gaps.Count -eq 3) 'Gap row count changed.'

    $invalidScheduled = @($runtime | Where-Object {
        $_.pm_auction_status -eq 'SCHEDULED_PM_AUCTION' -and
        ($_.auction_start_london -ne '15:00:00' -or
         $_.auction_start_utc -notmatch '^20[0-9]{2}-[0-9]{2}-[0-9]{2}T1[45]:00:00Z$' -or
         $_.london_utc_offset_minutes -notin @('0', '60'))
    })
    Assert-Contract ($invalidScheduled.Count -eq 0) 'A scheduled row has invalid London/UTC clock fields.'
    $invalidClosed = @($runtime | Where-Object {
        $_.pm_auction_status -ne 'SCHEDULED_PM_AUCTION' -and
        ($_.auction_start_london -ne '' -or $_.auction_start_utc -ne '')
    })
    Assert-Contract ($invalidClosed.Count -eq 0) 'A no-auction row contains an auction time.'

    $stateFuneral = Get-OneRow -Rows $runtime -Date '2022-09-19'
    $jubilee = Get-OneRow -Rows $runtime -Date '2022-06-03'
    $coronation = Get-OneRow -Rows $runtime -Date '2023-05-08'
    $christmasEve = Get-OneRow -Rows $runtime -Date '2024-12-24'
    Assert-Contract ($stateFuneral.pm_auction_status -eq 'NO_PM_AUCTION_HOLIDAY') 'The 2022 State Funeral closure is missing.'
    Assert-Contract ($jubilee.pm_auction_status -eq 'NO_PM_AUCTION_HOLIDAY') 'The 2022 Platinum Jubilee closure is missing.'
    Assert-Contract ($coronation.pm_auction_status -eq 'NO_PM_AUCTION_HOLIDAY') 'The 2023 Coronation closure is missing.'
    Assert-Contract ($christmasEve.pm_auction_status -eq 'NO_PM_AUCTION_HOLIDAY') 'Christmas Eve PM closure is missing.'

    $beforeSpring = Get-OneRow -Rows $runtime -Date '2025-03-28'
    $afterSpring = Get-OneRow -Rows $runtime -Date '2025-03-31'
    $beforeAutumn = Get-OneRow -Rows $runtime -Date '2025-10-24'
    $afterAutumn = Get-OneRow -Rows $runtime -Date '2025-10-27'
    Assert-Contract ($beforeSpring.auction_start_utc -eq '2025-03-28T15:00:00Z') 'Pre-BST auction UTC conversion is wrong.'
    Assert-Contract ($afterSpring.auction_start_utc -eq '2025-03-31T14:00:00Z') 'BST auction UTC conversion is wrong.'
    Assert-Contract ($beforeAutumn.auction_start_utc -eq '2025-10-24T14:00:00Z') 'Pre-GMT auction UTC conversion is wrong.'
    Assert-Contract ($afterAutumn.auction_start_utc -eq '2025-10-27T15:00:00Z') 'GMT auction UTC conversion is wrong.'

    Assert-Contract ($manifest.calendar_status -eq 'PARTIAL_BLOCKED') 'Manifest must remain fail-closed/partial.'
    Assert-Contract ($manifest.calendar_semantics -eq 'OFFICIAL_SCHEDULE_NOT_ACTUAL_PUBLICATION_LEDGER') 'Manifest schedule semantics changed.'
    Assert-Contract ($manifest.requested_coverage_start -eq '2018-01-01') 'Requested start changed.'
    Assert-Contract ($manifest.verified_schedule_start -eq '2020-01-01') 'Verified start changed.'
    Assert-Contract ($manifest.outside_verified_coverage_policy -eq 'FAIL_CLOSED') 'Outside-coverage policy must be FAIL_CLOSED.'
    Assert-Contract ($manifest.verified_schedule_eligibility_policy -eq 'SCHEDULED_PM_AUCTION_ROWS_ELIGIBLE') 'Verified schedule eligibility changed.'
    Assert-Contract ($manifest.unexpected_cancellation_policy -eq 'KNOWN_OFFICIAL_CANCELLATION_OR_NO_PUBLICATION_FAILS_CLOSED') 'Cancellation policy changed.'
    Assert-Contract ($manifest.historical_actual_occurrence_evidence -eq 'PROMOTION_GAP_NONBLOCKING_FOR_TECHNICAL_SCHEDULE_ELIGIBILITY') 'Historical occurrence evidence policy changed.'
    Assert-Contract ($manifest.runtime_sha256 -eq $build.runtime_sha256) 'Manifest/runtime hash binding changed.'
    Assert-Contract ($manifest.timezone_transitions_sha256 -eq $build.timezone_transitions_sha256) 'Manifest/timezone hash binding changed.'
    Assert-Contract (@($gaps | Where-Object gap_code -eq 'OFFICIAL_ANNUAL_PDF_NOT_BYTE_RETRIEVABLE').Count -eq 2) '2018/2019 source gaps are not explicit.'
    Assert-Contract (@($gaps | Where-Object gap_code -eq 'NO_HISTORICAL_OPERATIONAL_CANCELLATION_LEDGER').Count -eq 1) 'Operational cancellation-ledger gap is not explicit.'
    Assert-Contract (@($runtime | Where-Object date_london -like '2018-*').Count -eq 0) 'Unverified 2018 dates leaked into runtime.'
    Assert-Contract (@($runtime | Where-Object date_london -like '2019-*').Count -eq 0) 'Unverified 2019 dates leaked into runtime.'

    foreach ($source in $sources) {
        Assert-Contract ($source.official_sha256 -match '^[0-9a-f]{64}$') "Source $($source.source_id) lacks a pinned SHA-256."
        $uri = [Uri]$source.official_url
        Assert-Contract ($uri.Scheme -eq 'https') "Source $($source.source_id) is not HTTPS."
        Assert-Contract ($uri.Host -in @('www.ice.com', 'data.iana.org')) "Source $($source.source_id) is not authorized."
    }

    $firstProvision = @(& (Join-Path $PSScriptRoot 'provision_lbma_gold_pm_schedule.ps1') -CommonFilesRoot $provisionRoot -Confirm:$false)
    Assert-Contract ($firstProvision.Count -eq 6) 'Provisioner did not emit six artifact results.'
    Assert-Contract (@($firstProvision | Where-Object status -ne 'PROVISIONED').Count -eq 0) 'First provision was not fully PROVISIONED.'

    $secondProvision = @(& (Join-Path $PSScriptRoot 'provision_lbma_gold_pm_schedule.ps1') -CommonFilesRoot $provisionRoot -Confirm:$false)
    Assert-Contract ($secondProvision.Count -eq 6) 'Idempotent provision did not emit six artifact results.'
    Assert-Contract (@($secondProvision | Where-Object status -ne 'ALREADY_PROVISIONED').Count -eq 0) 'Second provision was not fully ALREADY_PROVISIONED.'

    $liveGuarded = $false
    try {
        & (Join-Path $PSScriptRoot 'provision_lbma_gold_pm_schedule.ps1') -CommonFilesRoot (Join-Path $testRoot 'T_Live\Common\Files') -WhatIf | Out-Null
    }
    catch {
        $liveGuarded = $_.Exception.Message -match 'Refusing to provision inside T_Live'
    }
    Assert-Contract $liveGuarded 'Provisioner T_Live refusal guard did not fire.'

    [IO.File]::WriteAllText(
        (Join-Path $provisionRoot $runtimeName),
        "tampered`n",
        [Text.UTF8Encoding]::new($false)
    )
    $mismatchGuarded = $false
    try {
        & (Join-Path $PSScriptRoot 'provision_lbma_gold_pm_schedule.ps1') -CommonFilesRoot $provisionRoot -Confirm:$false | Out-Null
    }
    catch {
        $mismatchGuarded = $_.Exception.Message -match 'mismatched LBMA schedule artifact already exists'
    }
    Assert-Contract $mismatchGuarded 'Provisioner existing-file mismatch guard did not fire.'

    [pscustomobject]@{
        status = 'PASS_WITH_DECLARED_GAPS'
        calendar_status = $manifest.calendar_status
        runtime_rows = $runtime.Count
        scheduled_pm_auction_rows = @($runtime | Where-Object pm_auction_status -eq 'SCHEDULED_PM_AUCTION').Count
        no_pm_auction_holiday_rows = @($runtime | Where-Object pm_auction_status -eq 'NO_PM_AUCTION_HOLIDAY').Count
        no_pm_auction_weekend_rows = @($runtime | Where-Object pm_auction_status -eq 'NO_PM_AUCTION_WEEKEND').Count
        official_source_rows = $sources.Count
        timezone_transition_rows = $transitions.Count
        declared_gap_rows = $gaps.Count
        runtime_sha256 = $build.runtime_sha256
        provenance_sha256 = $build.provenance_sha256
        sources_sha256 = $build.sources_sha256
        timezone_transitions_sha256 = $build.timezone_transitions_sha256
        gaps_sha256 = $build.gaps_sha256
        manifest_sha256 = $build.manifest_sha256
        official_sources_verified = [bool]$VerifyOfficialSources
        provisioner_idempotent = $true
        t_live_refusal_guard = $true
        mismatch_refusal_guard = $true
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
