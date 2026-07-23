[CmdletBinding()]
param(
    [string]$StateRoot = "D:\QM\reports\state",
    [string]$EvidenceRoot = "D:\QM\reports\factory_runs",
    [Parameter(Mandatory = $true)]
    [int]$EAId,
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [Parameter(Mandatory = $true)]
    [string]$Symbol,
    [string]$Phase = "P2",
    [Parameter(Mandatory = $true)]
    [string]$SubGateConfig,
    [ValidateSet("T1", "T2", "T3", "T4", "T5")]
    [string]$Terminal = "T1",
    [ValidateRange(2000, 2100)]
    [int]$Year = 2022,
    [string]$Expert,
    [string]$Period = "M15",
    [ValidateRange(2, 10)]
    [int]$Runs = 2,
    [ValidateRange(0, 1000000)]
    [int]$MinTrades = 1,
    [ValidateRange(60, 7200)]
    [int]$TimeoutSeconds = 1800,
    [string]$SetFile,
    [switch]$AllowRunningTerminal,
    [switch]$AllowMissingRealTicksLogMarker,
    [string]$OutJson = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-UtcNowIso { [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ") }

function Get-RunKey {
    param([string]$Tuple)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Tuple)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $hash = $sha.ComputeHash($bytes) } finally { $sha.Dispose() }
    ([System.BitConverter]::ToString($hash)).Replace("-", "").ToLowerInvariant()
}

function Ensure-Dir {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

function Ensure-ParentDir {
    param([string]$Path)
    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent)) { Ensure-Dir -Path $parent }
}

