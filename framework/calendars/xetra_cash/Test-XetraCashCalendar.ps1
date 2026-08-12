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
$testRoot = [IO.Path]::GetFullPath((Join-Path $tempBase ('qm_xetra_cash_calendar_' + [guid]::NewGuid().ToString('N'))))
if (-not $testRoot.StartsWith($tempBase + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing unsafe test root: $testRoot"
}

$dataDirectory = Join-Path $PSScriptRoot 'data'
$generatedDirectory = Join-Path $testRoot 'generated'
$provisionRoot = Join-Path $testRoot 'Terminal\Common\Files'
$calendarName = 'QM5_XETRA_cash_session_exceptions_20180101_20251231.csv'
$provenanceName = 'QM5_XETRA_cash_session_exceptions_provenance.csv'
$sourcesName = 'QM5_XETRA_cash_session_exceptions_sources.csv'
$manifestName = 'QM5_XETRA_cash_session_exceptions_manifest.json'

try {
    $build = & (Join-Path $PSScriptRoot 'build_xetra_cash_calendar.ps1') `
        -OutputDirectory $generatedDirectory `
        -VerifyOfficialSources:$VerifyOfficialSources

    Assert-Contract ($build.calendar_rows -eq 66) 'Expected 66 runtime rows.'
    Assert-Contract ($build.full_close_rows -eq 58) 'Expected 58 FULL_CLOSE rows.'
    Assert-Contract ($build.early_close_rows -eq 8) 'Expected 8 EARLY_CLOSE rows.'
    Assert-Contract ($build.source_rows -eq 16) 'Expected 16 official source records.'

    foreach ($name in @($calendarName, $provenanceName, $sourcesName, $manifestName)) {
        $checkedIn = Join-Path $dataDirectory $name
        $generated = Join-Path $generatedDirectory $name
        Assert-Contract (Test-Path -LiteralPath $checkedIn -PathType Leaf) "Missing governed artifact: $checkedIn"
        Assert-Contract (Test-Path -LiteralPath $generated -PathType Leaf) "Missing generated artifact: $generated"
        $checkedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $checkedIn).Hash
        $generatedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $generated).Hash
        Assert-Contract ($checkedHash -eq $generatedHash) "Generated artifact differs from governed artifact: $name"
    }

    $runtime = @(Import-Csv -LiteralPath (Join-Path $generatedDirectory $calendarName))
    $provenance = @(Import-Csv -LiteralPath (Join-Path $generatedDirectory $provenanceName))
    $sources = @(Import-Csv -LiteralPath (Join-Path $generatedDirectory $sourcesName))
    $manifest = Get-Content -Raw -LiteralPath (Join-Path $generatedDirectory $manifestName) | ConvertFrom-Json

    Assert-Contract ($runtime.Count -eq 66) 'Runtime row count changed.'
    Assert-Contract (($runtime.date_berlin | Sort-Object -Unique).Count -eq 66) 'Runtime dates are not unique.'
    Assert-Contract ($provenance.Count -eq 66) 'Provenance row count changed.'
    Assert-Contract ($sources.Count -eq 16) 'Source row count changed.'
    Assert-Contract ($manifest.calendar_id -eq 'DEUTSCHE_BOERSE_XETRA_CASH_EQUITIES') 'Calendar identity changed.'
    Assert-Contract ($manifest.venue_mic -eq 'XETR') 'Venue MIC changed.'
    Assert-Contract ($manifest.timezone -eq 'Europe/Berlin') 'Calendar timezone changed.'
    Assert-Contract ($manifest.outside_coverage_policy -eq 'FAIL_CLOSED') 'Outside-coverage policy must remain FAIL_CLOSED.'
    Assert-Contract ($manifest.normal_open_berlin -eq '09:00' -and $manifest.normal_close_berlin -eq '17:30') 'Normal Xetra session changed.'
    Assert-Contract ($manifest.early_close_semantics -eq 'START_OF_XETRA_CLOSING_AUCTION_CALL') 'Early-close meaning changed.'
    Assert-Contract ($manifest.early_close_berlin -eq '14:00') 'Early-close time changed.'
    Assert-Contract ($manifest.runtime_sha256 -eq $build.calendar_sha256) 'Manifest/runtime hash binding changed.'
    Assert-Contract ($manifest.provenance_sha256 -eq $build.provenance_sha256) 'Manifest/provenance hash binding changed.'
    Assert-Contract ($manifest.sources_sha256 -eq $build.sources_sha256) 'Manifest/source hash binding changed.'

    $sourceIds = @($sources.source_id | Sort-Object -Unique)
    Assert-Contract ($sourceIds.Count -eq 16) 'Source IDs are not unique.'
    Assert-Contract (@($sources | Where-Object { $_.official_pdf_url -notmatch '^https://www\.cashmarket\.deutsche-boerse\.com/' }).Count -eq 0) 'A non-primary source URL entered the registry.'
    Assert-Contract (@($sources | Where-Object { $_.official_pdf_sha256 -notmatch '^[0-9a-f]{64}$' }).Count -eq 0) 'A source PDF hash is malformed.'
    Assert-Contract (@($provenance | Where-Object { $_.source_id -notin $sourceIds }).Count -eq 0) 'A provenance row references an unknown source.'
    $provenanceDateSet = (@($provenance.date_berlin | Sort-Object) -join ',')
    $runtimeDateSet = (@($runtime.date_berlin | Sort-Object) -join ',')
    Assert-Contract ($provenanceDateSet -eq $runtimeDateSet) 'Runtime/provenance date sets differ.'

    Assert-Contract (@($runtime | Where-Object {
        $_.session_type -eq 'FULL_CLOSE' -and ($_.open_time_berlin -ne '' -or $_.close_time_berlin -ne '')
    }).Count -eq 0) 'A FULL_CLOSE row contains times.'
    Assert-Contract (@($runtime | Where-Object {
        $_.session_type -eq 'EARLY_CLOSE' -and ($_.open_time_berlin -ne '09:00' -or $_.close_time_berlin -ne '14:00')
    }).Count -eq 0) 'An EARLY_CLOSE row is not 09:00-14:00 Europe/Berlin.'
    Assert-Contract (@($runtime | Where-Object session_type -eq 'EARLY_CLOSE').Count -eq 8) 'Expected one final-session early close per year.'

    Assert-Contract (@($runtime | Where-Object { $_.date_berlin -eq '2018-05-21' -and $_.session_type -eq 'FULL_CLOSE' }).Count -eq 1) '2018 Whit Monday closure is missing.'
    Assert-Contract (@($runtime | Where-Object { $_.date_berlin -eq '2023-12-29' -and $_.session_type -eq 'EARLY_CLOSE' }).Count -eq 1) '2023 final-session early close is missing.'
    Assert-Contract (@($runtime | Where-Object date_berlin -eq '2022-01-03').Count -eq 0) 'An unsupported 2022 New Year closure was inferred.'
    Assert-Contract (@($runtime | Where-Object date_berlin -eq '2025-10-03').Count -eq 0) 'German Unity Day 2025 was incorrectly inferred as closed.'

    $firstProvision = @(& (Join-Path $PSScriptRoot 'provision_xetra_cash_calendar.ps1') -CommonFilesRoot $provisionRoot -Confirm:$false)
    Assert-Contract ($firstProvision.Count -eq 4) 'Provisioner did not emit four artifact results.'
    Assert-Contract (@($firstProvision | Where-Object status -ne 'PROVISIONED').Count -eq 0) 'First provision was not fully PROVISIONED.'

    $secondProvision = @(& (Join-Path $PSScriptRoot 'provision_xetra_cash_calendar.ps1') -CommonFilesRoot $provisionRoot -Confirm:$false)
    Assert-Contract ($secondProvision.Count -eq 4) 'Idempotent provision did not emit four artifact results.'
    Assert-Contract (@($secondProvision | Where-Object status -ne 'ALREADY_PROVISIONED').Count -eq 0) 'Second provision was not fully ALREADY_PROVISIONED.'

    [IO.File]::AppendAllText((Join-Path $provisionRoot $calendarName), "tamper`n", [Text.UTF8Encoding]::new($false))
    $conflictRefused = $false
    try {
        & (Join-Path $PSScriptRoot 'provision_xetra_cash_calendar.ps1') -CommonFilesRoot $provisionRoot -Confirm:$false | Out-Null
    }
    catch {
        $conflictRefused = $_.Exception.Message -match 'mismatched calendar artifact already exists'
    }
    Assert-Contract $conflictRefused 'Provisioner did not refuse an existing hash conflict.'

    $liveGuarded = $false
    try {
        & (Join-Path $PSScriptRoot 'provision_xetra_cash_calendar.ps1') -CommonFilesRoot (Join-Path $testRoot 'T_Live\Common\Files') -WhatIf | Out-Null
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
        provisioner_conflict_refusal = $true
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
