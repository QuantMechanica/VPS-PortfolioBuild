[CmdletBinding()]
param(
    [string]$ApiBaseUrl = $(if ($env:PAPERCLIP_API_URL) { $env:PAPERCLIP_API_URL } else { 'http://127.0.0.1:3100/api' }),
    [string]$ApiKey = $(if ($env:PAPERCLIP_API_KEY) { $env:PAPERCLIP_API_KEY } else { '' }),
    [string]$CompanyId = $(if ($env:PAPERCLIP_COMPANY_ID) { $env:PAPERCLIP_COMPANY_ID } else { '03d4dcc8-4cea-4133-9f68-90c0d99628fb' }),
    [string]$RoutineTitle = 'DWX import hourly check',
    [string]$AssigneeAgentId = '0e8f04e5-4019-45b0-951f-ca248cf82849',
    [string]$ExpectedCronExpression = '7 * * * *',
    [string]$ExpectedTimezone = 'UTC',
    [int]$MaxLagMinutes = 125
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Normalize-ApiBaseUrl {
    param([Parameter(Mandatory = $true)] [string]$Url)
    $trimmed = $Url.TrimEnd('/')
    if ($trimmed -match '/api$') {
        return $trimmed
    }
    return "$trimmed/api"
}

$result = [ordered]@{
    check = 'dwx_hourly_routine_tick'
    generated_at_utc = [datetime]::UtcNow.ToString('o')
    routine_title = $RoutineTitle
    assignee_agent_id = $AssigneeAgentId
    routine_exists = $false
    routine_id = $null
    trigger_id = $null
    trigger_cron = $null
    trigger_timezone = $null
    trigger_enabled = $null
    last_fired_at = $null
    age_minutes = $null
    max_lag_minutes = $MaxLagMinutes
    status = 'unknown'
    message = ''
}

if (-not $ApiKey) {
    $result.status = 'critical'
    $result.message = 'PAPERCLIP_API_KEY missing.'
    $result | ConvertTo-Json -Depth 8
    exit 2
}

$apiRoot = Normalize-ApiBaseUrl -Url $ApiBaseUrl
$headers = @{ Authorization = "Bearer $ApiKey" }
$routinesUri = "$apiRoot/companies/$CompanyId/routines"
$routines = @(Invoke-RestMethod -Method Get -Uri $routinesUri -Headers $headers)
$matches = @($routines | Where-Object { $_.title -eq $RoutineTitle -and $_.assigneeAgentId -eq $AssigneeAgentId })

if ($matches.Count -eq 0) {
    $result.status = 'critical'
    $result.message = 'DWX routine not found for expected title/assignee.'
    $result | ConvertTo-Json -Depth 8
    exit 2
}

if ($matches.Count -gt 1) {
    $result.status = 'critical'
    $result.message = 'Multiple DWX routines matched title/assignee; expected exactly one.'
    $result | ConvertTo-Json -Depth 8
    exit 2
}

$routine = $matches[0]
$result.routine_exists = $true
$result.routine_id = $routine.id

$scheduleTriggers = @($routine.triggers | Where-Object { $_.kind -eq 'schedule' -and $_.enabled -eq $true })
if ($scheduleTriggers.Count -eq 0) {
    $result.status = 'critical'
    $result.message = 'No enabled schedule trigger on DWX routine.'
    $result | ConvertTo-Json -Depth 8
    exit 2
}

$trigger = @($scheduleTriggers | Where-Object {
    $_.cronExpression -eq $ExpectedCronExpression -and $_.timezone -eq $ExpectedTimezone
} | Select-Object -First 1)
if (-not $trigger) {
    $trigger = @($scheduleTriggers | Select-Object -First 1)
}

$result.trigger_id = $trigger.id
$result.trigger_cron = $trigger.cronExpression
$result.trigger_timezone = $trigger.timezone
$result.trigger_enabled = $trigger.enabled

if ($trigger.cronExpression -ne $ExpectedCronExpression -or $trigger.timezone -ne $ExpectedTimezone) {
    $result.status = 'critical'
    $result.message = "DWX routine schedule drifted (expected '$ExpectedCronExpression' @ '$ExpectedTimezone')."
    $result | ConvertTo-Json -Depth 8
    exit 2
}

$timestampRaw = $null
if ($trigger.lastFiredAt) { $timestampRaw = $trigger.lastFiredAt }
elseif ($routine.lastTriggeredAt) { $timestampRaw = $routine.lastTriggeredAt }
elseif ($routine.lastEnqueuedAt) { $timestampRaw = $routine.lastEnqueuedAt }

if (-not $timestampRaw) {
    $result.status = 'warn'
    $result.message = 'Routine schedule is valid but no fired tick has been observed yet.'
    $result | ConvertTo-Json -Depth 8
    exit 1
}

$last = [datetime]::Parse($timestampRaw).ToUniversalTime()
$ageMinutes = [math]::Round(([datetime]::UtcNow - $last).TotalMinutes, 2)
$result.last_fired_at = $last.ToString('o')
$result.age_minutes = $ageMinutes

if ($ageMinutes -gt $MaxLagMinutes) {
    $result.status = 'critical'
    $result.message = 'DWX routine tick is stale.'
    $result | ConvertTo-Json -Depth 8
    exit 2
}

$result.status = 'ok'
$result.message = 'DWX routine cadence and recent tick verified.'
$result | ConvertTo-Json -Depth 8
exit 0

