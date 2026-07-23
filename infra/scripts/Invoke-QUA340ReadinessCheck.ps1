[CmdletBinding()]
param(
    [string]$StrategyCardPath = "C:\QM\worktrees\research\strategy-seeds\cards\lien-dbb-pick-tops_card.md",
    [string]$MagicRegistryPath = "C:\QM\worktrees\pipeline-operator\framework\registry\magic_numbers.csv",
    [string[]]$Terminals = @("T1","T2","T3","T4","T5")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Parse-EaIdFromCard {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]@{ found = $false; ea_id = $null; raw = $null; reason = "card_missing" }
    }

    $line = Get-Content -LiteralPath $Path | Where-Object { $_ -match '^ea_id\s*:' } | Select-Object -First 1
    if (-not $line) {
        return [pscustomobject]@{ found = $false; ea_id = $null; raw = $null; reason = "ea_id_line_missing" }
    }

    $raw = ($line -split ':',2)[1].Trim()
    if ($raw -match '^(TBD|tbd)$') {
        return [pscustomobject]@{ found = $true; ea_id = $null; raw = $raw; reason = "ea_id_tbd" }
    }
    if ($raw -match '^\d+$') {
        return [pscustomobject]@{ found = $true; ea_id = [int]$raw; raw = $raw; reason = "ok" }
    }

    return [pscustomobject]@{ found = $true; ea_id = $null; raw = $raw; reason = "ea_id_non_numeric" }
}

$card = Parse-EaIdFromCard -Path $StrategyCardPath
$registryLoaded = Test-Path -LiteralPath $MagicRegistryPath -PathType Leaf
$registryRows = @()
if ($registryLoaded) {
    $registryRows = Import-Csv -LiteralPath $MagicRegistryPath
}

$registryHit = $null
$ex5Checks = @()
$allEx5Present = $false

if ($card.ea_id -ne $null) {
    $registryHit = $registryRows | Where-Object { $_.ea_id -eq [string]$card.ea_id -and $_.status -eq 'active' } | Select-Object -First 1

    $eaFile = "QM5_{0}.ex5" -f $card.ea_id
    foreach ($t in $Terminals) {
        $path = "D:\QM\mt5\$t\MQL5\Experts\QM\$eaFile"
        $exists = Test-Path -LiteralPath $path -PathType Leaf
        $size = 0
        $mtime = $null
        if ($exists) {
            $item = Get-Item -LiteralPath $path
            $size = [int64]$item.Length
            $mtime = $item.LastWriteTimeUtc.ToString("o")
        }
        $ex5Checks += [pscustomobject]@{
            terminal = $t
            exists = $exists
            size_bytes = $size
            mtime_utc = $mtime
            path = $path
        }
    }
    $allEx5Present = @($ex5Checks | Where-Object { -not $_.exists }).Count -eq 0
}

$ready = ($card.ea_id -ne $null) -and ($null -ne $registryHit) -and $allEx5Present

$result = [ordered]@{
    ts_utc = [DateTime]::UtcNow.ToString("o")
    issue = "QUA-340"
    strategy_card = $StrategyCardPath
    card_parse = $card
    magic_registry = [ordered]@{
        path = $MagicRegistryPath
        exists = $registryLoaded
        active_match = $(if ($registryHit) { [ordered]@{ ea_id = $registryHit.ea_id; ea_slug = $registryHit.ea_slug; symbol = $registryHit.symbol; status = $registryHit.status } } else { $null })
    }
    ex5_parity = $ex5Checks
    readiness = [ordered]@{
        ready_for_queued_smoke = $ready
        unblock_owner = $(if ($ready) { "Pipeline-Operator" } else { "CEO+CTO / Development" })
        unblock_action = $(if ($ready) { "Run Invoke-PipelineQueuedSmokeRun.ps1 with new sub_gate_config digest." } else { "Allocate ea_id in card+registry and deploy QM5_<ea_id>.ex5 to T1-T5." })
    }
}

$result | ConvertTo-Json -Depth 8
if (-not $ready) { exit 1 }
exit 0