function Acquire-Lock {
    param([string]$LockPath, [int]$MaxAttempts = 40, [int]$SleepMs = 100)
    for ($i = 0; $i -lt $MaxAttempts; $i++) {
        try {
            return [System.IO.File]::Open($LockPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        } catch [System.IO.IOException] {
            Start-Sleep -Milliseconds $SleepMs
        }
    }
    throw "Unable to acquire lock: $LockPath"
}

function Read-DedupRows {
    param([string]$CsvPath)
    if (-not (Test-Path -LiteralPath $CsvPath)) { return @() }
    @(Import-Csv -LiteralPath $CsvPath)
}

function Write-DedupRows {
    param([string]$CsvPath, [array]$Rows)
    Ensure-ParentDir -Path $CsvPath
    $Rows | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding UTF8
}

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\.." )).Path
$runSmokeScript = Join-Path $repoRoot "framework\scripts\run_smoke.ps1"
if (-not (Test-Path -LiteralPath $runSmokeScript -PathType Leaf)) {
    throw "run_smoke.ps1 not found: $runSmokeScript"
}

$eaLabel = "QM5_{0}" -f $EAId
if (-not $Expert) {
    $Expert = "QM\QM5_{0}" -f $EAId
}
$stateRootFull = [System.IO.Path]::GetFullPath($StateRoot)
$evidenceRootFull = [System.IO.Path]::GetFullPath($EvidenceRoot)
Ensure-Dir -Path $stateRootFull
Ensure-Dir -Path $evidenceRootFull

$dedupCsv = Join-Path $stateRootFull "factory_run_dedup_v1.csv"
$dedupLock = Join-Path $stateRootFull "factory_run_dedup_v1.lock"
$queueJsonl = Join-Path $stateRootFull "factory_run_queue_v1.jsonl"
$dispatchState = Join-Path $stateRootFull "factory_dispatch_state_v1.json"

$tuple = "$eaLabel|$Version|$Symbol|$Phase|$SubGateConfig"
$runKey = Get-RunKey -Tuple $tuple
$enqueueTs = Get-UtcNowIso
$claimTs = Get-UtcNowIso
$scannerPid = $PID
$reportDir = Join-Path $evidenceRootFull "$eaLabel\$Version\$Phase\$Symbol\$runKey"
Ensure-Dir -Path $reportDir

$lockStream = $null
try {
    $lockStream = Acquire-Lock -LockPath $dedupLock
    $rows = Read-DedupRows -CsvPath $dedupCsv
    $duplicate = $rows | Where-Object { $_.run_key -eq $runKey }
    if ($duplicate) { throw "Duplicate tuple detected for run_key=$runKey" }

    $dispatchPayload = [ordered]@{
        ea_id = $eaLabel
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

    Ensure-ParentDir -Path $queueJsonl
    Ensure-ParentDir -Path $dispatchState
}
finally {
    if ($null -ne $lockStream) { $lockStream.Dispose() }
    if (Test-Path -LiteralPath $dedupLock) { Remove-Item -LiteralPath $dedupLock -Force }
}

$stdoutPath = Join-Path $reportDir "runner_stdout.log"
$stderrPath = Join-Path $reportDir "runner_stderr.log"
$summaryPath = $null
$runSmokeExitCode = 0
$runSmokeError = $null
$expertEx5Path = Join-Path (Join-Path "D:\QM\mt5\$Terminal" "MQL5\Experts") (($Expert -replace '/', '\') + ".ex5")
$magicRegistryPath = Join-Path $repoRoot "framework\registry\magic_numbers.csv"
$eaIdActiveInRegistry = $false
if (Test-Path -LiteralPath $magicRegistryPath -PathType Leaf) {
    $magicRows = Import-Csv -LiteralPath $magicRegistryPath
    $eaIdActiveInRegistry = @($magicRows | Where-Object { $_.ea_id -eq [string]$EAId -and $_.status -eq "active" }).Count -gt 0
}

$smokeParams = @{
    EAId = $EAId
    Symbol = $Symbol
    Year = $Year
    Terminal = $Terminal
    Period = $Period
    Runs = $Runs
    MinTrades = $MinTrades
    TimeoutSeconds = $TimeoutSeconds
    ReportRoot = $reportDir
}
if ($Expert) { $smokeParams.Expert = $Expert }
if ($SetFile) { $smokeParams.SetFile = $SetFile }
if ($AllowRunningTerminal.IsPresent) { $smokeParams.AllowRunningTerminal = $true }
if ($AllowMissingRealTicksLogMarker.IsPresent) { $smokeParams.AllowMissingRealTicksLogMarker = $true }

if (-not $eaIdActiveInRegistry) {
    $runSmokeExitCode = 1
    $runSmokeError = "EA id not active in registry: $EAId ($magicRegistryPath)"
    "Preflight failed: $runSmokeError" | Set-Content -LiteralPath $stderrPath -Encoding UTF8
} elseif (-not (Test-Path -LiteralPath $expertEx5Path -PathType Leaf)) {
    $runSmokeExitCode = 1
    $runSmokeError = "Required expert binary missing: $expertEx5Path"
    "Preflight failed: $runSmokeError" | Set-Content -LiteralPath $stderrPath -Encoding UTF8
} else {
    try {
        $output = & $runSmokeScript @smokeParams 2>&1
        $output | Set-Content -LiteralPath $stdoutPath -Encoding UTF8
        $summaryLine = $output | Where-Object { $_ -like "run_smoke.summary=*" } | Select-Object -Last 1
        if ($summaryLine) { $summaryPath = ($summaryLine -split "=", 2)[1] }
        $runSmokeExitCode = 0
    } catch {
        $runSmokeExitCode = 1
        $runSmokeError = $_.Exception.Message
        $_ | Out-String | Set-Content -LiteralPath $stderrPath -Encoding UTF8
    }
}

if (-not (Test-Path -LiteralPath $stderrPath)) {
    "" | Set-Content -LiteralPath $stderrPath -Encoding UTF8
}

$htmFiles = @()
if (Test-Path -LiteralPath $reportDir) {
    $htmFiles = @(Get-ChildItem -LiteralPath $reportDir -Recurse -Filter *.htm -File -ErrorAction SilentlyContinue)
}
$htmCount = $htmFiles.Count
$reportBytesMeasure = $null
if ($htmFiles.Count -gt 0) {
    $reportBytesMeasure = ($htmFiles | Measure-Object -Property Length -Sum)
}
$reportBytes = [int64]0
if ($null -ne $reportBytesMeasure -and $null -ne $reportBytesMeasure.Sum) {
    $reportBytes = [int64]$reportBytesMeasure.Sum
}

$finalStatus = "failed"
if ($runSmokeExitCode -eq 0) {
    if ($htmCount -gt 0) { $finalStatus = "succeeded" } else { $finalStatus = "no_report" }
} elseif ($runSmokeError -and ($runSmokeError -like "Required expert binary missing:*" -or $runSmokeError -like "EA id not active in registry:*")) {
    $finalStatus = "aborted"
} elseif ($htmCount -eq 0) {
    $finalStatus = "no_report"
}

$ackTs = Get-UtcNowIso
$manifest = [ordered]@{
    run_key = $runKey
    htm_count = $htmCount
    report_bytes = $reportBytes
    files = @($htmFiles | ForEach-Object {
        [ordered]@{ file = $_.FullName; bytes = [int64]$_.Length; mtime_utc = $_.LastWriteTimeUtc.ToString("yyyy-MM-ddTHH:mm:ssZ") }
    })
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $reportDir "report_manifest.json") -Encoding UTF8

$ackPayload = [ordered]@{
    run_key = $runKey
    status = $finalStatus
    ack_ts_utc = $ackTs
    report_dir = $reportDir
    htm_count = $htmCount
    report_bytes = $reportBytes
    run_smoke_summary = $summaryPath
    run_smoke_error = $runSmokeError
}
$ackPayload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $reportDir "ack.json") -Encoding UTF8

$queueEvent = [ordered]@{
    run_key = $runKey
    ea_id = $eaLabel
    version = $Version
    symbol = $Symbol
    phase = $Phase
    sub_gate_config = $SubGateConfig
    terminal = $Terminal
    transitions = @(
        [ordered]@{ status = "enqueue"; ts_utc = $enqueueTs },
        [ordered]@{ status = "claim"; ts_utc = $claimTs },
        [ordered]@{ status = "running"; ts_utc = $claimTs },
        [ordered]@{ status = "ack"; ts_utc = $ackTs; final_status = $finalStatus }
    )
    report_dir = $reportDir
}
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
    if ($duplicate) { throw "Duplicate tuple detected during ack write for run_key=$runKey" }

    $newRow = [PSCustomObject]@{
        run_key = $runKey
        ea_id = $eaLabel
        version = $Version
        symbol = $Symbol
        phase = $Phase
        sub_gate_config = $SubGateConfig
        enqueue_ts_utc = $enqueueTs
        claim_ts_utc = $claimTs
        terminal = $Terminal
        scanner_pid = $scannerPid
        status = "ack"
        final_status = $finalStatus
        ack_ts_utc = $ackTs
        report_dir = $reportDir
        htm_count = $htmCount
        report_bytes = $reportBytes
    }
    $rows = @($rows)
    $rows += $newRow
    Write-DedupRows -CsvPath $dedupCsv -Rows $rows
}
finally {
    if ($null -ne $lockStream) { $lockStream.Dispose() }
    if (Test-Path -LiteralPath $dedupLock) { Remove-Item -LiteralPath $dedupLock -Force }
}

$result = [ordered]@{
    status = "ok"
    run_key = $runKey
    ea_id = $eaLabel
    version = $Version
    symbol = $Symbol
    phase = $Phase
    sub_gate_config = $SubGateConfig
    terminal = $Terminal
    final_status = $finalStatus
    htm_count = $htmCount
    report_bytes = $reportBytes
    run_smoke_summary = $summaryPath
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
if ($finalStatus -ne "succeeded") { exit 1 }
exit 0
