[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$controllerPath = Join-Path $repoRoot 'framework\scripts\run_dev2_smoke.ps1'
$childPath = Join-Path $repoRoot 'framework\scripts\invoke_dev2_smoke_task.ps1'
$cleanupPath = Join-Path $repoRoot 'framework\scripts\cleanup_dev2_account_lease.ps1'
$credentialHelperPath = Join-Path $repoRoot 'framework\scripts\dev2_machine_credential.ps1'
$credentialProbePath = Join-Path $repoRoot 'framework\scripts\probe_dev2_machine_credential.ps1'
$credentialRotatePath = Join-Path $repoRoot 'framework\scripts\rotate_dev2_machine_credential.ps1'
$identityProbePath = Join-Path $repoRoot 'framework\scripts\invoke_dev2_identity_probe.ps1'

function Get-QmScriptAst {
    param([Parameter(Mandatory = $true)][string]$Path)
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $Path, [ref]$tokens, [ref]$errors
    )
    if (@($errors).Count -gt 0) {
        throw "PowerShell parse errors in '$Path': $($errors | Out-String)"
    }
    return $ast
}

function Get-QmFunctionTextFromAst {
    param(
        [Parameter(Mandatory = $true)]$Ast,
        [Parameter(Mandatory = $true)][string]$Name
    )
    $functionAst = $Ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq $Name
    }, $true)
    if ($null -eq $functionAst) { throw "$Name function not found." }
    return $functionAst.Extent.Text
}

