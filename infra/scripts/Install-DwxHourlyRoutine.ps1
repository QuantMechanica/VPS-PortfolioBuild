[CmdletBinding()]
param(
    [string]$ApiBaseUrl = $(if ($env:PAPERCLIP_API_URL) { $env:PAPERCLIP_API_URL } else { 'http://127.0.0.1:3100/api' }),
    [string]$ApiKey = $(if ($env:PAPERCLIP_API_KEY) { $env:PAPERCLIP_API_KEY } else { '' }),
    [string]$CompanyId = $(if ($env:PAPERCLIP_COMPANY_ID) { $env:PAPERCLIP_COMPANY_ID } else { '03d4dcc8-4cea-4133-9f68-90c0d99628fb' }),
    [string]$AssigneeAgentId = $(if ($env:PAPERCLIP_AGENT_ID) { $env:PAPERCLIP_AGENT_ID } else { '0e8f04e5-4019-45b0-951f-ca248cf82849' }),
    [string]$ProjectId = '',
    [string]$GoalId = '',
    [string]$ParentIssueId = '',
    [string]$RoutineTitle = 'DWX import hourly check',
    [string]$RoutineDescription = 'Hourly DWX import readiness/staging/verifier runner. Executes infra/scripts/Invoke-DwxHourlyCheck.ps1 on a Paperclip routine schedule and keeps overlap-safe behavior inside the runner lock.',
    [ValidateSet('critical', 'high', 'medium', 'low')] [string]$Priority = 'medium',
    [ValidateSet('active', 'paused', 'archived')] [string]$RoutineStatus = 'active',
    [ValidateSet('coalesce_if_active', 'skip_if_active', 'always_enqueue')] [string]$ConcurrencyPolicy = 'coalesce_if_active',
    [ValidateSet('skip_missed', 'enqueue_missed_with_cap')] [string]$CatchUpPolicy = 'skip_missed',
    [string]$CronExpression = '7 * * * *',
    [string]$Timezone = 'UTC',
    [string]$TriggerLabel = 'hourly',
    [switch]$DisableLegacyTask,
    [string]$LegacyTaskName = 'QM_DWX_HourlyCheck',
    [switch]$RunNow,
    [switch]$PreviewOnly,
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Apply.IsPresent -and $PreviewOnly.IsPresent) {
    throw "Use either -Apply or -PreviewOnly (not both)."
}

function Normalize-ApiBaseUrl {
    param([Parameter(Mandatory = $true)] [string]$Url)
    $trimmed = $Url.TrimEnd('/')
    if ($trimmed -match '/api$') {
        return $trimmed
    }
    return "$trimmed/api"
}

function New-ApiHeaders {
    param(
        [Parameter(Mandatory = $true)] [string]$Token,
        [switch]$Mutating
    )

    $headers = @{
        Authorization = "Bearer $Token"
    }

    if ($Mutating.IsPresent) {
        $runId = if ($env:PAPERCLIP_RUN_ID) { $env:PAPERCLIP_RUN_ID } else { [guid]::NewGuid().ToString() }
        $headers['X-Paperclip-Run-Id'] = $runId
    }

    return $headers
}

function Invoke-PaperclipJson {
    param(
        [Parameter(Mandatory = $true)] [ValidateSet('GET', 'POST', 'PATCH')] [string]$Method,
        [Parameter(Mandatory = $true)] [string]$Uri,
        [hashtable]$Body,
        [switch]$Mutating
    )

    $headers = New-ApiHeaders -Token $ApiKey -Mutating:$Mutating
    if ($Method -eq 'GET') {
        return Invoke-RestMethod -Method Get -Uri $Uri -Headers $headers
    }

    $json = if ($Body) { $Body | ConvertTo-Json -Depth 20 } else { '{}' }
    return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -ContentType 'application/json' -Body $json
}

