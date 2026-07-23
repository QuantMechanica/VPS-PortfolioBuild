[CmdletBinding()]
param(
    [string]$StateRoot = "C:\QM\worktrees\pipeline-operator\artifacts\qua-376-smoke\state",
    [string]$EvidenceRoot = "C:\QM\worktrees\pipeline-operator\artifacts\qua-376-smoke\factory_runs",
    [int]$EAId = 1001,
    [string]$Version = "v1",
    [string]$Phase = "P3.5",
    [string]$Terminal = "T1",
    [ValidateRange(2000, 2100)]
    [int]$Year = 2024,
    [string]$Expert = "QM/QM5_1001_framework_smoke",
    [string]$Period = "H1",
    [int]$Runs = 2,
    [int]$MinTrades = 1,
    [int]$TimeoutSeconds = 600,
    [string]$PairTag = "src05_s01:pair_proxy=xauusd.dwx-xtiusd.dwx",
    [string]$OutJson = "C:\QM\worktrees\pipeline-operator\artifacts\qua-376\proxy_pair_readiness.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\.." )).Path
$runner = Join-Path $repoRoot "infra\scripts\Invoke-PipelineQueuedSmokeRun.ps1"
if (-not (Test-Path -LiteralPath $runner -PathType Leaf)) {
    throw "Missing runner script: $runner"
}

function Get-TerminalExePath {
    param([Parameter(Mandatory = $true)][string]$TerminalName)
    return "D:\QM\mt5\$TerminalName\terminal64.exe"
}

function Stop-TerminalInstance {
    param([Parameter(Mandatory = $true)][string]$TerminalName)
    $exe = Get-TerminalExePath -TerminalName $TerminalName
    $proc = Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe }
    if ($proc) {
        $proc | Stop-Process -Force
        Start-Sleep -Seconds 2
    }
}

function Start-TerminalInstance {
    param([Parameter(Mandatory = $true)][string]$TerminalName)
    $exe = Get-TerminalExePath -TerminalName $TerminalName
    $existing = Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe }
    if ($existing) {
        return
    }
    if (Test-Path -LiteralPath $exe -PathType Leaf) {
        Start-Process -FilePath $exe | Out-Null
        Start-Sleep -Seconds 3
    }
}

function Normalize-TerminalInstances {
    param([Parameter(Mandatory = $true)][string]$TerminalName)
    $exe = Get-TerminalExePath -TerminalName $TerminalName
    $all = Get-Process terminal64 -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -eq $exe } |
        Sort-Object StartTime
    if (-not $all) {
        Start-TerminalInstance -TerminalName $TerminalName
        return
    }
    if (@($all).Count -le 1) {
        return
    }

    $keep = $all[-1].Id
    $toStop = $all | Where-Object { $_.Id -ne $keep }
    if ($toStop) {
        $toStop | Stop-Process -Force
        Start-Sleep -Seconds 2
    }
}

function Invoke-Leg {
    param(
        [Parameter(Mandatory = $true)] [string]$Symbol,
        [Parameter(Mandatory = $true)] [string]$LegName,
        [Parameter(Mandatory = $true)] [string]$RunNonce
    )

    $subGate = "{0}:{1}:lb20:{2}" -f $PairTag, $LegName, $RunNonce
    $tmpOut = Join-Path $env:TEMP ("qua376_proxy_{0}_{1}.json" -f $LegName, [guid]::NewGuid().ToString("N"))

    $args = @{
        StateRoot = $StateRoot
        EvidenceRoot = $EvidenceRoot
        EAId = $EAId
        Version = $Version
        Symbol = $Symbol
        Phase = $Phase
        SubGateConfig = $subGate
        Terminal = $Terminal
        Year = $Year
        Expert = $Expert
        Period = $Period
        Runs = $Runs
        MinTrades = $MinTrades
        TimeoutSeconds = $TimeoutSeconds
        AllowMissingRealTicksLogMarker = $true
        OutJson = $tmpOut
    }

    $cmdOutput = $null
    $exitCode = 0
    try {
        $cmdOutput = & $runner @args 2>&1
        $exitCode = $LASTEXITCODE
    } catch {
        $cmdOutput = $_ | Out-String
        $exitCode = 1
    }

    $result = $null
    if (Test-Path -LiteralPath $tmpOut) {
        $result = Get-Content -LiteralPath $tmpOut -Raw | ConvertFrom-Json
        Remove-Item -LiteralPath $tmpOut -Force
    }

    return [pscustomobject]@{
        leg = $LegName
        symbol = $Symbol
        sub_gate_config = $subGate
        exit_code = $exitCode
        output_tail = @($cmdOutput | Select-Object -Last 8)
        result = $result
    }
}

try {
    $nonce = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
    Stop-TerminalInstance -TerminalName $Terminal
    $xau = Invoke-Leg -Symbol "XAUUSD.DWX" -LegName "xau" -RunNonce $nonce
    Stop-TerminalInstance -TerminalName $Terminal
    $xti = Invoke-Leg -Symbol "XTIUSD.DWX" -LegName "xti" -RunNonce $nonce
}
finally {
    Start-TerminalInstance -TerminalName $Terminal
    Normalize-TerminalInstances -TerminalName $Terminal
}

$ok = $false
if ($xau.result -and $xti.result) {
    $ok = ([string]$xau.result.final_status -eq "succeeded") -and ([string]$xti.result.final_status -eq "succeeded")
}

$payload = [ordered]@{
    ts_utc = (Get-Date).ToUniversalTime().ToString("o")
    issue = "QUA-376"
    pair = "XAUUSD.DWX/XTIUSD.DWX"
    readiness = $(if ($ok) { "ready" } else { "not_ready" })
    legs = @($xau, $xti)
}

$parent = Split-Path -Parent $OutJson
if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}
$payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutJson -Encoding UTF8
$payload | ConvertTo-Json -Depth 8
