[CmdletBinding()]
param(
    [string]$PaperclipApiUrl = $(if ($env:PAPERCLIP_API_URL) { $env:PAPERCLIP_API_URL } else { "http://127.0.0.1:3100" }),
    [string]$ApiKey = $(if ($env:PAPERCLIP_API_KEY) { $env:PAPERCLIP_API_KEY } else { "" }),
    [string]$CompanyId = $(if ($env:PAPERCLIP_COMPANY_ID) { $env:PAPERCLIP_COMPANY_ID } else { "" }),
    [string]$RunId = $(if ($env:PAPERCLIP_RUN_ID) { $env:PAPERCLIP_RUN_ID } else { "runtime-health-scan-manual" }),
    [string]$OutputPath = "C:\QM\logs\infra\health\runtime_health_scan_latest.json",
    [string]$RuntimeStateOutputPath = "C:\QM\repo\public-data\company-runtime.json",
    [string]$PostgresUrl = $(if ($env:PAPERCLIP_POSTGRES_URL) { $env:PAPERCLIP_POSTGRES_URL } else { "" }),
    [string]$PsqlPath = $(if ($env:PSQL_PATH) { $env:PSQL_PATH } else { "psql" }),
    [switch]$AllowApiFallback,
    [int]$HotPollRunThreshold = 50,
    [int]$HotPollDoneThreshold = 5,
    [int]$StuckErrorMinutes = 30,
    [int]$StuckWakeOnDemandHeartbeatHours = 2,
    [int]$HeartbeatSilenceWatchdogHours = 24,
    [int]$BottleneckMinP0InProgress = 2,
    [int]$BottleneckMinRunsLast4h = 5,
    [double]$TokenBudgetThreshold = 0.9,
    [int]$RecursiveWakeMinIdenticalComments = 10,
    [switch]$DryRun,
    [switch]$ExecuteActions,
    [switch]$FailOnFinding
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ApiBase([string]$u) {
    $t = $u.TrimEnd('/')
    if ($t -match '/api$') { return $t }
    return "$t/api"
}

function EnsureDir([string]$filePath) {
    $dir = Split-Path -Parent $filePath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

function GetProp($obj, [string]$name) {
    if ($null -eq $obj) { return $null }
    if ($obj -is [System.Collections.IDictionary]) {
        foreach ($k in $obj.Keys) { if ([string]$k -ieq $name) { return $obj[$k] } }
    }
    $p = $obj.PSObject.Properties | Where-Object { $_.Name -ieq $name } | Select-Object -First 1
    if ($null -eq $p) { return $null }
    return $p.Value
}

function AsUtc($v) {
    if ($null -eq $v) { return $null }
    $s = [string]$v
    if ([string]::IsNullOrWhiteSpace($s)) { return $null }
    try { return ([datetime]::Parse($s)).ToUniversalTime() } catch { return $null }
}

function ApiCall([string]$method, [string]$path, $body = $null) {
    $uri = "$script:base$path"
    $h = @{ Authorization = "Bearer $script:key" }
    if ($method -ne 'GET') { $h['X-Paperclip-Run-Id'] = $script:runId }
    if ($method -eq 'GET') { return Invoke-RestMethod -Method Get -Uri $uri -Headers $h }
    if ($DryRun -or -not $ExecuteActions) {
        return [ordered]@{
            dry_run = [bool]$DryRun
            monitor_only = -not [bool]$ExecuteActions
            method = $method
            path = $path
            body = $body
        }
    }
    $json = if ($null -eq $body) { $null } else { $body | ConvertTo-Json -Depth 12 }
    return Invoke-RestMethod -Method $method -Uri $uri -Headers $h -ContentType 'application/json' -Body $json
}

function SafeGet([string]$path) {
    try { return @(ApiCall -method 'GET' -path $path) } catch { return @() }
}

function InvokePsqlJson([string]$sql) {
    $cmd = @(
        '-X', '-A', '-t', '--no-psqlrc',
        '-d', $PostgresUrl,
        '-c', $sql
    )
    $raw = & $PsqlPath @cmd 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "psql failed: $raw"
    }
    $text = ($raw | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return @() }
    return @($text | ConvertFrom-Json)
}

function RoleAgentId([object[]]$agents, [string]$roleOrKey) {
    $m = @($agents | Where-Object {
        ([string](GetProp $_ 'role')).ToLowerInvariant() -eq $roleOrKey.ToLowerInvariant() -or
        ([string](GetProp $_ 'nameKey')).ToLowerInvariant() -eq $roleOrKey.ToLowerInvariant() -or
        ([string](GetProp $_ 'name')).ToLowerInvariant() -eq $roleOrKey.ToLowerInvariant()
    } | Select-Object -First 1)
    if ($m.Count -eq 0) { return $null }
    return [string](GetProp $m[0] 'id')
}

function NewIssue([string]$title, [string]$desc, [string]$assigneeId, [string]$priority = 'high') {
    $payload = @{ title = $title; description = $desc; status = 'todo'; priority = $priority }
    if (-not [string]::IsNullOrWhiteSpace($assigneeId)) { $payload.assigneeAgentId = $assigneeId }
    return ApiCall -method 'POST' -path "/companies/$CompanyId/issues" -body $payload
}

if ([string]::IsNullOrWhiteSpace($ApiKey) -and ($ExecuteActions -or $AllowApiFallback)) {
    throw 'PAPERCLIP_API_KEY (or -ApiKey) is required when -ExecuteActions or -AllowApiFallback is used.'
}
if ([string]::IsNullOrWhiteSpace($CompanyId)) { throw 'PAPERCLIP_COMPANY_ID (or -CompanyId) is required.' }
if ([string]::IsNullOrWhiteSpace($PostgresUrl) -and -not $AllowApiFallback) {
    throw 'PAPERCLIP_POSTGRES_URL (or -PostgresUrl) is required unless -AllowApiFallback is set.'
}

$script:base = ApiBase $PaperclipApiUrl
$script:key = $ApiKey
$script:runId = $RunId
$now = [datetime]::UtcNow

$dbLoaded = $false
if (-not [string]::IsNullOrWhiteSpace($PostgresUrl)) {
    try {
        $companyEsc = $CompanyId.Replace("'", "''")
        $agents = InvokePsqlJson @"
select coalesce(json_agg(t), '[]'::json)
from (
  select
    id,
    name,
    role,
    role as "nameKey",
    status,
    last_heartbeat_at as "lastHeartbeatAt",
    null::timestamptz as "errorAt",
    runtime_config as "runtimeConfig"
  from agents
  where company_id = '$companyEsc'
) t;
"@
        $issuesInProgress = InvokePsqlJson @"
select coalesce(json_agg(t), '[]'::json)
from (
  select id, identifier, title, assignee_agent_id as "assigneeAgentId", priority, status
  from issues
  where company_id = '$companyEsc' and status = 'in_progress'
) t;
"@
        $issuesBlocked = InvokePsqlJson @"
select coalesce(json_agg(t), '[]'::json)
from (
  select id, identifier, title, assignee_agent_id as "assigneeAgentId", priority, status
  from issues
  where company_id = '$companyEsc' and status = 'blocked'
) t;
"@
        $issueStatusSummary = InvokePsqlJson @"
select coalesce(json_agg(t), '[]'::json)
from (
  select status, priority, count(*)::int as count
  from issues
  where company_id = '$companyEsc'
  group by status, priority
  order by status, priority
) t;
"@
        $issuesDone = InvokePsqlJson @"
select coalesce(json_agg(t), '[]'::json)
from (
  select id, assignee_agent_id as "assigneeAgentId", completed_at as "completedAt"
  from issues
  where company_id = '$companyEsc' and status = 'done'
) t;
"@
        $activity = InvokePsqlJson @"
select coalesce(json_agg(t), '[]'::json)
from (
  select
    issue_id as "entityId",
    author_agent_id as "actorAgentId",
    'comment'::text as action,
    'issue'::text as "entityType",
    created_at as "createdAt",
    jsonb_build_object('body', body) as details
  from issue_comments
  where company_id = '$companyEsc'
    and created_at > now() - interval '60 minutes'
) t;
"@
        $runs = InvokePsqlJson @"
select coalesce(json_agg(t), '[]'::json)
from (
  select
    id,
    agent_id as "agentId",
    coalesce(context_snapshot->>'issueId', context_snapshot->'paperclipIssue'->>'id') as "issueId",
    status,
    started_at as "startedAt"
  from heartbeat_runs
  where company_id = '$companyEsc'
    and started_at > now() - interval '4 hours'
) t;
"@
        $companySummary = InvokePsqlJson @"
select json_build_object(
  'weekly_run_count', coalesce((select count(*) from heartbeat_runs r where r.company_id = '$companyEsc' and r.started_at > now() - interval '7 days'), 0),
  'provider_run_cap', coalesce((select max(amount)::numeric from budget_policies b where b.company_id = '$companyEsc' and b.is_active and b.metric in ('runs', 'run_count', 'heartbeat_runs')), 0)
);
"@
        $dbLoaded = $true
    } catch {
        if (-not $AllowApiFallback) { throw }
    }
}
if (-not $dbLoaded) {
    $agents = SafeGet "/companies/$CompanyId/agents"
    $issuesInProgress = SafeGet "/companies/$CompanyId/issues?status=in_progress&limit=500"
    $issuesBlocked = SafeGet "/companies/$CompanyId/issues?status=blocked&limit=500"
    $issueStatusSummary = @()
    $issuesDone = SafeGet "/companies/$CompanyId/issues?status=done&limit=500"
    $activity = SafeGet "/companies/$CompanyId/activity?limit=2000"
    $runs = SafeGet "/companies/$CompanyId/runs?limit=2000"
    $summary = @((SafeGet "/companies/$CompanyId/costs/summary"))
    $companySummary = if (@($summary).Count -gt 0) { @($summary)[0] } else { $null }
} else {
    $companySummary = if (@($companySummary).Count -gt 0) { @($companySummary)[0] } else { $null }
}

$ceoId = RoleAgentId -agents $agents -roleOrKey 'ceo'
$ctoId = RoleAgentId -agents $agents -roleOrKey 'cto'
$ownerId = if ($env:QM_OWNER_AGENT_ID) { $env:QM_OWNER_AGENT_ID } else { $ceoId }

$findings = New-Object System.Collections.Generic.List[object]
$actions = New-Object System.Collections.Generic.List[object]
$hotPollFindings = New-Object System.Collections.Generic.List[object]
$stuckFindings = New-Object System.Collections.Generic.List[object]
$longSilenceFindings = New-Object System.Collections.Generic.List[object]
$bottleneckFindings = New-Object System.Collections.Generic.List[object]
$tokenBudgetFindings = New-Object System.Collections.Generic.List[object]
$recursiveFindings = New-Object System.Collections.Generic.List[object]

foreach ($agent in $agents) {
    $agentId = [string](GetProp $agent 'id')
    if ([string]::IsNullOrWhiteSpace($agentId)) { continue }
    $agentName = [string](GetProp $agent 'name')

    $runsLastHour = @($runs | Where-Object {
        ([string](GetProp $_ 'agentId')) -eq $agentId -and
        ($t = AsUtc (GetProp $_ 'startedAt')) -and $t -gt $now.AddHours(-1)
    }).Count

    $doneLastHour = @($issuesDone | Where-Object {
        ([string](GetProp $_ 'assigneeAgentId')) -eq $agentId -and
        ($d = AsUtc (GetProp $_ 'completedAt')) -and $d -gt $now.AddHours(-1)
    }).Count

    if ($runsLastHour -gt $HotPollRunThreshold -and $doneLastHour -lt $HotPollDoneThreshold) {
        $entry = @{ detector='hot_poll'; agent_id=$agentId; agent_name=$agentName; runs_last_hour=$runsLastHour; issues_done_last_hour=$doneLastHour }
        $findings.Add($entry) | Out-Null
        $hotPollFindings.Add($entry) | Out-Null
        $actions.Add((ApiCall -method 'POST' -path "/agents/$agentId/pause" -body @{})) | Out-Null
        $actions.Add((NewIssue -title "Runtime fix: hot-poll loop ($agentName)" -desc "Detected hot-poll anomaly: runs_last_hour=$runsLastHour, issues_done_last_hour=$doneLastHour." -assigneeId $ctoId)) | Out-Null
    }

    $status = ([string](GetProp $agent 'status')).ToLowerInvariant()
    $lastHeartbeat = AsUtc (GetProp $agent 'lastHeartbeatAt')
    $errorAt = AsUtc (GetProp $agent 'errorAt')
    $runtimeConfig = GetProp $agent 'runtimeConfig'
    $heartbeatCfg = GetProp $runtimeConfig 'heartbeat'
    $wakeOnDemand = [bool](GetProp $heartbeatCfg 'wakeOnDemand')
    $heartbeatEnabled = [bool](GetProp $heartbeatCfg 'enabled')
    if ($status -in @('paused', 'terminated', 'retired', 'disabled')) { continue }

    $errorStuck = $false
    if ($status -eq 'error') {
        if ($errorAt -and $errorAt -lt $now.AddMinutes(-$StuckErrorMinutes)) { $errorStuck = $true }
        elseif ($lastHeartbeat -and $lastHeartbeat -lt $now.AddMinutes(-$StuckErrorMinutes)) { $errorStuck = $true }
    }
    $wakeStale = $wakeOnDemand -and $status -eq 'running' -and (($null -eq $lastHeartbeat) -or ($lastHeartbeat -lt $now.AddHours(-$StuckWakeOnDemandHeartbeatHours)))

    if ($errorStuck -or $wakeStale) {
        $entry = @{ detector='stuck_session'; agent_id=$agentId; agent_name=$agentName; status=$status }
        $findings.Add($entry) | Out-Null
        $stuckFindings.Add($entry) | Out-Null
        $actions.Add((NewIssue -title "Stuck session: terminate+rehire review ($agentName)" -desc "Detected stuck-session condition for agent $agentId." -assigneeId $ceoId)) | Out-Null
    }

    $heartbeatSilentLong = ($wakeOnDemand -or $heartbeatEnabled) -and (($null -eq $lastHeartbeat) -or ($lastHeartbeat -lt $now.AddHours(-$HeartbeatSilenceWatchdogHours)))
    if ($heartbeatSilentLong) {
        $lastHeartbeatIso = if ($null -eq $lastHeartbeat) { $null } else { $lastHeartbeat.ToString('o') }
        $entry = @{
            detector = 'heartbeat_silence_watchdog'
            agent_id = $agentId
            agent_name = $agentName
            status = $status
            last_heartbeat_at = $lastHeartbeatIso
            silence_hours_threshold = $HeartbeatSilenceWatchdogHours
        }
        $findings.Add($entry) | Out-Null
        $longSilenceFindings.Add($entry) | Out-Null
        $actions.Add((NewIssue -title "Heartbeat watchdog: >=$HeartbeatSilenceWatchdogHours h silence ($agentName)" -desc "Detected agent heartbeat silence >= $HeartbeatSilenceWatchdogHours hours for agent $agentId." -assigneeId $ceoId)) | Out-Null
    }
}

$p0Buckets = $issuesInProgress | Where-Object {
    $p = ([string](GetProp $_ 'priority')).ToLowerInvariant()
    $p -eq 'p0'
} | Group-Object { [string](GetProp $_ 'assigneeAgentId') }

foreach ($bucket in $p0Buckets) {
    $agentId = [string]$bucket.Name
    if ([string]::IsNullOrWhiteSpace($agentId)) { continue }
    $issueIds = @($bucket.Group | ForEach-Object { [string](GetProp $_ 'id') } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($issueIds.Count -lt $BottleneckMinP0InProgress) { continue }

    $runsLast4h = @($runs | Where-Object {
        ([string](GetProp $_ 'agentId')) -eq $agentId -and
        ($t = AsUtc (GetProp $_ 'startedAt')) -and $t -gt $now.AddHours(-4) -and
        @('succeeded','success','completed') -contains ([string](GetProp $_ 'status')).ToLowerInvariant() -and
        ($issueIds -contains [string](GetProp $_ 'issueId'))
    }).Count

    if ($runsLast4h -lt $BottleneckMinRunsLast4h) {
        $entry = @{ detector='bottleneck'; agent_id=$agentId; p0_in_progress=$issueIds.Count; runs_last_4h=$runsLast4h }
        $findings.Add($entry) | Out-Null
        $bottleneckFindings.Add($entry) | Out-Null
        foreach ($issueId in $issueIds) {
            $actions.Add((ApiCall -method 'POST' -path "/issues/$issueId/comments" -body @{ body = "RuntimeHealthScan bottleneck: runs_last_4h=$runsLast4h, p0_in_progress=$($issueIds.Count)." })) | Out-Null
        }
        $actions.Add((ApiCall -method 'POST' -path "/agents/$agentId/heartbeat/invoke" -body @{})) | Out-Null
    }
}

if ($null -ne $companySummary) {
    $weeklyRunCount = [double](GetProp $companySummary 'weekly_run_count')
    if ($weeklyRunCount -le 0) { $weeklyRunCount = [double](GetProp $companySummary 'weeklyRunCount') }
    $providerCap = [double](GetProp $companySummary 'provider_run_cap')
    if ($providerCap -le 0) { $providerCap = [double](GetProp $companySummary 'providerRunCapWeekly') }
    if ($providerCap -gt 0) {
        $projectedMonthlyRuns = $weeklyRunCount * 4
        $thresholdRuns = $providerCap * $TokenBudgetThreshold
        if ($projectedMonthlyRuns -gt $thresholdRuns) {
            $entry = @{ detector='token_budget'; weekly_run_count=$weeklyRunCount; projected_monthly_runs=$projectedMonthlyRuns; provider_run_cap=$providerCap; threshold_runs=$thresholdRuns }
            $findings.Add($entry) | Out-Null
            $tokenBudgetFindings.Add($entry) | Out-Null
            foreach ($agent in $agents) {
                $agentId = [string](GetProp $agent 'id')
                if ([string]::IsNullOrWhiteSpace($agentId)) { continue }
                $runtimeConfig = GetProp $agent 'runtimeConfig'
                $heartbeatCfg = GetProp $runtimeConfig 'heartbeat'
                if ($null -eq $heartbeatCfg) { continue }
                if ((GetProp $heartbeatCfg 'enabled') -eq $false) { continue }
                $intervalMin = GetProp $heartbeatCfg 'intervalMin'
                if ($null -eq $intervalMin) { continue }
                $old = [int]$intervalMin
                $new = $old
                if ($old -le 10) { $new = 30 } elseif ($old -le 30) { $new = 60 }
                if ($new -eq $old) { continue }
                $newRuntime = $runtimeConfig | ConvertTo-Json -Depth 12 | ConvertFrom-Json
                (GetProp $newRuntime 'heartbeat').intervalMin = $new
                $actions.Add((ApiCall -method 'PATCH' -path "/agents/$agentId" -body @{ runtimeConfig = $newRuntime })) | Out-Null
            }
            $actions.Add((NewIssue -title 'OWNER notice: token budget pressure' -desc 'RuntimeHealthScan throttled timer heartbeats due to budget pressure.' -assigneeId $ownerId)) | Out-Null
        }
    }
}

$commentCounts = @{}
foreach ($entry in $activity) {
    $action = ([string](GetProp $entry 'action')).ToLowerInvariant()
    $entityType = ([string](GetProp $entry 'entityType')).ToLowerInvariant()
    if ($entityType -ne 'issue' -or $action -notmatch 'comment') { continue }
    $created = AsUtc (GetProp $entry 'createdAt')
    if ($null -eq $created -or $created -lt $now.AddMinutes(-60)) { continue }
    $issueId = [string](GetProp $entry 'entityId')
    $actor = [string](GetProp $entry 'actorAgentId')
    $body = [string](GetProp (GetProp $entry 'details') 'body')
    if ([string]::IsNullOrWhiteSpace($issueId) -or [string]::IsNullOrWhiteSpace($actor) -or [string]::IsNullOrWhiteSpace($body)) { continue }
    $key = "$issueId|$actor|$body"
    if (-not $commentCounts.ContainsKey($key)) { $commentCounts[$key] = 0 }
    $commentCounts[$key] = [int]$commentCounts[$key] + 1
}

foreach ($k in $commentCounts.Keys) {
    $count = [int]$commentCounts[$k]
    if ($count -lt $RecursiveWakeMinIdenticalComments) { continue }
    $parts = $k -split '\|', 3
    $issueId = $parts[0]
    $agentId = $parts[1]
    $body = $parts[2]
    $entry = @{ detector='recursive_wake'; issue_id=$issueId; agent_id=$agentId; identical_comments_60m=$count }
    $findings.Add($entry) | Out-Null
    $recursiveFindings.Add($entry) | Out-Null
    $actions.Add((ApiCall -method 'POST' -path "/agents/$agentId/pause" -body @{})) | Out-Null
    $hash = [System.BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($body))).Replace('-','')
    $sample = if ($hash.Length -ge 16) { $hash.Substring(0,16) } else { $hash }
    $actions.Add((NewIssue -title "Recursive wake loop fix required ($agentId)" -desc "Detected $count byte-identical comments on issue $issueId (sample hash $sample)." -assigneeId $ctoId)) | Out-Null
}

$overallStatus = 'ok'
if ($findings.Count -gt 0) { $overallStatus = 'alert' }

$agentRuntimeRows = @()
foreach ($agent in $agents) {
    $agentId = [string](GetProp $agent 'id')
    if ([string]::IsNullOrWhiteSpace($agentId)) { continue }

    $runsLastHour = @($runs | Where-Object {
        ([string](GetProp $_ 'agentId')) -eq $agentId -and
        ($t = AsUtc (GetProp $_ 'startedAt')) -and $t -gt $now.AddHours(-1)
    }).Count
    $runsLast4h = @($runs | Where-Object {
        ([string](GetProp $_ 'agentId')) -eq $agentId -and
        ($t = AsUtc (GetProp $_ 'startedAt')) -and $t -gt $now.AddHours(-4)
    }).Count
    $doneLastHour = @($issuesDone | Where-Object {
        ([string](GetProp $_ 'assigneeAgentId')) -eq $agentId -and
        ($d = AsUtc (GetProp $_ 'completedAt')) -and $d -gt $now.AddHours(-1)
    }).Count
    $assignedInProgress = @($issuesInProgress | Where-Object { ([string](GetProp $_ 'assigneeAgentId')) -eq $agentId }).Count
    $assignedBlocked = @($issuesBlocked | Where-Object { ([string](GetProp $_ 'assigneeAgentId')) -eq $agentId }).Count
    $agentFindings = @($findings | Where-Object { ([string](GetProp $_ 'agent_id')) -eq $agentId } | ForEach-Object { [string](GetProp $_ 'detector') })
    $runtimeConfig = GetProp $agent 'runtimeConfig'
    $heartbeatCfg = GetProp $runtimeConfig 'heartbeat'

    $agentRuntimeRows += [ordered]@{
        id = $agentId
        name = [string](GetProp $agent 'name')
        role = [string](GetProp $agent 'role')
        name_key = [string](GetProp $agent 'nameKey')
        status = [string](GetProp $agent 'status')
        last_heartbeat_at = [string](GetProp $agent 'lastHeartbeatAt')
        error_at = [string](GetProp $agent 'errorAt')
        heartbeat_enabled = GetProp $heartbeatCfg 'enabled'
        wake_on_demand = GetProp $heartbeatCfg 'wakeOnDemand'
        interval_min = GetProp $heartbeatCfg 'intervalMin'
        runs_last_hour = $runsLastHour
        runs_last_4h = $runsLast4h
        issues_done_last_hour = $doneLastHour
        in_progress_assigned = $assignedInProgress
        blocked_assigned = $assignedBlocked
        active_findings = @($agentFindings)
    }
}

$statusCounts = @{}
foreach ($row in $issueStatusSummary) {
    $status = [string](GetProp $row 'status')
    if ([string]::IsNullOrWhiteSpace($status)) { continue }
    if (-not $statusCounts.ContainsKey($status)) { $statusCounts[$status] = 0 }
    $statusCounts[$status] = [int]$statusCounts[$status] + [int](GetProp $row 'count')
}
if (@($issueStatusSummary).Count -eq 0) {
    $statusCounts['in_progress'] = @($issuesInProgress).Count
    $statusCounts['blocked'] = @($issuesBlocked).Count
    $statusCounts['done_loaded'] = @($issuesDone).Count
}

$activeAgents = @($agentRuntimeRows | Where-Object { ([string](GetProp $_ 'status')).ToLowerInvariant() -notin @('paused','terminated','retired','disabled') }).Count
$pausedAgents = @($agentRuntimeRows | Where-Object { ([string](GetProp $_ 'status')).ToLowerInvariant() -in @('paused','terminated','retired','disabled') }).Count
$weeklyRunCount = 0.0
$providerCap = 0.0
if ($null -ne $companySummary) {
    $weeklyRunCount = [double](GetProp $companySummary 'weekly_run_count')
    if ($weeklyRunCount -le 0) { $weeklyRunCount = [double](GetProp $companySummary 'weeklyRunCount') }
    $providerCap = [double](GetProp $companySummary 'provider_run_cap')
    if ($providerCap -le 0) { $providerCap = [double](GetProp $companySummary 'providerRunCapWeekly') }
}

$runtimeState = [ordered]@{
    schema = 'quantmechanica.company-runtime.v1'
    generated_at_utc = $now.ToString('o')
    company_id = $CompanyId
    data_source = if ($dbLoaded) { 'postgres' } else { 'api_fallback' }
    overall_status = $overallStatus
    autonomy_mode = if ($ExecuteActions -and -not $DryRun) { 'execution_enabled' } elseif ($DryRun) { 'monitor_only_dry_run' } else { 'monitor_only' }
    agents = [ordered]@{
        total = @($agentRuntimeRows).Count
        active = $activeAgents
        paused = $pausedAgents
        rows = @($agentRuntimeRows)
    }
    issues = [ordered]@{
        status_counts = $statusCounts
        in_progress_loaded = @($issuesInProgress).Count
        blocked_loaded = @($issuesBlocked).Count
    }
    runtime_health = [ordered]@{
        findings_count = $findings.Count
        actions_count = $actions.Count
        detectors = [ordered]@{
            hot_poll = $hotPollFindings.Count
            stuck_session = $stuckFindings.Count
            heartbeat_silence_watchdog = $longSilenceFindings.Count
            bottleneck = $bottleneckFindings.Count
            token_budget = $tokenBudgetFindings.Count
            recursive_wake = $recursiveFindings.Count
        }
    }
    budget = [ordered]@{
        weekly_run_count = $weeklyRunCount
        projected_monthly_runs = $weeklyRunCount * 4
        provider_run_cap = $providerCap
        threshold_ratio = $TokenBudgetThreshold
    }
    blockers = @($issuesBlocked | Select-Object -First 20 | ForEach-Object {
        [ordered]@{
            id = [string](GetProp $_ 'id')
            identifier = [string](GetProp $_ 'identifier')
            title = [string](GetProp $_ 'title')
            assignee_agent_id = [string](GetProp $_ 'assigneeAgentId')
            priority = [string](GetProp $_ 'priority')
        }
    })
}

$result = @{
    check = 'runtime_health_scan'
    generated_at_utc = $now.ToString('o')
    overall_status = $overallStatus
    dry_run = [bool]$DryRun
    findings_count = $findings.Count
    actions_count = $actions.Count
    detectors = @{
        hot_poll = $hotPollFindings.ToArray()
        stuck_session = $stuckFindings.ToArray()
        heartbeat_silence_watchdog = $longSilenceFindings.ToArray()
        bottleneck = $bottleneckFindings.ToArray()
        token_budget = $tokenBudgetFindings.ToArray()
        recursive_wake = $recursiveFindings.ToArray()
    }
    actions = $actions.ToArray()
}

EnsureDir $OutputPath
$result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
if (-not [string]::IsNullOrWhiteSpace($RuntimeStateOutputPath)) {
    EnsureDir $RuntimeStateOutputPath
    $runtimeState | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $RuntimeStateOutputPath -Encoding UTF8
}
Write-Output ($result | ConvertTo-Json -Depth 12)

if ($findings.Count -gt 0) {
    if ($FailOnFinding) { exit 2 }
    exit 1
}
exit 0
