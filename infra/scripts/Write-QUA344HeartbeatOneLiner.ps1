param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
    [string]$OutPath = ""
)

$ErrorActionPreference = 'Stop'

$statePath = Join-Path $RepoRoot 'docs\ops\QUA-344_HEARTBEAT_STATE.json'
if (-not (Test-Path -LiteralPath $statePath)) {
    throw "State file not found: $statePath"
}

$state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
$hbPath = [string]$state.last_heartbeat
$hb = Get-Content -LiteralPath $hbPath -Raw | ConvertFrom-Json

$line = "{0} QUA-344 {1} sig={2} owner={3}" -f (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"), $hb.change_type, $hb.signature, $hb.unblock_owner

if (-not $OutPath) {
    $OutPath = Join-Path $RepoRoot 'docs\ops\QUA-344_HEARTBEAT_ONELINER.txt'
}

$line | Set-Content -LiteralPath $OutPath
Write-Output $OutPath
