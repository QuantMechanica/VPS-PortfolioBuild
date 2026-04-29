[CmdletBinding()]
param(
    [string]$PaperclipApiUrl = $(if ($env:PAPERCLIP_API_URL) { $env:PAPERCLIP_API_URL } else { "http://127.0.0.1:3100" }),
    [string]$CompanyId = $(if ($env:PAPERCLIP_COMPANY_ID) { $env:PAPERCLIP_COMPANY_ID } else { "" }),
    [string]$ApiKey = $(if ($env:PAPERCLIP_API_KEY) { $env:PAPERCLIP_API_KEY } else { "" }),
    [string]$RunId = $(if ($env:PAPERCLIP_RUN_ID) { $env:PAPERCLIP_RUN_ID } else { "" }),
    [string]$StrategyResearchProjectId = "b2adcc7f-064f-47c7-8563-d1c917639231",
    [string[]]$Statuses = @("todo", "in_progress", "in_review", "blocked"),
    [string[]]$ExemptIssueIdentifiers = @("QUA-236"),
    [string[]]$IncludeIssueIdentifiers = @(),
    [string]$OutPath = "C:\QM\logs\infra\health\class2_execution_policy_sentinel_latest.json",
    [switch]$ApplyMissingPolicy,
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
        check = "class2_execution_policy_sentinel"
        generated_at_utc = [datetime]::UtcNow.ToString("o")
        status = $Status
        message = $Message
        details = $Details
    }
}

