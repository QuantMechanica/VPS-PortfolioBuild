[CmdletBinding()]
param(
    [string]$PaperclipApiUrl = $(if ($env:PAPERCLIP_API_URL) { $env:PAPERCLIP_API_URL } else { "http://127.0.0.1:3100" }),
    [string]$ApiKey = $(if ($env:PAPERCLIP_API_KEY) { $env:PAPERCLIP_API_KEY } else { "" }),
    [string]$CompanyId = $(if ($env:PAPERCLIP_COMPANY_ID) { $env:PAPERCLIP_COMPANY_ID } else { "" }),
    [string]$RunId = $(if ($env:PAPERCLIP_RUN_ID) { $env:PAPERCLIP_RUN_ID } else { "runtime-health-scan-manual" }),
    [string]$OutputPath = "C:\QM\logs\infra\health\runtime_health_scan_latest.json",
    [int]$HotPollRunThreshold = 50,
    [int]$HotPollDoneThreshold = 5,
    [int]$StuckErrorMinutes = 30,
    [int]$StuckWakeOnDemandHeartbeatHours = 2,
    [int]$BottleneckMinP0InProgress = 2,
    [int]$BottleneckMinRunsLast4h = 5,
    [double]$TokenBudgetThreshold = 0.9,
    [int]$RecursiveWakeMinIdenticalComments = 10,
    [switch]$DryRun,
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
    if ($DryRun) { return [ordered]@{ dry_run = $true; method = $method; path = $path; body = $body } }
    $json = if ($null -eq $body) { $null } else { $body | ConvertTo-Json -Depth 12 }
    return Invoke-RestMethod -Method $method -Uri $uri -Headers $h -ContentType 'application/json' -Body $json
}

function SafeGet([string]$path) {
    try { return @(ApiCall -method 'GET' -path $path) } catch { return @() }
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

if ([string]::IsNullOrWhiteSpace($ApiKey)) { throw 'PAPERCLIP_API_KEY (or -ApiKey) is required.' }
if ([string]::IsNullOrWhiteSpace($CompanyId)) { throw 'PAPERCLIP_COMPANY_ID (or -CompanyId) is required.' }

$script:base = ApiBase $PaperclipApiUrl
$script:key = $ApiKey
$script:runId = $RunId
$now = [datetime]::UtcNow

$agents = SafeGet "/companies/$CompanyId/agents"
$issuesInProgress = SafeGet "/companies/$CompanyId/issues?status=in_progress&limit=500"
$issuesDone = SafeGet "/companies/$CompanyId/issues?status=done&limit=500"
$activity = SafeGet "/companies/$CompanyId/activity?limit=2000"
$runs = SafeGet "/companies/$CompanyId/runs?limit=2000"
$summary = @((SafeGet "/companies/$CompanyId/costs/summary"))
$companySummary = if ($summary.Count -gt 0) { $summary[0] } else { $null }

$ceoId = RoleAgentId -agents $agents -roleOrKey 'ceo'
$ctoId = RoleAgentId -agents $agents -roleOrKey 'cto'
$ownerId = if ($env:QM_OWNER_AGENT_ID) { $env:QM_OWNER_AGENT_ID } else { $ceoId }

$findings = New-Object System.Collections.Generic.List[object]
$actions = New-Object System.Collections.Generic.List[object]
$hotPollFindings = New-Object System.Collections.Generic.List[object]
$stuckFindings = New-Object System.Collections.Generic.List[object]
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

    $errorStuck = $false
    if ($status -eq 'error') {
        if ($errorAt -and $errorAt -lt $now.AddMinutes(-$StuckErrorMinutes)) { $errorStuck = $true }
        elseif ($lastHeartbeat -and $lastHeartbeat -lt $now.AddMinutes(-$StuckErrorMinutes)) { $errorStuck = $true }
    }
    $wakeStale = $wakeOnDemand -and (($null -eq $lastHeartbeat) -or ($lastHeartbeat -lt $now.AddHours(-$StuckWakeOnDemandHeartbeatHours)))

    if ($errorStuck -or $wakeStale) {
        $entry = @{ detector='stuck_session'; agent_id=$agentId; agent_name=$agentName; status=$status }
        $findings.Add($entry) | Out-Null
        $stuckFindings.Add($entry) | Out-Null
        $actions.Add((NewIssue -title "Stuck session: terminate+rehire review ($agentName)" -desc "Detected stuck-session condition for agent $agentId." -assigneeId $ceoId)) | Out-Null
    }
}

$p0Buckets = $issuesInProgress | Where-Object {
    $p = ([string](GetProp $_ 'priority')).ToLowerInvariant()
    $p -eq 'high' -or $p -eq 'p0'
} | Group-Object { [string](GetProp $_ 'assigneeAgentId') }

foreach ($bucket in $p0Buckets) {
    $agentId = [string]$bucket.Name
    if ([string]::IsNullOrWhiteSpace($agentId)) { continue }
    $issueIds = @($bucket.Group | ForEach-Object { [string](GetProp $_ 'id') } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($issueIds.Count -lt $BottleneckMinP0InProgress) { continue }

    $runsLast4h = @($runs | Where-Object {
        ([string](GetProp $_ 'agentId')) -eq $agentId -and
        ($t = AsUtc (GetProp $_ 'startedAt')) -and $t -gt $now.AddHours(-4) -and
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
    $spent = [double](GetProp $companySummary 'spentMonthlyCents')
    $budget = [double](GetProp $companySummary 'budgetMonthlyCents')
    if ($budget -gt 0) {
        $util = $spent / $budget
        if ($util -ge $TokenBudgetThreshold) {
            $entry = @{ detector='token_budget'; utilization=[math]::Round($util,4); spent_monthly_cents=$spent; budget_monthly_cents=$budget }
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
        bottleneck = $bottleneckFindings.ToArray()
        token_budget = $tokenBudgetFindings.ToArray()
        recursive_wake = $recursiveFindings.ToArray()
    }
    actions = $actions.ToArray()
}

EnsureDir $OutputPath
$result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Output ($result | ConvertTo-Json -Depth 12)

if ($findings.Count -gt 0) {
    if ($FailOnFinding) { exit 2 }
    exit 1
}
exit 0
