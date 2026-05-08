param(
    [string]$HandoffScript = 'infra\scripts\Invoke-QUA774ExternalUnblockHandoff.ps1',
    [string]$ProbeCachePath = 'artifacts\ops\QUA-774_EXTERNAL_UNBLOCK_LAST_PROBE.test.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$handoffFull = Join-Path $repoRoot $HandoffScript
$cacheFull = Join-Path $repoRoot $ProbeCachePath

if (-not (Test-Path -LiteralPath $handoffFull -PathType Leaf)) {
    throw "Handoff script missing: $handoffFull"
}

$cacheDir = Split-Path -Parent $cacheFull
if (-not [string]::IsNullOrWhiteSpace($cacheDir) -and -not (Test-Path -LiteralPath $cacheDir -PathType Container)) {
    New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
}

if (Test-Path -LiteralPath $cacheFull -PathType Leaf) {
    Remove-Item -LiteralPath $cacheFull -Force
}

$first = & $handoffFull -ProbeCachePath $ProbeCachePath
$second = & $handoffFull -ProbeCachePath $ProbeCachePath
$forced = & $handoffFull -ProbeCachePath $ProbeCachePath -Force

$errors = @()

if ([bool]$first.skipped) {
    $errors += 'first_run_unexpected_skip'
}
if (-not [bool]$second.skipped) {
    $errors += 'second_run_expected_skip_missing'
}
if ([string]$second.reason -ne 'signal_unchanged_still_blocked') {
    $errors += 'second_run_reason_mismatch'
}
if ([bool]$forced.skipped) {
    $errors += 'force_run_unexpected_skip'
}

$status = if ($errors.Count -eq 0) { 'ok' } else { 'fail' }

$result = [pscustomobject]@{
    issue_id = 'QUA-774'
    status = $status
    probe_cache_path = $ProbeCachePath
    first_skipped = [bool]$first.skipped
    second_skipped = [bool]$second.skipped
    second_reason = $second.reason
    force_skipped = [bool]$forced.skipped
    errors = $errors
}

$result

if ($status -ne 'ok') {
    exit 2
}