function Write-Result {
    param([object]$Result)
    $json = $Result | ConvertTo-Json -Depth 10
    $outDir = Split-Path -Parent $OutPath
    if (-not [string]::IsNullOrWhiteSpace($outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }
    $json | Set-Content -LiteralPath $OutPath -Encoding UTF8
    $json
}

function Get-PropValue {
    param(
        [AllowNull()] [object]$Object,
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
    if ($null -ne $prop) { return $prop.Value }
    $match = @($Object.PSObject.Properties | Where-Object { $_.Name -ieq $Name } | Select-Object -First 1)
    if ($match.Count -gt 0) { return $match[0].Value }
    return $null
}

function Normalize-ApiBaseUrl {
    param([Parameter(Mandatory = $true)] [string]$Url)
    $trimmed = $Url.TrimEnd("/")
    if ($trimmed -match "/api$") { return $trimmed }
    return "$trimmed/api"
}

function Is-Class2Candidate {
    param(
        [Parameter(Mandatory = $true)] [object]$Issue,
        [string]$ProjectId,
        [string[]]$ExemptIdentifiers
    )
    $identifier = [string](Get-PropValue -Object $Issue -Name "identifier")
    if ($IncludeIssueIdentifiers -contains $identifier) { return $true }
    if ($ExemptIdentifiers -contains $identifier) { return $false }

    $issueProjectId = [string](Get-PropValue -Object $Issue -Name "projectId")
    if ($issueProjectId -ne $ProjectId) { return $false }

    # Class-2 scope in DL-030 is Strategy Card child issues under strategy research.
    $parentIssueId = [string](Get-PropValue -Object $Issue -Name "parentIssueId")
    $parentId = [string](Get-PropValue -Object $Issue -Name "parentId")
    if ([string]::IsNullOrWhiteSpace($parentIssueId) -and [string]::IsNullOrWhiteSpace($parentId)) {
        return $false
    }

    $title = [string](Get-PropValue -Object $Issue -Name "title")
    if ($title -match "(?i)\b(source|survey|charter)\b") { return $false }
    if ($title -notmatch "(?i)^\s*SRC\d{2}_S\d+[a-z]?\b") { return $false }

    return $true
}

function Has-ExecutionPolicy {
    param([AllowNull()] [object]$ExecutionPolicy)
    if ($null -eq $ExecutionPolicy) { return $false }
    $mode = [string](Get-PropValue -Object $ExecutionPolicy -Name "mode")
    $commentRequired = Get-PropValue -Object $ExecutionPolicy -Name "commentRequired"
    $stages = @(Get-PropValue -Object $ExecutionPolicy -Name "stages")
    if ([string]::IsNullOrWhiteSpace($mode)) { return $false }
    if ($null -eq $commentRequired) { return $false }
    if ($stages.Count -lt 1) { return $false }
    return $true
}

function Get-Class2Policy {
    [ordered]@{
        mode = "normal"
        commentRequired = $true
        stages = @(
            [ordered]@{
                type = "review"
                participants = @(
                    [ordered]@{ type = "agent"; agentId = "7795b4b0-8ecd-46da-ab22-06def7c8fa2d" },
                    [ordered]@{ type = "user"; userId = "local-board" }
                )
            }
        )
    }
}

if ([string]::IsNullOrWhiteSpace($CompanyId) -or [string]::IsNullOrWhiteSpace($ApiKey)) {
    $missing = @()
    if ([string]::IsNullOrWhiteSpace($CompanyId)) { $missing += "CompanyId/PAPERCLIP_COMPANY_ID" }
    if ([string]::IsNullOrWhiteSpace($ApiKey)) { $missing += "ApiKey/PAPERCLIP_API_KEY" }
    $result = New-Result -Status "critical" -Message "Sentinel config missing required Paperclip auth values." -Details @{ missing = $missing }
    Write-Result -Result $result
    exit 2
}

$apiBase = Normalize-ApiBaseUrl -Url $PaperclipApiUrl
$headers = @{ Authorization = "Bearer $ApiKey" }
$statusCsv = ($Statuses | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ","
$listUrl = "$apiBase/companies/$CompanyId/issues?status=$statusCsv&limit=200"
$issuesRaw = Invoke-RestMethod -Method Get -Uri $listUrl -Headers $headers
$issues = @($issuesRaw | ForEach-Object { $_ })

$candidates = New-Object System.Collections.ArrayList
$violations = New-Object System.Collections.ArrayList
$patches = New-Object System.Collections.ArrayList
$class2Policy = Get-Class2Policy

foreach ($issue in $issues) {
    if (-not (Is-Class2Candidate -Issue $issue -ProjectId $StrategyResearchProjectId -ExemptIdentifiers $ExemptIssueIdentifiers)) {
        continue
    }
    $null = $candidates.Add($issue)

    $executionPolicy = Get-PropValue -Object $issue -Name "executionPolicy"
    if (Has-ExecutionPolicy -ExecutionPolicy $executionPolicy) {
        continue
    }

    $issueId = [string](Get-PropValue -Object $issue -Name "id")
    $identifier = [string](Get-PropValue -Object $issue -Name "identifier")
    $title = [string](Get-PropValue -Object $issue -Name "title")
    $status = [string](Get-PropValue -Object $issue -Name "status")
    $entry = [ordered]@{
        issue_id = $issueId
        identifier = $identifier
        title = $title
        status = $status
        patched = $false
        patch_error = $null
    }

    if ($ApplyMissingPolicy.IsPresent) {
        if ([string]::IsNullOrWhiteSpace($RunId)) {
            $entry.patch_error = "RunId required for ApplyMissingPolicy (set PAPERCLIP_RUN_ID or pass -RunId)."
        }
        else {
            $patchHeaders = @{
                Authorization = "Bearer $ApiKey"
                "X-Paperclip-Run-Id" = $RunId
            }
            $patchUri = "$apiBase/issues/$issueId"
            $payload = @{ executionPolicy = $class2Policy } | ConvertTo-Json -Depth 10
            try {
                Invoke-RestMethod -Method Patch -Uri $patchUri -Headers $patchHeaders -ContentType "application/json" -Body $payload | Out-Null
                $entry.patched = $true
                $null = $patches.Add($identifier)
            }
            catch {
                $entry.patch_error = $_.Exception.Message
            }
        }
    }

    $null = $violations.Add($entry)
}

$details = [ordered]@{
    strategy_research_project_id = $StrategyResearchProjectId
    scanned_issue_count = $issues.Count
    class2_candidate_count = $candidates.Count
    missing_policy_count = $violations.Count
    include_issue_identifiers = @($IncludeIssueIdentifiers)
    apply_missing_policy = [bool]$ApplyMissingPolicy.IsPresent
    patched_identifiers = @($patches)
    violations = @($violations)
}

if ($violations.Count -eq 0) {
    $result = New-Result -Status "ok" -Message "No Class-2 strategy-card issues missing executionPolicy." -Details $details
    Write-Result -Result $result
    exit 0
}

$allPatched = $ApplyMissingPolicy.IsPresent -and @($violations | Where-Object { -not $_.patched }).Count -eq 0
if ($allPatched) {
    $result = New-Result -Status "warn" -Message "Class-2 issues missing executionPolicy were detected and patched." -Details $details
    Write-Result -Result $result
    exit 1
}

$result = New-Result -Status "critical" -Message "Class-2 issues missing executionPolicy detected." -Details $details
Write-Result -Result $result
if ($FailOnFinding.IsPresent) {
    exit 2
}
exit 1
