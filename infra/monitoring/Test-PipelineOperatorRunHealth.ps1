[CmdletBinding()]
param(
    [string]$ApiUrl = $(if ($env:PAPERCLIP_API_URL) { $env:PAPERCLIP_API_URL } else { "http://127.0.0.1:3100" }),
    [string]$ApiKey = $(if ($env:PAPERCLIP_API_KEY) { $env:PAPERCLIP_API_KEY } else { "" }),
    [string]$CompanyId = $(if ($env:PAPERCLIP_COMPANY_ID) { $env:PAPERCLIP_COMPANY_ID } else { "" }),
    [string]$PipelineOperatorAgentId = "46fc11e5-7fc2-43f4-9a34-bde29e5dee3b",
    [int]$WindowHours = 24,
    [int]$FetchLimit = 500,
    [int]$UnrecoveredProcessLossCritical = 1,
    [double]$OverallFailRateWarnPct = 20.0,
    [double]$UsageLimitWarnPct = 10.0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Emit-Result {
    param(
        [hashtable]$Payload,
        [int]$ExitCode
    )
    $Payload | ConvertTo-Json -Depth 8
    exit $ExitCode
}

$now = [datetime]::UtcNow
$result = [ordered]@{
    check = "pipeline_operator_run_health"
    status = "unknown"
    message = ""
    generated_at_utc = $now.ToString("o")
    window_hours = $WindowHours
    window_start_utc = $now.AddHours(-1 * $WindowHours).ToString("o")
    agent_id = $PipelineOperatorAgentId
    counts = [ordered]@{
        total = 0
        failed = 0
        process_loss_failed = 0
        process_loss_recovered = 0
        process_loss_unrecovered = 0
        usage_limit_failed = 0
    }
    rates = [ordered]@{
        fail_pct = 0.0
        usage_limit_fail_pct = 0.0
    }
    sample = [ordered]@{
        unrecovered_process_loss_run_ids = @()
        recovered_process_loss_pairs = @()
    }
}

$missing = @()
if (-not $ApiKey) { $missing += "ApiKey/PAPERCLIP_API_KEY" }
if (-not $CompanyId) { $missing += "CompanyId/PAPERCLIP_COMPANY_ID" }
if ($missing.Count -gt 0) {
    $result.status = "critical"
    $result.message = "Missing required Paperclip auth/config values."
    $result["missing"] = $missing
    Emit-Result -Payload $result -ExitCode 2
}

$headers = @{ Authorization = "Bearer $ApiKey" }
$uri = "$($ApiUrl.TrimEnd('/'))/api/companies/$CompanyId/heartbeat-runs?agentId=$PipelineOperatorAgentId&limit=$FetchLimit"

try {
    $rawRuns = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
    $runs = New-Object System.Collections.Generic.List[object]
    foreach ($entry in @($rawRuns)) {
        if ($entry -is [System.Array]) {
            foreach ($inner in $entry) {
                $runs.Add($inner)
            }
            continue
        }
        $runs.Add($entry)
    }
}
catch {
    $result.status = "critical"
    $result.message = "Failed to query heartbeat runs."
    $result["error"] = $_.Exception.Message
    Emit-Result -Payload $result -ExitCode 2
}

$windowStart = $now.AddHours(-1 * $WindowHours)
$recentRuns = @()
foreach ($run in $runs) {
    $createdAtRaw = $run.createdAt
    if ($createdAtRaw -is [System.Array]) {
        if ($createdAtRaw.Count -eq 0) { continue }
        $createdAtRaw = $createdAtRaw[0]
    }
    if (-not $createdAtRaw) { continue }
    $createdAt = if ($createdAtRaw -is [datetime]) { $createdAtRaw } else { [datetime]$createdAtRaw }
    if ($createdAt -ge $windowStart) {
        $recentRuns += $run
    }
}

$failedRuns = @($recentRuns | Where-Object { $_.status -eq "failed" })
$processLossFailedRuns = @(
    $failedRuns | Where-Object {
        $_.errorCode -eq "process_lost" -or ($_.error -is [string] -and $_.error.StartsWith("Process lost"))
    }
)
$usageLimitFailedRuns = @(
    $failedRuns | Where-Object {
        $_.error -is [string] -and $_.error.ToLowerInvariant().Contains("usage limit")
    }
)

$retryRunsBySource = @{}
foreach ($run in $recentRuns) {
    if ($run.retryOfRunId) {
        if (-not $retryRunsBySource.ContainsKey($run.retryOfRunId)) {
            $retryRunsBySource[$run.retryOfRunId] = @()
        }
        $retryRunsBySource[$run.retryOfRunId] += $run
    }
}

$recoveredPairs = New-Object System.Collections.Generic.List[object]
$unrecoveredIds = New-Object System.Collections.Generic.List[string]

foreach ($failedRun in $processLossFailedRuns) {
    $retryCandidates = if ($retryRunsBySource.ContainsKey($failedRun.id)) { @($retryRunsBySource[$failedRun.id]) } else { @() }
    $successRetry = $retryCandidates | Where-Object { $_.status -eq "succeeded" } | Select-Object -First 1
    if ($successRetry) {
        $recoveredPairs.Add([ordered]@{
            failed_run_id = $failedRun.id
            retry_run_id = $successRetry.id
        })
        continue
    }
    $unrecoveredIds.Add($failedRun.id)
}

$totalCount = $recentRuns.Count
$failedCount = $failedRuns.Count
$usageLimitFailedCount = $usageLimitFailedRuns.Count
$failPct = if ($totalCount -gt 0) { [math]::Round(($failedCount * 100.0) / $totalCount, 2) } else { 0.0 }
$usageFailPct = if ($totalCount -gt 0) { [math]::Round(($usageLimitFailedCount * 100.0) / $totalCount, 2) } else { 0.0 }

$result.counts.total = $totalCount
$result.counts.failed = $failedCount
$result.counts.process_loss_failed = $processLossFailedRuns.Count
$result.counts.process_loss_recovered = $recoveredPairs.Count
$result.counts.process_loss_unrecovered = $unrecoveredIds.Count
$result.counts.usage_limit_failed = $usageLimitFailedCount
$result.rates.fail_pct = $failPct
$result.rates.usage_limit_fail_pct = $usageFailPct
$result.sample.unrecovered_process_loss_run_ids = @($unrecoveredIds | Select-Object -First 10)
$result.sample.recovered_process_loss_pairs = @($recoveredPairs | Select-Object -First 10)

if ($totalCount -eq 0) {
    $result.status = "warn"
    $result.message = "No Pipeline-Operator runs in window; cannot assess process-loss health."
    Emit-Result -Payload $result -ExitCode 1
}

if ($unrecoveredIds.Count -ge $UnrecoveredProcessLossCritical) {
    $result.status = "critical"
    $result.message = "Unrecovered process_loss failures detected."
    Emit-Result -Payload $result -ExitCode 2
}

if ($failPct -ge $OverallFailRateWarnPct -or $usageFailPct -ge $UsageLimitWarnPct) {
    $result.status = "warn"
    $result.message = "Run failure rate elevated, but process_loss failures are recovered by retry."
    Emit-Result -Payload $result -ExitCode 1
}

$result.status = "ok"
$result.message = "No unrecovered process_loss failures in window."
Emit-Result -Payload $result -ExitCode 0
