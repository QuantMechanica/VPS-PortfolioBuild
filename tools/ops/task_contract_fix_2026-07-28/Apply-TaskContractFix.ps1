<#
.SYNOPSIS
  Plan, apply, or roll back the reviewed 2026-07-28 scheduled-task contracts.

.DESCRIPTION
  PLAN is read-only. Factory mutation requires an exact content-bound plan ID,
  exact FACTORY_OFF SHA-256, durable OWNER decision reference and create-only
  receipt path. The shared protocol-v2 mutation lock is held across complete
  scope preflight, every registration, verification, receipt publication and
  compensation. Enabled is preserved from exported task XML. Live-task
  contracts are deliberately plan-only and require a separate future package.
#>
[CmdletBinding(DefaultParameterSetName = 'Plan', SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Apply')]
    [switch]$Apply,

    [Parameter(Mandatory = $true, ParameterSetName = 'Rollback')]
    [switch]$Rollback,

    [Parameter(ParameterSetName = 'Plan')]
    [Parameter(Mandatory = $true, ParameterSetName = 'Apply')]
    [Parameter(Mandatory = $true, ParameterSetName = 'Rollback')]
    [ValidateSet('Factory', 'Live')]
    [string]$TaskScope,

    [Parameter(ParameterSetName = 'Plan')]
    [ValidateSet('Apply', 'Rollback')]
    [string]$PlanMode = 'Apply',

    [Parameter(ParameterSetName = 'Plan')]
    [switch]$Json,

    [Parameter(Mandatory = $true, ParameterSetName = 'Apply')]
    [Parameter(Mandatory = $true, ParameterSetName = 'Rollback')]
    [ValidatePattern('^[0-9a-fA-F]{64}$')]
    [string]$ExpectedFactoryOffSha256,

    [Parameter(Mandatory = $true, ParameterSetName = 'Apply')]
    [Parameter(Mandatory = $true, ParameterSetName = 'Rollback')]
    [ValidatePattern('^[0-9a-fA-F]{64}$')]
    [string]$ExpectedPlanId,

    [Parameter(Mandatory = $true, ParameterSetName = 'Apply')]
    [Parameter(Mandatory = $true, ParameterSetName = 'Rollback')]
    [string]$OwnerDecisionRef,

    [Parameter(Mandatory = $true, ParameterSetName = 'Apply')]
    [Parameter(Mandatory = $true, ParameterSetName = 'Rollback')]
    [string]$OwnerAuthorizedBy,

    [Parameter(Mandatory = $true, ParameterSetName = 'Apply')]
    [Parameter(Mandatory = $true, ParameterSetName = 'Rollback')]
    [string]$OwnerAuthorizedAtUtc,

    [Parameter(Mandatory = $true, ParameterSetName = 'Apply')]
    [Parameter(Mandatory = $true, ParameterSetName = 'Rollback')]
    [string]$ReceiptPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$factoryOffFlagPath = 'D:\QM\strategy_farm\state\FACTORY_OFF.flag'
$factoryMutationLockPath = 'D:\QM\strategy_farm\state\FACTORY_MUTATION.lock'
$receiptRoot = [IO.Path]::GetFullPath('D:\QM\strategy_farm\artifacts\task_contract_fix_2026-07-28')
$mutationProtocolPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\strategy_farm\factory_mutation_lock.ps1'))

function Assert-TaskContractMutationProtocolAvailable {
    if ($script:QmFactoryMutationLockProtocolVersion -ne 2) {
        throw 'Mutation-lock protocol version mismatch'
    }
    foreach ($functionName in @('Remove-QmFactoryMutationLockIfUnchanged')) {
        $command = Get-Command -Name $functionName -CommandType Function -ErrorAction SilentlyContinue
        if ($null -eq $command) {
            throw "Mutation-lock protocol function missing: $functionName"
        }
    }
}

# Import the function-only protocol in script scope. Dot-sourcing it from inside
# Enter-TaskContractMutationLock would discard its helper functions when that
# function returns, making exact-identity cleanup unavailable in finally.
if (-not (Test-Path -LiteralPath $mutationProtocolPath -PathType Leaf)) {
    throw "Mutation-lock protocol missing: $mutationProtocolPath"
}
$script:QmFactoryMutationLockProtocolVersion = $null
. $mutationProtocolPath
Assert-TaskContractMutationProtocolAvailable

$factoryTaskNames = @(
    'QM_StrategyFarm_AgyGovernor',
    'QM_StrategyFarm_CodexFleetPacer',
    'QM_StrategyFarm_GeminiOrchestration_15min',
    'QM_StrategyFarm_MailboxSourceIntake_Daily',
    'QM_StrategyFarm_WorkerDedupe'
)
$liveTaskNames = @(
    'QM_T_Live_AtLogon',
    'QM_FTMO_AtLogon',
    'QM_Live_MT5_SessionSupervisor'
)

function Get-BytesSha256 {
    param([byte[]]$Bytes)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Get-FileSha256 {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required file missing: $Path"
    }
    return Get-BytesSha256 -Bytes ([IO.File]::ReadAllBytes($Path))
}

function Get-TextSha256 {
    param([string]$Text)
    return Get-BytesSha256 -Bytes ([Text.Encoding]::UTF8.GetBytes($Text))
}

function Read-TaskXml {
    param([string]$Directory, [string]$TaskName)
    $path = Join-Path (Join-Path $PSScriptRoot $Directory) ($TaskName + '.xml')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Package file missing: $path"
    }
    return [pscustomobject]@{
        path = $path
        text = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
        sha256 = Get-FileSha256 -Path $path
    }
}

function Get-TaskContractFingerprint {
    param([string]$XmlText)
    [xml]$document = $XmlText
    $ns = New-Object System.Xml.XmlNamespaceManager($document.NameTable)
    $ns.AddNamespace('t', 'http://schemas.microsoft.com/windows/2004/02/mit/task')
    foreach ($node in @($document.SelectNodes('//t:RegistrationInfo/t:Date', $ns))) {
        [void]$node.ParentNode.RemoveChild($node)
    }
    # Enabled is runtime state rather than runnable-contract identity. Factory
    # OFF intentionally adds false to exports; it is preserved separately.
    foreach ($node in @($document.SelectNodes('//t:Settings/t:Enabled', $ns))) {
        [void]$node.ParentNode.RemoveChild($node)
    }
    foreach ($node in @($document.SelectNodes('//text()[normalize-space(.) = ""]'))) {
        [void]$node.ParentNode.RemoveChild($node)
    }
    return Get-TextSha256 -Text $document.DocumentElement.OuterXml
}

function Get-TaskXmlEnabledState {
    param([string]$XmlText)
    [xml]$document = $XmlText
    $ns = New-Object System.Xml.XmlNamespaceManager($document.NameTable)
    $ns.AddNamespace('t', 'http://schemas.microsoft.com/windows/2004/02/mit/task')
    $enabledNode = $document.SelectSingleNode('//t:Settings/t:Enabled', $ns)
    if ($null -eq $enabledNode) {
        # XML default is true. Operational State=Running/Ready is deliberately
        # not consulted because a disabled task can still have a running action.
        return $true
    }
    $text = [string]$enabledNode.InnerText
    if ($text -eq 'true') { return $true }
    if ($text -eq 'false') { return $false }
    throw "Task XML has invalid Enabled value '$text'"
}

function ConvertTo-TaskSchedulerXmlString {
    param([xml]$Document)

    # Register-ScheduledTask passes -Xml to the Task Scheduler COM API as a
    # Unicode BSTR. A retained encoding="UTF-8" declaration therefore makes
    # the XML parser attempt an impossible encoding switch. Serialize through
    # a StringBuilder-backed XmlWriter so the declaration truthfully says
    # utf-16 while the runnable XML contract remains unchanged.
    $settings = [Xml.XmlWriterSettings]::new()
    $settings.Encoding = [Text.Encoding]::Unicode
    $settings.Indent = $false
    $settings.OmitXmlDeclaration = $false
    $settings.NewLineHandling = [Xml.NewLineHandling]::None
    $builder = [Text.StringBuilder]::new()
    $writer = [Xml.XmlWriter]::Create($builder, $settings)
    try {
        $Document.Save($writer)
    } finally {
        $writer.Dispose()
    }
    [string]$serialized = $builder.ToString()
    if ($serialized -notmatch '^<\?xml\s+version="1\.0"\s+encoding="utf-16"\?>') {
        throw 'Task Scheduler XML serialization did not produce a UTF-16 declaration.'
    }
    return $serialized
}

function Assert-TaskSchedulerXmlRegistrationPayload {
    param(
        [string]$XmlText,
        [string]$TaskLabel
    )

    # NewTask(0) plus XmlText assignment invokes the same Task Scheduler COM
    # schema parser used by registration, but creates no registered task and
    # changes no scheduler state.
    $taskService = $null
    $taskDefinition = $null
    try {
        $taskService = New-Object -ComObject 'Schedule.Service'
        [void]$taskService.Connect()
        $taskDefinition = $taskService.NewTask(0)
        $taskDefinition.XmlText = $XmlText
    } catch {
        throw "Task Scheduler COM parser rejected $TaskLabel registration XML: $($_.Exception.Message)"
    } finally {
        if ($null -ne $taskDefinition) {
            try {
                [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($taskDefinition)
            } catch {}
        }
        if ($null -ne $taskService) {
            try {
                [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($taskService)
            } catch {}
        }
    }
}

function Set-TaskXmlEnabledState {
    param([string]$XmlText, [bool]$Enabled)
    [xml]$document = $XmlText
    $taskNamespace = 'http://schemas.microsoft.com/windows/2004/02/mit/task'
    $ns = New-Object System.Xml.XmlNamespaceManager($document.NameTable)
    $ns.AddNamespace('t', $taskNamespace)
    $settings = $document.SelectSingleNode('//t:Settings', $ns)
    if ($null -eq $settings) { throw 'Task XML has no Settings element' }
    $enabledNode = $document.SelectSingleNode('//t:Settings/t:Enabled', $ns)
    if ($null -eq $enabledNode) {
        $enabledNode = $document.CreateElement('Enabled', $taskNamespace)
        [void]$settings.AppendChild($enabledNode)
    }
    $enabledNode.InnerText = if ($Enabled) { 'true' } else { 'false' }
    [string]$serialized = ConvertTo-TaskSchedulerXmlString -Document $document
    if ((Get-TaskContractFingerprint -XmlText $serialized) -ne
        (Get-TaskContractFingerprint -XmlText $XmlText)) {
        throw 'Enabled-state serialization changed the runnable task contract.'
    }
    return $serialized
}

function Get-LiveTaskXml {
    param([string]$TaskName)
    return Export-ScheduledTask -TaskPath '\' -TaskName $TaskName -ErrorAction Stop
}

function Get-FactoryOffSha256 {
    return Get-FileSha256 -Path $factoryOffFlagPath
}

function Assert-FactoryOffHash {
    param([string]$ExpectedSha256)
    $actual = Get-FactoryOffSha256
    if ($actual -ne $ExpectedSha256.ToLowerInvariant()) {
        throw "FACTORY_OFF.flag SHA-256 mismatch: expected=$ExpectedSha256 actual=$actual"
    }
    return $actual
}

function Assert-OwnerAuthorization {
    param([string]$DecisionRef, [string]$AuthorizedBy, [string]$AuthorizedAtUtc)
    foreach ($value in @($DecisionRef, $AuthorizedBy)) {
        if ([string]::IsNullOrWhiteSpace($value) -or $value.Length -lt 3 -or
            $value -match '(?i)TBD|PLACEHOLDER|UNKNOWN') {
            throw 'Fresh OWNER authorization contains a missing or placeholder value.'
        }
    }
    if ($AuthorizedAtUtc -notmatch '(?:Z|[+-]00:00)$') {
        throw 'OwnerAuthorizedAtUtc must use UTC (Z or +00:00).'
    }
    [datetimeoffset]$authorizedAt = [datetimeoffset]::MinValue
    if (-not [datetimeoffset]::TryParse(
        $AuthorizedAtUtc,
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::RoundtripKind,
        [ref]$authorizedAt
    )) {
        throw 'OwnerAuthorizedAtUtc is not a valid timestamp.'
    }
    $now = [datetimeoffset]::UtcNow
    if ($authorizedAt.ToUniversalTime() -gt $now.AddMinutes(5)) {
        throw 'OWNER authorization is more than five minutes in the future.'
    }
    if ($authorizedAt.ToUniversalTime() -lt $now.AddHours(-24)) {
        throw 'OWNER authorization has expired after 24 hours.'
    }
    return $authorizedAt.ToUniversalTime().ToString('o')
}

function Get-RepositorySourceCommit {
    $repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $value = @(& git -C $repoRoot rev-parse HEAD 2>$null)
    if ($LASTEXITCODE -ne 0 -or $value.Count -ne 1 -or $value[0] -notmatch '^[0-9a-f]{40}$') {
        throw 'Cannot bind task-contract plan to an exact repository commit.'
    }
    return [string]$value[0]
}

function New-TaskContractPlan {
    param([string]$OperationMode, [string]$Scope, [string]$FactoryOffSha256)
    $selected = if ($Scope -eq 'Factory') { $factoryTaskNames } else { $liveTaskNames }
    $allowedSource = if ($OperationMode -eq 'APPLY') { 'BEFORE' } else { 'AFTER' }
    $targetState = if ($OperationMode -eq 'APPLY') { 'AFTER' } else { 'BEFORE' }
    $entries = [Collections.Generic.List[object]]::new()
    $publicRows = [Collections.Generic.List[object]]::new()

    # Complete every package/live validation before a caller may mutate task 1.
    foreach ($name in $selected) {
        $before = Read-TaskXml 'before' $name
        $after = Read-TaskXml 'after' $name
        $rollback = Read-TaskXml 'rollback' $name
        $beforeFingerprint = Get-TaskContractFingerprint $before.text
        $afterFingerprint = Get-TaskContractFingerprint $after.text
        $rollbackFingerprint = Get-TaskContractFingerprint $rollback.text
        if ($beforeFingerprint -ne $rollbackFingerprint) {
            throw "Rollback does not reproduce BEFORE for $name"
        }
        $liveXml = Get-LiveTaskXml $name
        $liveFingerprint = Get-TaskContractFingerprint $liveXml
        $enabled = Get-TaskXmlEnabledState -XmlText $liveXml
        $liveState = if ($liveFingerprint -eq $beforeFingerprint) {
            'BEFORE'
        } elseif ($liveFingerprint -eq $afterFingerprint) {
            'AFTER'
        } else {
            'DRIFT'
        }
        $desiredContractXml = if ($OperationMode -eq 'APPLY') { $after.text } else { $rollback.text }
        $row = [ordered]@{
            task = $name
            live_state = $liveState
            enabled_before = $enabled
            allowed_source_state = $allowedSource
            target_state = $targetState
            live_contract_sha256 = $liveFingerprint
            target_contract_sha256 = Get-TaskContractFingerprint $desiredContractXml
            package_before_sha256 = $before.sha256
            package_after_sha256 = $after.sha256
            package_rollback_sha256 = $rollback.sha256
            action = if ($liveState -eq $allowedSource) { 'REGISTER' } elseif ($liveState -eq $targetState) { 'ALREADY_TARGET_REFUSE_REAPPLY' } else { 'REFUSE' }
        }
        $publicRows.Add([pscustomobject]$row)
        $entries.Add([pscustomobject]@{
            task = $name
            live_state = $liveState
            enabled_before = $enabled
            allowed_source_state = $allowedSource
            live_contract_sha256 = $liveFingerprint
            target_contract_sha256 = $row.target_contract_sha256
            original_xml = $liveXml
            original_registration_xml = ConvertTo-TaskSchedulerXmlString -Document ([xml]$liveXml)
            desired_xml = Set-TaskXmlEnabledState -XmlText $desiredContractXml -Enabled $enabled
        })
    }

    $packageAggregateText = @($publicRows | ForEach-Object {
        "$($_.task)|$($_.package_before_sha256)|$($_.package_after_sha256)|$($_.package_rollback_sha256)"
    }) -join "`n"

    $body = [ordered]@{
        schema_version = 'qm.task-contract-fix-plan/v1'
        package_id = 'task_contract_fix_2026-07-28'
        source_commit = Get-RepositorySourceCommit
        apply_script_sha256 = Get-FileSha256 -Path $PSCommandPath
        package_aggregate_sha256 = Get-TextSha256 -Text $packageAggregateText
        operation = $OperationMode
        scope = $Scope
        factory_off_flag = [ordered]@{
            path = $factoryOffFlagPath
            sha256 = $FactoryOffSha256
        }
        tasks = @($publicRows)
    }
    $canonical = $body | ConvertTo-Json -Depth 8 -Compress
    $planId = Get-TextSha256 -Text $canonical
    $document = [ordered]@{ plan_id = $planId }
    foreach ($key in $body.Keys) { $document[$key] = $body[$key] }
    return [pscustomobject]@{
        plan_id = $planId
        document = $document
        entries = @($entries)
    }
}

function Assert-PlanApplicable {
    param($Plan)
    $invalid = @($Plan.entries | Where-Object {
        $_.live_state -ne $_.allowed_source_state
    })
    if ($invalid.Count -gt 0) {
        $detail = @($invalid | ForEach-Object { "$($_.task)=$($_.live_state)" }) -join ', '
        throw "Plan source-state precondition failed: $detail"
    }
    if ($Plan.document.scope -eq 'Factory') {
        $enabledFactoryTasks = @($Plan.entries | Where-Object { $_.enabled_before })
        if ($enabledFactoryTasks.Count -gt 0) {
            $detail = @($enabledFactoryTasks | ForEach-Object { $_.task }) -join ', '
            throw "Factory-scope tasks must remain disabled during apply: $detail"
        }
    }
}

function Assert-TaskContractRegistrationPayloads {
    param($Plan)

    foreach ($entry in $Plan.entries) {
        Assert-TaskSchedulerXmlRegistrationPayload `
            -XmlText $entry.desired_xml `
            -TaskLabel "$($entry.task) desired"
        Assert-TaskSchedulerXmlRegistrationPayload `
            -XmlText $entry.original_registration_xml `
            -TaskLabel "$($entry.task) compensation"
    }
}

function Enter-TaskContractMutationLock {
    # Repeat the side-effect-free prerequisite assertion immediately before
    # CreateNew. Any missing protocol helper must fail before a lock exists.
    Assert-TaskContractMutationProtocolAvailable
    $stream = $null
    try {
        $stream = [IO.File]::Open(
            $factoryMutationLockPath,
            [IO.FileMode]::CreateNew,
            [IO.FileAccess]::ReadWrite,
            [IO.FileShare]::Read
        )
        $nonce = [guid]::NewGuid().ToString('N')
        $record = [ordered]@{
            pid = $PID
            owner = 'task_contract_fix_2026-07-28'
            nonce = $nonce
            created_at = [DateTime]::UtcNow.ToString('o')
        } | ConvertTo-Json -Compress
        $bytes = [Text.Encoding]::UTF8.GetBytes($record)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
        return [pscustomobject]@{
            stream = $stream
            nonce = $nonce
            raw_bytes_base64 = [Convert]::ToBase64String($bytes)
        }
    } catch {
        if ($null -ne $stream) { $stream.Dispose() }
        throw "Task-contract mutation lock unavailable: $($_.Exception.Message)"
    }
}

function Exit-TaskContractMutationLock {
    param($Lock)
    if ($null -eq $Lock) { return $true }
    $Lock.stream.Dispose()
    return Remove-QmFactoryMutationLockIfUnchanged `
        -Path $factoryMutationLockPath `
        -ExpectedRawBytesBase64 $Lock.raw_bytes_base64
}

function Assert-EntryCas {
    param($Entry)
    $currentXml = Get-LiveTaskXml $Entry.task
    $currentFingerprint = Get-TaskContractFingerprint $currentXml
    $currentEnabled = Get-TaskXmlEnabledState -XmlText $currentXml
    if ($currentFingerprint -ne $Entry.live_contract_sha256 -or
        $currentEnabled -ne $Entry.enabled_before) {
        throw "$($Entry.task) changed after locked preflight; refusing registration"
    }
}

function Restore-AttemptedTasks {
    param([object[]]$Attempted)
    $errors = [Collections.Generic.List[string]]::new()
    $results = [Collections.Generic.List[object]]::new()
    [array]::Reverse($Attempted)
    foreach ($entry in $Attempted) {
        try {
            Register-ScheduledTask -TaskPath '\' -TaskName $entry.task `
                -Xml $entry.original_registration_xml -Force -ErrorAction Stop | Out-Null
            $restoredXml = Get-LiveTaskXml $entry.task
            if ((Get-TaskContractFingerprint $restoredXml) -ne $entry.live_contract_sha256 -or
                (Get-TaskXmlEnabledState $restoredXml) -ne $entry.enabled_before) {
                throw 'restored task does not match captured preimage'
            }
            $results.Add([pscustomobject][ordered]@{
                task = $entry.task
                status = 'RESTORED_VERIFIED'
                error = $null
            })
        } catch {
            $errors.Add("$($entry.task): $($_.Exception.Message)")
            $results.Add([pscustomobject][ordered]@{
                task = $entry.task
                status = 'RESTORE_FAILED'
                error = $_.Exception.Message
            })
        }
    }
    return [pscustomobject]@{
        results = @($results)
        errors = @($errors)
    }
}

function Resolve-TaskContractReceiptPath {
    param([string]$Path)
    $fullPath = [IO.Path]::GetFullPath($Path)
    $rootPrefix = $receiptRoot.TrimEnd('\') + '\'
    if (-not $fullPath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetExtension($fullPath) -ne '.json') {
        throw "ReceiptPath must be a JSON file beneath $receiptRoot"
    }
    if (Test-Path -LiteralPath $fullPath) {
        throw "Create-only receipt already exists: $fullPath"
    }
    $parent = Split-Path -Parent $fullPath
    [IO.Directory]::CreateDirectory($parent) | Out-Null
    return $fullPath
}

function Join-TaskContractErrorMessage {
    param([string]$Primary, [string]$Additional)
    if ([string]::IsNullOrWhiteSpace($Primary)) { return $Additional }
    if ([string]::IsNullOrWhiteSpace($Additional)) { return $Primary }
    return "$Primary; $Additional"
}

function New-TaskContractReceiptDocument {
    param(
        $Plan,
        [string]$Mode,
        [string]$Scope,
        [string]$DecisionRef,
        [string]$AuthorizedBy,
        [string]$AuthorizedAtUtc,
        $Lock
    )
    $taskRows = @($Plan.entries | ForEach-Object {
        [ordered]@{
            task = $_.task
            pre_contract_sha256 = $_.live_contract_sha256
            pre_enabled = $_.enabled_before
            preimage_xml_base64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($_.original_xml))
            desired_contract_sha256 = $_.target_contract_sha256
            attempted = $false
            post_contract_sha256 = $null
            post_enabled = $null
            verification = 'PENDING'
        }
    })
    return [ordered]@{
        schema_version = 'qm.task-contract-fix-receipt/v1'
        package_id = 'task_contract_fix_2026-07-28'
        run_id = [guid]::NewGuid().ToString('D')
        started_at_utc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        completed_at_utc = $null
        plan_id = $Plan.plan_id
        source_commit = $Plan.document.source_commit
        apply_script_sha256 = $Plan.document.apply_script_sha256
        package_aggregate_sha256 = $Plan.document.package_aggregate_sha256
        operation = $Mode
        scope = $Scope
        owner_authorization = [ordered]@{
            authority = 'OWNER'
            authorized_by = $AuthorizedBy
            authorized_at_utc = $AuthorizedAtUtc
            decision_ref = $DecisionRef
        }
        factory_off_flag_sha256 = $Plan.document.factory_off_flag.sha256
        lock = [ordered]@{
            path = $factoryMutationLockPath
            protocol_version = 2
            owner = 'task_contract_fix_2026-07-28'
            nonce = $Lock.nonce
            release_status = 'HELD'
        }
        tasks = $taskRows
        compensation = [ordered]@{
            attempted = $false
            results = @()
        }
        authorization_boundaries = [ordered]@{
            factory_start = $false
            factory_restart = $false
            process_start = $false
            mt5 = $false
            autotrading = $false
            deployment = $false
        }
        failure = [ordered]@{
            primary_error = $null
            cleanup_error = $null
        }
        status = 'IN_PROGRESS'
    }
}

function Write-TaskContractReceiptState {
    param($Document, [string]$Path, [switch]$CreateOnly)
    $bytes = [Text.Encoding]::UTF8.GetBytes(($Document | ConvertTo-Json -Depth 10) + "`n")
    if ($CreateOnly.IsPresent) {
        $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
        try {
            $stream.Write($bytes, 0, $bytes.Length)
            $stream.Flush($true)
        } finally {
            $stream.Dispose()
        }
    } else {
        $temporary = "$Path.$PID.$([guid]::NewGuid().ToString('N')).tmp"
        try {
            $stream = [IO.File]::Open($temporary, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
            try {
                $stream.Write($bytes, 0, $bytes.Length)
                $stream.Flush($true)
            } finally {
                $stream.Dispose()
            }
            Move-Item -LiteralPath $temporary -Destination $Path -Force -ErrorAction Stop
        } finally {
            Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
        }
    }
    return [pscustomobject]@{
        path = $Path
        sha256 = Get-FileSha256 -Path $Path
    }
}

$mode = if ($Apply.IsPresent) { 'APPLY' } elseif ($Rollback.IsPresent) { 'ROLLBACK' } else { 'PLAN' }
if ([string]::IsNullOrWhiteSpace($TaskScope)) { $TaskScope = 'Factory' }
$operationMode = if ($mode -eq 'PLAN') { $PlanMode.ToUpperInvariant() } else { $mode }

if ($mode -eq 'PLAN') {
    $offSha = Get-FactoryOffSha256
    $plan = New-TaskContractPlan -OperationMode $operationMode -Scope $TaskScope -FactoryOffSha256 $offSha
    Assert-TaskContractRegistrationPayloads -Plan $plan
    if ($Json.IsPresent) {
        $plan.document | ConvertTo-Json -Depth 8
    } else {
        $plan.document.tasks | Format-Table task,live_state,enabled_before,allowed_source_state,target_state,action -AutoSize
        Write-Output "PLAN_ID $($plan.plan_id)"
        Write-Output "FACTORY_OFF_SHA256 $offSha"
    }
    exit 0
}

if ($TaskScope -ne 'Factory') {
    throw 'Live task contracts are plan-only in this package; use a separately reviewed OWNER package.'
}
$normalizedOwnerAuthorizedAtUtc = Assert-OwnerAuthorization `
    -DecisionRef $OwnerDecisionRef `
    -AuthorizedBy $OwnerAuthorizedBy `
    -AuthorizedAtUtc $OwnerAuthorizedAtUtc
$expectedOffSha = $ExpectedFactoryOffSha256.ToLowerInvariant()
$expectedPlan = $ExpectedPlanId.ToLowerInvariant()
[void](Assert-FactoryOffHash -ExpectedSha256 $expectedOffSha)

# -WhatIf is rigorously read-only: no lock file, receipt directory or task write.
if ($WhatIfPreference) {
    $preview = New-TaskContractPlan -OperationMode $operationMode -Scope $TaskScope -FactoryOffSha256 $expectedOffSha
    if ($preview.plan_id -ne $expectedPlan) {
        throw "ExpectedPlanId mismatch: expected=$expectedPlan actual=$($preview.plan_id)"
    }
    Assert-PlanApplicable -Plan $preview
    Assert-TaskContractRegistrationPayloads -Plan $preview
    foreach ($entry in $preview.entries) {
        [void]$PSCmdlet.ShouldProcess($entry.task, "Register scheduled-task contract $($preview.document.tasks[0].target_state)")
    }
    Write-Output "WHATIF_VALIDATED PLAN_ID $($preview.plan_id)"
    exit 0
}

# Perform the complete read-only plan/applicability/serialization preflight
# before acquiring the global mutation lock. The same checks are repeated
# under the lock below to preserve the original CAS and plan binding.
$preflight = New-TaskContractPlan -OperationMode $operationMode -Scope $TaskScope -FactoryOffSha256 $expectedOffSha
if ($preflight.plan_id -ne $expectedPlan) {
    throw "ExpectedPlanId mismatch: expected=$expectedPlan actual=$($preflight.plan_id)"
}
Assert-PlanApplicable -Plan $preflight
Assert-TaskContractRegistrationPayloads -Plan $preflight
Assert-TaskContractMutationProtocolAvailable

$lock = $null
$attempted = [Collections.Generic.List[object]]::new()
$receiptInfo = $null
$receiptDocument = $null
$fullReceiptPath = $null
$receiptOwned = $false
$mutationSucceeded = $false
$retainLock = $false
$deferredError = $null
try {
    $lock = Enter-TaskContractMutationLock
    [void](Assert-FactoryOffHash -ExpectedSha256 $expectedOffSha)
    $plan = New-TaskContractPlan -OperationMode $operationMode -Scope $TaskScope -FactoryOffSha256 $expectedOffSha
    if ($plan.plan_id -ne $expectedPlan) {
        throw "ExpectedPlanId mismatch: expected=$expectedPlan actual=$($plan.plan_id)"
    }
    Assert-PlanApplicable -Plan $plan
    Assert-TaskContractRegistrationPayloads -Plan $plan
    $fullReceiptPath = Resolve-TaskContractReceiptPath -Path $ReceiptPath
    $receiptDocument = New-TaskContractReceiptDocument `
        -Plan $plan `
        -Mode $operationMode `
        -Scope $TaskScope `
        -DecisionRef $OwnerDecisionRef `
        -AuthorizedBy $OwnerAuthorizedBy `
        -AuthorizedAtUtc $normalizedOwnerAuthorizedAtUtc `
        -Lock $lock
    $receiptInfo = Write-TaskContractReceiptState `
        -Document $receiptDocument `
        -Path $fullReceiptPath `
        -CreateOnly
    $receiptOwned = $true

    foreach ($entry in $plan.entries) {
        [void](Assert-FactoryOffHash -ExpectedSha256 $expectedOffSha)
        Assert-EntryCas -Entry $entry
        $receiptTask = @($receiptDocument.tasks | Where-Object { $_.task -eq $entry.task })[0]
        $receiptTask.attempted = $true
        $receiptTask.verification = 'ATTEMPTING'
        $receiptInfo = Write-TaskContractReceiptState `
            -Document $receiptDocument `
            -Path $fullReceiptPath
        $attempted.Add($entry)
        if ($PSCmdlet.ShouldProcess($entry.task, "Register scheduled-task contract $operationMode")) {
            Register-ScheduledTask -TaskPath '\' -TaskName $entry.task `
                -Xml $entry.desired_xml -Force -ErrorAction Stop | Out-Null
        }
        $verifiedXml = Get-LiveTaskXml $entry.task
        if ((Get-TaskContractFingerprint $verifiedXml) -ne $entry.target_contract_sha256 -or
            (Get-TaskXmlEnabledState $verifiedXml) -ne $entry.enabled_before) {
            throw "Post-register contract/Enabled verification failed for $($entry.task)"
        }
        $receiptTask.post_contract_sha256 = Get-TaskContractFingerprint $verifiedXml
        $receiptTask.post_enabled = Get-TaskXmlEnabledState $verifiedXml
        $receiptTask.verification = 'PASS'
        $receiptInfo = Write-TaskContractReceiptState `
            -Document $receiptDocument `
            -Path $fullReceiptPath
    }
    [void](Assert-FactoryOffHash -ExpectedSha256 $expectedOffSha)
    foreach ($entry in $plan.entries) {
        $postXml = Get-LiveTaskXml $entry.task
        if ((Get-TaskContractFingerprint $postXml) -ne $entry.target_contract_sha256 -or
            (Get-TaskXmlEnabledState $postXml) -ne $entry.enabled_before -or
            (Get-TaskXmlEnabledState $postXml)) {
            throw "Final scope verification failed for $($entry.task)"
        }
    }
    $receiptDocument.completed_at_utc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $receiptDocument.status = if ($operationMode -eq 'APPLY') {
        'APPLIED_VERIFIED'
    } else {
        'ROLLED_BACK_VERIFIED'
    }
    $receiptInfo = Write-TaskContractReceiptState `
        -Document $receiptDocument `
        -Path $fullReceiptPath
    $mutationSucceeded = $true
} catch {
    $failure = $_.Exception.Message
    if ($receiptOwned -and $null -ne $receiptDocument) {
        $receiptDocument.failure.primary_error = [ordered]@{
            captured_at_utc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            exception_type = $_.Exception.GetType().FullName
            fully_qualified_error_id = $_.FullyQualifiedErrorId
            message = $failure
        }
        try {
            $receiptInfo = Write-TaskContractReceiptState `
                -Document $receiptDocument `
                -Path $fullReceiptPath
        } catch {
            $failure = Join-TaskContractErrorMessage `
                -Primary $failure `
                -Additional "failure receipt update failed: $($_.Exception.Message)"
        }
    }
    $recovery = Restore-AttemptedTasks -Attempted @($attempted)
    if ($receiptOwned -and $null -ne $receiptDocument) {
        $receiptDocument.compensation.attempted = ($attempted.Count -gt 0)
        $receiptDocument.compensation.results = @($recovery.results)
        $receiptDocument.completed_at_utc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        if ($recovery.errors.Count -gt 0) {
            $receiptDocument.status = 'FAILED_UNCOMPENSATED_LOCK_RETAINED'
        } else {
            $receiptDocument.status = 'FAILED_COMPENSATED'
        }
        try {
            $receiptInfo = Write-TaskContractReceiptState `
                -Document $receiptDocument `
                -Path $fullReceiptPath
        } catch {
            $failure = "$failure; receipt update failed: $($_.Exception.Message)"
        }
    }
    if ($recovery.errors.Count -gt 0) {
        $retainLock = $true
        $deferredError = "Task-contract mutation failed: $failure; COMPENSATION_FAILED: $($recovery.errors -join '; ')"
    } else {
        $deferredError = "Task-contract mutation failed: $failure; compensation=PASS"
    }
} finally {
    if ($null -ne $lock) {
        if ($retainLock) {
            try {
                $lock.stream.Dispose()
            } catch {
                $retainDisposeError = $_
                $retainDisposeMessage = "Retained mutation-lock handle disposal failed: $($retainDisposeError.Exception.Message)"
                $deferredError = Join-TaskContractErrorMessage `
                    -Primary $deferredError `
                    -Additional $retainDisposeMessage
                if ($receiptOwned -and $null -ne $receiptDocument) {
                    $receiptDocument.failure.cleanup_error = [ordered]@{
                        captured_at_utc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
                        code = 'RETAINED_LOCK_DISPOSE_EXCEPTION'
                        exception_type = $retainDisposeError.Exception.GetType().FullName
                        fully_qualified_error_id = $retainDisposeError.FullyQualifiedErrorId
                        message = $retainDisposeError.Exception.Message
                    }
                }
            }
            if ($receiptOwned -and $null -ne $receiptDocument) {
                $receiptDocument.lock.release_status = 'RETAINED_FAIL_CLOSED'
                try {
                    $receiptInfo = Write-TaskContractReceiptState `
                        -Document $receiptDocument `
                        -Path $fullReceiptPath
                } catch {}
            }
        } else {
            $released = $false
            $releaseThrew = $false
            try {
                $released = Exit-TaskContractMutationLock -Lock $lock
            } catch {
                $releaseThrew = $true
                $releaseError = $_
                try { $lock.stream.Dispose() } catch {}
                $cleanupMessage = "LOCK_CLEANUP_FAILED: $($releaseError.Exception.Message)"
                if ($receiptOwned -and $null -ne $receiptDocument) {
                    $receiptDocument.lock.release_status = 'RETAINED_CLEANUP_ERROR'
                    $receiptDocument.failure.cleanup_error = [ordered]@{
                        captured_at_utc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
                        code = 'LOCK_RELEASE_EXCEPTION'
                        exception_type = $releaseError.Exception.GetType().FullName
                        fully_qualified_error_id = $releaseError.FullyQualifiedErrorId
                        message = $releaseError.Exception.Message
                    }
                    if ($mutationSucceeded) {
                        $receiptDocument.status = "$($receiptDocument.status)_LOCK_RETAINED"
                    }
                    try {
                        $receiptInfo = Write-TaskContractReceiptState `
                            -Document $receiptDocument `
                            -Path $fullReceiptPath
                    } catch {
                        $cleanupMessage = Join-TaskContractErrorMessage `
                            -Primary $cleanupMessage `
                            -Additional "cleanup receipt update failed: $($_.Exception.Message)"
                    }
                }
                $deferredError = Join-TaskContractErrorMessage `
                    -Primary $deferredError `
                    -Additional $cleanupMessage
            }
            if (-not $releaseThrew) {
                if (-not $released) {
                    $cleanupMessage = 'Task-contract mutation lock identity release failed; retained fail-closed for OWNER inspection.'
                    if ($receiptOwned -and $null -ne $receiptDocument) {
                        $receiptDocument.lock.release_status = 'RETAINED_IDENTITY_RELEASE_FAILED'
                        $receiptDocument.failure.cleanup_error = [ordered]@{
                            captured_at_utc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
                            code = 'IDENTITY_RELEASE_FAILED'
                            exception_type = $null
                            fully_qualified_error_id = $null
                            message = $cleanupMessage
                        }
                        if ($mutationSucceeded) {
                            $receiptDocument.status = "$($receiptDocument.status)_LOCK_RETAINED"
                        }
                        try {
                            $receiptInfo = Write-TaskContractReceiptState `
                                -Document $receiptDocument `
                                -Path $fullReceiptPath
                        } catch {
                            $cleanupMessage = Join-TaskContractErrorMessage `
                                -Primary $cleanupMessage `
                                -Additional "cleanup receipt update failed: $($_.Exception.Message)"
                        }
                    }
                    $deferredError = Join-TaskContractErrorMessage `
                        -Primary $deferredError `
                        -Additional $cleanupMessage
                } elseif ($receiptOwned -and $null -ne $receiptDocument) {
                    $receiptDocument.lock.release_status = 'RELEASED_EXACT_IDENTITY'
                    try {
                        $receiptInfo = Write-TaskContractReceiptState `
                            -Document $receiptDocument `
                            -Path $fullReceiptPath
                    } catch {
                        $receiptFinalizeError = "Task-contract receipt finalization failed after safe lock release: $($_.Exception.Message)"
                        $deferredError = Join-TaskContractErrorMessage `
                            -Primary $deferredError `
                            -Additional $receiptFinalizeError
                    }
                }
            }
        }
    }
}

if (-not [string]::IsNullOrWhiteSpace($deferredError)) {
    throw $deferredError
}
if (-not $mutationSucceeded -or $null -eq $receiptInfo) {
    throw 'Task-contract mutation ended without a verified receipt.'
}
Write-Output "$operationMode PLAN_ID $($plan.plan_id)"
Write-Output "RECEIPT $($receiptInfo.path) SHA256 $($receiptInfo.sha256)"
