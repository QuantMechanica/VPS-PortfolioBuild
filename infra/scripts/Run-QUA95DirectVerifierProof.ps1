[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$Symbol = 'XTIUSD.DWX',
    [string]$VerifyScript = 'D:\QM\mt5\T1\dwx_import\verify_import.py',
    [ValidateSet('sidecar','source')]
    [string]$TailBasis = 'source',
    [int]$TailToleranceMs = 1000,
    [string]$SmokeLogDir = 'infra\smoke',
    [string]$OutEvidenceJson = 'lessons-learned\evidence\2026-04-27_qua95_xtiusd_direct_verify_rerun.json',
    [string]$OutProofMd = 'docs\ops\QUA-95_DIRECT_VERIFIER_RERUN_2026-04-27.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $VerifyScript)) {
    throw "Verify script not found: $VerifyScript"
}

$smokeFull = Join-Path $RepoRoot $SmokeLogDir
New-Item -ItemType Directory -Path $smokeFull -Force | Out-Null
$stamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$logPath = Join-Path $smokeFull ("verify_import_direct_{0}_qua95.log" -f $stamp)

$rawOut = & python $VerifyScript --symbol $Symbol --tail-basis $TailBasis --tail-tol-ms $TailToleranceMs 2>&1
$verifyCode = $LASTEXITCODE
$outLines = @($rawOut | ForEach-Object { $_.ToString() })
$outLines | Set-Content -LiteralPath $logPath -Encoding UTF8

$line = ($outLines | Where-Object { $_ -match '^\[\s*(OK|FAIL)' } | Select-Object -First 1)
if (-not $line) {
    $line = ($outLines | Select-Object -First 1)
}

function Get-IntMatch([string]$Pattern, [string]$Text) {
    $m = [regex]::Match($Text, $Pattern)
    if ($m.Success) { return [int](($m.Groups[1].Value) -replace ',', '') }
    return $null
}

function Get-DoubleMatch([string]$Pattern, [string]$Text) {
    $m = [regex]::Match($Text, $Pattern)
    if ($m.Success) { return [double]$m.Groups[1].Value }
    return $null
}

$verdict = $null
$mVerdict = [regex]::Match([string]$line, '^\[\s*([^\]]+)\]')
if ($mVerdict.Success) {
    $verdict = $mVerdict.Groups[1].Value.Trim()
}

$tailDeltaMs = Get-DoubleMatch 'tail_delta_ms=([-0-9.]+)' $line
$midTicks = Get-IntMatch 'mid_ticks_5min=([0-9]+)' $line
$barsOneShot = Get-IntMatch 'bars_one_shot=([0-9]+)' $line
$barsChunked = Get-IntMatch 'bars_chunked=([0-9,]+)' $line
$barsExpectedAccessible = Get-IntMatch 'bars_expected_accessible=([0-9,]+)' $line
$barsDrift = Get-IntMatch 'bars_drift=([-0-9]+)' $line

$capturedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
$tailShortfallSeconds = if ($tailDeltaMs -ne $null) { [math]::Round(([math]::Abs($tailDeltaMs) / 1000.0), 3) } else { $null }
$barsPositive = (($barsOneShot -ne $null -and $barsOneShot -gt 0) -or ($barsChunked -ne $null -and $barsChunked -gt 0))
$tailAligned = ($tailDeltaMs -ne $null -and [math]::Abs($tailDeltaMs) -le $TailToleranceMs)
$recommended = if ($barsPositive -and $tailAligned) { 'clear' } else { 'blocked' }
$disposition = if ($recommended -eq 'blocked') { 'defer' } else { 'clear' }

$evidence = [ordered]@{
    issue = 'QUA-95'
    symbol = $Symbol
    captured_at_local = $capturedAt
    command = ("python {0} --symbol {1} --tail-basis {2} --tail-tol-ms {3}" -f $VerifyScript, $Symbol, $TailBasis, $TailToleranceMs)
    verify_exit_code = $verifyCode
    verdict = $verdict
    tail_delta_ms = $tailDeltaMs
    tail_shortfall_seconds = $tailShortfallSeconds
    mid_ticks_5min = $midTicks
    bars_one_shot = $barsOneShot
    bars_chunked = $barsChunked
    bars_expected_accessible = $barsExpectedAccessible
    bars_drift = $barsDrift
    tail_basis = $TailBasis
    tail_tolerance_ms = $TailToleranceMs
    raw_log = $logPath
    recommended_state = $recommended
    disposition = $disposition
}

$evidenceFull = Join-Path $RepoRoot $OutEvidenceJson
New-Item -ItemType Directory -Path (Split-Path -Parent $evidenceFull) -Force | Out-Null
$evidence | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $evidenceFull -Encoding UTF8

$proofLines = @(
    '# QUA-95 Direct Verifier Rerun Proof (2026-04-27)',
    '',
    'Issue: QUA-95  ',
    ("Symbol: {0}" -f $Symbol),
    '',
    '## Command',
    '',
    '```powershell',
    ("python {0} --symbol {1} --tail-basis {2} --tail-tol-ms {3}" -f $VerifyScript, $Symbol, $TailBasis, $TailToleranceMs),
    '```',
    '',
    '## Result',
    '',
    ("- exit code: {0}" -f $verifyCode),
    ("- verdict: {0}" -f $verdict),
    ("- tail delta ms: {0}" -f $tailDeltaMs),
    ("- tail shortfall seconds: {0}" -f $tailShortfallSeconds),
    ("- mid ticks (5m): {0}" -f $midTicks),
    ("- bars one-shot: {0}" -f $barsOneShot),
    ("- bars chunked: {0}" -f $barsChunked),
    ("- bars expected accessible: {0}" -f $barsExpectedAccessible),
    ("- bars drift: {0}" -f $barsDrift),
    ("- raw log: {0}" -f $logPath),
    ("- captured at: {0}" -f $capturedAt),
    '',
    '## Disposition',
    '',
    ("Acceptance remains {0}; state stays {1}/{2}." -f ($(if ($recommended -eq 'blocked') {'unmet'} else {'met'}), $recommended, $disposition))
)

$proofFull = Join-Path $RepoRoot $OutProofMd
New-Item -ItemType Directory -Path (Split-Path -Parent $proofFull) -Force | Out-Null
$proofLines | Set-Content -LiteralPath $proofFull -Encoding UTF8

Write-Output ("verify_exit_code={0}" -f $verifyCode)
Write-Output ("raw_log={0}" -f $logPath)
Write-Output ("wrote={0}" -f $evidenceFull)
Write-Output ("wrote={0}" -f $proofFull)
exit 0
