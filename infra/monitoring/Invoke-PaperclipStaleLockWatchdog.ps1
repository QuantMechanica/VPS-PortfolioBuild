[CmdletBinding()]
param(
    [string]$PaperclipApiUrl = $(if ($env:PAPERCLIP_API_URL) { $env:PAPERCLIP_API_URL } else { "http://127.0.0.1:3100" }),
    [string]$CompanyId = $(if ($env:PAPERCLIP_COMPANY_ID) { $env:PAPERCLIP_COMPANY_ID } else { "" }),
    [string]$ApiKey = $(if ($env:PAPERCLIP_API_KEY) { $env:PAPERCLIP_API_KEY } else { "" }),
    [int]$StaleAfterMinutes = 15,
    [string[]]$Statuses = @("in_progress"),
    [string[]]$AllowedAssigneeAgentIds = @("46fc11e5-7fc2-43f4-9a34-bde29e5dee3b"),
    [switch]$AutoRecover,
    [switch]$FailOnFinding
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-Result {
    param(
        [string]$Status,
        [string]$Message,
        [object]$Details = $null
    )
    [ordered]@{
        check = "paperclip_stale_lock_watchdog"
        generated_at_utc = [datetime]::UtcNow.ToString("o")
        status = $Status
        message = $Message
        details = $Details
    }
}

function Invoke-PaperclipApiGet {
    param([string]$Uri)
    Invoke-RestMethod -Method Get -Uri $Uri -Headers $script:headers
}

function Invoke-PaperclipApiPatch {
    param(
        [string]$Uri,
        [hashtable]$Payload
    )
    $runId = [guid]::NewGuid().ToString()
    $mutatingHeaders = @{
        Authorization = $script:headers.Authorization
        "X-Paperclip-Run-Id" = $runId
    }
    Invoke-RestMethod -Method Patch -Uri $Uri -Headers $mutatingHeaders -ContentType "application/json" -Body ($Payload | ConvertTo-Json -Depth 8)
}

function Get-PropValue {
    param(
        [Parameter(Mandatory = $true)] [object]$Object,
        [Parameter(Mandatory = $true)] [string]$Name
    )
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

if ([string]::IsNullOrWhiteSpace($CompanyId) -or [string]::IsNullOrWhiteSpace($ApiKey)) {
    $missing = @()
    if ([string]::IsNullOrWhiteSpace($CompanyId)) { $missing += "CompanyId/PAPERCLIP_COMPANY_ID" }
    if ([string]::IsNullOrWhiteSpace($ApiKey)) { $missing += "ApiKey/PAPERCLIP_API_KEY" }
    $result = New-Result -Status "critical" -Message "Paperclip watchdog configuration missing required auth values." -Details @{ missing = $missing }
    $result | ConvertTo-Json -Depth 8
    exit 2
}

$apiBase = $PaperclipApiUrl.TrimEnd("/")
$script:headers = @{ Authorization = "Bearer $ApiKey" }

$statusCsv = ($Statuses | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ","
$listUrl = "$apiBase/api/companies/$CompanyId/issues?status=$statusCsv&limit=200"
$issues = @(Invoke-PaperclipApiGet -Uri $listUrl)

$now = [datetime]::UtcNow
$stale = New-Object System.Collections.Generic.List[object]
$recoveries = New-Object System.Collections.Generic.List[object]

foreach ($issue in $issues) {
    $executionLockedAt = [string](Get-PropValue -Object $issue -Name "executionLockedAt")
    $activeRun = Get-PropValue -Object $issue -Name "activeRun"
    $assigneeAgentId = [string](Get-PropValue -Object $issue -Name "assigneeAgentId")
    if ([string]::IsNullOrWhiteSpace($executionLockedAt)) { continue }
    if ($null -ne $activeRun) { continue }

    $agentAllowed = $true
    if ($AllowedAssigneeAgentIds.Count -gt 0) {
        $agentAllowed = $AllowedAssigneeAgentIds -contains $assigneeAgentId
    }
    if (-not $agentAllowed) { continue }

    $lockedAt = [datetime]::Parse($executionLockedAt).ToUniversalTime()
    $ageMin = [math]::Round(($now - $lockedAt).TotalMinutes, 2)
    if ($ageMin -lt $StaleAfterMinutes) { continue }

    $entry = [ordered]@{
        issue_id = [string](Get-PropValue -Object $issue -Name "id")
        identifier = [string](Get-PropValue -Object $issue -Name "identifier")
        title = [string](Get-PropValue -Object $issue -Name "title")
        status = [string](Get-PropValue -Object $issue -Name "status")
        assignee_agent_id = $assigneeAgentId
        checkout_run_id = [string](Get-PropValue -Object $issue -Name "checkoutRunId")
        execution_run_id = [string](Get-PropValue -Object $issue -Name "executionRunId")
        execution_agent_name_key = [string](Get-PropValue -Object $issue -Name "executionAgentNameKey")
        execution_locked_at = $executionLockedAt
        lock_age_minutes = $ageMin
        auto_recover_attempted = $false
        auto_recover_ok = $false
        auto_recover_error = $null
    }

    if ($AutoRecover.IsPresent -and -not [string]::IsNullOrWhiteSpace($assigneeAgentId)) {
        $entry.auto_recover_attempted = $true
        $issueUrl = "$apiBase/api/issues/$([string](Get-PropValue -Object $issue -Name 'id'))"
        try {
            Invoke-PaperclipApiPatch -Uri $issueUrl -Payload @{ assigneeAgentId = $null } | Out-Null
            Invoke-PaperclipApiPatch -Uri $issueUrl -Payload @{ assigneeAgentId = $assigneeAgentId } | Out-Null
            $entry.auto_recover_ok = $true
            $recoveries.Add([ordered]@{
                issue_id = [string](Get-PropValue -Object $issue -Name "id")
                identifier = [string](Get-PropValue -Object $issue -Name "identifier")
                restored_assignee_agent_id = $assigneeAgentId
            }) | Out-Null
        }
        catch {
            $entry.auto_recover_error = $_.Exception.Message
        }
    }

    $stale.Add($entry) | Out-Null
}

if ($stale.Count -eq 0) {
    $result = New-Result -Status "ok" -Message "No stale Paperclip issue locks detected." -Details @{
        stale_after_minutes = $StaleAfterMinutes
        statuses = $Statuses
        allowed_assignee_agent_ids = $AllowedAssigneeAgentIds
    }
    $result | ConvertTo-Json -Depth 10
    exit 0
}

$failedRecoveries = @($stale | Where-Object { $_.auto_recover_attempted -and -not $_.auto_recover_ok }).Count
$allRecovered = $AutoRecover.IsPresent -and $failedRecoveries -eq 0
$status = if ($allRecovered) { "warn" } else { "critical" }
$message = if ($allRecovered) {
    "Detected stale Paperclip issue locks; automatic PATCH-only assignee-cycle succeeded."
}
else {
    "Detected stale Paperclip issue locks."
}

$result = New-Result -Status $status -Message $message -Details @{
    stale_count = $stale.Count
    stale_after_minutes = $StaleAfterMinutes
    auto_recover = $AutoRecover.IsPresent
    recoveries = @($recoveries)
    issues = @($stale)
}
$result | ConvertTo-Json -Depth 10

if ($FailOnFinding.IsPresent -or $status -eq "critical") {
    exit 2
}
exit 1
