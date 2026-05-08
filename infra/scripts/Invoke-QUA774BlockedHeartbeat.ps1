param(
    [string]$RunScript = 'infra\scripts\Run-QUA774BlockerRefresh.ps1',
    [string]$PayloadScript = 'infra\scripts\New-QUA774IssueTransitionPayload.ps1',
    [string]$ValidateScript = 'infra\scripts\Test-QUA774BlockedPackage.ps1'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$runFull = Join-Path $repoRoot $RunScript
$payloadFull = Join-Path $repoRoot $PayloadScript
$validateFull = Join-Path $repoRoot $ValidateScript

foreach ($p in @($runFull, $payloadFull, $validateFull)) {
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) {
        throw "Required script missing: $p"
    }
}

$refresh = & $runFull
$payload = & $payloadFull
$verify = & $validateFull

[pscustomobject]@{
    issue_id = 'QUA-774'
    generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    refresh = $refresh
    payload = $payload
    verify = $verify
}
