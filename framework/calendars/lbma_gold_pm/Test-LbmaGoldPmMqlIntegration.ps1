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

function Get-PinnedMacro {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Name
    )

    $match = [regex]::Match(
        $Source,
        '(?m)^#define\s+' + [regex]::Escape($Name) + '\s+"([0-9A-F]{64})"\s*$'
    )
    Assert-Contract $match.Success "Missing or malformed hash macro: $Name"
    return $match.Groups[1].Value.ToLowerInvariant()
}

function Assert-MqlDelimitersBalanced {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Label
    )

    $stack = [Collections.Generic.Stack[char]]::new()
    $state = 'code'
    $escaped = $false
    for ($i = 0; $i -lt $Source.Length; $i++) {
        $c = $Source[$i]
        $next = if ($i + 1 -lt $Source.Length) { $Source[$i + 1] } else { [char]0 }

        if ($state -eq 'line-comment') {
            if ($c -eq "`n") { $state = 'code' }
            continue
        }
        if ($state -eq 'block-comment') {
            if ($c -eq '*' -and $next -eq '/') {
                $state = 'code'
                $i++
            }
            continue
        }
        if ($state -eq 'double-quote' -or $state -eq 'single-quote') {
            if ($escaped) {
                $escaped = $false
                continue
            }
            if ($c -eq '\') {
                $escaped = $true
                continue
            }
            if (($state -eq 'double-quote' -and $c -eq '"') -or
                ($state -eq 'single-quote' -and $c -eq "'")) {
                $state = 'code'
            }
            continue
        }

        if ($c -eq '/' -and $next -eq '/') {
            $state = 'line-comment'
            $i++
            continue
        }
        if ($c -eq '/' -and $next -eq '*') {
            $state = 'block-comment'
            $i++
            continue
        }
        if ($c -eq '"') {
            $state = 'double-quote'
            continue
        }
        if ($c -eq "'") {
            $state = 'single-quote'
            continue
        }
        if ($c -in @('(', '[', '{')) {
            $stack.Push($c)
            continue
        }
        if ($c -in @(')', ']', '}')) {
            Assert-Contract ($stack.Count -gt 0) "$Label has an unmatched closing '$c' at offset $i."
            $opening = $stack.Pop()
            $expected = switch ($c) { ')' { '(' } ']' { '[' } '}' { '{' } }
            Assert-Contract ($opening -eq $expected) "$Label has mismatched '$opening' and '$c' at offset $i."
        }
    }

    Assert-Contract ($state -notin @('block-comment', 'double-quote', 'single-quote')) "$Label ends inside $state."
    Assert-Contract ($stack.Count -eq 0) "$Label has an unmatched opening delimiter."
}

$loaderPath = Join-Path $PSScriptRoot '..\..\include\QM\QM_LbmaGoldPmCalendar.mqh'
$eaPath = Join-Path $PSScriptRoot '..\..\EAs\QM5_20037_lbma-pm-brk\QM5_20037_lbma-pm-brk.mq5'
$specPath = Join-Path $PSScriptRoot '..\..\EAs\QM5_20037_lbma-pm-brk\SPEC.md'
$loaderPath = [IO.Path]::GetFullPath($loaderPath)
$eaPath = [IO.Path]::GetFullPath($eaPath)
$specPath = [IO.Path]::GetFullPath($specPath)

foreach ($path in @($loaderPath, $eaPath, $specPath)) {
    Assert-Contract (Test-Path -LiteralPath $path -PathType Leaf) "Missing integration file: $path"
}

$loader = Get-Content -Raw -LiteralPath $loaderPath
$ea = Get-Content -Raw -LiteralPath $eaPath
$spec = Get-Content -Raw -LiteralPath $specPath
Assert-MqlDelimitersBalanced -Source $loader -Label 'LBMA calendar loader'
Assert-MqlDelimitersBalanced -Source $ea -Label 'QM5_20037 EA'
$dataDirectory = Join-Path $PSScriptRoot 'data'
$bindings = @(
    [pscustomobject]@{ Macro = 'QM_LBMA_GOLD_PM_RUNTIME_SHA256'; File = 'QM5_LBMA_Gold_PM_schedule_20200101_20251231.csv' },
    [pscustomobject]@{ Macro = 'QM_LBMA_GOLD_PM_PROVENANCE_SHA256'; File = 'QM5_LBMA_Gold_PM_schedule_provenance.csv' },
    [pscustomobject]@{ Macro = 'QM_LBMA_GOLD_PM_SOURCES_SHA256'; File = 'QM5_LBMA_Gold_PM_schedule_sources.csv' },
    [pscustomobject]@{ Macro = 'QM_LBMA_GOLD_PM_TRANSITIONS_SHA256'; File = 'QM5_Europe_London_transitions_20180101_20251231.csv' },
    [pscustomobject]@{ Macro = 'QM_LBMA_GOLD_PM_GAPS_SHA256'; File = 'QM5_LBMA_Gold_PM_schedule_gaps.csv' },
    [pscustomobject]@{ Macro = 'QM_LBMA_GOLD_PM_MANIFEST_SHA256'; File = 'QM5_LBMA_Gold_PM_schedule_manifest.json' }
)

