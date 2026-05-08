param(
    [string]$ChildPayloadScript = 'infra\scripts\New-QUA774ExternalUnblockChildPayload.ps1',
    [string]$EscalationScript = 'infra\scripts\Write-QUA774ExternalUnblockEscalation.ps1',
    [string]$SignalCheckScript = 'infra\scripts\Test-QUA774ExternalUnblockSignal.ps1',
    [string]$PackageCheckScript = 'infra\scripts\Test-QUA774ExternalUnblockPackage.ps1'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$childFull = Join-Path $repoRoot $ChildPayloadScript
$escalationFull = Join-Path $repoRoot $EscalationScript
$signalFull = Join-Path $repoRoot $SignalCheckScript
$packageFull = Join-Path $repoRoot $PackageCheckScript

foreach ($p in @($childFull, $escalationFull, $signalFull, $packageFull)) {
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) {
        throw "Required script missing: $p"
    }
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

[pscustomobject]@{
    issue_id = 'QUA-774'
    generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    child_payload = $child
    escalation_note = $escalation
    package_check = $package
    signal_check = $signal
}
