[CmdletBinding()]
param(
    [ValidateSet('WhatIf', 'Apply', 'Rollback')]
    [string]$Mode = 'WhatIf',
    [string]$PlanPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    return Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}

function Get-NormalizedXmlHash {
    param([Parameter(Mandatory = $true)][string]$Xml)
    $normalized = ($Xml -replace "`r`n", "`n").TrimEnd([char[]]"`r`n")
    $bytes = [Text.Encoding]::UTF8.GetBytes($normalized)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Resolve-RepoPath {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Path
    )
    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }
    return [IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Assert-BeforeArtifact {
    param(
        [Parameter(Mandatory = $true)]$TaskPlan,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )
    $beforePath = Resolve-RepoPath -RepoRoot $RepoRoot -Path ([string]$TaskPlan.before.xml_path)
    if (-not (Test-Path -LiteralPath $beforePath -PathType Leaf)) {
        throw "before XML missing for $($TaskPlan.name): $beforePath"
    }
    $fileHash = (Get-FileHash -LiteralPath $beforePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($fileHash -ne [string]$TaskPlan.before.file_sha256) {
        throw "before XML file hash mismatch for $($TaskPlan.name)"
    }
    $beforeXml = Get-Content -LiteralPath $beforePath -Raw
    $textHash = Get-NormalizedXmlHash -Xml $beforeXml
    if ($textHash -ne [string]$TaskPlan.before.normalized_xml_sha256) {
        throw "before XML normalized hash mismatch for $($TaskPlan.name)"
    }
    return [pscustomobject]@{
        Path = $beforePath
        Xml = $beforeXml
    }
}

function Get-LiveContract {
    param([Parameter(Mandatory = $true)][string]$TaskName)
    $task = Get-ScheduledTask -TaskPath '\' -TaskName $TaskName -ErrorAction Stop
    $action = @($task.Actions)
    if ($action.Count -ne 1) {
        throw "$TaskName has $($action.Count) actions; expected exactly one"
    }
    $xml = Export-ScheduledTask -TaskPath '\' -TaskName $TaskName -ErrorAction Stop
    return [pscustomobject]@{
        Task = $task
        Action = $action[0]
        Xml = $xml
        Hash = Get-NormalizedXmlHash -Xml $xml
    }
}

function Assert-LiveBefore {
    param(
        [Parameter(Mandatory = $true)]$TaskPlan,
        [Parameter(Mandatory = $true)]$Live
    )
    if ($Live.Hash -ne [string]$TaskPlan.before.normalized_xml_sha256) {
        throw "live task drift for $($TaskPlan.name): expected $($TaskPlan.before.normalized_xml_sha256), got $($Live.Hash)"
    }
}

function Test-AfterContract {
    param(
        [Parameter(Mandatory = $true)]$TaskPlan,
        [Parameter(Mandatory = $true)]$Live
    )
    $after = $TaskPlan.after
    return (
        [string]$Live.Task.Principal.UserId -in @('SYSTEM', 'S-1-5-18') -and
        [string]$Live.Task.Principal.LogonType -eq [string]$after.principal.logon_type -and
        [string]$Live.Task.Principal.RunLevel -eq [string]$after.principal.run_level -and
        [string]$Live.Action.Execute -eq [string]$after.action.execute -and
        [string]$Live.Action.Arguments -eq [string]$after.action.arguments -and
        [string]$Live.Action.WorkingDirectory -eq [string]$after.action.working_directory
    )
}

$repoRoot = Get-RepoRoot
if (-not $PlanPath) {
    $PlanPath = Join-Path $repoRoot 'docs\ops\evidence\2026-07-31_mnt003_minimal_plan.json'
}
$resolvedPlan = Resolve-RepoPath -RepoRoot $repoRoot -Path $PlanPath
if (-not (Test-Path -LiteralPath $resolvedPlan -PathType Leaf)) {
    throw "plan missing: $resolvedPlan"
}
$plan = Get-Content -LiteralPath $resolvedPlan -Raw | ConvertFrom-Json
if ([string]$plan.schema -ne 'qm.mnt003.minimal-task-contract-plan/v1') {
    throw "unsupported plan schema: $($plan.schema)"
}
$taskPlans = @($plan.tasks)
if ($taskPlans.Count -ne 5) {
    throw "plan must contain exactly five tasks; got $($taskPlans.Count)"
}

$beforeArtifacts = @{}
foreach ($taskPlan in $taskPlans) {
    $beforeArtifacts[[string]$taskPlan.name] = Assert-BeforeArtifact -TaskPlan $taskPlan -RepoRoot $repoRoot
}

if ($Mode -eq 'Rollback') {
    foreach ($taskPlan in $taskPlans) {
        $name = [string]$taskPlan.name
        Register-ScheduledTask -TaskPath '\' -TaskName $name `
            -Xml $beforeArtifacts[$name].Xml -Force | Out-Null
        Write-Output "ROLLBACK registered exact before XML: $name"
    }
    exit 0
}

$whatIfRows = @()
$liveBefore = @{}
foreach ($taskPlan in $taskPlans) {
    $name = [string]$taskPlan.name
    $live = Get-LiveContract -TaskName $name
    Assert-LiveBefore -TaskPlan $taskPlan -Live $live
    $liveBefore[$name] = $live
    $whatIfRows += [pscustomobject]@{
        task = $name
        before_hash = $live.Hash
        before_principal = "$($live.Task.Principal.UserId)/$($live.Task.Principal.LogonType)/$($live.Task.Principal.RunLevel)"
        after_principal = "$($taskPlan.after.principal.user_id)/$($taskPlan.after.principal.logon_type)/$($taskPlan.after.principal.run_level)"
        before_action = "$($live.Action.Execute) $($live.Action.Arguments)"
        after_action = "$($taskPlan.after.action.execute) $($taskPlan.after.action.arguments)"
        preserved = 'registration, triggers, settings, enabled state'
    }
}

if ($Mode -eq 'WhatIf') {
    $whatIfRows | ConvertTo-Json -Depth 5
    Write-Output 'WHATIF_ONLY: no Register-ScheduledTask or Set-ScheduledTask call executed.'
    exit 0
}

$changed = New-Object Collections.Generic.List[string]
try {
    foreach ($taskPlan in $taskPlans) {
        $name = [string]$taskPlan.name
        $after = $taskPlan.after
        $principal = New-ScheduledTaskPrincipal `
            -UserId ([string]$after.principal.user_id) `
            -LogonType ([string]$after.principal.logon_type) `
            -RunLevel ([string]$after.principal.run_level)
        $action = New-ScheduledTaskAction `
            -Execute ([string]$after.action.execute) `
            -Argument ([string]$after.action.arguments) `
            -WorkingDirectory ([string]$after.action.working_directory)
        Set-ScheduledTask -TaskPath '\' -TaskName $name `
            -Principal $principal -Action $action | Out-Null
        $changed.Add($name)
        $liveAfter = Get-LiveContract -TaskName $name
        if (-not (Test-AfterContract -TaskPlan $taskPlan -Live $liveAfter)) {
            throw "post-apply contract mismatch for $name"
        }
        Write-Output "APPLIED principal/action only: $name"
    }
} catch {
    $applyError = $_
    foreach ($name in $changed) {
        Register-ScheduledTask -TaskPath '\' -TaskName $name `
            -Xml $beforeArtifacts[$name].Xml -Force | Out-Null
        Write-Output "AUTO_ROLLBACK exact before XML: $name"
    }
    throw $applyError
}