foreach ($binding in $bindings) {
    $artifactPath = Join-Path $dataDirectory $binding.File
    Assert-Contract (Test-Path -LiteralPath $artifactPath -PathType Leaf) "Missing bound artifact: $artifactPath"
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $artifactPath).Hash.ToLowerInvariant()
    $pinned = Get-PinnedMacro -Source $loader -Name $binding.Macro
    Assert-Contract ($actual -eq $pinned) "Loader hash binding differs for $($binding.File)."
}

$transitionArtifactPath = Join-Path $dataDirectory 'QM5_Europe_London_transitions_20180101_20251231.csv'
$epochMatch = [regex]::Match(
    $loader,
    '(?s)static\s+const\s+long\s+transition_epoch\s*\[[^\]]+\]\s*=\s*\{(?<values>.*?)\};'
)
$offsetMatch = [regex]::Match(
    $loader,
    '(?s)static\s+const\s+int\s+offset_after\s*\[[^\]]+\]\s*=\s*\{(?<values>.*?)\};'
)
Assert-Contract $epochMatch.Success 'Embedded transition epoch table is missing.'
Assert-Contract $offsetMatch.Success 'Embedded transition offset table is missing.'
$embeddedEpochs = @([regex]::Matches($epochMatch.Groups['values'].Value, '\d+') | ForEach-Object { [long]$_.Value })
$embeddedOffsets = @([regex]::Matches($offsetMatch.Groups['values'].Value, '\d+') | ForEach-Object { [int]$_.Value })
$transitionRows = @(Import-Csv -LiteralPath $transitionArtifactPath)
Assert-Contract ($transitionRows.Count -eq 16) 'Transition artifact no longer contains sixteen rows.'
Assert-Contract ($embeddedEpochs.Count -eq $transitionRows.Count) 'Embedded transition epoch count differs from artifact.'
Assert-Contract ($embeddedOffsets.Count -eq $transitionRows.Count) 'Embedded transition offset count differs from artifact.'
$dateStyles = [Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal
for ($i = 0; $i -lt $transitionRows.Count; $i++) {
    $artifactEpoch = [DateTimeOffset]::Parse(
        $transitionRows[$i].transition_utc,
        [Globalization.CultureInfo]::InvariantCulture,
        $dateStyles
    ).ToUnixTimeSeconds()
    Assert-Contract ($embeddedEpochs[$i] -eq $artifactEpoch) "Embedded transition epoch differs at row $($i + 1)."
    Assert-Contract ($embeddedOffsets[$i] -eq [int]$transitionRows[$i].offset_after_minutes) "Embedded transition offset differs at row $($i + 1)."
}
Assert-Contract ($loader.Contains('#define QM_LBMA_GOLD_PM_EMBEDDED_CLOCK_SOURCE_SHA256 QM_LBMA_GOLD_PM_TRANSITIONS_SHA256')) 'Embedded clock is not bound to the pinned transition artifact hash.'
$calendarFailStart = $loader.IndexOf('bool QM_LbmaGoldPmCalendarFail')
$verifyArtifactStart = $loader.IndexOf('bool QM_LbmaGoldPmVerifyArtifact')
Assert-Contract ($calendarFailStart -ge 0 -and $verifyArtifactStart -gt $calendarFailStart) 'Could not isolate calendar failure handler.'
$calendarFailBody = $loader.Substring($calendarFailStart, $verifyArtifactStart - $calendarFailStart)
Assert-Contract (-not $calendarFailBody.Contains('ArrayResize(g_qm_lbma_gold_pm_transition_utc')) 'Calendar failure erases the open-position exit-clock fallback.'
Assert-Contract ($loader -match '(?s)bool\s+QM_LbmaGoldPmCalendarLoad\(\).*?QM_LbmaGoldPmLoadEmbeddedClock\(\).*?QM_LbmaGoldPmVerifyArtifact\(') 'Embedded exit clock is not initialized before package verification can fail.'
Assert-Contract ($loader.Contains('transition_utc != g_qm_lbma_gold_pm_transition_utc[rows]')) 'Transition artifact is not reconciled against the embedded table.'

$requiredLoaderTokens = @(
    'QM_LbmaGoldPmCalendarLoad',
    'QM_LbmaGoldPmLoadRuntimeAndProvenance',
    'QM_LbmaGoldPmLoadTransitions',
    'QM_LbmaGoldPmLoadEmbeddedClock',
    'QM_LbmaGoldPmEmbeddedClockReady',
    'QM_LbmaGoldPmCalendarClassify',
    'QM_LbmaGoldPmAuctionStartUTC',
    'QM_LbmaGoldPmLondonLocalToUTC',
    'QM_LBMA_GOLD_PM_COVERAGE_START = 20200101',
    'QM_LBMA_GOLD_PM_COVERAGE_END = 20251231',
    'QM_LBMA_GOLD_PM_EXPECTED_ROWS = 2192',
    'QM_LBMA_GOLD_PM_EXPECTED_SCHEDULED_ROWS = 1503',
    'PROMOTION_EVIDENCE_GAP_NO_HISTORICAL_LEDGER'
)
foreach ($token in $requiredLoaderTokens) {
    Assert-Contract ($loader.Contains($token)) "Loader contract token is missing: $token"
}

$requiredEaTokens = @(
    '#include <QM/QM_LbmaGoldPmCalendar.mqh>',
    'g_lbma_calendar_ready = QM_LbmaGoldPmCalendarLoad();',
    'QM_LbmaGoldPmCalendarClassify(date_key)',
    'QM_LbmaGoldPmAuctionStartUTC(date_key, scheduled_auction_utc)',
    'SCHEDULE_DATE_OUT_OF_VERIFIED_COVERAGE',
    'OFFICIAL_PM_NO_AUCTION_HOLIDAY',
    'PINNED_AUCTION_CLOCK_MISMATCH',
    'OFFICIAL_CANCELLATION_OR_NO_PUBLICATION',
    'PROVENANCE_LOCKED_SCHEDULED_PM_AUCTION',
    'CALENDAR_EVIDENCE_GAP',
    'SCHEDULED_PM_AUCTION_ROWS_ADMITTED',
    'EXIT_CLOCK_FALLBACK',
    'OPEN_POSITION_ONLY',
    'embedded_exit_clock_ready'
)
foreach ($token in $requiredEaTokens) {
    Assert-Contract ($ea.Contains($token)) "EA integration token is missing: $token"
}

Assert-Contract (-not $ea.Contains('Strategy_IsUtcWeekday')) 'EA still contains the weekday eligibility shortcut.'
Assert-Contract (-not $ea.Contains('Strategy_LastSundayUtc')) 'EA still contains the unpinned London DST shortcut.'
Assert-Contract (-not $ea.Contains('Strategy_IsUKDSTUtc')) 'EA still contains the unpinned London DST predicate.'
Assert-Contract (-not $ea.Contains('actual_status == QM_LBMA_GOLD_PM_ACTUAL_UNKNOWN')) 'Unknown historical occurrence status became an unintended blanket block.'
Assert-Contract ($ea.Contains('actual_status == QM_LBMA_GOLD_PM_ACTUAL_CANCELLED_OR_NO_PUBLICATION')) 'Known cancellation/No-Publication fail-closed gate is missing.'
Assert-Contract ($ea -match '(?s)if\(!g_lbma_calendar_ready\).*?return true;') 'Package failure no longer blocks new entries.'
Assert-Contract ($spec.Contains('exit-only restart fallback')) 'SPEC does not document the embedded exit-clock boundary.'
Assert-Contract (-not $spec.Contains('Exact valid bars replace the external auction ledger')) 'SPEC still claims that bars replace the official calendar.'
Assert-Contract (-not $spec.Contains('On each UTC weekday')) 'SPEC still describes weekday-based eligibility.'
Assert-Contract ($spec.Contains('Only a provenance-matched `SCHEDULED_PM_AUCTION` row')) 'SPEC does not state the restored calendar contract.'
Assert-Contract ($spec -match '(?s)neither\s+full-window Q02-ready nor a validated successful strategy') 'SPEC overstates current qualification.'

$touchedProduct = $loader + "`n" + $ea + "`n" + $spec + "`n" +
    (Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'README.md'))
Assert-Contract ($touchedProduct -notmatch '(?i)metadata[_ -]?complete\s*=\s*false') 'A static metadata-complete=false gate was introduced.'

[pscustomobject]@{
    status = 'PASS_STATIC_NO_BUILD'
    hash_bound_artifacts = $bindings.Count
    loader = $loaderPath
    ea = $eaPath
    spec = $specPath
    verified_schedule_start = 20200101
    verified_schedule_end = 20251231
    outside_coverage_fail_closed = $true
    known_cancellation_fail_closed = $true
    missing_occurrence_ledger_promotion_gap = $true
    embedded_exit_clock_rows = $embeddedEpochs.Count
    embedded_exit_clock_matches_artifact = $true
    mql_delimiters_balanced = $true
}
