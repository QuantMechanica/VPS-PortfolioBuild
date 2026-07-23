param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
    [string]$StatePath = "",
    [string]$OutDir = ""
)

$ErrorActionPreference = 'Stop'

if (-not $OutDir) {
    $OutDir = Join-Path $RepoRoot 'docs\ops'
}
if (-not $StatePath) {
    $StatePath = Join-Path $OutDir 'QUA-344_HEARTBEAT_STATE.json'
}

$ts = Get-Date
$stamp = $ts.ToString('yyyy-MM-ddTHHmmssK').Replace(':','')
$readinessPath = Join-Path $OutDir ("QUA-344_READINESS_CHECK_{0}.json" -f $stamp)

$readinessScript = Join-Path $RepoRoot 'infra\scripts\Test-QUA344Readiness.ps1'
& powershell -NoProfile -ExecutionPolicy Bypass -File $readinessScript -RepoRoot $RepoRoot -OutPath $readinessPath | Out-Null

$curr = Get-Content -LiteralPath $readinessPath -Raw | ConvertFrom-Json
$currSig = "{0}|{1}|{2}|{3}" -f $curr.status, $curr.checks.card_status, $curr.checks.ea_id, $curr.checks.ea_binary_path

$prevSig = ""
if (Test-Path -LiteralPath $StatePath) {
    try {
        $prev = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
        $prevSig = [string]$prev.signature
    } catch {}
}

$changeType = if ($currSig -eq $prevSig) { 'no_change' } else { 'state_changed' }

$heartbeat = [ordered]@{
    issue = 'QUA-344'
    generated_at_local = $ts.ToString('yyyy-MM-ddTHH:mm:ssK')
    change_type = $changeType
    readiness_snapshot = $readinessPath
    signature = $currSig
    status = $curr.status
    unblock_owner = $curr.unblock_owner
    unblock_action = $curr.unblock_action
}

$heartbeatPath = Join-Path $OutDir ("QUA-344_HEARTBEAT_{0}.json" -f $stamp)
($heartbeat | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $heartbeatPath

$state = [ordered]@{
    issue = 'QUA-344'
    updated_at_local = $ts.ToString('yyyy-MM-ddTHH:mm:ssK')
    signature = $currSig
    last_heartbeat = $heartbeatPath
    last_readiness = $readinessPath
}
($state | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath $StatePath

Write-Output $heartbeatPath

