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
$testRoot = [IO.Path]::GetFullPath((Join-Path $tempBase ('qm_nyse_us_cash_calendar_' + [guid]::NewGuid().ToString('N'))))
if (-not $testRoot.StartsWith($tempBase + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing unsafe test root: $testRoot"
}

$dataDirectory = Join-Path $PSScriptRoot 'data'
$generatedDirectory = Join-Path $testRoot 'generated'
$provisionRoot = Join-Path $testRoot 'Common\Files'
$calendarName = 'QM5_NYSE_US_cash_session_exceptions_20180101_20251231.csv'
$provenanceName = 'QM5_NYSE_US_cash_session_exceptions_provenance.csv'
$sourcesName = 'QM5_NYSE_US_cash_session_exceptions_sources.csv'
$manifestName = 'QM5_NYSE_US_cash_session_exceptions_manifest.json'

try {
    $buildArgs = @{
        OutputDirectory = $generatedDirectory
        VerifyOfficialSources = $VerifyOfficialSources
    }
    $build = & (Join-Path $PSScriptRoot 'build_nyse_us_cash_calendar.ps1') @buildArgs

    Assert-Contract ($build.calendar_rows -eq 95) 'Expected 95 runtime rows.'
    Assert-Contract ($build.full_close_rows -eq 77) 'Expected 77 FULL_CLOSE rows.'
    Assert-Contract ($build.early_close_rows -eq 18) 'Expected 18 EARLY_CLOSE rows.'
    Assert-Contract ($build.source_rows -eq 10) 'Expected 10 official source records.'

    foreach ($name in @($calendarName, $provenanceName, $sourcesName, $manifestName)) {
        $checkedIn = Join-Path $dataDirectory $name
        $generated = Join-Path $generatedDirectory $name
        Assert-Contract (Test-Path -LiteralPath $checkedIn -PathType Leaf) "Missing checked-in artifact: $checkedIn"
        Assert-Contract (Test-Path -LiteralPath $generated -PathType Leaf) "Missing generated artifact: $generated"
        $checkedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $checkedIn).Hash
        $generatedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $generated).Hash
        Assert-Contract ($checkedHash -eq $generatedHash) "Generated artifact differs from checked-in artifact: $name"
    }

    $runtime = @(Import-Csv -LiteralPath (Join-Path $generatedDirectory $calendarName))
    $provenance = @(Import-Csv -LiteralPath (Join-Path $generatedDirectory $provenanceName))
    $sources = @(Import-Csv -LiteralPath (Join-Path $generatedDirectory $sourcesName))
    $manifest = Get-Content -Raw -LiteralPath (Join-Path $generatedDirectory $manifestName) | ConvertFrom-Json

    Assert-Contract ($runtime.Count -eq 95) 'Runtime row count changed.'
    Assert-Contract (($runtime.date_new_york | Sort-Object -Unique).Count -eq 95) 'Runtime dates are not unique.'
    Assert-Contract ($provenance.Count -eq 95) 'Provenance row count changed.'
    Assert-Contract ($sources.Count -eq 10) 'Source row count changed.'
    Assert-Contract ($manifest.outside_coverage_policy -eq 'FAIL_CLOSED') 'Outside-coverage policy must remain FAIL_CLOSED.'
    Assert-Contract ($manifest.timezone -eq 'America/New_York') 'Calendar timezone changed.'
    Assert-Contract ($manifest.runtime_sha256 -eq $build.calendar_sha256) 'Manifest/runtime hash binding changed.'

    $bush = @($runtime | Where-Object date_new_york -eq '2018-12-05')
    $carter = @($runtime | Where-Object date_new_york -eq '2025-01-09')
    $juneteenth2022 = @($runtime | Where-Object date_new_york -eq '2022-06-20')
    Assert-Contract ($bush.Count -eq 1 -and $bush[0].session_type -eq 'FULL_CLOSE') 'Bush Day-of-Mourning closure is missing.'
    Assert-Contract ($carter.Count -eq 1 -and $carter[0].session_type -eq 'FULL_CLOSE') 'Carter Day-of-Mourning closure is missing.'
    Assert-Contract ($juneteenth2022.Count -eq 1 -and $juneteenth2022[0].session_type -eq 'FULL_CLOSE') 'Juneteenth 2022 closure is missing.'
    Assert-Contract (@($runtime | Where-Object date_new_york -eq '2022-01-01').Count -eq 0) 'NYSE explicitly observed no separate New Years closure in 2022.'
    Assert-Contract (@($runtime | Where-Object {
        $_.session_type -eq 'EARLY_CLOSE' -and
        ($_.open_time_new_york -ne '09:30' -or $_.close_time_new_york -ne '13:00')
    }).Count -eq 0) 'An early-close row is not 09:30-13:00 New York time.'

    $firstProvision = @(& (Join-Path $PSScriptRoot 'provision_nyse_us_cash_calendar.ps1') -CommonFilesRoot $provisionRoot -Confirm:$false)
    Assert-Contract ($firstProvision.Count -eq 4) 'Provisioner did not emit four artifact results.'
    Assert-Contract (@($firstProvision | Where-Object status -ne 'PROVISIONED').Count -eq 0) 'First provision was not fully PROVISIONED.'

    $secondProvision = @(& (Join-Path $PSScriptRoot 'provision_nyse_us_cash_calendar.ps1') -CommonFilesRoot $provisionRoot -Confirm:$false)
    Assert-Contract ($secondProvision.Count -eq 4) 'Idempotent provision did not emit four artifact results.'
    Assert-Contract (@($secondProvision | Where-Object status -ne 'ALREADY_PROVISIONED').Count -eq 0) 'Second provision was not fully ALREADY_PROVISIONED.'

    $liveGuarded = $false
    try {
        & (Join-Path $PSScriptRoot 'provision_nyse_us_cash_calendar.ps1') -CommonFilesRoot (Join-Path $testRoot 'T_Live\Common\Files') -WhatIf | Out-Null
    }
    catch {
        $liveGuarded = $_.Exception.Message -match 'Refusing to provision inside T_Live'
    }
    Assert-Contract $liveGuarded 'Provisioner T_Live refusal guard did not fire.'

    [pscustomobject]@{
        status = 'PASS'
        runtime_rows = $runtime.Count
        full_close_rows = @($runtime | Where-Object session_type -eq 'FULL_CLOSE').Count
        early_close_rows = @($runtime | Where-Object session_type -eq 'EARLY_CLOSE').Count
        official_source_rows = $sources.Count
        runtime_sha256 = $build.calendar_sha256
        provenance_sha256 = $build.provenance_sha256
        sources_sha256 = $build.sources_sha256
        manifest_sha256 = $build.manifest_sha256
        official_sources_verified = [bool]$VerifyOfficialSources
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