$script:PerAttemptOverheadSeconds = 600
$script:ControllerFinalizationMarginSeconds = 600
$controllerAst = Get-QmScriptAst -Path $controllerPath
$childAst = Get-QmScriptAst -Path $childPath
$null = Get-QmScriptAst -Path $credentialHelperPath
$null = Get-QmScriptAst -Path $credentialProbePath
$rotationAst = Get-QmScriptAst -Path $credentialRotatePath
$identityProbeAst = Get-QmScriptAst -Path $identityProbePath
Invoke-Expression (Get-QmFunctionTextFromAst -Ast $controllerAst -Name 'Get-QmMinimumDev2ControllerTimeoutSeconds')
$controllerMinimum = Get-QmMinimumDev2ControllerTimeoutSeconds `
    -MaximumRunAttempts 4 -RunTimeoutSeconds 28800
if ($controllerMinimum -ne 118200) {
    throw "Controller timeout arithmetic drifted: $controllerMinimum"
}
if ((Get-QmMinimumDev2ControllerTimeoutSeconds -MaximumRunAttempts 10 -RunTimeoutSeconds 28800) -le 172800) {
    throw 'An underbudgeted ten-attempt maximum was not above the controller hard limit.'
}

& {
    $script:MockOwnerLookup = 'PASS'
    function New-QmMockCimException {
        param([Parameter(Mandatory = $true)][Microsoft.Management.Infrastructure.NativeErrorCode]$NativeErrorCode)
        $exception = [Microsoft.Management.Infrastructure.CimException]::new('synthetic CIM failure')
        $field = [Microsoft.Management.Infrastructure.CimException].GetField(
            '<NativeErrorCode>k__BackingField',
            [System.Reflection.BindingFlags]'Instance,NonPublic'
        )
        $field.SetValue($exception, $NativeErrorCode)
        return $exception
    }
    function Invoke-CimMethod {
        param(
            [object]$InputObject,
            [string]$MethodName,
            [object]$ErrorAction
        )
        switch ($script:MockOwnerLookup) {
            'NOT_FOUND' {
                throw (New-QmMockCimException -NativeErrorCode NotFound)
            }
            'ACCESS_DENIED' {
                throw (New-QmMockCimException -NativeErrorCode AccessDenied)
            }
            'UNREADABLE' {
                return [pscustomobject]@{ ReturnValue = 2; Sid = $null }
            }
            default {
                return [pscustomobject]@{ ReturnValue = 0; Sid = 'S-1-5-21-1-2-3-1006' }
            }
        }
    }

    Invoke-Expression (Get-QmFunctionTextFromAst -Ast $childAst -Name 'Get-QmProcessOwnerSid')
    $process = [pscustomobject]@{ ProcessId = 9001 }
    $script:MockOwnerLookup = 'NOT_FOUND'
    if ($null -ne (Get-QmProcessOwnerSid -ProcessRecord $process)) {
        throw 'Explicit CIM NotFound did not map to the exited-process sentinel.'
    }
    $script:MockOwnerLookup = 'ACCESS_DENIED'
    $otherCimFailureRejected = $false
    try {
        Get-QmProcessOwnerSid -ProcessRecord $process | Out-Null
    } catch [Microsoft.Management.Infrastructure.CimException] {
        $otherCimFailureRejected = (
            $_.Exception.NativeErrorCode -eq [Microsoft.Management.Infrastructure.NativeErrorCode]::AccessDenied
        )
    }
    if (-not $otherCimFailureRejected) {
        throw 'A non-NotFound CIM owner lookup failure was not propagated fail-closed.'
    }
    $script:MockOwnerLookup = 'UNREADABLE'
    $unreadableRejected = $false
    try {
        Get-QmProcessOwnerSid -ProcessRecord $process | Out-Null
    } catch {
        $unreadableRejected = $_.Exception.Message -like '*unreadable result*'
    }
    if (-not $unreadableRejected) {
        throw 'A live but unreadable owner result was not rejected fail-closed.'
    }
}

& {
    $script:Dev2Root = 'D:\QM\mt5\DEV2'
    $script:MockOwnerSid = 'S-1-5-21-1-2-3-1006'
    $script:MockProcesses = @(
        [pscustomobject]@{
            ProcessId = 9001
            ExecutablePath = 'D:\QM\mt5\DEV2\metatester64.exe'
            CreationDate = [DateTimeOffset]::UtcNow
        }
    )
    $script:MockListeners = @()
    $script:UseMockPidProcesses = $false
    $script:MockPidProcesses = @()
    $script:UseMockPidProcessSequence = $false
    $script:MockPidProcessSequence = @()
    $script:MockPidLookupCount = 0
    $script:OwnerLookupCount = 0

    function ConvertTo-QmFullPath {
        param([Parameter(Mandatory = $true)][string]$Path)
        return [System.IO.Path]::GetFullPath($Path)
    }
    function Get-QmProcessOwnerSid {
        param([Parameter(Mandatory = $true)][object]$ProcessRecord)
        $script:OwnerLookupCount++
        return $script:MockOwnerSid
    }
    function Get-CimInstance {
        param(
            [string]$ClassName,
            [string]$Filter,
            [string[]]$Property,
            [object]$ErrorAction
        )
        if ($Filter -like 'ProcessId = *' -and $script:UseMockPidProcessSequence) {
            $index = [Math]::Min(
                $script:MockPidLookupCount,
                $script:MockPidProcessSequence.Count - 1
            )
            $script:MockPidLookupCount++
            return @($script:MockPidProcessSequence[$index])
        }
        if ($Filter -like 'ProcessId = *' -and $script:UseMockPidProcesses) {
            return @($script:MockPidProcesses)
        }
        return @($script:MockProcesses)
    }
    function Get-NetTCPConnection {
        param(
            [string]$State,
            [int]$OwningProcess,
            [int]$LocalPort,
            [object]$ErrorAction
        )
        $rows = @($script:MockListeners)
        if ($PSBoundParameters.ContainsKey('OwningProcess')) {
            $rows = @($rows | Where-Object { [int]$_.OwningProcess -eq $OwningProcess })
        }
        if ($PSBoundParameters.ContainsKey('LocalPort')) {
            $rows = @($rows | Where-Object { [int]$_.LocalPort -eq $LocalPort })
        }
        return $rows
    }

    Invoke-Expression (Get-QmFunctionTextFromAst -Ast $childAst -Name 'Test-QmListenerAddressesOverlap')
    Invoke-Expression (Get-QmFunctionTextFromAst -Ast $childAst -Name 'Get-QmLiveProcessById')
    Invoke-Expression (Get-QmFunctionTextFromAst -Ast $childAst -Name 'Test-QmSameProcessGeneration')
    Invoke-Expression (Get-QmFunctionTextFromAst -Ast $childAst -Name 'Update-QmDev2AgentListenerProof')
    $portContract = [ordered]@{ minimum_port = 3000; maximum_port = 65535 }
    $baseline = @{
        '3004' = @([pscustomobject]@{ local_address = '127.0.0.1'; owning_process = 17436 })
    }

    $script:MockListeners = @(
        [pscustomobject]@{ LocalAddress = '127.0.0.1'; LocalPort = 3004; OwningProcess = 9001 }
    )
    $seen = @{}
    Update-QmDev2AgentListenerProof -Baseline $baseline -Seen $seen `
        -ExpectedOwnerSid $script:MockOwnerSid -EarliestCreationUtc ([DateTimeOffset]::UtcNow.AddSeconds(-1)) `
        -PortContract $portContract
    if ($seen.Count -ne 1) { throw 'Released baseline endpoint was not accepted exactly once.' }
    $proof = @($seen.Values)[0]
    if (-not [bool]$proof.baseline_endpoint_was_occupied -or
        [int]$proof.released_baseline_owner_count -ne 1 -or
        [int]$proof.current_overlapping_owner_count -ne 1 -or
        -not [bool]$proof.exclusive_current_owner -or
        [bool]$proof.concurrent_port_owner) {
        throw 'Released baseline endpoint proof fields drifted.'
    }

    foreach ($conflictingAddress in @('127.0.0.1', '::ffff:127.0.0.1', '0.0.0.0', '::')) {
        $script:MockListeners = @(
            [pscustomobject]@{ LocalAddress = '127.0.0.1'; LocalPort = 3004; OwningProcess = 9001 },
            [pscustomobject]@{ LocalAddress = $conflictingAddress; LocalPort = 3004; OwningProcess = 17436 }
        )
        $rejected = $false
        try {
            Update-QmDev2AgentListenerProof -Baseline $baseline -Seen @{} `
                -ExpectedOwnerSid $script:MockOwnerSid -EarliestCreationUtc ([DateTimeOffset]::UtcNow.AddSeconds(-1)) `
                -PortContract $portContract
        } catch {
            $rejected = $true
        }
        if (-not $rejected) { throw "Concurrent overlapping endpoint was accepted: $conflictingAddress" }
    }

    $script:MockListeners = @(
        [pscustomobject]@{ LocalAddress = '127.0.0.1'; LocalPort = 3004; OwningProcess = 9001 },
        [pscustomobject]@{ LocalAddress = '192.0.2.10'; LocalPort = 3004; OwningProcess = 17436 }
    )
    $seen = @{}
    Update-QmDev2AgentListenerProof -Baseline $baseline -Seen $seen `
        -ExpectedOwnerSid $script:MockOwnerSid -EarliestCreationUtc ([DateTimeOffset]::UtcNow.AddSeconds(-1)) `
        -PortContract $portContract
    if ($seen.Count -ne 1) { throw 'Non-overlapping address on the same port was rejected.' }

    $script:MockListeners = @()
    $script:MockOwnerSid = $null
    $seen = @{}
    Update-QmDev2AgentListenerProof -Baseline $baseline -Seen $seen `
        -ExpectedOwnerSid 'S-1-5-21-1-2-3-1006' -EarliestCreationUtc ([DateTimeOffset]::UtcNow.AddSeconds(-1)) `
        -PortContract $portContract
    if ($seen.Count -ne 0) {
        throw 'An owner-lookup NotFound race created a listener proof.'
    }

    $script:MockOwnerSid = 'S-1-5-18'
    $wrongOwnerRejected = $false
    try {
        Update-QmDev2AgentListenerProof -Baseline $baseline -Seen @{} `
            -ExpectedOwnerSid 'S-1-5-21-1-2-3-1006' -EarliestCreationUtc ([DateTimeOffset]::UtcNow.AddSeconds(-1)) `
            -PortContract $portContract
    } catch {
        $wrongOwnerRejected = $_.Exception.Message -like '*wrong owner SID*'
    }
    if (-not $wrongOwnerRejected) {
        throw 'A stable exact-path process with a readable wrong SID was not rejected.'
    }

    $script:MockOwnerSid = 'S-1-5-21-1-2-3-1006'
    $script:UseMockPidProcesses = $true
    $script:MockPidProcesses = @(
        [pscustomobject]@{
            ProcessId = 9001
            ExecutablePath = 'D:\QM\mt5\DEV2\metatester64.exe'
            CreationDate = ([DateTimeOffset]$script:MockProcesses[0].CreationDate).AddSeconds(1)
        }
    )
    $ownerLookupsBeforeDrift = $script:OwnerLookupCount
    $seen = @{}
    Update-QmDev2AgentListenerProof -Baseline $baseline -Seen $seen `
        -ExpectedOwnerSid $script:MockOwnerSid -EarliestCreationUtc ([DateTimeOffset]::UtcNow.AddSeconds(-1)) `
        -PortContract $portContract
    if ($seen.Count -ne 0 -or $script:OwnerLookupCount -ne $ownerLookupsBeforeDrift) {
        throw 'PID reuse/process-generation drift was not skipped before owner attribution.'
    }

    $script:UseMockPidProcesses = $false
    $script:UseMockPidProcessSequence = $true
    $script:MockPidLookupCount = 0
    $postListenerGeneration = [pscustomobject]@{
        ProcessId = 9001
        ExecutablePath = 'D:\QM\mt5\DEV2\metatester64.exe'
        CreationDate = ([DateTimeOffset]$script:MockProcesses[0].CreationDate).AddSeconds(2)
    }
    $script:MockPidProcessSequence = @(
        $script:MockProcesses[0],
        $script:MockProcesses[0],
        $postListenerGeneration
    )
    $script:MockListeners = @(
        [pscustomobject]@{ LocalAddress = '127.0.0.1'; LocalPort = 3004; OwningProcess = 9001 },
        [pscustomobject]@{ LocalAddress = '127.0.0.1'; LocalPort = 3004; OwningProcess = 17436 }
    )
    $seen = @{}
    Update-QmDev2AgentListenerProof -Baseline $baseline -Seen $seen `
        -ExpectedOwnerSid $script:MockOwnerSid -EarliestCreationUtc ([DateTimeOffset]::UtcNow.AddSeconds(-1)) `
        -PortContract $portContract
    if ($seen.Count -ne 0 -or $script:MockPidLookupCount -ne 3) {
        throw 'Post-listener PID generation drift was evaluated or published instead of skipped.'
    }
}

Remove-Item -LiteralPath Function:\Get-QmMinimumDev2ControllerTimeoutSeconds -ErrorAction Stop
Invoke-Expression (Get-QmFunctionTextFromAst -Ast $childAst -Name 'Get-QmMinimumDev2ControllerTimeoutSeconds')
$childMinimum = Get-QmMinimumDev2ControllerTimeoutSeconds `
    -MaximumRunAttempts 4 -RunTimeoutSeconds 28800
