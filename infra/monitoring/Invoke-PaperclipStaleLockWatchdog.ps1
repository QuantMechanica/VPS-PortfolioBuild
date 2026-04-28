[CmdletBinding()]
param(
    [string]$PaperclipApiUrl = $(if ($env:PAPERCLIP_API_URL) { $env:PAPERCLIP_API_URL } else { "http://127.0.0.1:3100" }),
    [string]$CompanyId = $(if ($env:PAPERCLIP_COMPANY_ID) { $env:PAPERCLIP_COMPANY_ID } else { "" }),
    [string]$ApiKey = $(if ($env:PAPERCLIP_API_KEY) { $env:PAPERCLIP_API_KEY } else { "" }),
    [int]$StaleAfterMinutes = 15,
    [int]$RunningLockMaxMinutes = 90,
    [string[]]$Statuses = @("in_progress"),
    [string]$AssigneeAgentId = $(if ($env:PAPERCLIP_AGENT_ID) { $env:PAPERCLIP_AGENT_ID } else { "" }),
    [string[]]$AllowedAssigneeAgentIds = @(),
    [string]$OutPath = "",
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
        [Parameter(Mandatory = $false)] [AllowNull()] [object]$Object,
        [Parameter(Mandatory = $true)] [string]$Name
    )
    if ($null -eq $Object) { return $null }
    if ($Object -is [System.Collections.IDictionary]) {
        foreach ($key in $Object.Keys) {
            if ([string]$key -ieq $Name) {
                return $Object[$key]
            }
        }
    }

    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) {
        $matches = @($Object.PSObject.Properties | Where-Object { $_.Name -ieq $Name })
        if ($matches.Count -gt 0) {
            $prop = $matches[0]
        }
    }
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

function Write-Result {
    param([object]$Result)
    $json = $Result | ConvertTo-Json -Depth 10
    if (-not [string]::IsNullOrWhiteSpace($OutPath)) {
        $outFull = $OutPath
        if (-not [System.IO.Path]::IsPathRooted($outFull)) {
            $outFull = Join-Path (Get-Location).Path $outFull
        }
        $outDir = Split-Path -Parent $outFull
        if (-not [string]::IsNullOrWhiteSpace($outDir)) {
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
        }
        $json | Set-Content -LiteralPath $outFull -Encoding UTF8
    }
    $json
}

if ([string]::IsNullOrWhiteSpace($CompanyId) -or [string]::IsNullOrWhiteSpace($ApiKey)) {
    $missing = @()
    if ([string]::IsNullOrWhiteSpace($CompanyId)) { $missing += "CompanyId/PAPERCLIP_COMPANY_ID" }
    if ([string]::IsNullOrWhiteSpace($ApiKey)) { $missing += "ApiKey/PAPERCLIP_API_KEY" }
    $result = New-Result -Status "critical" -Message "Paperclip watchdog configuration missing required auth values." -Details @{ missing = $missing }
    Write-Result -Result $result
    exit 2
}

