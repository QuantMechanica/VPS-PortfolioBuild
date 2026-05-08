param(
    [string]$RunScript = 'infra\scripts\Run-QUA774BlockerRefresh.ps1',
    [string]$PayloadScript = 'infra\scripts\New-QUA774IssueTransitionPayload.ps1',
    [string]$ValidateScript = 'infra\scripts\Test-QUA774BlockedPackage.ps1',
    [string]$HandoffIntegrityScript = 'infra\scripts\Test-QUA774HandoffIntegrity.ps1'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$runFull = Join-Path $repoRoot $RunScript
$payloadFull = Join-Path $repoRoot $PayloadScript
$validateFull = Join-Path $repoRoot $ValidateScript
$handoffFull = Join-Path $repoRoot $HandoffIntegrityScript

foreach ($p in @($runFull, $payloadFull, $validateFull, $handoffFull)) {
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) {
        throw "Required script missing: $p"
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
}
