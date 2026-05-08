param(
    [string]$ChildPayloadScript = 'infra\scripts\New-QUA774ExternalUnblockChildPayload.ps1',
    [string]$EscalationScript = 'infra\scripts\Write-QUA774ExternalUnblockEscalation.ps1',
    [string]$SignalCheckScript = 'infra\scripts\Test-QUA774ExternalUnblockSignal.ps1',
    [string]$PackageCheckScript = 'infra\scripts\Test-QUA774ExternalUnblockPackage.ps1',
    [string]$SignalPath = 'docs\ops\QUA-774_EXTERNAL_UNBLOCK_SIGNAL.json',
    [string]$ProbeCachePath = 'artifacts\ops\QUA-774_EXTERNAL_UNBLOCK_LAST_PROBE.json',
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$childFull = Join-Path $repoRoot $ChildPayloadScript
$escalationFull = Join-Path $repoRoot $EscalationScript
$signalFull = Join-Path $repoRoot $SignalCheckScript
$packageFull = Join-Path $repoRoot $PackageCheckScript
$signalJsonFull = Join-Path $repoRoot $SignalPath
$cacheFull = Join-Path $repoRoot $ProbeCachePath

foreach ($p in @($childFull, $escalationFull, $signalFull, $packageFull)) {
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) {
        throw "Required script missing: $p"
    }
}

$signalFingerprint = [pscustomobject]@{
    signal_path = $SignalPath
    signal_exists = $false
    signal_sha256 = $null
    signal_last_write_utc = $null
}

if (Test-Path -LiteralPath $signalJsonFull -PathType Leaf) {
    $signalItem = Get-Item -LiteralPath $signalJsonFull
    $signalHash = (Get-FileHash -LiteralPath $signalJsonFull -Algorithm SHA256).Hash
    $signalFingerprint = [pscustomobject]@{
        signal_path = $SignalPath
        signal_exists = $true
        signal_sha256 = $signalHash
        signal_last_write_utc = $signalItem.LastWriteTimeUtc.ToString('o')
    }
}

$cached = $null
if (Test-Path -LiteralPath $cacheFull -PathType Leaf) {
    try {
        $cached = (Get-Content -LiteralPath $cacheFull -Raw) | ConvertFrom-Json
    }
    catch {
        $cached = $null
    }
}

$fingerprintUnchanged = $false
if ($null -ne $cached -and $null -ne $cached.signal_fingerprint) {
    $prev = $cached.signal_fingerprint
    $fingerprintUnchanged = (
        [string]$prev.signal_path -eq [string]$signalFingerprint.signal_path -and
        [bool]$prev.signal_exists -eq [bool]$signalFingerprint.signal_exists -and
        [string]$prev.signal_sha256 -eq [string]$signalFingerprint.signal_sha256 -and
        [string]$prev.signal_last_write_utc -eq [string]$signalFingerprint.signal_last_write_utc
    )
}

if (
    -not $Force -and
    $fingerprintUnchanged -and
    $null -ne $cached.last_signal_check -and
    [string]$cached.last_signal_check.status -eq 'waiting_external_signal' -and
    [bool]$cached.last_signal_check.ready_to_resume -eq $false
) {
    [pscustomobject]@{
        issue_id = 'QUA-774'
        skipped = $true
        reason = 'signal_unchanged_still_blocked'
        generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
        signal_fingerprint = $signalFingerprint
        probe_cache_path = $ProbeCachePath
        previous_probe_utc = $cached.checked_at_utc
        package_check = $cached.last_package_check
        signal_check = $cached.last_signal_check
    }
    return
}

$child = & $childFull
$escalation = & $escalationFull
$package = & $packageFull

$signal = $null
$savedPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $signal = & $signalFull
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 3) {
        throw "Signal check failed with exit code $LASTEXITCODE"
    }
}
finally {
    $ErrorActionPreference = $savedPreference
}

$result = [pscustomobject]@{
    issue_id = 'QUA-774'
    skipped = $false
    generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    child_payload = $child
    escalation_note = $escalation
    package_check = $package
    signal_check = $signal
    signal_fingerprint = $signalFingerprint
    probe_cache_path = $ProbeCachePath
}

$cacheDir = Split-Path -Parent $cacheFull
if (-not [string]::IsNullOrWhiteSpace($cacheDir) -and -not (Test-Path -LiteralPath $cacheDir -PathType Container)) {
    New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
}

$cachePayload = [pscustomobject]@{
    issue_id = 'QUA-774'
    checked_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    signal_fingerprint = $signalFingerprint
    last_package_check = $package
    last_signal_check = $signal
}
$cachePayload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $cacheFull -Encoding UTF8

$result