$apiBase = $PaperclipApiUrl.TrimEnd("/")
$script:headers = @{ Authorization = "Bearer $ApiKey" }
$allowedAssignees = @($AllowedAssigneeAgentIds | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
if ($allowedAssignees.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($AssigneeAgentId)) {
    $allowedAssignees = @($AssigneeAgentId)
}

$statusCsv = ($Statuses | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ","
$queryParts = @("status=$statusCsv", "limit=200")
if (-not [string]::IsNullOrWhiteSpace($AssigneeAgentId)) {
    $queryParts += "assigneeAgentId=$([uri]::EscapeDataString($AssigneeAgentId))"
}
$query = $queryParts -join "&"
$listUrl = "$apiBase/api/companies/$CompanyId/issues?$query"
$issuesRaw = Invoke-PaperclipApiGet -Uri $listUrl
$issues = @($issuesRaw | ForEach-Object { $_ })

$now = [datetime]::UtcNow
$stale = New-Object System.Collections.ArrayList
$recoveries = New-Object System.Collections.ArrayList

foreach ($issue in $issues) {
    $executionLockedAt = [string](Get-PropValue -Object $issue -Name "executionLockedAt")
    $activeRun = Get-PropValue -Object $issue -Name "activeRun"
    $assigneeAgentId = [string](Get-PropValue -Object $issue -Name "assigneeAgentId")
    $activeRunId = [string](Get-PropValue -Object $activeRun -Name "id")
    $activeRunStartedAt = [string](Get-PropValue -Object $activeRun -Name "startedAt")

    $agentAllowed = $true
    if ($allowedAssignees.Count -gt 0) {
        $agentAllowed = $allowedAssignees -contains $assigneeAgentId
    }
    if (-not $agentAllowed) { continue }

    $ageBasis = $null
    $ageMin = $null
    if (-not [string]::IsNullOrWhiteSpace($executionLockedAt)) {
        try {
            $lockedAt = [datetime]::Parse($executionLockedAt).ToUniversalTime()
            $ageMin = [math]::Round(($now - $lockedAt).TotalMinutes, 2)
            $ageBasis = "execution_locked_at"
        }
        catch {}
    }
    if ($null -eq $ageMin -and $null -ne $activeRun -and -not [string]::IsNullOrWhiteSpace($activeRunStartedAt)) {
        try {
            $runStartedAt = [datetime]::Parse($activeRunStartedAt).ToUniversalTime()
            $ageMin = [math]::Round(($now - $runStartedAt).TotalMinutes, 2)
            $ageBasis = "active_run_started_at"
        }
        catch {}
    }
    if ($null -eq $ageMin) { continue }

    $lockClass = $null
    if ($null -eq $activeRun -and $ageMin -ge $StaleAfterMinutes) {
        $lockClass = "orphaned_lock"
    }
    elseif ($null -ne $activeRun -and $ageMin -ge $RunningLockMaxMinutes) {
        $lockClass = "stale_running_lock"
    }
    if ($null -eq $lockClass) { continue }

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
        age_basis = $ageBasis
        lock_class = $lockClass
        active_run_id = if ([string]::IsNullOrWhiteSpace($activeRunId)) { $null } else { $activeRunId }
        active_run_started_at = if ([string]::IsNullOrWhiteSpace($activeRunStartedAt)) { $null } else { $activeRunStartedAt }
        lock_age_minutes = $ageMin
        auto_recover_attempted = $false
        auto_recover_ok = $false
        auto_recover_error = $null
    }

    if ($AutoRecover.IsPresent -and $lockClass -eq "orphaned_lock" -and -not [string]::IsNullOrWhiteSpace($assigneeAgentId)) {
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
        running_lock_max_minutes = $RunningLockMaxMinutes
        statuses = $Statuses
        allowed_assignee_agent_ids = $allowedAssignees
    }
    Write-Result -Result $result
    exit 0
}

$failedRecoveries = @($stale | Where-Object { $_.auto_recover_attempted -and -not $_.auto_recover_ok }).Count
$allRecovered = $AutoRecover.IsPresent -and $failedRecoveries -eq 0
$orphanedCount = @($stale | Where-Object { $_.lock_class -eq "orphaned_lock" }).Count
$staleRunningCount = @($stale | Where-Object { $_.lock_class -eq "stale_running_lock" }).Count
$status = if ($allRecovered) { "warn" } else { "critical" }
$message = if ($allRecovered) {
    "Detected stale Paperclip issue locks; automatic PATCH-only assignee-cycle succeeded."
}
else {
    "Detected stale Paperclip issue locks."
}

$result = New-Result -Status $status -Message $message -Details @{
    stale_count = $stale.Count
    orphaned_lock_count = $orphanedCount
    stale_running_lock_count = $staleRunningCount
    stale_after_minutes = $StaleAfterMinutes
    running_lock_max_minutes = $RunningLockMaxMinutes
    auto_recover = $AutoRecover.IsPresent
    recoveries = @($recoveries)
    allowed_assignee_agent_ids = $allowedAssignees
    issues = @($stale)
}
Write-Result -Result $result

if ($FailOnFinding.IsPresent -or $status -eq "critical") {
    exit 2
}
exit 1
