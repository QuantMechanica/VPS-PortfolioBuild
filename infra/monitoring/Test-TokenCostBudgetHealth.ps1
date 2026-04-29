[CmdletBinding()]
param(
    [string]$ApiUrl = $(if ($env:PAPERCLIP_API_URL) { $env:PAPERCLIP_API_URL } else { "http://127.0.0.1:3100" }),
    [string]$ApiKey = $(if ($env:PAPERCLIP_API_KEY) { $env:PAPERCLIP_API_KEY } else { "" }),
    [string]$CompanyId = $(if ($env:PAPERCLIP_COMPANY_ID) { $env:PAPERCLIP_COMPANY_ID } else { "" }),
    [int64]$DailyTokenBudget = $(if ($env:QM_DAILY_TOKEN_BUDGET) { [int64]$env:QM_DAILY_TOKEN_BUDGET } else { 2500000 }),
    [int64]$MonthlyTokenCap = $(if ($env:QM_MONTHLY_TOKEN_CAP) { [int64]$env:QM_MONTHLY_TOKEN_CAP } else { 75000000 }),
    [int]$WarnThresholdPct = 70,
    [int]$HighWarnThresholdPct = 80,
    [int]$CriticalThresholdPct = 95,
    [int]$FetchLimit = 2000,
    [string]$SnapshotDirectory = "D:\QM\reports\ops",
    [string]$InputRunsPath = "",
    [switch]$NoWriteSnapshot,
    [switch]$NoWriteMarkdownSummary
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Emit-Result {
    param([hashtable]$Payload, [int]$ExitCode)
    $Payload | ConvertTo-Json -Depth 10
    exit $ExitCode
}

function Flatten-Runs {
    param([object]$Raw)
    $list = New-Object System.Collections.Generic.List[object]
    foreach ($entry in @($Raw)) {
        if ($entry -is [System.Array]) {
            foreach ($inner in $entry) { $list.Add($inner) }
            continue
        }
        $list.Add($entry)
    }
    return $list.ToArray()
}

function Try-GetPathValue {
    param([object]$Object, [string[]]$Path)
    $cursor = $Object
    foreach ($segment in $Path) {
        if ($null -eq $cursor) { return $null }
        $prop = $cursor.PSObject.Properties[$segment]
        if ($null -eq $prop) { return $null }
        $cursor = $prop.Value
    }
    return $cursor
}

function Get-TokenCountFromRun {
    param([object]$Run)

    $candidatePaths = @(
        @("totalTokens"), @("total_tokens"), @("tokenCount"), @("token_count"),
        @("usage", "totalTokens"), @("usage", "total_tokens"), @("usage", "tokenCount"),
        @("metrics", "totalTokens"), @("metrics", "total_tokens"),
        @("modelUsage", "totalTokens"), @("model_usage", "total_tokens")
    )
    foreach ($path in $candidatePaths) {
        $value = Try-GetPathValue -Object $Run -Path $path
        if ($value -is [int] -or $value -is [long] -or $value -is [double] -or $value -is [decimal]) {
            return [int64][math]::Round([double]$value, 0)
        }
    }

    $prompt = Try-GetPathValue -Object $Run -Path @("promptTokens")
    if ($null -eq $prompt) { $prompt = Try-GetPathValue -Object $Run -Path @("prompt_tokens") }
    if ($null -eq $prompt) { $prompt = Try-GetPathValue -Object $Run -Path @("usage", "promptTokens") }
    if ($null -eq $prompt) { $prompt = Try-GetPathValue -Object $Run -Path @("usage", "prompt_tokens") }

    $completion = Try-GetPathValue -Object $Run -Path @("completionTokens")
    if ($null -eq $completion) { $completion = Try-GetPathValue -Object $Run -Path @("completion_tokens") }
    if ($null -eq $completion) { $completion = Try-GetPathValue -Object $Run -Path @("usage", "completionTokens") }
    if ($null -eq $completion) { $completion = Try-GetPathValue -Object $Run -Path @("usage", "completion_tokens") }

    $promptVal = if ($prompt -is [ValueType]) { [double]$prompt } else { 0 }
    $completionVal = if ($completion -is [ValueType]) { [double]$completion } else { 0 }
    if ($promptVal -gt 0 -or $completionVal -gt 0) {
        return [int64][math]::Round($promptVal + $completionVal, 0)
    }

    return 0
}

$now = [datetime]::UtcNow
$dayStart = $now.Date
$window24h = $now.AddHours(-24)
$window7d = $now.AddDays(-7)
$monthStart = [datetime]::new($now.Year, $now.Month, 1, 0, 0, 0, [System.DateTimeKind]::Utc)
$daysInMonth = [datetime]::DaysInMonth($now.Year, $now.Month)
$dayOfMonth = $now.Day

$result = [ordered]@{
    check = "token_cost_budget_health"
    status = "unknown"
    message = ""
    generated_at_utc = $now.ToString("o")
    date_utc = $dayStart.ToString("yyyy-MM-dd")
    thresholds_pct = [ordered]@{ warn = $WarnThresholdPct; high_warn = $HighWarnThresholdPct; critical = $CriticalThresholdPct }
    caps = [ordered]@{ daily_token_budget = $DailyTokenBudget; monthly_token_cap = $MonthlyTokenCap; cap_is_placeholder = $true }
    windows = [ordered]@{ last_24h_start_utc = $window24h.ToString("o"); last_7d_start_utc = $window7d.ToString("o"); month_start_utc = $monthStart.ToString("o") }
    totals = [ordered]@{ tokens_last_24h = 0; tokens_last_7d = 0; tokens_month_to_date = 0; monthly_forecast_linear = 0; monthly_cap_usage_pct_forecast = 0.0 }
    per_agent = @()
    alarm = [ordered]@{ level = "ok"; breached_threshold_pct = $null; monthly_cap_usage_pct_forecast = 0.0 }
    output = [ordered]@{ json_path = ""; markdown_path = "" }
}

$runs = @()
if ($InputRunsPath) {
    if (-not (Test-Path -LiteralPath $InputRunsPath)) {
        $result.status = "critical"
        $result.message = "InputRunsPath not found."
        $result["missing"] = @($InputRunsPath)
        Emit-Result -Payload $result -ExitCode 2
    }
    $raw = Get-Content -Raw -LiteralPath $InputRunsPath | ConvertFrom-Json
    $runs = Flatten-Runs -Raw $raw
}
else {
    $missing = @()
    if (-not $ApiKey) { $missing += "ApiKey/PAPERCLIP_API_KEY" }
    if (-not $CompanyId) { $missing += "CompanyId/PAPERCLIP_COMPANY_ID" }
    if ($missing.Count -gt 0) {
        $result.status = "critical"
        $result.message = "Missing required token-cost monitor configuration."
        $result["missing"] = $missing
        Emit-Result -Payload $result -ExitCode 2
    }

    $headers = @{ Authorization = "Bearer $ApiKey" }
    $uri = "$($ApiUrl.TrimEnd('/'))/api/companies/$CompanyId/heartbeat-runs?limit=$FetchLimit"
    try {
        $rawRuns = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
        $runs = Flatten-Runs -Raw $rawRuns
    }
    catch {
        $result.status = "critical"
        $result.message = "Failed to query heartbeat runs for token-cost monitor."
        $result["error"] = $_.Exception.Message
        Emit-Result -Payload $result -ExitCode 2
    }
}

$agentRollup = @{}
foreach ($run in $runs) {
    $createdAtRaw = $run.createdAt
    if ($createdAtRaw -is [System.Array]) {
        if ($createdAtRaw.Count -eq 0) { continue }
        $createdAtRaw = $createdAtRaw[0]
    }
    if (-not $createdAtRaw) { continue }
    $createdAt = if ($createdAtRaw -is [datetime]) { $createdAtRaw.ToUniversalTime() } else { ([datetime]$createdAtRaw).ToUniversalTime() }

    $agentId = "unknown"
    if ($run.PSObject.Properties["agentId"]) { $agentId = [string]$run.agentId }
    elseif ($run.PSObject.Properties["agent_id"]) { $agentId = [string]$run.agent_id }
    if ([string]::IsNullOrWhiteSpace($agentId)) { $agentId = "unknown" }

    if (-not $agentRollup.ContainsKey($agentId)) {
        $agentRollup[$agentId] = [ordered]@{ tokens_last_24h = [int64]0; tokens_last_7d = [int64]0; tokens_month_to_date = [int64]0 }
    }

    $tokens = Get-TokenCountFromRun -Run $run

    if ($createdAt -ge $window24h) {
        $result.totals.tokens_last_24h += $tokens
        $agentRollup[$agentId].tokens_last_24h += $tokens
    }
    if ($createdAt -ge $window7d) {
        $result.totals.tokens_last_7d += $tokens
        $agentRollup[$agentId].tokens_last_7d += $tokens
    }
    if ($createdAt -ge $monthStart) {
        $result.totals.tokens_month_to_date += $tokens
        $agentRollup[$agentId].tokens_month_to_date += $tokens
    }
}

$daily7dAvg = if ($result.totals.tokens_last_7d -gt 0) { [double]$result.totals.tokens_last_7d / 7.0 } else { 0.0 }
$forecast = [int64][math]::Round($daily7dAvg * $daysInMonth, 0)
$result.totals.monthly_forecast_linear = $forecast

$capUsageForecastPct = if ($MonthlyTokenCap -gt 0) { [math]::Round(($forecast * 100.0) / $MonthlyTokenCap, 2) } else { 0.0 }
$result.totals.monthly_cap_usage_pct_forecast = $capUsageForecastPct
$result.alarm.monthly_cap_usage_pct_forecast = $capUsageForecastPct

foreach ($k in $agentRollup.Keys | Sort-Object) {
    $result.per_agent += [ordered]@{ agent_id = $k; tokens_last_24h = $agentRollup[$k].tokens_last_24h; tokens_last_7d = $agentRollup[$k].tokens_last_7d; tokens_month_to_date = $agentRollup[$k].tokens_month_to_date }
}

if ($capUsageForecastPct -ge $CriticalThresholdPct) {
    $result.status = "critical"
    $result.message = "Monthly token forecast reached critical threshold."
    $result.alarm.level = "critical"
    $result.alarm.breached_threshold_pct = $CriticalThresholdPct
    $exitCode = 2
}
elseif ($capUsageForecastPct -ge $HighWarnThresholdPct) {
    $result.status = "warn"
    $result.message = "Monthly token forecast reached high warning threshold."
    $result.alarm.level = "warn"
    $result.alarm.breached_threshold_pct = $HighWarnThresholdPct
    $exitCode = 1
}
elseif ($capUsageForecastPct -ge $WarnThresholdPct) {
    $result.status = "warn"
    $result.message = "Monthly token forecast reached warning threshold."
    $result.alarm.level = "warn"
    $result.alarm.breached_threshold_pct = $WarnThresholdPct
    $exitCode = 1
}
else {
    $result.status = "ok"
    $result.message = "Monthly token forecast is below warning threshold."
    $result.alarm.level = "ok"
    $exitCode = 0
}

if (-not $NoWriteSnapshot.IsPresent) {
    New-Item -ItemType Directory -Path $SnapshotDirectory -Force | Out-Null
    $dateStamp = $dayStart.ToString("yyyy-MM-dd")
    $jsonPath = Join-Path $SnapshotDirectory ("token_usage_{0}.json" -f $dateStamp)
    $latestPath = Join-Path $SnapshotDirectory "token_usage_latest.json"
    $json = $result | ConvertTo-Json -Depth 10
    $json | Set-Content -LiteralPath $jsonPath -Encoding ASCII
    $json | Set-Content -LiteralPath $latestPath -Encoding ASCII
    $result.output.json_path = $jsonPath

    if (-not $NoWriteMarkdownSummary.IsPresent) {
        $mdPath = Join-Path $SnapshotDirectory ("token_usage_summary_{0}.md" -f $dateStamp)
        $md = @(
            "# Token Usage Daily Summary ({0})" -f $dateStamp,
            "",
            "- JSON snapshot: {0}" -f $jsonPath,
            "- Alarm: {0}" -f $result.alarm.level,
            "- Forecast usage: {0}% of monthly cap" -f $capUsageForecastPct,
            "- Monthly forecast (linear, 7d slope): {0} tokens" -f $forecast,
            "",
            "Doc-KM handoff: mirror this summary and cite the JSON snapshot path above."
        ) -join "`r`n"
        $md | Set-Content -LiteralPath $mdPath -Encoding ASCII
        $result.output.markdown_path = $mdPath
    }
}

Emit-Result -Payload $result -ExitCode $exitCode
