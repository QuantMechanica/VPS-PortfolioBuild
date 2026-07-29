<#
.SYNOPSIS
  Plan, apply, or roll back the reviewed 2026-07-28 scheduled-task contracts.

.DESCRIPTION
  Default invocation is read-only PLAN mode. -Apply registers after/*.xml only
  when the live task still matches before/*.xml. -Rollback registers
  rollback/*.xml only when the live task matches after/*.xml. A third-state
  drift is refused. The script never starts, stops, enables, or disables a task
  and never touches the trading runtime.
#>
[CmdletBinding(DefaultParameterSetName = 'Plan', SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Apply')]
    [switch]$Apply,

    [Parameter(Mandatory = $true, ParameterSetName = 'Rollback')]
    [switch]$Rollback
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$taskNames = @(
    'QM_StrategyFarm_AgyGovernor',
    'QM_StrategyFarm_CodexFleetPacer',
    'QM_StrategyFarm_GeminiOrchestration_15min',
    'QM_StrategyFarm_MailboxSourceIntake_Daily',
    'QM_StrategyFarm_WorkerDedupe',
    'QM_T_Live_AtLogon',
    'QM_FTMO_AtLogon',
    'QM_Live_MT5_SessionSupervisor'
)

function Read-TaskXml {
    param([string]$Directory, [string]$TaskName)
    $path = Join-Path (Join-Path $PSScriptRoot $Directory) ($TaskName + '.xml')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Package file missing: $path"
    }
    return [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
}

function Get-TaskContractFingerprint {
    param([string]$XmlText)
    [xml]$document = $XmlText
    # Task Scheduler may add a registration timestamp. It is not part of the
    # runnable contract; everything else remains in the comparison.
    $ns = New-Object System.Xml.XmlNamespaceManager($document.NameTable)
    $ns.AddNamespace('t', 'http://schemas.microsoft.com/windows/2004/02/mit/task')
    foreach ($node in @($document.SelectNodes('//t:RegistrationInfo/t:Date', $ns))) {
        [void]$node.ParentNode.RemoveChild($node)
    }
    foreach ($node in @($document.SelectNodes('//text()[normalize-space(.) = ""]'))) {
        [void]$node.ParentNode.RemoveChild($node)
    }
    $bytes = [Text.Encoding]::UTF8.GetBytes($document.DocumentElement.OuterXml)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Get-LiveTaskXml {
    param([string]$TaskName)
    return Export-ScheduledTask -TaskPath '\' -TaskName $TaskName -ErrorAction Stop
}

$mode = if ($Apply.IsPresent) { 'APPLY' } elseif ($Rollback.IsPresent) { 'ROLLBACK' } else { 'PLAN' }
$results = [Collections.Generic.List[object]]::new()

foreach ($name in $taskNames) {
    $beforeXml = Read-TaskXml 'before' $name
    $afterXml = Read-TaskXml 'after' $name
    $rollbackXml = Read-TaskXml 'rollback' $name
    $beforeFingerprint = Get-TaskContractFingerprint $beforeXml
    $afterFingerprint = Get-TaskContractFingerprint $afterXml
    $rollbackFingerprint = Get-TaskContractFingerprint $rollbackXml
    if ($beforeFingerprint -ne $rollbackFingerprint) {
        throw "Rollback does not reproduce BEFORE for $name"
    }

    $liveXml = Get-LiveTaskXml $name
    $liveFingerprint = Get-TaskContractFingerprint $liveXml
    $liveState = if ($liveFingerprint -eq $beforeFingerprint) {
        'BEFORE'
    } elseif ($liveFingerprint -eq $afterFingerprint) {
        'AFTER'
    } else {
        'DRIFT'
    }

    if ($mode -eq 'PLAN') {
        $results.Add([pscustomobject]@{
            task = $name
            live_state = $liveState
            action = if ($liveState -eq 'BEFORE') { 'would_apply' } elseif ($liveState -eq 'AFTER') { 'already_applied' } else { 'refuse_drift' }
        })
        continue
    }

    $targetState = if ($mode -eq 'APPLY') { 'AFTER' } else { 'BEFORE' }
    if ($liveState -eq $targetState) {
        $results.Add([pscustomobject]@{ task = $name; live_state = $liveState; action = 'no_change' })
        continue
    }
    $allowedSource = if ($mode -eq 'APPLY') { 'BEFORE' } else { 'AFTER' }
    if ($liveState -ne $allowedSource) {
        throw "$name is $liveState; $mode requires $allowedSource. Refusing overwrite."
    }

    $desiredXml = if ($mode -eq 'APPLY') { $afterXml } else { $rollbackXml }
    if ($PSCmdlet.ShouldProcess($name, "Register scheduled-task contract $targetState")) {
        Register-ScheduledTask -TaskPath '\' -TaskName $name -Xml $desiredXml -Force -ErrorAction Stop | Out-Null
        $verifiedXml = Get-LiveTaskXml $name
        $verifiedFingerprint = Get-TaskContractFingerprint $verifiedXml
        $desiredFingerprint = Get-TaskContractFingerprint $desiredXml
        if ($verifiedFingerprint -ne $desiredFingerprint) {
            throw "Post-register verification failed for $name"
        }
        $results.Add([pscustomobject]@{ task = $name; live_state = $targetState; action = 'registered_and_verified' })
    }
}

$results | Format-Table -AutoSize