function Resolve-ProjectIdFromTask {
    param([string]$ApiRoot)

    if (-not $env:PAPERCLIP_TASK_ID) {
        return ''
    }

    $issueUri = "$ApiRoot/issues/$($env:PAPERCLIP_TASK_ID)"
    $issue = Invoke-PaperclipJson -Method GET -Uri $issueUri
    if ($issue.projectId) {
        return [string]$issue.projectId
    }

    return ''
}

if (-not $ApiKey) {
    throw 'PAPERCLIP_API_KEY missing. Refusing to continue.'
}

$apiRoot = Normalize-ApiBaseUrl -Url $ApiBaseUrl
$actions = New-Object System.Collections.Generic.List[string]
$result = [ordered]@{
    generated_at_utc = [datetime]::UtcNow.ToString('o')
    apply = $Apply.IsPresent
    preview_only = $PreviewOnly.IsPresent
    api_base_url = $apiRoot
    company_id = $CompanyId
    assignee_agent_id = $AssigneeAgentId
    routine_title = $RoutineTitle
    routine_id = $null
    trigger_id = $null
    actions = $actions
}

$routinesUri = "$apiRoot/companies/$CompanyId/routines"
$routines = @(Invoke-PaperclipJson -Method GET -Uri $routinesUri)
$matches = @($routines | Where-Object { $_.title -eq $RoutineTitle -and $_.assigneeAgentId -eq $AssigneeAgentId })

if ($matches.Count -gt 1) {
    throw "Multiple routines matched title '$RoutineTitle' for assignee '$AssigneeAgentId'. Refusing ambiguous update."
}

$routine = $null
if ($matches.Count -eq 1) {
    $routine = $matches[0]
    $actions.Add("routine_found:$($routine.id)")
}

if (-not $routine) {
    $resolvedProjectId = $ProjectId
    if (-not $resolvedProjectId) {
        $resolvedProjectId = Resolve-ProjectIdFromTask -ApiRoot $apiRoot
    }

    if (-not $resolvedProjectId) {
        throw 'ProjectId is required for routine creation (not provided and not resolvable from PAPERCLIP_TASK_ID).'
    }

    $createBody = @{
        title = $RoutineTitle
        description = $RoutineDescription
        assigneeAgentId = $AssigneeAgentId
        projectId = $resolvedProjectId
        priority = $Priority
        status = $RoutineStatus
        concurrencyPolicy = $ConcurrencyPolicy
        catchUpPolicy = $CatchUpPolicy
    }
    if ($GoalId) { $createBody.goalId = $GoalId }
    if ($ParentIssueId) { $createBody.parentIssueId = $ParentIssueId }

    if ($Apply.IsPresent) {
        $routine = Invoke-PaperclipJson -Method POST -Uri $routinesUri -Body $createBody -Mutating
        $actions.Add("routine_created:$($routine.id)")
    }
    else {
        $actions.Add('preview:routine_create')
        $routine = [pscustomobject]@{
            id = '<preview>'
            title = $RoutineTitle
            assigneeAgentId = $AssigneeAgentId
            description = $RoutineDescription
            priority = $Priority
            status = $RoutineStatus
            concurrencyPolicy = $ConcurrencyPolicy
            catchUpPolicy = $CatchUpPolicy
            triggers = @()
        }
    }
}

$result.routine_id = $routine.id

$patch = @{}
if ($routine.description -ne $RoutineDescription) { $patch.description = $RoutineDescription }
if ($routine.priority -ne $Priority) { $patch.priority = $Priority }
if ($routine.status -ne $RoutineStatus) { $patch.status = $RoutineStatus }
if ($routine.concurrencyPolicy -ne $ConcurrencyPolicy) { $patch.concurrencyPolicy = $ConcurrencyPolicy }
if ($routine.catchUpPolicy -ne $CatchUpPolicy) { $patch.catchUpPolicy = $CatchUpPolicy }
if ($routine.assigneeAgentId -ne $AssigneeAgentId) { $patch.assigneeAgentId = $AssigneeAgentId }

