param(
    [string]$RunScript = 'infra\scripts\Run-QUA774BlockerRefresh.ps1',
    [string]$PayloadScript = 'infra\scripts\New-QUA774IssueTransitionPayload.ps1',
    [string]$ValidateScript = 'infra\scripts\Test-QUA774BlockedPackage.ps1',
    [string]$HandoffIntegrityScript = 'infra\scripts\Test-QUA774HandoffIntegrity.ps1',
    [string]$ExternalSignalScript = 'infra\scripts\Test-QUA774ExternalUnblockSignal.ps1',
    [switch]$RequireExternalSignal
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$runFull = Join-Path $repoRoot $RunScript
$payloadFull = Join-Path $repoRoot $PayloadScript
$validateFull = Join-Path $repoRoot $ValidateScript
$handoffFull = Join-Path $repoRoot $HandoffIntegrityScript
$externalSignalFull = Join-Path $repoRoot $ExternalSignalScript

foreach ($p in @($runFull, $payloadFull, $validateFull, $handoffFull, $externalSignalFull)) {
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) {
        throw "Required script missing: $p"
    }
}

$externalSignal = $null
if ($RequireExternalSignal) {
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $externalSignal = & $externalSignalFull
        if ($LASTEXITCODE -eq 3) {
            [pscustomobject]@{
                issue_id = 'QUA-774'
                generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
                skipped = $true
                skip_reason = 'waiting_external_unblock_signal'
                external_signal = $externalSignal
            }
            exit 0
        }
        if ($LASTEXITCODE -ne 0) {
            throw "External signal check failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        $ErrorActionPreference = $savedPreference
    }
}

$refresh = & $runFull
$payload = & $payloadFull
$verify = & $validateFull
$handoff = & $handoffFull

[pscustomobject]@{
    issue_id = 'QUA-774'
    generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    refresh = $refresh
    payload = $payload
    verify = $verify
    handoff_integrity = $handoff
    external_signal = $externalSignal
}
