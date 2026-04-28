[CmdletBinding()]
param(
    [string]$DeployScriptPath = 'C:\QM\repo\framework\scripts\deploy_ea_to_all_terminals.ps1',
    [string[]]$EaPaths = @(
        'D:\QM\mt5\T1\MQL5\Experts\QM\EA_Skeleton.ex5',
        'D:\QM\mt5\T1\MQL5\Experts\QM\QM5_1001_framework_smoke.ex5',
        'D:\QM\mt5\T1\MQL5\Experts\QM\QM5_1002_davey-eu-night.ex5',
        'D:\QM\mt5\T1\MQL5\Experts\QM\QM5_SRC04_S03_lien_fade_double_zeros.ex5'
    ),
    [string]$EvidenceJsonPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$deployScriptFull = [IO.Path]::GetFullPath($DeployScriptPath)
if (-not (Test-Path -LiteralPath $deployScriptFull -PathType Leaf)) {
    throw "Deploy script not found: $deployScriptFull"
}

$paths = @($EaPaths | Where-Object { $_ -and $_.Trim().Length -gt 0 } | ForEach-Object { [IO.Path]::GetFullPath($_.Trim()) } | Select-Object -Unique)
if ($paths.Count -eq 0) {
    throw 'EaPaths is empty.'
}

$all = @()
foreach ($ea in $paths) {
    if (-not (Test-Path -LiteralPath $ea -PathType Leaf)) {
        throw "EA file not found: $ea"
    }
    $tmp = Join-Path $env:TEMP ("qm_qua411_" + [guid]::NewGuid().ToString('N') + '.json')
    try {
        $lines = & powershell -NoProfile -ExecutionPolicy Bypass -File $deployScriptFull -EaPath $ea -EvidenceJsonPath $tmp 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Deploy failed for $ea`n$($lines -join [Environment]::NewLine)"
        }
        foreach ($line in $lines) {
            Write-Output $line
        }
        $payload = Get-Content -LiteralPath $tmp -Raw -Encoding UTF8 | ConvertFrom-Json
        $all += [pscustomobject]@{
            ea_path = $ea
            evidence = $payload
        }
    }
    finally {
        if (Test-Path -LiteralPath $tmp -PathType Leaf) {
            Remove-Item -LiteralPath $tmp -Force
        }
    }
}

if ($EvidenceJsonPath) {
    $full = [IO.Path]::GetFullPath($EvidenceJsonPath)
    $dir = Split-Path -Path $full -Parent
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $out = [ordered]@{
        ran_at_local = (Get-Date).ToString('o')
        deploy_script_path = $deployScriptFull
        ea_count = $all.Count
        runs = $all
    }
    $out | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $full -Encoding UTF8
}

exit 0