if ($patch.Count -gt 0) {
    if ($Apply.IsPresent) {
        $routine = Invoke-PaperclipJson -Method PATCH -Uri "$apiRoot/routines/$($routine.id)" -Body $patch -Mutating
        $actions.Add("routine_patched:$($routine.id)")
    }
    else {
        $actions.Add('preview:routine_patch')
    }
}
else {
    $actions.Add('routine_already_converged')
}

$scheduleTriggers = @($routine.triggers | Where-Object { $_.kind -eq 'schedule' })
$trigger = $null
if ($TriggerLabel) {
    $trigger = @($scheduleTriggers | Where-Object { $_.label -eq $TriggerLabel } | Select-Object -First 1)
}
if (-not $trigger) {
    $trigger = @($scheduleTriggers | Select-Object -First 1)
}

if (-not $trigger) {
    $triggerBody = @{
        kind = 'schedule'
        cronExpression = $CronExpression
        timezone = $Timezone
    }
    if ($TriggerLabel) { $triggerBody.label = $TriggerLabel }

    if ($Apply.IsPresent) {
        $trigger = Invoke-PaperclipJson -Method POST -Uri "$apiRoot/routines/$($routine.id)/triggers" -Body $triggerBody -Mutating
        $actions.Add("trigger_created:$($trigger.id)")
    }
    else {
        $actions.Add('preview:trigger_create')
        $trigger = [pscustomobject]@{
            id = '<preview-trigger>'
            cronExpression = $CronExpression
            timezone = $Timezone
            enabled = $true
            label = $TriggerLabel
            kind = 'schedule'
        }
    }
}
else {
    $triggerPatch = @{}
    if ($trigger.cronExpression -ne $CronExpression) { $triggerPatch.cronExpression = $CronExpression }
    if ($trigger.timezone -ne $Timezone) { $triggerPatch.timezone = $Timezone }
    if ($trigger.enabled -ne $true) { $triggerPatch.enabled = $true }
    if ($TriggerLabel -and $trigger.label -ne $TriggerLabel) { $triggerPatch.label = $TriggerLabel }

    if ($triggerPatch.Count -gt 0) {
        if ($Apply.IsPresent) {
            $trigger = Invoke-PaperclipJson -Method PATCH -Uri "$apiRoot/routine-triggers/$($trigger.id)" -Body $triggerPatch -Mutating
            $actions.Add("trigger_patched:$($trigger.id)")
        }
        else {
            $actions.Add('preview:trigger_patch')
        }
    }
    else {
        $actions.Add('trigger_already_converged')
    }
}

$result.trigger_id = $trigger.id

if ($DisableLegacyTask.IsPresent) {
    $legacy = Get-ScheduledTask -TaskName $LegacyTaskName -ErrorAction SilentlyContinue
    if ($legacy) {
        if ($Apply.IsPresent) {
            Disable-ScheduledTask -TaskName $LegacyTaskName | Out-Null
            $actions.Add("legacy_task_disabled:$LegacyTaskName")
        }
        else {
            $actions.Add("preview:legacy_task_disable:$LegacyTaskName")
        }
    }
    else {
        $actions.Add("legacy_task_absent:$LegacyTaskName")
    }
}

if ($RunNow.IsPresent) {
    $runBody = @{
        source = 'manual'
        triggerId = $trigger.id
        idempotencyKey = "dwx-hourly-manual-$([datetime]::UtcNow.ToString('yyyyMMddHHmm'))"
    }
    if ($Apply.IsPresent) {
        $run = Invoke-PaperclipJson -Method POST -Uri "$apiRoot/routines/$($routine.id)/run" -Body $runBody -Mutating
        if ($run.id) {
            $actions.Add("manual_run_enqueued:$($run.id)")
        }
        else {
            $actions.Add("manual_run_enqueued:$($routine.id)")
        }
    }
    else {
        $actions.Add('preview:manual_run')
    }
}

$result | ConvertTo-Json -Depth 10
