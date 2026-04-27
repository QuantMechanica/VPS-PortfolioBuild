param(
    [string]$StateRoot = "D:\QM\reports\state",
    [string]$EvidenceRoot = "D:\QM\reports\factory_runs",
    [string]$EaId = "QM5_1001",
    [string]$Version = "v5.0.0",
    [string]$Symbol = "EURUSD",
    [string]$Phase = "P2",
    [string]$SubGateConfig = "dryrun-config-001",
    [ValidateSet("T1", "T2", "T3", "T4", "T5")]
    [string]$Terminal = "T1",
    [ValidateSet("succeeded", "failed", "no_report", "aborted")]
    [string]$FinalStatus = "succeeded",
    [string]$OutJson = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-UtcNowIso {
    return [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
}

function Get-RunKey {
    param([string]$Tuple)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Tuple)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($bytes)
    } finally {
        $sha.Dispose()
    }
    return ([System.BitConverter]::ToString($hash)).Replace("-", "").ToLowerInvariant()
}

function Ensure-ParentDir {
    param([string]$Path)
    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

function Acquire-Lock {
    param(
        [string]$LockPath,
        [int]$MaxAttempts = 40,
        [int]$SleepMs = 100
    )
    for ($i = 0; $i -lt $MaxAttempts; $i++) {
        try {
            $stream = [System.IO.File]::Open($LockPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
            return $stream
        } catch [System.IO.IOException] {
            Start-Sleep -Milliseconds $SleepMs
        }
    }
    throw "Unable to acquire lock: $LockPath"
}

function Read-DedupRows {
    param([string]$CsvPath)
    if (-not (Test-Path -LiteralPath $CsvPath)) {
        return @()
    }
    return @(Import-Csv -LiteralPath $CsvPath)
}

function Write-DedupRows {
    param(
        [string]$CsvPath,
        [array]$Rows
    )
    Ensure-ParentDir -Path $CsvPath
    $Rows | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding UTF8
}

$stateRootFull = [System.IO.Path]::GetFullPath($StateRoot)
$evidenceRootFull = [System.IO.Path]::GetFullPath($EvidenceRoot)
if (-not (Test-Path -LiteralPath $stateRootFull)) {
    New-Item -ItemType Directory -Path $stateRootFull -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $evidenceRootFull)) {
    New-Item -ItemType Directory -Path $evidenceRootFull -Force | Out-Null
}

$dedupCsv = Join-Path $stateRootFull "factory_run_dedup_v1.csv"
$dedupLock = Join-Path $stateRootFull "factory_run_dedup_v1.lock"
$queueJsonl = Join-Path $stateRootFull "factory_run_queue_v1.jsonl"
$dispatchState = Join-Path $stateRootFull "factory_dispatch_state_v1.json"

$tuple = "$EaId|$Version|$Symbol|$Phase|$SubGateConfig"
$runKey = Get-RunKey -Tuple $tuple

$enqueueTs = Get-UtcNowIso
$claimTs = Get-UtcNowIso
$ackTs = Get-UtcNowIso
$scannerPid = $PID

$reportDir = Join-Path $evidenceRootFull "$EaId\$Version\$Phase\$Symbol\$runKey"
if (-not (Test-Path -LiteralPath $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

$dispatchPayload = [ordered]@{
    ea_id = $EaId
    version = $Version
    symbol = $Symbol
    phase = $Phase
    sub_gate_config = $SubGateConfig
    terminal = $Terminal
    run_key = $runKey
    enqueue_ts_utc = $enqueueTs
    claim_ts_utc = $claimTs
}
$dispatchPayload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $reportDir "dispatch.json") -Encoding UTF8

$runnerOut = "dry-run queue transition executed"
$runnerErr = ""
Set-Content -LiteralPath (Join-Path $reportDir "runner_stdout.log") -Value $runnerOut -Encoding UTF8
Set-Content -LiteralPath (Join-Path $reportDir "runner_stderr.log") -Value $runnerErr -Encoding UTF8

$pidPayload = [ordered]@{
    scanner_pid = $scannerPid
    terminal = $Terminal
    terminal_pid = "dryrun"
}
$pidPayload | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $reportDir "pid_snapshot.json") -Encoding UTF8

$dummyReport = Join-Path $reportDir "result_01.htm"
"<html><body>dryrun</body></html>" | Set-Content -LiteralPath $dummyReport -Encoding UTF8
$reportItem = Get-Item -LiteralPath $dummyReport
$reportBytes = [int64]$reportItem.Length
$htmCount = 1

$manifest = [ordered]@{
    run_key = $runKey
    htm_count = $htmCount
    report_bytes = $reportBytes
    files = @(
        [ordered]@{
            file = $reportItem.Name
            bytes = [int64]$reportItem.Length
            mtime_utc = $reportItem.LastWriteTimeUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
    )
}
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $reportDir "report_manifest.json") -Encoding UTF8

$ackPayload = [ordered]@{
    run_key = $runKey
    status = $FinalStatus
    ack_ts_utc = $ackTs
    report_dir = $reportDir
    htm_count = $htmCount
    report_bytes = $reportBytes
}
$ackPayload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $reportDir "ack.json") -Encoding UTF8

