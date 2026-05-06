param(
    [string[]]$Terminals = @("T1", "T2", "T3", "T4", "T5"),
    [string[]]$Symbols = @("US500.DWX", "NAS100.DWX", "NDXm.DWX"),
    [string]$Mt5Root = "D:\QM\mt5",
    [string]$JsonOut
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$results = @()

foreach ($terminal in $Terminals) {
    $historyRoot = Join-Path $Mt5Root "$terminal\Bases\Custom\history"
    $ticksRoot = Join-Path $Mt5Root "$terminal\Bases\Custom\ticks"

    foreach ($symbol in $Symbols) {
        $historyPath = Join-Path $historyRoot $symbol
        $ticksPath = Join-Path $ticksRoot $symbol

        $historyExists = Test-Path -LiteralPath $historyPath -PathType Container
        $ticksExists = Test-Path -LiteralPath $ticksPath -PathType Container

        $historyFileCount = 0
        $ticksFileCount = 0

        if ($historyExists) {
            $historyFileCount = @(
                Get-ChildItem -LiteralPath $historyPath -File -ErrorAction SilentlyContinue
            ).Count
        }

        if ($ticksExists) {
            $ticksFileCount = @(
                Get-ChildItem -LiteralPath $ticksPath -File -ErrorAction SilentlyContinue
            ).Count
        }

        $results += [pscustomobject]@{
            terminal = $terminal
            symbol = $symbol
            history_exists = $historyExists
            ticks_exists = $ticksExists
            history_file_count = $historyFileCount
            ticks_file_count = $ticksFileCount
            status = if ($historyExists -and $ticksExists) { "present" } else { "missing" }
            history_path = $historyPath
            ticks_path = $ticksPath
        }
    }
}

$summary = [pscustomobject]@{
    generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    mt5_root = $Mt5Root
    terminals = $Terminals
    symbols = $Symbols
    total_checks = $results.Count
    missing_checks = @($results | Where-Object { $_.status -eq "missing" }).Count
    present_checks = @($results | Where-Object { $_.status -eq "present" }).Count
    results = $results
}

$json = $summary | ConvertTo-Json -Depth 8

if ($JsonOut) {
    $outDir = Split-Path -Parent $JsonOut
    if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }
    Set-Content -LiteralPath $JsonOut -Value $json -Encoding UTF8
}

$summary
