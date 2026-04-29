[CmdletBinding()]
param(
    [string]$ApiUrl = $(if ($env:PAPERCLIP_API_URL) { $env:PAPERCLIP_API_URL } else { "http://127.0.0.1:3100" }),
    [string]$ApiKey = $(if ($env:PAPERCLIP_API_TOKEN) { $env:PAPERCLIP_API_TOKEN } elseif ($env:PAPERCLIP_API_KEY) { $env:PAPERCLIP_API_KEY } else { "" }),
    [string]$CompanyId = $(if ($env:PAPERCLIP_COMPANY_ID) { $env:PAPERCLIP_COMPANY_ID } else { "" }),
    [double]$DailyBudgetUsd = $(if ($env:QM_TOKEN_DAILY_BUDGET_USD) { [double]$env:QM_TOKEN_DAILY_BUDGET_USD } else { 25.0 }),
    [int]$FetchLimit = 1000,
    [string]$PipelineOperatorAgentId = "46fc11e5-7fc2-43f4-9a34-bde29e5dee3b",
    [string]$InputRunsJsonPath = "",
    [string]$SnapshotPath = "C:\QM\logs\infra\health\token_cost_daily_snapshot_latest.json",
    [string]$SnapshotHistoryDirectory = "C:\QM\logs\infra\health\token_cost_daily"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-NumberOrZero {
    param([object]$Value)
    if ($null -eq $Value) { return 0.0 }
    try { return [double]$Value } catch { return 0.0 }
}

function Get-PathValue {
    param(
        [object]$Object,
        [string]$Path
    )
    $cursor = $Object
    foreach ($part in $Path.Split(".")) {
        if ($null -eq $cursor) { return $null }
        $prop = $cursor.PSObject.Properties[$part]
        if ($null -eq $prop) { return $null }
        $cursor = $prop.Value
    }
    return $cursor
}

function Get-CostFromRun {
    param([object]$Run)
    foreach ($path in @(
        "usage.total_cost_usd",
        "usage.cost_usd",
        "usage.costUsd",
        "total_cost_usd",
        "cost_usd",
        "costUsd"
    )) {
        $candidate = Get-PathValue -Object $Run -Path $path
        $cost = Get-NumberOrZero -Value $candidate
        if ($cost -gt 0) { return $cost }
    }
    return 0.0
}

function Get-TokenField {
    param(
        [object]$Run,
        [string[]]$Candidates
    )
    foreach ($name in $Candidates) {
        $value = Get-PathValue -Object $Run -Path $name
        if ($null -ne $value) {
            return [long](Get-NumberOrZero -Value $value)
        }
    }
    return 0
}

function Ensure-ParentDir {
    param([string]$Path)
    $parent = Split-Path -Path $Path -Parent
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

function Normalize-Runs {
    param([object]$InputObject)
    if ($null -eq $InputObject) { return @() }
    if ($InputObject -is [System.Array]) { return @($InputObject) }
    if ($InputObject -is [System.Collections.IList]) { return @($InputObject) }
    if ($InputObject.PSObject.Properties["items"]) {
        return @($InputObject.items)
    }
    return @($InputObject)
}

$nowUtc = [datetime]::UtcNow
$dayStartUtc = [datetime]::new($nowUtc.Year, $nowUtc.Month, $nowUtc.Day, 0, 0, 0, [System.DateTimeKind]::Utc)
$dayEndUtc = $dayStartUtc.AddDays(1)

if ($DailyBudgetUsd -le 0) {
    throw "DailyBudgetUsd must be > 0."
}

$runs = @()
if (-not [string]::IsNullOrWhiteSpace($InputRunsJsonPath)) {
    if (-not (Test-Path -LiteralPath $InputRunsJsonPath)) {
        throw "InputRunsJsonPath not found: $InputRunsJsonPath"
    }
    $runsRaw = Get-Content -Raw -LiteralPath $InputRunsJsonPath | ConvertFrom-Json
    $runs = Normalize-Runs -InputObject $runsRaw
}
else {
    $missing = @()
    if (-not $ApiKey) { $missing += "ApiKey/PAPERCLIP_API_TOKEN|PAPERCLIP_API_KEY" }
    if (-not $CompanyId) { $missing += "CompanyId/PAPERCLIP_COMPANY_ID" }
    if ($missing.Count -gt 0) {
        $out = [ordered]@{
            check = "token_cost_budget"
            status = "critical"
            message = "Missing required Paperclip auth/config values."
            missing = $missing
            generated_at_utc = $nowUtc.ToString("o")
        }
        $out | ConvertTo-Json -Depth 8
        exit 2
    }

    $uri = "$($ApiUrl.TrimEnd('/'))/api/companies/$CompanyId/heartbeat-runs?agentId=$PipelineOperatorAgentId&limit=$FetchLimit"
    $headers = @{ Authorization = "Bearer $ApiKey" }
    $rawRuns = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
    $runs = Normalize-Runs -InputObject $rawRuns
}

$todayRuns = New-Object System.Collections.Generic.List[object]
$totalCostUsd = 0.0
$totalTokens = 0L
$inputTokens = 0L
$outputTokens = 0L

foreach ($run in $runs) {
    $createdAtRaw = $run.createdAt
    if ($createdAtRaw -is [System.Array]) {
        if ($createdAtRaw.Count -eq 0) { continue }
        $createdAtRaw = $createdAtRaw[0]
    }
    if (-not $createdAtRaw) { continue }
    $createdAt = if ($createdAtRaw -is [datetime]) { $createdAtRaw.ToUniversalTime() } else { ([datetime]$createdAtRaw).ToUniversalTime() }
    if ($createdAt -lt $dayStartUtc -or $createdAt -ge $dayEndUtc) { continue }

    $todayRuns.Add($run)
    $totalCostUsd += Get-CostFromRun -Run $run
    $totalTokens += Get-TokenField -Run $run -Candidates @("usage.total_tokens", "usage.totalTokens", "token_usage.total_tokens", "total_tokens")
    $inputTokens += Get-TokenField -Run $run -Candidates @("usage.input_tokens", "usage.prompt_tokens", "usage.inputTokens", "token_usage.input_tokens")
    $outputTokens += Get-TokenField -Run $run -Candidates @("usage.output_tokens", "usage.completion_tokens", "usage.outputTokens", "token_usage.output_tokens")
}

$pctUsed = if ($DailyBudgetUsd -gt 0) { [math]::Round(($totalCostUsd / $DailyBudgetUsd) * 100.0, 2) } else { 0.0 }
$cross70 = $pctUsed -ge 70.0
$cross80 = $pctUsed -ge 80.0
$cross95 = $pctUsed -ge 95.0

$status = "ok"
$message = "Token cost within daily budget."
$exitCode = 0
if ($cross95) {
    $status = "critical"
    $message = "Token cost is at or above 95% of daily budget."
    $exitCode = 2
}
elseif ($cross80) {
    $status = "warn"
    $message = "Token cost is at or above 80% of daily budget."
    $exitCode = 1
}
elseif ($cross70) {
    $status = "warn"
    $message = "Token cost is at or above 70% of daily budget."
    $exitCode = 1
}

$snapshot = [ordered]@{
    date_utc = $dayStartUtc.ToString("yyyy-MM-dd")
    generated_at_utc = $nowUtc.ToString("o")
    budget_usd = [math]::Round($DailyBudgetUsd, 4)
    spent_usd = [math]::Round($totalCostUsd, 6)
    budget_used_pct = $pctUsed
    runs_count = $todayRuns.Count
    tokens = [ordered]@{
        total = $totalTokens
        input = $inputTokens
        output = $outputTokens
    }
    thresholds = [ordered]@{
        pct_70_crossed = $cross70
        pct_80_crossed = $cross80
        pct_95_crossed = $cross95
    }
}

Ensure-ParentDir -Path $SnapshotPath
$snapshot | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $SnapshotPath -Encoding UTF8
if (-not (Test-Path -LiteralPath $SnapshotHistoryDirectory)) {
    New-Item -ItemType Directory -Path $SnapshotHistoryDirectory -Force | Out-Null
}
$historyPath = Join-Path $SnapshotHistoryDirectory ("token_cost_{0}.json" -f $dayStartUtc.ToString("yyyy-MM-dd"))
$snapshot | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $historyPath -Encoding UTF8

$out = [ordered]@{
    check = "token_cost_budget"
    status = $status
    message = $message
    generated_at_utc = $nowUtc.ToString("o")
    budget_usd = [math]::Round($DailyBudgetUsd, 4)
    spent_usd = [math]::Round($totalCostUsd, 6)
    budget_used_pct = $pctUsed
    runs_count = $todayRuns.Count
    thresholds = $snapshot.thresholds
    snapshot_written = $true
    snapshot_path = $SnapshotPath
    snapshot_history_path = $historyPath
}

$out | ConvertTo-Json -Depth 8
exit $exitCode
