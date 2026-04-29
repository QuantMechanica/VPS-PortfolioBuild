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
    [int]$RecursiveWakeMinIdenticalComments = 10,
    [switch]$DryRun,
    [switch]$FailOnFinding
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Normalize-ApiBase {
    param([string]$Url)
    $trimmed = $Url.TrimEnd('/')
    if ($trimmed -match '/api$') { return $trimmed }
    return "$trimmed/api"
}

function Ensure-DirForFile {
    param([string]$Path)
    $dir = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

function Get-Prop {
    param([object]$Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    if ($Object -is [System.Collections.IDictionary]) {
        foreach ($k in $Object.Keys) {
            if ([string]$k -ieq $Name) { return $Object[$k] }
        }
    }
    $prop = $Object.PSObject.Properties | Where-Object { $_.Name -ieq $Name } | Select-Object -First 1
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

function To-UtcDate {
    param([object]$Value)
    if ($null -eq $Value) { return $null }
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    try { return ([datetime]::Parse($text)).ToUniversalTime() } catch { return $null }
}

function Invoke-Api {
    param(
        [ValidateSet('GET','POST','PATCH')] [string]$Method,
        [string]$Path,
        [object]$Body = $null
    )
    $uri = "$script:ApiBase$Path"
    $headers = @{ Authorization = "Bearer $script:ApiKey" }
    if ($Method -ne 'GET') {
        $headers['X-Paperclip-Run-Id'] = $script:RunId
    }
    if ($Method -eq 'GET') {
        return Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
    }
    if ($DryRun.IsPresent) {
        return [ordered]@{ dry_run = $true; method = $Method; path = $Path; body = $Body }
    }
    $json = if ($null -eq $Body) { $null } else { $Body | ConvertTo-Json -Depth 12 }
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -ContentType 'application/json' -Body $json
}

function Safe-Get {
    param([string]$Path, [object]$Default)
    try {
        return Invoke-Api -Method GET -Path $Path
    }
    catch {
        return $Default
    }
}

function Resolve-OwnerId {
    param(
        [object[]]$Agents,
        [string]$Role,
        [string]$NameFallback
    )
    $byRole = @($Agents | Where-Object { ([string](Get-Prop $_ 'role')).ToLowerInvariant() -eq $Role.ToLowerInvariant() })
    if ($byRole.Count -gt 0) { return [string](Get-Prop $byRole[0] 'id') }
    if (-not [string]::IsNullOrWhiteSpace($NameFallback)) {
        $byName = @($Agents | Where-Object { ([string](Get-Prop $_ 'name')) -eq $NameFallback })
        if ($byName.Count -gt 0) { return [string](Get-Prop $byName[0] 'id') }
    }
    return $null
}

function New-FollowupIssue {
    param(
        [string]$Title,
        [string]$Description,
        [string]$AssigneeAgentId,
        [string]$Priority = 'high'
    )
    if ([string]::IsNullOrWhiteSpace($CompanyId)) { return $null }
    $payload = @{
        title = $Title
        description = $Description
        status = 'todo'
        priority = $Priority
    }
    if (-not [string]::IsNullOrWhiteSpace($AssigneeAgentId)) {
        $payload.assigneeAgentId = $AssigneeAgentId
    }
    return Invoke-Api -Method POST -Path "/companies/$CompanyId/issues" -Body $payload
}

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    throw 'PAPERCLIP_API_KEY (or -ApiKey) is required.'
}
if ([string]::IsNullOrWhiteSpace($CompanyId)) {
    throw 'PAPERCLIP_COMPANY_ID (or -CompanyId) is required.'
}

$script:ApiBase = Normalize-ApiBase -Url $PaperclipApiUrl
$script:ApiKey = $ApiKey
$script:RunId = $RunId
$now = [datetime]::UtcNow

$agentsRaw = Safe-Get -Path "/companies/$CompanyId/agents" -Default @()
$agents = @($agentsRaw)
$issuesInProgressRaw = Safe-Get -Path "/companies/$CompanyId/issues?status=in_progress&limit=500" -Default @()
$issuesDoneRaw = Safe-Get -Path "/companies/$CompanyId/issues?status=done&limit=500" -Default @()
$activityRaw = Safe-Get -Path "/companies/$CompanyId/activity?limit=2000" -Default @()
$activity = @($activityRaw)
$runsRaw = Safe-Get -Path "/companies/$CompanyId/runs?limit=2000" -Default @()
$runs = @($runsRaw)

$ceoId = Resolve-OwnerId -Agents $agents -Role 'ceo' -NameFallback 'CEO'
$ctoId = Resolve-OwnerId -Agents $agents -Role 'cto' -NameFallback 'CTO'
$ownerId = if ($env:QM_OWNER_AGENT_ID) { $env:QM_OWNER_AGENT_ID } else { $ceoId }

$actions = New-Object System.Collections.Generic.List[object]
$findings = New-Object System.Collections.Generic.List[object]

# Detector 1: hot-poll
foreach ($agent in $agents) {
    $agentId = [string](Get-Prop $agent 'id')
    $agentName = [string](Get-Prop $agent 'name')

    $runsLastHour = 0
    if ($runs.Count -gt 0) {
        $runsLastHour = @($runs | Where-Object {
            ([string](Get-Prop $_ 'agentId')) -eq $agentId -and
            (To-UtcDate (Get-Prop $_ 'startedAt')) -gt $now.AddHours(-1)
        }).Count
    }
    else {
        $runsLastHour = @($activity | Where-Object {
            ([string](Get-Prop $_ 'actorAgentId')) -eq $agentId -and
            ([string](Get-Prop $_ 'entityType')).ToLowerInvariant() -eq 'run' -and
            (To-UtcDate (Get-Prop $_ 'createdAt')) -gt $now.AddHours(-1)
        }).Count
    }

    $doneLastHour = @($issuesDoneRaw | Where-Object {
        ([string](Get-Prop $_ 'assigneeAgentId')) -eq $agentId -and
        (To-UtcDate (Get-Prop $_ 'completedAt')) -gt $now.AddHours(-1)
    }).Count

    if ($runsLastHour -gt $HotPollRunThreshold -and $doneLastHour -lt $HotPollDoneThreshold) {
        $findings.Add(@{ detector = 'hot_poll'; agent_id = $agentId; agent_name = $agentName; runs_last_hour = $runsLastHour; issues_done_last_hour = $doneLastHour }) | Out-Null
        $actions.Add((Invoke-Api -Method POST -Path "/agents/$agentId/pause" -Body @{})) | Out-Null
        $actions.Add((New-FollowupIssue -Title "Runtime fix: hot-poll loop ($agentName)" -Description "Detected hot-poll anomaly: runs_last_hour=$runsLastHour, issues_done_last_hour=$doneLastHour. Required: dedup/filter fix and wake discipline." -AssigneeAgentId $ctoId -Priority 'high')) | Out-Null
    }
}

# Detector 2: stuck-session
foreach ($agent in $agents) {
    $agentId = [string](Get-Prop $agent 'id')
    $agentName = [string](Get-Prop $agent 'name')
    $status = ([string](Get-Prop $agent 'status')).ToLowerInvariant()
    $lastHeartbeat = To-UtcDate (Get-Prop $agent 'lastHeartbeatAt')
    $errorSince = To-UtcDate (Get-Prop $agent 'errorAt')
    $runtimeConfig = Get-Prop $agent 'runtimeConfig'
    $heartbeatCfg = Get-Prop $runtimeConfig 'heartbeat'
    $wakeOnDemand = [bool](Get-Prop $heartbeatCfg 'wakeOnDemand')

    $isErrorStuck = $false
    if ($status -eq 'error') {
        if ($null -ne $errorSince -and $errorSince -lt $now.AddMinutes(-$StuckErrorMinutes)) { $isErrorStuck = $true }
        elseif ($null -ne $lastHeartbeat -and $lastHeartbeat -lt $now.AddMinutes(-$StuckErrorMinutes)) { $isErrorStuck = $true }
    }

    $isWakeOnDemandStale = $false
    if ($wakeOnDemand -and ($null -eq $lastHeartbeat -or $lastHeartbeat -lt $now.AddHours(-$StuckWakeOnDemandHeartbeatHours))) {
        $isWakeOnDemandStale = $true
    }

    if ($isErrorStuck -or $isWakeOnDemandStale) {
        $findings.Add(@{ detector = 'stuck_session'; agent_id = $agentId; agent_name = $agentName; status = $status; wake_on_demand = $wakeOnDemand; last_heartbeat_at = $lastHeartbeat }) | Out-Null
        $actions.Add((New-FollowupIssue -Title "Stuck session: terminate+rehire review ($agentName)" -Description "Detected stuck-session condition (error>30m or stale heartbeat with wakeOnDemand). Recommendation: terminate + re-hire from BASIS prompt." -AssigneeAgentId $ceoId -Priority 'high')) | Out-Null
    }
}

# Detector 3: bottleneck
$p0InProgressByAssignee = $issuesInProgressRaw | Where-Object { ([string](Get-Prop $_ 'priority')).ToLowerInvariant() -in @('high','p0') } | Group-Object { [string](Get-Prop $_ 'assigneeAgentId') }
foreach ($bucket in $p0InProgressByAssignee) {
    $agentId = [string]$bucket.Name
    if ([string]::IsNullOrWhiteSpace($agentId)) { continue }
    $issueIds = @($bucket.Group | ForEach-Object { [string](Get-Prop $_ 'id') })
    if ($issueIds.Count -lt $BottleneckMinP0InProgress) { continue }

    $runsLast4h = 0
    if ($runs.Count -gt 0) {
        $runsLast4h = @($runs | Where-Object {
            ([string](Get-Prop $_ 'agentId')) -eq $agentId -and
            (To-UtcDate (Get-Prop $_ 'startedAt')) -gt $now.AddHours(-4) -and
            ($issueIds -contains [string](Get-Prop $_ 'issueId'))
        }).Count
    }
    if ($runsLast4h -eq 0) {
        $runsLast4h = @($activity | Where-Object {
            ([string](Get-Prop $_ 'actorAgentId')) -eq $agentId -and
            (To-UtcDate (Get-Prop $_ 'createdAt')) -gt $now.AddHours(-4) -and
            ($issueIds -contains [string](Get-Prop $_ 'entityId'))
        }).Count
    }

    if ($runsLast4h -lt $BottleneckMinRunsLast4h) {
        $findings.Add(@{ detector = 'bottleneck'; agent_id = $agentId; p0_in_progress = $issueIds.Count; runs_last_4h = $runsLast4h; issue_ids = $issueIds }) | Out-Null
        foreach ($issueId in $issueIds) {
            $commentPayload = @{ body = "RuntimeHealthScan: P0 bottleneck detected (runs_last_4h=$runsLast4h, p0_in_progress=$($issueIds.Count)). Immediate unblock update required in this heartbeat." }
            $actions.Add((Invoke-Api -Method POST -Path "/issues/$issueId/comments" -Body $commentPayload)) | Out-Null
        }
        $actions.Add((Invoke-Api -Method POST -Path "/agents/$agentId/heartbeat/invoke" -Body @{})) | Out-Null
    }
}

# Detector 4: token-budget pressure
$companySummary = Safe-Get -Path "/companies/$CompanyId/costs/summary" -Default $null
if ($null -ne $companySummary) {
    $spentMonthlyCents = [double](Get-Prop $companySummary 'spentMonthlyCents')
    $budgetMonthlyCents = [double](Get-Prop $companySummary 'budgetMonthlyCents')
    if ($budgetMonthlyCents -gt 0 -and $spentMonthlyCents -ge ($budgetMonthlyCents * 0.9)) {
        $findings.Add(@{ detector = 'token_budget'; spent_monthly_cents = $spentMonthlyCents; budget_monthly_cents = $budgetMonthlyCents; utilization = [math]::Round($spentMonthlyCents / $budgetMonthlyCents, 4) }) | Out-Null

        foreach ($agent in $agents) {
            $agentId = [string](Get-Prop $agent 'id')
            $runtimeConfig = Get-Prop $agent 'runtimeConfig'
            if ($null -eq $runtimeConfig) { continue }
            $heartbeatCfg = Get-Prop $runtimeConfig 'heartbeat'
            if ($null -eq $heartbeatCfg) { continue }

            $enabled = Get-Prop $heartbeatCfg 'enabled'
            if ($enabled -eq $false) { continue }

            $intervalMin = Get-Prop $heartbeatCfg 'intervalMin'
            if ($null -eq $intervalMin) { continue }
            $newInterval = [int]$intervalMin
            if ([int]$intervalMin -le 10) { $newInterval = 30 }
            elseif ([int]$intervalMin -le 30) { $newInterval = 60 }
            if ($newInterval -eq [int]$intervalMin) { continue }

            $newRuntime = $runtimeConfig | ConvertTo-Json -Depth 12 | ConvertFrom-Json
            $newHeartbeat = Get-Prop $newRuntime 'heartbeat'
            $newHeartbeat.intervalMin = $newInterval
            $actions.Add((Invoke-Api -Method PATCH -Path "/agents/$agentId" -Body @{ runtimeConfig = $newRuntime })) | Out-Null
        }

        $actions.Add((New-FollowupIssue -Title "OWNER notice: token budget pressure" -Description "RuntimeHealthScan throttled timer heartbeats due to >=90% monthly budget utilization. OWNER review required." -AssigneeAgentId $ownerId -Priority 'high')) | Out-Null
    }
}

# Detector 5: recursive wake
$commentsByIssue = @{}
foreach ($entry in $activity) {
    $action = ([string](Get-Prop $entry 'action')).ToLowerInvariant()
    $entityType = ([string](Get-Prop $entry 'entityType')).ToLowerInvariant()
    if ($entityType -ne 'issue' -or $action -notmatch 'comment') { continue }
    $createdAt = To-UtcDate (Get-Prop $entry 'createdAt')
    if ($null -eq $createdAt -or $createdAt -lt $now.AddMinutes(-60)) { continue }

    $issueId = [string](Get-Prop $entry 'entityId')
    $actorAgentId = [string](Get-Prop $entry 'actorAgentId')
    $details = Get-Prop $entry 'details'
    $body = [string](Get-Prop $details 'body')
    if ([string]::IsNullOrWhiteSpace($issueId) -or [string]::IsNullOrWhiteSpace($actorAgentId) -or [string]::IsNullOrWhiteSpace($body)) { continue }

    $key = "$issueId|$actorAgentId|$body"
    if (-not $commentsByIssue.ContainsKey($key)) { $commentsByIssue[$key] = 0 }
    $commentsByIssue[$key] += 1
}

foreach ($k in $commentsByIssue.Keys) {
    $count = [int]$commentsByIssue[$k]
    if ($count -lt $RecursiveWakeMinIdenticalComments) { continue }

    $parts = $k.Split('|', 3)
    $issueId = $parts[0]
    $agentId = $parts[1]
    $body = $parts[2]

    $findings.Add(@{ detector = 'recursive_wake'; issue_id = $issueId; agent_id = $agentId; identical_comments_60m = $count }) | Out-Null
    $actions.Add((Invoke-Api -Method POST -Path "/agents/$agentId/pause" -Body @{})) | Out-Null
    $actions.Add((New-FollowupIssue -Title "Recursive wake loop fix required ($agentId)" -Description "Detected $count byte-identical comments within 60m on issue $issueId. Sample body hash: $([System.BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($body))).Replace('-','').Substring(0,16)))." -AssigneeAgentId $ctoId -Priority 'high')) | Out-Null
}

$overall = if ($findings.Count -gt 0) { 'alert' } else { 'ok' }
$result = [ordered]@{
    check = 'runtime_health_scan'
    generated_at_utc = $now.ToString('o')
    overall_status = $overall
    dry_run = [bool]$DryRun
    detectors = @{
        hot_poll = @($findings | Where-Object { $_.detector -eq 'hot_poll' })
        stuck_session = @($findings | Where-Object { $_.detector -eq 'stuck_session' })
        bottleneck = @($findings | Where-Object { $_.detector -eq 'bottleneck' })
        token_budget = @($findings | Where-Object { $_.detector -eq 'token_budget' })
        recursive_wake = @($findings | Where-Object { $_.detector -eq 'recursive_wake' })
    }
    findings_count = $findings.Count
    actions_count = $actions.Count
    actions = @($actions)
}

Ensure-DirForFile -Path $OutputPath
$result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Output ($result | ConvertTo-Json -Depth 12)

if ($findings.Count -gt 0) {
    if ($FailOnFinding.IsPresent) { exit 2 }
    exit 1
}
exit 0
