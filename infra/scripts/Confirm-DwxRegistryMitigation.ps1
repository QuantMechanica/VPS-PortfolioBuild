[CmdletBinding()]
param(
    [string]$TerminalLogDir = "D:\QM\mt5\T1\logs",
    [string]$MqlLogDir = "D:\QM\mt5\T1\MQL5\logs",
    [string]$RegistryPath = "D:\QM\mt5\T1\Bases\symbols.custom.dat",
    [string]$BaselineRegistryPath = "D:\QM\mt5\T1\Bases\symbols.custom.dat.bak.before-recovery.20260426",
    [int]$MinSuccessfulRuns = 3,
    [int]$MinSafeBytes = 16384,
    [string]$OutJson = "C:\QM\repo\lessons-learned\evidence\qua69_registry_mitigation_confirmation.json",
    [switch]$FailOnInsufficientEvidence
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-LatestLogFile {
    param(
        [Parameter(Mandatory = $true)][string]$DirectoryPath,
        [Parameter(Mandatory = $true)][string]$Role
    )

    if (-not (Test-Path -LiteralPath $DirectoryPath)) {
        throw "$Role log directory not found: $DirectoryPath"
    }

    $latest = Get-ChildItem -LiteralPath $DirectoryPath -File -Filter "*.log" -ErrorAction Stop |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($null -eq $latest) {
        throw "No .log files found in $Role log directory: $DirectoryPath"
    }

    return $latest
}

function Get-Sha256OrNull {
    param([string]$PathValue)

    if (-not (Test-Path -LiteralPath $PathValue)) {
        return $null
    }

    return (Get-FileHash -LiteralPath $PathValue -Algorithm SHA256 -ErrorAction Stop).Hash
}

$terminalLog = Get-LatestLogFile -DirectoryPath $TerminalLogDir -Role "Terminal"
$mqlLog = Get-LatestLogFile -DirectoryPath $MqlLogDir -Role "MQL5"

$terminalLines = @(Get-Content -LiteralPath $terminalLog.FullName -ErrorAction Stop)
$mqlLines = @(Get-Content -LiteralPath $mqlLog.FullName -ErrorAction Stop)

$loadedPattern = 'script Fix_DWX_Spec_v3 \(EURUSD,M1\) loaded successfully'
$closedPattern = 'script Fix_DWX_Spec_v3 \(EURUSD,M1\) closes terminal with code 0'
$batchPattern = 'BATCH\|processed=5\|sleep_ms=200'
$donePattern = '=== Fix_DWX_Spec_v3: done expected=36 matched=36 patched=(\d+) unchanged=(\d+) failed=(\d+) ==='

$loadedLines = @($terminalLines | Where-Object { $_ -match $loadedPattern })
$closedLines = @($terminalLines | Where-Object { $_ -match $closedPattern })
$batchLines = @($mqlLines | Where-Object { $_ -match $batchPattern })
$doneLines = @($mqlLines | Where-Object { $_ -match $donePattern })

$doneSummaries = New-Object System.Collections.Generic.List[object]
foreach ($line in $doneLines) {
    if ($line -match $donePattern) {
        $doneSummaries.Add([pscustomobject]@{
            patched = [int]$matches[1]
            unchanged = [int]$matches[2]
            failed = [int]$matches[3]
            raw = $line
        }) | Out-Null
    }
}

$doneZeroCount = @($doneSummaries | Where-Object { $_.failed -eq 0 }).Count
$successfulRunSamples = @(
    $closedLines |
        Select-Object -Last ([Math]::Min($closedLines.Count, 5)) |
        ForEach-Object { [string]$_ }
)

$registryExists = Test-Path -LiteralPath $RegistryPath
$registrySizeBytes = $null
$registryLastWrite = $null
$registryHash = $null
if ($registryExists) {
    $registryItem = Get-Item -LiteralPath $RegistryPath -ErrorAction Stop
    $registrySizeBytes = [int64]$registryItem.Length
    $registryLastWrite = $registryItem.LastWriteTime.ToString("o")
    $registryHash = Get-Sha256OrNull -PathValue $RegistryPath
}

$baselineExists = Test-Path -LiteralPath $BaselineRegistryPath
$baselineSizeBytes = $null
$baselineHash = $null
if ($baselineExists) {
    $baselineItem = Get-Item -LiteralPath $BaselineRegistryPath -ErrorAction Stop
    $baselineSizeBytes = [int64]$baselineItem.Length
    $baselineHash = Get-Sha256OrNull -PathValue $BaselineRegistryPath
}

$checks = [ordered]@{
    registry_exists = $registryExists
    registry_size_safe = ($registryExists -and $registrySizeBytes -ge $MinSafeBytes)
    terminal_successful_runs = ($closedLines.Count -ge $MinSuccessfulRuns)
    throttle_markers_present = ($batchLines.Count -gt 0)
}

$verdict = "pass"
if (@($checks.GetEnumerator() | Where-Object { -not $_.Value }).Count -gt 0) {
    $verdict = "fail"
}

$result = [ordered]@{
    generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    issue = "QUA-69"
    mitigation = "Fix_DWX_Spec_v3 batch-of-5 + Sleep(200)"
    verdict = $verdict
    checks = $checks
    evidence = [ordered]@{
        terminal_log = $terminalLog.FullName
        mql_log = $mqlLog.FullName
        successful_run_count = $closedLines.Count
        successful_run_samples = $successfulRunSamples
        load_count = $loadedLines.Count
        batch_marker_count = $batchLines.Count
        done_summary_count = $doneSummaries.Count
        done_failed_zero_count = $doneZeroCount
    }
    registry = [ordered]@{
        path = $RegistryPath
        size_bytes = $registrySizeBytes
        min_safe_bytes = $MinSafeBytes
        sha256 = $registryHash
        last_write_time_local = $registryLastWrite
    }
    baseline_registry = [ordered]@{
        path = $BaselineRegistryPath
        exists = $baselineExists
        size_bytes = $baselineSizeBytes
        sha256 = $baselineHash
    }
}

$outDir = Split-Path -Path $OutJson -Parent
if ($outDir) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutJson -Encoding ASCII
Write-Host "Wrote mitigation confirmation evidence: $OutJson"
Write-Host "Verdict: $verdict"
Write-Host "Successful runs: $($closedLines.Count)"
Write-Host "Registry bytes: $registrySizeBytes"

if ($FailOnInsufficientEvidence.IsPresent -and $verdict -ne "pass") {
    exit 2
}
