[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$IssueId,

    [Parameter(Mandatory = $true)]
    [string]$Symbol,

    [string]$RepoRoot = 'C:\QM\repo',
    [string]$PythonExe = 'python',
    [string]$VerifyImportScript = 'D:\QM\mt5\T1\dwx_import\verify_import.py',
    [ValidateSet('sidecar','source')]
    [string]$TailBasis = 'source',
    [int]$TailToleranceMs = 1000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Convert-IntValue {
    param([string]$Value)
    return [int64]($Value -replace ',', '')
}

if (-not (Test-Path -LiteralPath $RepoRoot)) {
    throw "Repo root not found: $RepoRoot"
}
if (-not (Test-Path -LiteralPath $VerifyImportScript)) {
    throw "verify_import.py not found: $VerifyImportScript"
}

$smokeDir = Join-Path $RepoRoot 'infra\smoke'
$evidenceDir = Join-Path $RepoRoot 'lessons-learned\evidence'
New-Item -ItemType Directory -Path $smokeDir -Force | Out-Null
New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null

$now = Get-Date
$dateTag = $now.ToString('yyyy-MM-dd')
$timeTag = $now.ToString('yyyy-MM-dd_HHmmss')
$issueTag = ($IssueId.ToLowerInvariant() -replace '[^a-z0-9]', '')
$symbolTag = ($Symbol -replace '\.DWX$', '').ToLowerInvariant()

$rawLogPath = Join-Path $smokeDir ("verify_import_run_{0}_{1}.log" -f $timeTag, $issueTag)
$evidencePath = Join-Path $evidenceDir ("{0}_{1}_{2}_rerun_evidence.json" -f $dateTag, $issueTag, $symbolTag)

$procOutput = & $PythonExe $VerifyImportScript --symbol $Symbol --tail-basis $TailBasis --tail-tol-ms $TailToleranceMs 2>&1
$verifyExitCode = $LASTEXITCODE
$logText = ($procOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
Set-Content -LiteralPath $rawLogPath -Value $logText -Encoding UTF8

$failRows = @()
# Supports both legacy verifier rows:
#   ... mid_ticks_5min=0; bars expected=446,753/got=0 ...
# and newer rows:
#   ... mid_ticks_5min=0; bars_sidecar_expected=446,753; ... bars_chunked=0; ...
$rowPattern = [regex]'^\[\s*(?<verdict>[^\]]+)\]\s+(?<symbol>[^:]+):.*?mid_ticks_5min=(?<mid>\d+);(?:(?:.*?bars expected=(?<barsExpLegacy>[0-9,]+)/got=(?<barsGotLegacy>[0-9,]+))|(?:.*?bars_sidecar_expected=(?<barsExpNew>[0-9,]+);.*?bars_chunked=(?<barsGotNew>[0-9,]+)))'
$tailPattern = [regex]'tail_ms expected=(?<tailExp>\d+)/got=(?<tailGot>\d+)'
$tailDeltaPattern = [regex]'tail_delta_ms=(?<tailDelta>-?[0-9.]+)'

$target = $null
foreach ($line in ($logText -split "`r?`n")) {
    $m = $rowPattern.Match($line)
    if (-not $m.Success) {
        continue
    }

    $verdict = $m.Groups['verdict'].Value.Trim()
    if (-not $verdict.ToUpperInvariant().StartsWith('FAIL')) {
        continue
    }

    $sym = $m.Groups['symbol'].Value.Trim()
    $barsExpectedRaw = $null
    $barsGotRaw = $null
    if ($m.Groups['barsExpLegacy'].Success -and $m.Groups['barsGotLegacy'].Success) {
        $barsExpectedRaw = $m.Groups['barsExpLegacy'].Value
        $barsGotRaw = $m.Groups['barsGotLegacy'].Value
    } elseif ($m.Groups['barsExpNew'].Success -and $m.Groups['barsGotNew'].Success) {
        $barsExpectedRaw = $m.Groups['barsExpNew'].Value
        $barsGotRaw = $m.Groups['barsGotNew'].Value
    } else {
        continue
    }

    $entry = [ordered]@{
        symbol = $sym
        verdict = $verdict
        mid_ticks_5min = [int]$m.Groups['mid'].Value
        bars_expected = Convert-IntValue $barsExpectedRaw
        bars_got = Convert-IntValue $barsGotRaw
    }
    $failRows += [pscustomobject]$entry

    if ($sym -ieq $Symbol) {
        $tailMatch = $tailPattern.Match($line)
        $tailExpected = $null
        $tailGot = $null
        $tailShortfall = $null
        if ($tailMatch.Success) {
            $tailExpected = [int64]$tailMatch.Groups['tailExp'].Value
            $tailGot = [int64]$tailMatch.Groups['tailGot'].Value
            $tailShortfall = [Math]::Round(($tailExpected - $tailGot) / 1000.0, 3)
        }
        $tailDelta = $null
        $tailDeltaMatch = $tailDeltaPattern.Match($line)
        if ($tailDeltaMatch.Success) {
            $tailDelta = [double]$tailDeltaMatch.Groups['tailDelta'].Value
        }
        $target = [ordered]@{
            name = $sym
            verdict = $verdict
            mid_ticks_5min = $entry.mid_ticks_5min
            bars_expected = $entry.bars_expected
            bars_got = $entry.bars_got
            tail_ms_expected = $tailExpected
            tail_ms_got = $tailGot
            tail_delta_ms = $tailDelta
            tail_shortfall_seconds = $tailShortfall
        }
    }
}

$allExpectedPositive = $true
$allBarsZero = $true
$allMidZero = $true
foreach ($row in $failRows) {
    if ($row.bars_expected -le 0) { $allExpectedPositive = $false }
    if ($row.bars_got -ne 0) { $allBarsZero = $false }
    if ($row.mid_ticks_5min -ne 0) { $allMidZero = $false }
}

$systemicZeroBars = ($failRows.Count -ge 10 -and $allExpectedPositive -and $allBarsZero)
$systemicZeroMidTicks = ($failRows.Count -ge 10 -and $allMidZero)

$disposition = 'fix'
if ($null -ne $target) {
    $tailAligned = (
        ($null -ne $target.tail_delta_ms -and [math]::Abs([double]$target.tail_delta_ms) -le $TailToleranceMs) -or
        ($null -ne $target.tail_ms_expected -and $null -ne $target.tail_ms_got -and $target.tail_ms_expected -eq $target.tail_ms_got)
    )
    if ($target.bars_got -gt 0 -and $tailAligned) {
        $disposition = 'clear'
    } elseif ($target.bars_got -eq 0 -or $systemicZeroBars) {
        $disposition = 'defer'
    }
}

$evidence = [ordered]@{
    issue = $IssueId
    generated_at_local = $now.ToString('yyyy-MM-ddTHH:mm:ssK')
    command = "$PythonExe $VerifyImportScript --symbol $Symbol --tail-basis $TailBasis --tail-tol-ms $TailToleranceMs"
    raw_log_path_local = $rawLogPath
    verify_exit_code = $verifyExitCode
    classifier = [ordered]@{
        fail_count = $failRows.Count
        systemic_zero_bars = $systemicZeroBars
        systemic_zero_mid_ticks = $systemicZeroMidTicks
    }
    symbol = $target
    disposition = $disposition
}

$evidence | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $evidencePath -Encoding UTF8

Write-Host ("verify_exit_code={0}" -f $verifyExitCode)
Write-Host ("raw_log={0}" -f $rawLogPath)
Write-Host ("evidence_json={0}" -f $evidencePath)
Write-Host ("disposition={0}" -f $disposition)