$queueEvent = [ordered]@{
    run_key = $runKey
    ea_id = $EaId
    version = $Version
    symbol = $Symbol
    phase = $Phase
    sub_gate_config = $SubGateConfig
    terminal = $Terminal
    transitions = @(
        [ordered]@{ status = "queued"; ts_utc = $enqueueTs },
        [ordered]@{ status = "claimed"; ts_utc = $claimTs },
        [ordered]@{ status = "running"; ts_utc = $claimTs },
        [ordered]@{ status = $FinalStatus; ts_utc = $ackTs }
    )
    report_dir = $reportDir
}
Ensure-ParentDir -Path $queueJsonl
Add-Content -LiteralPath $queueJsonl -Value ($queueEvent | ConvertTo-Json -Depth 8 -Compress) -Encoding UTF8

$dispatchStatePayload = [ordered]@{
    last_run_key = $runKey
    last_terminal = $Terminal
    updated_utc = Get-UtcNowIso
}
$dispatchStatePayload | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $dispatchState -Encoding UTF8

$lockStream = $null
try {
    $lockStream = Acquire-Lock -LockPath $dedupLock
    $rows = Read-DedupRows -CsvPath $dedupCsv
    $duplicate = $rows | Where-Object { $_.run_key -eq $runKey }
    if ($duplicate) {
        throw "Duplicate tuple detected for run_key=$runKey"
    }

    $newRow = [PSCustomObject]@{
        run_key = $runKey
        ea_id = $EaId
        version = $Version
        symbol = $Symbol
        phase = $Phase
        sub_gate_config = $SubGateConfig
        enqueue_ts_utc = $enqueueTs
        claim_ts_utc = $claimTs
        terminal = $Terminal
        scanner_pid = $scannerPid
        status = $FinalStatus
        ack_ts_utc = $ackTs
        report_dir = $reportDir
        htm_count = $htmCount
        report_bytes = $reportBytes
    }
    $rows = @($rows + $newRow)
    Write-DedupRows -CsvPath $dedupCsv -Rows $rows
}
finally {
    if ($null -ne $lockStream) {
        $lockStream.Dispose()
    }
    if (Test-Path -LiteralPath $dedupLock) {
        Remove-Item -LiteralPath $dedupLock -Force
    }
}

$result = [ordered]@{
    status = "ok"
    run_key = $runKey
    ea_id = $EaId
    version = $Version
    symbol = $Symbol
    phase = $Phase
    sub_gate_config = $SubGateConfig
    terminal = $Terminal
    final_status = $FinalStatus
    paths = [ordered]@{
        dedup_csv = $dedupCsv
        queue_jsonl = $queueJsonl
        dispatch_state_json = $dispatchState
        report_dir = $reportDir
    }
}

if (-not [string]::IsNullOrWhiteSpace($OutJson)) {
    $outJsonFull = [System.IO.Path]::GetFullPath($OutJson)
    Ensure-ParentDir -Path $outJsonFull
    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $outJsonFull -Encoding UTF8
}

$result | ConvertTo-Json -Depth 6