if ($childMinimum -ne $controllerMinimum) {
    throw "Controller/child timeout arithmetic differs: controller=$controllerMinimum child=$childMinimum"
}

Invoke-Expression (Get-QmFunctionTextFromAst -Ast $controllerAst -Name 'ConvertTo-QmFullPath')
Invoke-Expression (Get-QmFunctionTextFromAst -Ast $controllerAst -Name 'Assert-QmNoReparseComponents')
Invoke-Expression (Get-QmFunctionTextFromAst -Ast $controllerAst -Name 'Assert-QmImmediateCleanupDisarmReceipt')
Invoke-Expression (Get-QmFunctionTextFromAst -Ast $controllerAst -Name 'Read-QmExactImmediateCleanupEvidence')
Invoke-Expression (Get-QmFunctionTextFromAst -Ast $controllerAst -Name 'Assert-QmCleanupEvidenceAfterActionFence')
$expectedResultPath = 'D:\QM\reports\dev2\runs\test\control\cleanup_lease.result.json'
$receipt = [pscustomobject]@{
    artifact_type = 'QM_DEV2_ACCOUNT_CLEANUP_DISARM_RESULT'
    success = $true
    containment_verified = $true
    lease_disarmed = $true
    account_restored_disabled = $true
    owner_process_count = 0
    dev2_root_process_count = 0
    target_task_registered = $false
    cleanup_task_registered = $false
    expected_sid = 'S-1-5-21-1'
    target_task_name = 'QM_DEV2_SMOKE_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    cleanup_task_name = 'QM_DEV2_CLEANUP_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    containment_result_path = $expectedResultPath
}
Assert-QmImmediateCleanupDisarmReceipt -Receipt $receipt `
    -ExpectedSid $receipt.expected_sid -ExpectedTargetTaskName $receipt.target_task_name `
    -ExpectedCleanupTaskName $receipt.cleanup_task_name `
    -ExpectedContainmentResultPath $expectedResultPath

foreach ($tamper in @(
    @{ Field = 'success'; Value = 'true' },
    @{ Field = 'expected_sid'; Value = 'S-1-5-21-2' },
    @{ Field = 'target_task_name'; Value = 'QM_DEV2_SMOKE_cccccccccccccccccccccccccccccccc' },
    @{ Field = 'cleanup_task_name'; Value = 'QM_DEV2_CLEANUP_dddddddddddddddddddddddddddddddd' },
    @{ Field = 'containment_result_path'; Value = 'D:\QM\reports\dev2\runs\test\output\cleanup_lease.result.json' }
)) {
    $candidate = $receipt.PSObject.Copy()
    $candidate.($tamper.Field) = $tamper.Value
    $rejected = $false
    try {
        Assert-QmImmediateCleanupDisarmReceipt -Receipt $candidate `
            -ExpectedSid $receipt.expected_sid -ExpectedTargetTaskName $receipt.target_task_name `
            -ExpectedCleanupTaskName $receipt.cleanup_task_name `
            -ExpectedContainmentResultPath $expectedResultPath
    } catch {
        $rejected = $true
    }
    if (-not $rejected) { throw "Cleanup receipt tamper was accepted: $($tamper.Field)" }
}

$evidenceTestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('qm-dev2-controller-evidence-' + [guid]::NewGuid().ToString('N'))
[void][System.IO.Directory]::CreateDirectory($evidenceTestRoot)
try {
    $resultPath = Join-Path $evidenceTestRoot 'cleanup_lease.result.json'
    $disarmPath = Join-Path $evidenceTestRoot 'cleanup_lease.disarm.result.json'
    $resultPayload = [ordered]@{
        schema_version = 1
        artifact_type = 'QM_DEV2_ACCOUNT_CLEANUP_RESULT'
        completed_utc = [DateTimeOffset]::UtcNow.ToString('o')
        success = $true
        containment_verified = $true
        lease_disarmed = $false
        expected_sid = $receipt.expected_sid
        target_task_name = $receipt.target_task_name
        cleanup_task_name = $receipt.cleanup_task_name
        manifest_valid = $true
        account_restored_disabled = $true
        owner_process_count = 0
        dev2_root_process_count = 0
        target_task_registered = $false
        cleanup_task_registered = $true
        failures = @()
    }
    $disarmPayload = [ordered]@{
        schema_version = 1
        artifact_type = 'QM_DEV2_ACCOUNT_CLEANUP_DISARM_RESULT'
        completed_utc = [DateTimeOffset]::UtcNow.ToString('o')
        success = $true
        containment_result_path = $resultPath
        containment_verified = $true
        lease_disarmed = $true
        expected_sid = $receipt.expected_sid
        target_task_name = $receipt.target_task_name
        cleanup_task_name = $receipt.cleanup_task_name
        account_restored_disabled = $true
        owner_process_count = 0
        dev2_root_process_count = 0
        target_task_registered = $false
        cleanup_task_registered = $false
        failures = @()
    }
    [System.IO.File]::WriteAllText($resultPath, ($resultPayload | ConvertTo-Json -Compress), [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($disarmPath, ($disarmPayload | ConvertTo-Json -Compress), [System.Text.UTF8Encoding]::new($false))
    Assert-QmCleanupEvidenceAfterActionFence -ResultPath $resultPath -DisarmPath $disarmPath `
        -ExpectedSid $receipt.expected_sid -ExpectedTargetTaskName $receipt.target_task_name `
        -ExpectedCleanupTaskName $receipt.cleanup_task_name

    $resultPayload.success = $false
    [System.IO.File]::WriteAllText($resultPath, ($resultPayload | ConvertTo-Json -Compress), [System.Text.UTF8Encoding]::new($false))
    $failedResultRejected = $false
    try {
        Assert-QmCleanupEvidenceAfterActionFence -ResultPath $resultPath -DisarmPath $disarmPath `
            -ExpectedSid $receipt.expected_sid -ExpectedTargetTaskName $receipt.target_task_name `
            -ExpectedCleanupTaskName $receipt.cleanup_task_name
    } catch { $failedResultRejected = $true }
    if (-not $failedResultRejected) { throw 'A failed cleanup result passed the post-fence controller validator.' }

    [System.IO.File]::Delete($resultPath)
    $orphanDisarmRejected = $false
    try {
        Assert-QmCleanupEvidenceAfterActionFence -ResultPath $resultPath -DisarmPath $disarmPath `
            -ExpectedSid $receipt.expected_sid -ExpectedTargetTaskName $receipt.target_task_name `
            -ExpectedCleanupTaskName $receipt.cleanup_task_name
    } catch { $orphanDisarmRejected = $true }
    if (-not $orphanDisarmRejected) { throw 'Orphan cleanup disarm evidence passed the post-fence controller validator.' }
} finally {
    if (Test-Path -LiteralPath $evidenceTestRoot -PathType Container) {
        [System.IO.Directory]::Delete($evidenceTestRoot, $true)
    }
}

$controllerText = Get-Content -LiteralPath $controllerPath -Raw -ErrorAction Stop
$cleanupText = Get-Content -LiteralPath $cleanupPath -Raw -ErrorAction Stop
$childText = Get-Content -LiteralPath $childPath -Raw -ErrorAction Stop
$rotationText = Get-Content -LiteralPath $credentialRotatePath -Raw -ErrorAction Stop
$identityProbeText = Get-Content -LiteralPath $identityProbePath -Raw -ErrorAction Stop
foreach ($marker in @(
    "Join-Path `$controlDirectory 'cleanup_lease.result.json'",
    "Join-Path `$controlDirectory 'cleanup_lease.disarm.result.json'",
    'Immediate SYSTEM cleanup lease failed independent host containment postchecks.',
    'QM_DEV2_PROFILE_INIT_', 'Global\QM_DEV2_CLEANUP_ACTION_',
    'cleanup_action_mutex = $cleanupActionMutexName', '-CleanupActionMutex',
    'Enter-QmCleanupActionMutex -Name $cleanupActionMutexName',
    'while ($null -ne $cursor)'
)) {
    if (-not $controllerText.Contains($marker, [System.StringComparison]::Ordinal)) {
        throw "Protected cleanup controller marker is missing: $marker"
    }
}
foreach ($marker in @(
        'ExpectedCredentialSha256', 'ExpectedHelperSha256',
        'machine_credential_sha256', 'machine_credential_helper_sha256',
        'Read-QmDev2MachineCredentialEnvelope', 'Get-QmDev2MachineCredential'
    )) {
    if (-not $controllerText.Contains($marker, [System.StringComparison]::Ordinal)) {
        throw "Machine-credential controller marker is missing: $marker"
    }
}
foreach ($marker in @(
        "'machine_credential_path'", "'machine_credential_sha256'",
        "'machine_credential_helper_path'", "'machine_credential_helper_sha256'",
        'machine_credential_sha256 = $machineCredentialSha256',
        'machine_credential_helper_sha256 = $machineCredentialHelperSha256'
    )) {
    if (-not $childText.Contains($marker, [System.StringComparison]::Ordinal)) {
        throw "Limited child machine-credential binding marker is missing: $marker"
    }
}
foreach ($forbidden in @('Import-Clixml', 'ProtectedData', 'Get-QmDev2MachineCredential')) {
    if ($childText.Contains($forbidden, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Limited smoke child may not read or decrypt the machine credential: $forbidden"
    }
}
$cleanupRegisterIndex = $controllerText.IndexOf('Register-ScheduledTask -TaskName $cleanupTaskName', [System.StringComparison]::Ordinal)
$credentialDecryptIndex = $controllerText.IndexOf('$credential = Get-QmDev2MachineCredential', [System.StringComparison]::Ordinal)
$accountEnableIndex = $controllerText.IndexOf('$dev2AccountEnabledByController = Enable-QmDev2ControllerAccountState', [System.StringComparison]::Ordinal)
if ($cleanupRegisterIndex -lt 0 -or $credentialDecryptIndex -le $cleanupRegisterIndex -or
    $accountEnableIndex -le $credentialDecryptIndex) {
    throw 'Controller must arm SYSTEM cleanup before just-in-time decrypt and account enable.'
}
$noDev2TasksText = Get-QmFunctionTextFromAst -Ast $controllerAst -Name 'Assert-QmNoDev2Tasks'
if (-not $noDev2TasksText.Contains('$script:ProfileTaskNamePrefix', [System.StringComparison]::Ordinal)) {
    throw 'DEV2 controller task preflight does not include the bound profile-init task family.'
}
$cleanupMutexDerivationIndex = $controllerText.IndexOf('$cleanupActionMutexName = "$($script:CleanupActionMutexPrefix)$nonce"', [System.StringComparison]::Ordinal)
$cleanupLeaseMutexIndex = $controllerText.IndexOf('cleanup_action_mutex = $cleanupActionMutexName', [System.StringComparison]::Ordinal)
$cleanupMutexArgumentIndex = $controllerText.IndexOf('-CleanupActionMutex "{5}"', [System.StringComparison]::Ordinal)
if ($cleanupMutexDerivationIndex -lt 0 -or $cleanupLeaseMutexIndex -le $cleanupMutexDerivationIndex -or
    $cleanupMutexArgumentIndex -le $cleanupLeaseMutexIndex -or $cleanupRegisterIndex -le $cleanupMutexArgumentIndex) {
    throw 'Controller did not bind the per-run cleanup action mutex through nonce, lease, and exact task arguments before registration.'
}
$controllerFinallyIndex = $controllerText.LastIndexOf('$plainPassword = $null', [System.StringComparison]::Ordinal)
$targetDrainIndex = $controllerText.IndexOf('Remove-QmScheduledTaskBounded -TaskName $taskName -DisableBeforeStop', $controllerFinallyIndex, [System.StringComparison]::Ordinal)
$firstProcessSweepIndex = $controllerText.IndexOf('Stop-QmDev2ProcessesExact -ExpectedOwnerSid', $targetDrainIndex, [System.StringComparison]::Ordinal)
$accountRestoreIndex = $controllerText.IndexOf('$dev2AccountRestoredDisabled = Restore-QmDev2ControllerAccountState', $firstProcessSweepIndex, [System.StringComparison]::Ordinal)
$secondProcessSweepIndex = $controllerText.IndexOf('Stop-QmDev2ProcessesExact -ExpectedOwnerSid', $accountRestoreIndex, [System.StringComparison]::Ordinal)
$containmentReassertIndex = $controllerText.IndexOf('Assert-QmDev2ContainedBeforeCleanupLeaseDisarm', $secondProcessSweepIndex, [System.StringComparison]::Ordinal)
$normalDisarmIndex = $controllerText.IndexOf('if ($cleanupTaskRegistered -and -not [string]::IsNullOrWhiteSpace($cleanupTaskName) -and $cleanupErrors.Count -eq 0)', [System.StringComparison]::Ordinal)
if ($controllerFinallyIndex -lt 0 -or $targetDrainIndex -le $controllerFinallyIndex -or
    $firstProcessSweepIndex -le $targetDrainIndex -or $accountRestoreIndex -le $firstProcessSweepIndex -or
    $secondProcessSweepIndex -le $accountRestoreIndex -or $containmentReassertIndex -le $secondProcessSweepIndex -or
    $normalDisarmIndex -le $containmentReassertIndex) {
    throw 'Target task/process/account containment is not reasserted before cleanup-lease disarm.'
}
$normalCleanupDrainIndex = if ($normalDisarmIndex -ge 0) {
    $controllerText.IndexOf('Remove-QmScheduledTaskBounded -TaskName $cleanupTaskName -DisableBeforeStop', $normalDisarmIndex, [System.StringComparison]::Ordinal)
} else { -1 }
$normalCleanupMutexIndex = if ($normalDisarmIndex -ge 0) {
    $controllerText.IndexOf('$cleanupActionMutex = Enter-QmCleanupActionMutex -Name $cleanupActionMutexName', $normalDisarmIndex, [System.StringComparison]::Ordinal)
} else { -1 }
$normalEvidenceIndex = if ($normalDisarmIndex -ge 0) {
    $controllerText.IndexOf('Assert-QmCleanupEvidenceAfterActionFence -ResultPath $cleanupResultPath', $normalDisarmIndex, [System.StringComparison]::Ordinal)
} else { -1 }
$fallbackIndex = $controllerText.IndexOf('if ($cleanupErrors.Count -gt 0 -and $cleanupTaskRegistered', [System.StringComparison]::Ordinal)
$fallbackCleanupMutexIndex = if ($fallbackIndex -ge 0) {
    $controllerText.IndexOf('$cleanupActionMutex = Enter-QmCleanupActionMutex -Name $cleanupActionMutexName', $fallbackIndex, [System.StringComparison]::Ordinal)
} else { -1 }
$fallbackEvidenceIndex = if ($fallbackIndex -ge 0) {
    $controllerText.IndexOf('Assert-QmCleanupEvidenceAfterActionFence -ResultPath $cleanupResultPath', $fallbackIndex, [System.StringComparison]::Ordinal)
} else { -1 }
$cleanupActionReleaseIndex = $controllerText.LastIndexOf('$cleanupActionMutex.ReleaseMutex()', [System.StringComparison]::Ordinal)
$controllerMutexReleaseIndex = $controllerText.LastIndexOf('$mutex.ReleaseMutex()', [System.StringComparison]::Ordinal)
if ($normalCleanupDrainIndex -le $normalDisarmIndex -or $normalCleanupMutexIndex -le $normalCleanupDrainIndex -or
    $normalEvidenceIndex -le $normalCleanupMutexIndex -or $fallbackCleanupMutexIndex -le $fallbackIndex -or
    $fallbackEvidenceIndex -le $fallbackCleanupMutexIndex -or $cleanupActionReleaseIndex -le $fallbackEvidenceIndex -or
    $controllerMutexReleaseIndex -le $cleanupActionReleaseIndex) {
    throw 'Controller cleanup action mutex handoff does not fence normal disarm, fallback evidence, and final release.'
}
$boundedDrainText = Get-QmFunctionTextFromAst -Ast $controllerAst -Name 'Remove-QmScheduledTaskBounded'
$disableIndex = $boundedDrainText.IndexOf('Disable-ScheduledTask', [System.StringComparison]::Ordinal)
$stopIndex = $boundedDrainText.IndexOf('Stop-ScheduledTask', [System.StringComparison]::Ordinal)
$unregisterIndex = $boundedDrainText.IndexOf('Unregister-ScheduledTask', [System.StringComparison]::Ordinal)
$absenceIndex = $boundedDrainText.LastIndexOf('timed out waiting for task absence', [System.StringComparison]::Ordinal)
if ($disableIndex -lt 0 -or $stopIndex -le $disableIndex -or $unregisterIndex -le $stopIndex -or
    $absenceIndex -le $unregisterIndex) {
    throw 'Bounded cleanup task drain is not Disable -> Stop/wait -> Unregister -> absence.'
}
& {
    $script:TaskPath = '\'
    $script:mockTaskPresent = $true
    $script:mockTaskState = 'Ready'
    $script:drainEvents = New-Object System.Collections.Generic.List[string]
    function Get-ScheduledTask {
        param([string]$TaskName, [string]$TaskPath, [object]$ErrorAction)
        if (-not $script:mockTaskPresent) { return $null }
        return [pscustomobject]@{ TaskName = $TaskName; TaskPath = $TaskPath; State = $script:mockTaskState }
    }
    function Disable-ScheduledTask {
        param([string]$TaskName, [string]$TaskPath, [object]$ErrorAction)
        $script:drainEvents.Add('DISABLE')
        # Simulate an expiry trigger that won immediately before Disable took effect.
        $script:mockTaskState = 'Running'
    }
    function Stop-ScheduledTask {
        param([string]$TaskName, [string]$TaskPath, [object]$ErrorAction)
        if ($script:drainEvents.Count -eq 0 -or $script:drainEvents[0] -cne 'DISABLE') {
            throw 'Stop occurred before Disable.'
        }
        $script:drainEvents.Add('STOP')
        $script:mockTaskState = 'Ready'
    }
    function Unregister-ScheduledTask {
        param([string]$TaskName, [string]$TaskPath, [switch]$Confirm, [object]$ErrorAction)
        if ($script:drainEvents.Count -lt 2 -or $script:drainEvents[1] -cne 'STOP') {
            throw 'Unregister occurred before bounded Stop/wait.'
        }
        $script:drainEvents.Add('UNREGISTER')
        $script:mockTaskPresent = $false
    }
    function Start-Sleep { param([int]$Milliseconds) }
    Invoke-Expression (Get-QmFunctionTextFromAst -Ast $controllerAst -Name 'Remove-QmScheduledTaskBounded')
    Remove-QmScheduledTaskBounded -TaskName ('QM_DEV2_CLEANUP_' + ('a' * 32)) `
        -DisableBeforeStop -TimeoutMilliseconds 100 -PollMilliseconds 1
    if ([string]::Join('|', $script:drainEvents.ToArray()) -cne 'DISABLE|STOP|UNREGISTER' -or
        $script:mockTaskPresent) {
        throw 'Ready-to-Running cleanup trigger race was not drained in exact order.'
    }
}
$identityProofIndex = $rotationText.IndexOf('$identityProved = $true', [System.StringComparison]::Ordinal)
$credentialPublishIndex = $rotationText.IndexOf('[System.IO.File]::Move($pendingCredentialPath, $credentialPath, $false)', [System.StringComparison]::Ordinal)
$publishVerifiedIndex = $rotationText.IndexOf('$credentialPublished = $true', [System.StringComparison]::Ordinal)
if ($identityProofIndex -lt 0 -or $credentialPublishIndex -le $identityProofIndex -or
    $publishVerifiedIndex -le $credentialPublishIndex) {
    throw 'Rotation published the canonical credential before Limited/Password identity proof.'
}
foreach ($marker in @(
        'Import-Clixml -LiteralPath $legacyCredentialPath',
        'Set-LocalUser -SID (New-Object System.Security.Principal.SecurityIdentifier($targetSid))',
        'PASSWORD_ROLLED_BACK_TO_LEGACY_PENDING_FORENSICALLY_BOUND',
        'credential.machine-dpapi.failed.$nonce.json',
        'Assert-QmRotationCleanupTaskContract',
        'credential.machine-dpapi.rotation-receipt.json',
        'one-time rotation refuses replacement',
        'Write-QmCanonicalRotationReceipt',
        '[System.IO.File]::Move($temporary, $full, $false)',
        'Assert-QmDev2CredentialExactAcl -Path $parent -Directory',
        'Assert-QmDev2CredentialExactAcl -Path $full'
    )) {
    if (-not $rotationText.Contains($marker, [System.StringComparison]::Ordinal)) {
        throw "Rotation rollback/containment marker is missing: $marker"
    }
}
$canonicalAbsenceIndex = $rotationText.IndexOf('one-time rotation refuses replacement', [System.StringComparison]::Ordinal)
$passwordMutationIndex = $rotationText.IndexOf('Set-LocalUser -SID (New-Object System.Security.Principal.SecurityIdentifier($targetSid)) -Password $securePassword', [System.StringComparison]::Ordinal)
$finalContainmentIndex = $rotationText.LastIndexOf('$finalUser = Get-LocalUser', [System.StringComparison]::Ordinal)
$canonicalReceiptWriteIndex = $rotationText.LastIndexOf('Write-QmCanonicalRotationReceipt', [System.StringComparison]::Ordinal)
$finalMutexReleaseIndex = $rotationText.LastIndexOf('$mutex.ReleaseMutex()', [System.StringComparison]::Ordinal)
if ($canonicalAbsenceIndex -lt 0 -or $passwordMutationIndex -le $canonicalAbsenceIndex -or
    $finalContainmentIndex -le $passwordMutationIndex -or $canonicalReceiptWriteIndex -le $finalContainmentIndex -or
    $finalMutexReleaseIndex -le $canonicalReceiptWriteIndex) {
    throw 'Canonical rotation receipt is not absent before mutation, published after containment, and mutex-protected.'
}
$receiptMatch = [regex]::Match(
    $rotationText,
    '(?ms)^function New-QmRotationCanonicalReceiptPayload \{.*?return \[ordered\]@\{(?<body>.*?)^\s{4}\}'
)
if (-not $receiptMatch.Success) { throw 'Canonical rotation receipt payload was not found.' }
$actualReceiptFields = @(
    [regex]::Matches($receiptMatch.Groups['body'].Value, '(?m)^\s{8}(?<name>[a-z0-9_]+)\s*=') |
        ForEach-Object { $_.Groups['name'].Value } |
        Sort-Object
)
$expectedReceiptFields = @(
    'schema_version', 'artifact_type', 'status', 'completed_utc', 'contract_id',
    'target_account', 'target_sid', 'target_disabled_at_rest', 'target_password_required_at_rest',
    'machine_credential_path', 'machine_credential_sha256', 'machine_credential_generation_id',
    'machine_credential_helper_path', 'machine_credential_helper_sha256',
    'identity_probe_child_path', 'identity_probe_child_sha256',
    'identity_probe_result_path', 'identity_probe_result_sha256',
    'identity_probe_logon_type', 'identity_probe_run_level',
    'machine_credential_matches_proved_password', 'published_after_identity_proof',
    'legacy_credential_path', 'legacy_credential_preserved', 'cleanup_lease_disarmed',
    'owner_process_count', 'dev2_root_process_count'
) | Sort-Object
if ($actualReceiptFields.Count -ne 27 -or
    [string]::Join('|', $actualReceiptFields) -cne [string]::Join('|', $expectedReceiptFields)) {
    throw 'Canonical rotation receipt differs from the exact 27-field v1 schema.'
}
foreach ($binding in @(
        "identity_probe_logon_type = 'Password'",
        "identity_probe_run_level = 'Limited'",
        'machine_credential_matches_proved_password = $true',
        'published_after_identity_proof = $true',
        'target_password_required_at_rest = $true'
    )) {
    if (-not $receiptMatch.Groups['body'].Value.Contains($binding, [System.StringComparison]::Ordinal)) {
        throw "Canonical rotation receipt proof binding is missing: $binding"
    }
}

Invoke-Expression (Get-QmFunctionTextFromAst -Ast $rotationAst -Name 'Get-QmRotationRecoveryDisposition')
$recoveryCases = @(
    @{ Phase = 'IDENTITY_PROVED'; Proof = $true; Staged = $false; Final = $true; Receipt = $false; Expected = 'FINALIZE_PROVED_PUBLISHED' },
    @{ Phase = 'IDENTITY_PROVED'; Proof = $true; Staged = $true; Final = $false; Receipt = $false; Expected = 'FINALIZE_PROVED_STAGED' },
    @{ Phase = 'CREDENTIAL_PUBLISHED_AFTER_IDENTITY_PROOF'; Proof = $true; Staged = $false; Final = $true; Receipt = $false; Expected = 'FINALIZE_PROVED_PUBLISHED' },
    @{ Phase = 'FINAL_CONTAINMENT_VERIFIED'; Proof = $true; Staged = $false; Final = $true; Receipt = $false; Expected = 'FINALIZE_PROVED_PUBLISHED' },
    @{ Phase = 'READY_FOR_CANONICAL_RECEIPT'; Proof = $true; Staged = $false; Final = $true; Receipt = $false; Expected = 'FINALIZE_PROVED_PUBLISHED' },
    @{ Phase = 'READY_FOR_CANONICAL_RECEIPT'; Proof = $true; Staged = $false; Final = $true; Receipt = $true; Expected = 'VALIDATE_COMMITTED_RECEIPT' },
    @{ Phase = 'COMMITTED'; Proof = $true; Staged = $false; Final = $true; Receipt = $true; Expected = 'VALIDATE_COMMITTED_RECEIPT' },
    @{ Phase = 'PASSWORD_SET'; Proof = $false; Staged = $true; Final = $false; Receipt = $false; Expected = 'CONTAIN_PRE_PROOF_FORENSIC_ONLY' }
)
foreach ($case in $recoveryCases) {
    $actual = Get-QmRotationRecoveryDisposition -Phase $case.Phase `
        -IdentityProofVerified $case.Proof -StagedCredentialExists $case.Staged `
        -FinalCredentialExists $case.Final -CanonicalReceiptExists $case.Receipt
    if ($actual -cne $case.Expected) {
        throw "Recovery disposition drifted for phase $($case.Phase): $actual"
    }
}
foreach ($tamper in @(
        @{ Phase = 'PASSWORD_SET'; Proof = $true; Staged = $true; Final = $false; Receipt = $false },
        @{ Phase = 'IDENTITY_PROVED'; Proof = $false; Staged = $false; Final = $true; Receipt = $false },
        @{ Phase = 'IDENTITY_PROVED'; Proof = $true; Staged = $true; Final = $true; Receipt = $false },
        @{ Phase = 'IDENTITY_PROVED'; Proof = $true; Staged = $false; Final = $true; Receipt = $true },
        @{ Phase = 'COMMITTED'; Proof = $true; Staged = $false; Final = $true; Receipt = $false }
    )) {
    $rejected = $false
    try {
        $null = Get-QmRotationRecoveryDisposition -Phase $tamper.Phase `
            -IdentityProofVerified $tamper.Proof -StagedCredentialExists $tamper.Staged `
            -FinalCredentialExists $tamper.Final -CanonicalReceiptExists $tamper.Receipt
    } catch { $rejected = $true }
    if (-not $rejected) { throw "Recovery accepted an adversarial partial state: $($tamper.Phase)" }
}

foreach ($marker in @(
        'schema_version = $journalSchemaVersion', 'phase = ''CLEANUP_LEASE_ARMED''',
        'lane_contract_sha256 = $contractSha256', 'credential_sha256 = $machineCredential.Sha256',
        'credential_generation_id = $machineCredential.GenerationId',
        'credential_helper_sha256 = $helperSha256', 'identity_probe_child_sha256 = $childSha256',
        'identity_probe_request_sha256 = $requestSha256', 'identity_probe_result_sha256 = $null',
        'cleanup_lease_sha256 = $cleanupLeaseSha256', 'cleanup_helper_sha256 = $cleanupHelperSha256',
        'tester_groups_sha256 = $groupsSha256', 'legacy_credential_sha256 = $legacyCredentialSha256',
        'identity_probe_logon_type = ''Password''', 'identity_probe_run_level = ''Limited''',
        'Invoke-QmRotationResumeFinalize', 'password_rotated_by_resume = $false'
    )) {
    if (-not $rotationText.Contains($marker, [System.StringComparison]::Ordinal)) {
        throw "Recovery journal/finalizer marker is missing: $marker"
    }
}
$sourceWriterCheckIndex = $rotationText.LastIndexOf(
    'Assert-QmRotationAdminControlledSourceFile -Path $source -ForbiddenWriterSid $targetSid',
    [System.StringComparison]::Ordinal
)
if ($sourceWriterCheckIndex -lt 0 -or $sourceWriterCheckIndex -ge $passwordMutationIndex) {
    throw 'Initial rotation does not reject QMDev2-writable contract/helper/child/legacy sources before password mutation.'
}
$journalSealIndex = $rotationText.IndexOf('Write-QmRotationJournalExact -Path $journalPath -Payload $journal', [System.StringComparison]::Ordinal)
if ($journalSealIndex -lt 0 -or $passwordMutationIndex -le $journalSealIndex) {
    throw 'Exact prepublish journal is not sealed before the first password mutation.'
}

$fixedCredential = 'C:\ProgramData\QM\DEV2\credential.machine-dpapi.json'
$fixedCanonicalReceipt = 'C:\ProgramData\QM\DEV2\credential.machine-dpapi.rotation-receipt.json'
$legacyCredential = 'C:\ProgramData\QM\DEV2\credential.clixml'
$beforePlan = [ordered]@{
    credential_exists = Test-Path -LiteralPath $fixedCredential -PathType Leaf
    receipt_exists = Test-Path -LiteralPath $fixedCanonicalReceipt -PathType Leaf
    legacy_sha256 = if (Test-Path -LiteralPath $legacyCredential -PathType Leaf) {
        (Get-FileHash -LiteralPath $legacyCredential -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    } else { $null }
}
$planText = (& pwsh -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $credentialRotatePath) -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'Rotation plan-only invocation failed.' }
$plan = $planText | ConvertFrom-Json -ErrorAction Stop
$afterPlan = [ordered]@{
    credential_exists = Test-Path -LiteralPath $fixedCredential -PathType Leaf
    receipt_exists = Test-Path -LiteralPath $fixedCanonicalReceipt -PathType Leaf
    legacy_sha256 = if (Test-Path -LiteralPath $legacyCredential -PathType Leaf) {
        (Get-FileHash -LiteralPath $legacyCredential -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    } else { $null }
}
if ([string]$plan.status -cne 'PLAN_ONLY' -or $plan.mutates_host -isnot [bool] -or [bool]$plan.mutates_host -or
    ($beforePlan | ConvertTo-Json -Compress) -cne ($afterPlan | ConvertTo-Json -Compress)) {
    throw 'Rotation plan-only mode mutated or misreported fixed credential evidence.'
}
foreach ($forbidden in @('run_smoke.ps1', 'terminal64.exe', 'metatester64.exe', 'Import-Clixml', 'ProtectedData')) {
    if ($identityProbeText.Contains($forbidden, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Identity-only child crossed a forbidden native/credential boundary: $forbidden"
    }
}
foreach ($marker in @(
    "control\cleanup_lease.result.json",
    "control\cleanup_lease.disarm.result.json"
)) {
    if (-not $cleanupText.Contains($marker, [System.StringComparison]::Ordinal)) {
        throw "Protected cleanup helper marker is missing: $marker"
    }
}

Write-Host 'PASS Test-Dev2ControllerContracts'
