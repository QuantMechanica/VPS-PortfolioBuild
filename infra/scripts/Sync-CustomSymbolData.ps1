param(
    [Parameter(Mandatory = $true)]
    [string]$SourceTerminal,
    [Parameter(Mandatory = $true)]
    [string[]]$TargetTerminals,
    [Parameter(Mandatory = $true)]
    [string[]]$Symbols,
    [string]$Mt5Root = "D:\QM\mt5"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Sync-SymbolFolder {
    param(
        [Parameter(Mandatory = $true)] [string]$SourcePath,
        [Parameter(Mandatory = $true)] [string]$TargetPath
    )

    if (-not (Test-Path -LiteralPath $SourcePath -PathType Container)) {
        throw "Source path missing: $SourcePath"
    }

    $parent = Split-Path -Parent $TargetPath
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $staging = "$TargetPath.__staging__"
    if (Test-Path -LiteralPath $staging) {
        Remove-Item -LiteralPath $staging -Recurse -Force
    }

    New-Item -ItemType Directory -Path $staging -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $SourcePath "*") -Destination $staging -Recurse -Force

    if (Test-Path -LiteralPath $TargetPath) {
        Remove-Item -LiteralPath $TargetPath -Recurse -Force
    }

    Move-Item -LiteralPath $staging -Destination $TargetPath -Force
}

$ops = @()

foreach ($symbol in $Symbols) {
    $srcHistory = Join-Path $Mt5Root "$SourceTerminal\Bases\Custom\history\$symbol"
    $srcTicks = Join-Path $Mt5Root "$SourceTerminal\Bases\Custom\ticks\$symbol"

    foreach ($target in $TargetTerminals) {
        $dstHistory = Join-Path $Mt5Root "$target\Bases\Custom\history\$symbol"
        $dstTicks = Join-Path $Mt5Root "$target\Bases\Custom\ticks\$symbol"

        Sync-SymbolFolder -SourcePath $srcHistory -TargetPath $dstHistory
        Sync-SymbolFolder -SourcePath $srcTicks -TargetPath $dstTicks

        $ops += [pscustomobject]@{
            symbol = $symbol
            source_terminal = $SourceTerminal
            target_terminal = $target
            history_target = $dstHistory
            ticks_target = $dstTicks
            status = "synced"
            synced_at_utc = (Get-Date).ToUniversalTime().ToString("o")
        }
    }
}

$ops
