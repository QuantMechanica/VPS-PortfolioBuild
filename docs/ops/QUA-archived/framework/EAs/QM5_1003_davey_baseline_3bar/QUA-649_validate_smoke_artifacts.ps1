[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RunDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $RunDir -PathType Container)) {
    throw "RunDir does not exist: $RunDir"
}

$rawDir = Join-Path $RunDir "raw"
if (-not (Test-Path -LiteralPath $rawDir -PathType Container)) {
    throw "Missing raw directory: $rawDir"
}

$runDirs = @(Get-ChildItem -LiteralPath $rawDir -Directory | Sort-Object Name)
if ($runDirs.Count -eq 0) {
    throw "No run_* directories found under: $rawDir"
}

$results = @()
foreach ($r in $runDirs) {
    $reportPath = Join-Path $r.FullName "report.htm"
    $reportExists = Test-Path -LiteralPath $reportPath -PathType Leaf
    $reportSize = if ($reportExists) { (Get-Item -LiteralPath $reportPath).Length } else { 0 }

    $testerLogs = @(Get-ChildItem -LiteralPath $r.FullName -File -Filter "*.log" -ErrorAction SilentlyContinue)
    $logExists = ($testerLogs.Count -gt 0)
    $logPath = if ($logExists) { $testerLogs[0].FullName } else { "" }

    $status = if ($reportExists -and $reportSize -gt 0 -and $logExists) { "OK" } else { "FAIL" }

    $results += [pscustomobject]@{
        run = $r.Name
        report_exists = $reportExists
        report_size_bytes = $reportSize
        tester_log_exists = $logExists
        tester_log_path = $logPath
        status = $status
    }
}

$failCount = @($results | Where-Object { $_.status -eq "FAIL" }).Count
$overall = if ($failCount -eq 0) { "PASS" } else { "FAIL" }

$payload = [pscustomobject]@{
    run_dir = $RunDir
    checked_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    overall = $overall
    runs = $results
}

$jsonPath = Join-Path $RunDir "artifact_validation.json"
$payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $jsonPath -Encoding utf8

Write-Output "artifact_validation.overall=$overall"
Write-Output "artifact_validation.report=$jsonPath"
