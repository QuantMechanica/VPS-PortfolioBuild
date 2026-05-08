[CmdletBinding()]
param(
    [string]$ApiUrl = $(if ($env:PAPERCLIP_API_URL) { $env:PAPERCLIP_API_URL } else { "http://127.0.0.1:3100" }),
    [string]$ApiKey = $(if ($env:PAPERCLIP_API_TOKEN) { $env:PAPERCLIP_API_TOKEN } elseif ($env:PAPERCLIP_API_KEY) { $env:PAPERCLIP_API_KEY } else { "" }),
    [string]$CompanyId = $(if ($env:PAPERCLIP_COMPANY_ID) { $env:PAPERCLIP_COMPANY_ID } else { "" }),
    [string]$InputAgentsJsonPath = "",
    [string]$StatePath = "C:\QM\logs\infra\health\qm_token_monitor_state.json",
    [string]$OutputJsonPath = "C:\QM\logs\infra\health\qm_token_monitor_latest.json",
    [string]$OutputMarkdownPath = "C:\QM\logs\infra\health\qm_token_monitor_latest.md",
    [string]$TokenBudgetPath = "C:\QM\repo\framework\registry\token_budget.json",
    [switch]$NoWriteOutputFiles
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-ParentDir {
    param([string]$Path)
    $parent = Split-Path -Path $Path -Parent
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

function To-Array {
    param([object]$Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [System.Array]) { return @($Value) }
    if ($Value.PSObject.Properties["items"]) { return @($Value.items) }
    return @($Value)
}

function To-Int64 {
    param([object]$Value)
    if ($null -eq $Value) { return [int64]0 }
    try { return [int64]([double]$Value) } catch { return [int64]0 }
}

function To-Double {
    param([object]$Value)
    if ($null -eq $Value) { return 0.0 }
    try { return [double]$Value } catch { return 0.0 }
}

function Parse-Utc {
    param([object]$Value)
    if ($null -eq $Value) { return $null }
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    try { return ([datetime]$Value).ToUniversalTime() } catch { return $null }
}

function Get-Prop {
    param(
        [object]$Object,
        [string[]]$Names,
        [object]$Default = $null
    )
    foreach ($n in $Names) {
        if ($Object.PSObject.Properties[$n]) {
            return $Object.$n
        }
    }
    return $Default
}

$nowUtc = [datetime]::UtcNow
$dayOfMonth = [math]::Max(1, $nowUtc.Day)

$agentsRaw = @()
if (-not [string]::IsNullOrWhiteSpace($InputAgentsJsonPath)) {
    if (-not (Test-Path -LiteralPath $InputAgentsJsonPath)) {
        throw "InputAgentsJsonPath not found: $InputAgentsJsonPath"
    }
    $agentsRaw = To-Array (Get-Content -Raw -LiteralPath $InputAgentsJsonPath | ConvertFrom-Json)
}
else {
    if ([string]::IsNullOrWhiteSpace($ApiKey) -or [string]::IsNullOrWhiteSpace($CompanyId)) {
        throw "Missing ApiKey/PAPERCLIP_API_KEY or CompanyId/PAPERCLIP_COMPANY_ID."
    }
    $uri = "$($ApiUrl.TrimEnd('/'))/api/companies/$CompanyId/agents"
    $headers = @{ Authorization = "Bearer $ApiKey" }
    $agentsRaw = To-Array (Invoke-RestMethod -Method Get -Uri $uri -Headers $headers)
}

$budget = $null
if (Test-Path -LiteralPath $TokenBudgetPath) {
    $budget = Get-Content -Raw -LiteralPath $TokenBudgetPath | ConvertFrom-Json
}
$orgCapCents = To-Int64 (Get-Prop -Object $budget.company -Names @("monthly_budget_cents") -Default 0)
$warnPct = To-Int64 (Get-Prop -Object $budget.company -Names @("alarm_threshold_pct") -Default 70)
$criticalPct = To-Int64 (Get-Prop -Object $budget.company -Names @("hard_stop_pct") -Default 95)
if ($warnPct -le 0) { $warnPct = 70 }
if ($criticalPct -le 0) { $criticalPct = 95 }

$previousState = $null
if (Test-Path -LiteralPath $StatePath) {
    try { $previousState = Get-Content -Raw -LiteralPath $StatePath | ConvertFrom-Json } catch { $previousState = $null }
}
$prevAt = Parse-Utc (Get-Prop -Object $previousState -Names @("generated_at_utc") -Default $null)
$elapsedHours = 0.0
if ($null -ne $prevAt) { $elapsedHours = ($nowUtc - $prevAt).TotalHours }

$agents = @()
$anomalies = @()
$orgSpentCents = [int64]0
$orgDailyDelta = 0.0

foreach ($a in $agentsRaw) {
    $id = [string](Get-Prop -Object $a -Names @("id", "agentId") -Default "")
    if ([string]::IsNullOrWhiteSpace($id)) { continue }
    $name = [string](Get-Prop -Object $a -Names @("name", "displayName") -Default $id)
    $adapter = [string](Get-Prop -Object $a -Names @("adapter", "adapterName") -Default "")
    $status = [string](Get-Prop -Object $a -Names @("status") -Default "")
    $spent = To-Int64 (Get-Prop -Object $a -Names @("spentMonthlyCents") -Default 0)
    $lastHeartbeat = Parse-Utc (Get-Prop -Object $a -Names @("lastHeartbeatAt") -Default $null)

    $prevSpent = [int64]0
    if ($null -ne $previousState -and $previousState.PSObject.Properties["agentsById"]) {
        $prevAgent = $previousState.agentsById.PSObject.Properties[$id]
        if ($null -ne $prevAgent) {
            $prevSpent = To-Int64 (Get-Prop -Object $prevAgent.Value -Names @("spent_cents") -Default 0)
        }
    }
    $delta = [int64]($spent - $prevSpent)
    if ($delta -lt 0) { $delta = 0 }

    $dailyDelta = if ($elapsedHours -gt 0.0) { [math]::Round(($delta / $elapsedHours) * 24.0, 2) } else { [math]::Round($spent / $dayOfMonth, 2) }
    $orgSpentCents += $spent
    $orgDailyDelta += $dailyDelta

    $heartbeatAgeMin = $null
    if ($null -ne $lastHeartbeat) { $heartbeatAgeMin = [math]::Round(($nowUtc - $lastHeartbeat).TotalMinutes, 2) }
    if ($elapsedHours -gt 0.0 -and $elapsedHours -le 1.0 -and $delta -ge 100 -and $heartbeatAgeMin -ne $null -and $heartbeatAgeMin -le 10.0) {
        $anomalies += [pscustomobject]@{
            code = "HEARTBEAT_STORM_SUSPECTED"
            severity = "warn"
            agent_id = $id
            agent_name = $name
            detail = "High spend delta over short interval with very recent heartbeat."
            delta_cents = $delta
            elapsed_hours = [math]::Round($elapsedHours, 4)
            daily_delta_cents = $dailyDelta
            last_heartbeat_age_minutes = $heartbeatAgeMin
        }
    }

    $agents += [pscustomobject]@{
        agent_id = $id
        agent_name = $name
        adapter = $adapter
        status = $status
        spent_cents = $spent
        daily_delta_cents = $dailyDelta
        last_heartbeat_at_utc = if ($null -ne $lastHeartbeat) { $lastHeartbeat.ToString("o") } else { $null }
    }
}

$top3 = @($agents | Sort-Object -Property spent_cents -Descending | Select-Object -First 3)
$orgCapPctUsed = if ($orgCapCents -gt 0) { [math]::Round(($orgSpentCents * 100.0) / $orgCapCents, 2) } else { 0.0 }
$daysToExhaust = $null
if ($orgCapCents -gt 0 -and $orgDailyDelta -gt 0.0) {
    $remaining = [math]::Max(0.0, [double]($orgCapCents - $orgSpentCents))
    $daysToExhaust = [math]::Round($remaining / $orgDailyDelta, 2)
}

$statusValue = "ok"
if ($orgCapPctUsed -ge $criticalPct) {
    $statusValue = "critical"
    $anomalies += [pscustomobject]@{
        code = "ORG_CAP_CRITICAL"
        severity = "critical"
        detail = "Org spend reached hard-stop threshold."
        org_cap_pct_used = $orgCapPctUsed
        threshold_pct = $criticalPct
    }
}
elseif ($orgCapPctUsed -ge $warnPct) {
    $statusValue = "warn"
    $anomalies += [pscustomobject]@{
        code = "ORG_CAP_WARN"
        severity = "warn"
        detail = "Org spend reached warning threshold."
        org_cap_pct_used = $orgCapPctUsed
        threshold_pct = $warnPct
    }
}

if ($daysToExhaust -ne $null -and $daysToExhaust -le 4.0) {
    if ($statusValue -eq "ok") { $statusValue = "warn" }
    $anomalies += [pscustomobject]@{
        code = "ORG_EXHAUSTION_LEQ_4D"
        severity = if ($daysToExhaust -le 2.0) { "critical" } else { "warn" }
        detail = "Projected exhaustion window is within 4 days."
        days_to_exhaust = $daysToExhaust
    }
}

$history = @()
if ($null -ne $previousState -and $previousState.PSObject.Properties["history"]) {
    $history = @($previousState.history)
}
$history += [pscustomobject]@{
    generated_at_utc = $nowUtc.ToString("o")
    org_daily_delta_cents = [math]::Round($orgDailyDelta, 2)
}
$history = @($history | Select-Object -Last 7)
$sum7d = 0.0
foreach ($h in $history) { $sum7d += To-Double $h.org_daily_delta_cents }
$avg7d = if ($history.Count -gt 0) { [math]::Round($sum7d / $history.Count, 2) } else { 0.0 }

$output = [pscustomobject]@{
    check = "qm_token_monitor"
    status = $statusValue
    generated_at_utc = $nowUtc.ToString("o")
    company_id = $CompanyId
    spent_cents = $orgSpentCents
    daily_delta = [math]::Round($orgDailyDelta, 2)
    org_cap_cents = $orgCapCents
    org_cap_pct_used = $orgCapPctUsed
    burn_trend = [pscustomobject]@{
        daily_delta_24h_cents = [math]::Round($orgDailyDelta, 2)
        daily_delta_7d_avg_cents = $avg7d
    }
    days_to_exhaust = $daysToExhaust
    top3_agents = $top3
    anomalies = $anomalies
    source = [pscustomobject]@{
        mode = if (-not [string]::IsNullOrWhiteSpace($InputAgentsJsonPath)) { "fixture" } else { "api" }
        token_budget_path = $TokenBudgetPath
    }
}

$stateObj = [ordered]@{
    generated_at_utc = $nowUtc.ToString("o")
    org_spent_cents = $orgSpentCents
    org_daily_delta_cents = [math]::Round($orgDailyDelta, 2)
    agentsById = [ordered]@{}
    history = $history
}
foreach ($a in $agents) {
    $stateObj.agentsById[$a.agent_id] = [pscustomobject]@{
        spent_cents = $a.spent_cents
        daily_delta_cents = $a.daily_delta_cents
    }
}

if (-not $NoWriteOutputFiles.IsPresent) {
    Ensure-ParentDir -Path $StatePath
    Ensure-ParentDir -Path $OutputJsonPath
    Ensure-ParentDir -Path $OutputMarkdownPath

    ($stateObj | ConvertTo-Json -Depth 12) | Set-Content -LiteralPath $StatePath -Encoding UTF8
    ($output | ConvertTo-Json -Depth 12) | Set-Content -LiteralPath $OutputJsonPath -Encoding UTF8

    $lines = @(
        "# QM Token Monitor",
        "",
        "- Generated UTC: $($output.generated_at_utc)",
        "- Status: $($output.status)",
        "- spent_cents: $($output.spent_cents)",
        "- daily_delta: $($output.daily_delta)",
        "- org_cap_pct_used: $($output.org_cap_pct_used)",
        "- days_to_exhaust: $(if ($null -ne $output.days_to_exhaust) { $output.days_to_exhaust } else { 'n/a' })",
        "",
        "| Agent | Spent (cents) | Daily Delta (cents/day) | Last Heartbeat UTC |",
        "|---|---:|---:|---|"
    )
    foreach ($a in $top3) {
        $lines += "| $($a.agent_name) (`$($a.agent_id)`) | $($a.spent_cents) | $($a.daily_delta_cents) | $($a.last_heartbeat_at_utc) |"
    }
    if (@($anomalies).Count -gt 0) {
        $lines += ""
        $lines += "## Anomalies"
        foreach ($an in $anomalies) {
            $lines += "- [$($an.severity)] $($an.code): $($an.detail)"
        }
    }
    ($lines -join "`r`n") | Set-Content -LiteralPath $OutputMarkdownPath -Encoding UTF8
}

$output | ConvertTo-Json -Depth 12
if ($statusValue -eq "critical") { exit 2 }
if ($statusValue -eq "warn") { exit 1 }
exit 0

