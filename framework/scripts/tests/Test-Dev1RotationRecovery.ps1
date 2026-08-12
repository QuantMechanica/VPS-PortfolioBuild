[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$rotationPath = Join-Path $repoRoot 'framework\scripts\rotate_dev1_machine_credential.ps1'
$cleanupPath = Join-Path $repoRoot 'framework\scripts\cleanup_dev1_account_lease.ps1'
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $rotationPath, [ref]$tokens, [ref]$errors
)
if (@($errors).Count -ne 0) { throw "Rotation script has parse errors: $($errors | Out-String)" }
$cleanupTokens = $null
$cleanupErrors = $null
$cleanupAst = [System.Management.Automation.Language.Parser]::ParseFile(
    $cleanupPath, [ref]$cleanupTokens, [ref]$cleanupErrors
)
if (@($cleanupErrors).Count -ne 0) { throw "Cleanup script has parse errors: $($cleanupErrors | Out-String)" }
$targetTaskParameter = @($cleanupAst.ParamBlock.Parameters | Where-Object {
        $_.Name.VariablePath.UserPath -ceq 'TargetTaskName'
    })
if ($targetTaskParameter.Count -ne 1) { throw 'Cleanup helper has no exact TargetTaskName parameter.' }
$targetTaskPatternAttributes = @($targetTaskParameter[0].Attributes | Where-Object {
        $_.TypeName.FullName -ceq 'ValidatePattern'
    })
if ($targetTaskPatternAttributes.Count -ne 1 -or
    $targetTaskPatternAttributes[0].PositionalArguments.Count -ne 1) {
    throw 'Cleanup helper TargetTaskName lacks one exact ValidatePattern contract.'
}
$targetTaskPattern = [string]$targetTaskPatternAttributes[0].PositionalArguments[0].Value
if ($targetTaskPattern -cne '^(?:QM_DEV1_SMOKE_|QM_DEV1_COMPILE_)[0-9a-f]{32}$' -or
    ('QM_DEV1_SMOKE_' + ('1' * 32)) -cnotmatch $targetTaskPattern -or
    ('QM_DEV1_COMPILE_' + ('2' * 32)) -cnotmatch $targetTaskPattern -or
    ('QM_DEV1_COMPILE_OTHER_' + ('3' * 32)) -cmatch $targetTaskPattern) {
    throw 'Cleanup helper target-task allowlist drifted from exact smoke/compile families.'
}

function Get-QmRecoveryFunctionText {
    param([Parameter(Mandatory = $true)][string]$Name)
    $functionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $Name
    }, $true)
    if ($null -eq $functionAst) { throw "Recovery function is missing: $Name" }
    return $functionAst.Extent.Text
}

function Get-QmCleanupFunctionText {
    param([Parameter(Mandatory = $true)][string]$Name)
    $functionAst = $cleanupAst.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $Name
    }, $true)
    if ($null -eq $functionAst) { throw "Cleanup function is missing: $Name" }
    return $functionAst.Extent.Text
}

$journalSchemaVersion = 2
$journalArtifactType = 'QM_DEV1_MACHINE_CREDENTIAL_ROTATION_JOURNAL'
$contractId = 'QM_DEV1_ISOLATED_MT5_LANE_V3'
$lane = 'DEV1'
$targetUserName = 'QMDev1'
$compileTaskPrefix = 'QM_DEV1_COMPILE_'
$cleanupActionMutexPrefix = 'Global\QM_DEV1_CLEANUP_ACTION_'
Invoke-Expression (Get-QmRecoveryFunctionText -Name 'Resolve-QmRotationSid')
Invoke-Expression (Get-QmRecoveryFunctionText -Name 'Get-QmRotationJournalFieldNames')
Invoke-Expression (Get-QmRecoveryFunctionText -Name 'Assert-QmRotationJournalSchema')
Invoke-Expression (Get-QmRecoveryFunctionText -Name 'Get-QmRotationRecoveryDisposition')
Invoke-Expression (Get-QmRecoveryFunctionText -Name 'Test-QmRotationRetryClearPhase')
Invoke-Expression (Get-QmRecoveryFunctionText -Name 'New-QmRotationCanonicalReceiptPayload')
Invoke-Expression (Get-QmRecoveryFunctionText -Name 'Assert-QmRotationCleanupEvidenceSnapshot')

$now = [DateTimeOffset]::UtcNow
$hashA = 'a' * 64
$hashB = 'b' * 64
$hashC = 'c' * 64
$sid = 'S-1-5-21-111-222-333-1006'
if ((Resolve-QmRotationSid -AccountName $sid) -cne $sid) {
    throw 'Rotation SID resolver does not accept raw ACL SID identity references.'
}
$localDev1 = Get-LocalUser -Name 'QMDev1' -ErrorAction Stop
if ((Resolve-QmRotationSid -AccountName '.\QMDev1') -cne $localDev1.SID.Value) {
    throw 'Rotation SID resolver does not normalize the legacy local-account alias.'
}
$rotationId = $now.ToString('yyyyMMddTHHmmssZ') + '_' + ('d' * 32)
$nonce = 'e' * 32
$journal = [ordered]@{
    schema_version = 2
    artifact_type = $journalArtifactType
    rotation_id = $rotationId
    nonce = $nonce
    phase = 'IDENTITY_PROVED'
    created_utc = $now.AddMinutes(-2).ToString('o')
    updated_utc = $now.AddMinutes(-1).ToString('o')
    contract_id = $contractId
    lane = $lane
    lane_contract_path = 'C:\QM\repo\framework\registry\dev1_lane_contract.json'
    lane_contract_sha256 = $hashA
    target_account = "$env:COMPUTERNAME\QMDev1"
    target_sid = $sid
    target_profile = 'C:\Users\QMDev1'
    identity_probe_logon_type = 'Password'
    identity_probe_run_level = 'Limited'
    credential_staged_path = "C:\ProgramData\QM\DEV1\credential.machine-dpapi.pending.$nonce.json"
    credential_final_path = 'C:\ProgramData\QM\DEV1\credential.machine-dpapi.json'
    credential_sha256 = $hashB
    credential_generation_id = 'f' * 32
    credential_helper_path = 'C:\QM\repo\framework\scripts\dev1_machine_credential.ps1'
    credential_helper_sha256 = $hashC
    identity_probe_child_path = 'C:\QM\repo\framework\scripts\invoke_dev1_identity_probe.ps1'
    identity_probe_child_sha256 = $hashA
    identity_probe_request_path = "D:\QM\reports\dev1\credential-rotation\$rotationId\control\identity_probe_request.json"
    identity_probe_request_sha256 = $hashB
    identity_probe_result_path = "D:\QM\reports\dev1\credential-rotation\$rotationId\output\identity_probe_result.json"
    identity_probe_result_sha256 = $hashC
    identity_proof_completed_utc = $now.AddMinutes(-1).ToString('o')
    identity_proof_verified = $true
    target_task_name = 'QM_DEV1_SMOKE_' + ('1' * 32)
    cleanup_task_name = 'QM_DEV1_CLEANUP_' + ('2' * 32)
    cleanup_action_mutex = 'Global\QM_DEV1_CLEANUP_ACTION_' + $nonce
    cleanup_lease_path = "D:\QM\reports\dev1\credential-rotation\$rotationId\control\cleanup_lease.json"
    cleanup_lease_sha256 = $hashA
    cleanup_helper_path = "D:\QM\reports\dev1\credential-rotation\$rotationId\control\cleanup_dev1_account_lease.ps1"
    cleanup_helper_sha256 = $hashB
    tester_groups_source_path = "D:\QM\reports\dev1\credential-rotation\$rotationId\control\Darwinex-Live_real.canonical.txt"
    tester_groups_target_path = 'D:\QM\mt5\DEV1\MQL5\Profiles\Tester\Groups\Darwinex-Live_real.txt'
    tester_groups_sha256 = $hashC
    cleanup_result_path = "D:\QM\reports\dev1\credential-rotation\$rotationId\control\cleanup_lease.result.json"
    cleanup_disarm_path = "D:\QM\reports\dev1\credential-rotation\$rotationId\control\cleanup_lease.disarm.result.json"
    cleanup_result_sha256 = $null
    cleanup_disarm_sha256 = $null
    cleanup_result_failure_archive_sha256 = $null
    cleanup_disarm_failure_archive_sha256 = $null
    legacy_credential_path = 'C:\ProgramData\QM\DEV1\credential.clixml'
    legacy_credential_sha256 = $hashA
    legacy_credential_preserved = $true
    dynamic_receipt_path = "D:\QM\reports\dev1\credential-rotation\$rotationId\control\rotation_receipt.json"
    canonical_receipt_path = 'C:\ProgramData\QM\DEV1\credential.machine-dpapi.rotation-receipt.json'
    receipt_completed_utc = $null
}

Assert-QmRotationJournalSchema -Journal ([pscustomobject]$journal)
if (@(Get-QmRotationJournalFieldNames).Count -ne 52) {
    throw 'Recovery journal field count drifted from the exact v2 schema.'
}

foreach ($tamper in @(
        @{ Field = 'credential_helper_sha256'; Value = 'A' * 64 },
        @{ Field = 'identity_probe_child_sha256'; Value = $null },
        @{ Field = 'legacy_credential_sha256'; Value = '0' },
        @{ Field = 'identity_probe_request_sha256'; Value = 'f' * 63 },
        @{ Field = 'cleanup_lease_sha256'; Value = 'g' * 64 },
        @{ Field = 'cleanup_action_mutex'; Value = 'Global\QM_DEV1_CLEANUP_ACTION_' + ('0' * 32) },
        @{ Field = 'credential_generation_id'; Value = 'F' * 32 },
        @{ Field = 'identity_probe_logon_type'; Value = 'S4U' },
        @{ Field = 'identity_probe_run_level'; Value = 'Highest' },
        @{ Field = 'identity_proof_verified'; Value = $false }
    )) {
    $candidate = [ordered]@{}
    foreach ($name in Get-QmRotationJournalFieldNames) { $candidate[$name] = $journal[$name] }
    $candidate[$tamper.Field] = $tamper.Value
    $rejected = $false
    try { Assert-QmRotationJournalSchema -Journal ([pscustomobject]$candidate) } catch { $rejected = $true }
    if (-not $rejected) { throw "Recovery journal tamper was accepted: $($tamper.Field)" }
}
$extra = [pscustomobject]$journal
$extra | Add-Member -NotePropertyName unexpected -NotePropertyValue $true
$rejected = $false
try { Assert-QmRotationJournalSchema -Journal $extra } catch { $rejected = $true }
if (-not $rejected) { throw 'Recovery journal accepted an extra field.' }

$crashPhases = @(
    'IDENTITY_PROVED',
    'CREDENTIAL_PUBLISHED_AFTER_IDENTITY_PROOF',
    'FINAL_CONTAINMENT_VERIFIED',
    'READY_FOR_CANONICAL_RECEIPT'
)
foreach ($phase in $crashPhases) {
    $result = Get-QmRotationRecoveryDisposition -Phase $phase -IdentityProofVerified $true `
        -StagedCredentialExists $false -FinalCredentialExists $true -CanonicalReceiptExists $false
    if ($result -cne 'FINALIZE_PROVED_PUBLISHED') {
        throw "Crash-after-Move recovery was rejected at phase: $phase"
    }
}
foreach ($phase in @('PREPARED', 'CLEANUP_LEASE_ARMED')) {
    $result = Get-QmRotationRecoveryDisposition -Phase $phase -IdentityProofVerified $false `
        -StagedCredentialExists $true -FinalCredentialExists $false -CanonicalReceiptExists $false
    if ($result -cne 'CONTAIN_PRE_PROOF_FORENSIC_ONLY') {
        throw "Pre-migration crash recovery is not containment-only at phase: $phase"
    }
}
$rollbackJournal = [ordered]@{}
foreach ($name in Get-QmRotationJournalFieldNames) { $rollbackJournal[$name] = $journal[$name] }
$rollbackJournal.phase = 'PASSWORD_ROLLBACK_INTENT_FORENSICALLY_BOUND'
Assert-QmRotationJournalSchema -Journal ([pscustomobject]$rollbackJournal)
$rollbackJournal.phase = 'PASSWORD_ROLLED_BACK_TO_LEGACY_PENDING_FORENSICALLY_BOUND'
Assert-QmRotationJournalSchema -Journal ([pscustomobject]$rollbackJournal)
$rollbackDisposition = Get-QmRotationRecoveryDisposition `
    -Phase $rollbackJournal.phase -IdentityProofVerified $true `
    -StagedCredentialExists $false -FinalCredentialExists $false -CanonicalReceiptExists $false
if ($rollbackDisposition -cne 'CONTAIN_ROLLBACK_RETRY_CLEAR') {
    throw 'Password-rollback journal is not routed to containment-only retry-clear recovery.'
}
$rollbackFinalDisposition = Get-QmRotationRecoveryDisposition -Phase $rollbackJournal.phase -IdentityProofVerified $true `
    -StagedCredentialExists $false -FinalCredentialExists $true -CanonicalReceiptExists $false
if ($rollbackFinalDisposition -cne 'CONTAIN_ROLLBACK_RETRY_CLEAR') {
    throw 'Rollback intent with a final artifact was not routed to quarantine-only recovery.'
}
$rollbackReceiptRejected = $false
try {
    $null = Get-QmRotationRecoveryDisposition -Phase $rollbackJournal.phase -IdentityProofVerified $true `
        -StagedCredentialExists $false -FinalCredentialExists $true -CanonicalReceiptExists $true
} catch { $rollbackReceiptRejected = $true }
if (-not $rollbackReceiptRejected) { throw 'Password-rollback recovery accepted a canonical success receipt.' }
$rollbackJournal.phase = 'PASSWORD_ROLLBACK_CONTAINED_RETRY_CLEAR'
$rollbackJournal.cleanup_result_sha256 = $hashB
$rollbackJournal.cleanup_disarm_sha256 = $hashC
Assert-QmRotationJournalSchema -Journal ([pscustomobject]$rollbackJournal)
$preProofJournal = [ordered]@{}
foreach ($name in Get-QmRotationJournalFieldNames) { $preProofJournal[$name] = $journal[$name] }
$preProofJournal.phase = 'PRE_PROOF_CONTAINED_RETRY_CLEAR'
$preProofJournal.identity_probe_result_sha256 = $null
$preProofJournal.identity_proof_completed_utc = $null
$preProofJournal.identity_proof_verified = $false
$preProofJournal.cleanup_result_sha256 = $hashB
$preProofJournal.cleanup_disarm_sha256 = $hashC
Assert-QmRotationJournalSchema -Journal ([pscustomobject]$preProofJournal)
$preProofDisposition = Get-QmRotationRecoveryDisposition -Phase $preProofJournal.phase `
    -IdentityProofVerified $false -StagedCredentialExists $false -FinalCredentialExists $false `
    -CanonicalReceiptExists $false
if ($preProofDisposition -cne 'CONTAIN_PRE_PROOF_RETRY_CLEAR' -or
    -not (Test-QmRotationRetryClearPhase -Phase $preProofJournal.phase)) {
    throw 'Pre-proof containment is not a durable retry-clear terminal state.'
}
$invalidatedProofJournal = [ordered]@{}
foreach ($name in Get-QmRotationJournalFieldNames) { $invalidatedProofJournal[$name] = $journal[$name] }
$invalidatedProofJournal.phase = 'PROOF_INVALIDATED_CONTAINED_RETRY_CLEAR'
$invalidatedProofJournal.cleanup_result_sha256 = $hashB
$invalidatedProofJournal.cleanup_disarm_sha256 = $hashC
Assert-QmRotationJournalSchema -Journal ([pscustomobject]$invalidatedProofJournal)
$invalidatedDisposition = Get-QmRotationRecoveryDisposition -Phase $invalidatedProofJournal.phase `
    -IdentityProofVerified $true -StagedCredentialExists $false -FinalCredentialExists $false `
    -CanonicalReceiptExists $false
if ($invalidatedDisposition -cne 'CONTAIN_PROOF_INVALIDATED_RETRY_CLEAR' -or
    -not (Test-QmRotationRetryClearPhase -Phase $invalidatedProofJournal.phase)) {
    throw 'Invalidated identity proof can re-enter a credential-publication disposition.'
}
$invalidatedFinalRejected = $false
try {
    $null = Get-QmRotationRecoveryDisposition -Phase $invalidatedProofJournal.phase `
        -IdentityProofVerified $true -StagedCredentialExists $false -FinalCredentialExists $true `
        -CanonicalReceiptExists $false
} catch { $invalidatedFinalRejected = $true }
if (-not $invalidatedFinalRejected) { throw 'Invalidated proof accepted a canonical credential artifact.' }
$idempotent = Get-QmRotationRecoveryDisposition -Phase 'READY_FOR_CANONICAL_RECEIPT' `
    -IdentityProofVerified $true -StagedCredentialExists $false -FinalCredentialExists $true `
    -CanonicalReceiptExists $true
if ($idempotent -cne 'VALIDATE_COMMITTED_RECEIPT') {
    throw 'Crash-after-canonical-write state is not idempotently validated.'
}

$journal.phase = 'FINAL_CONTAINMENT_VERIFIED'
$journal.receipt_completed_utc = $now.ToString('o')
$journal.cleanup_result_sha256 = $hashB
$journal.cleanup_disarm_sha256 = $hashC
$journal.updated_utc = $now.ToString('o')
Assert-QmRotationJournalSchema -Journal ([pscustomobject]$journal)
$receipt = New-QmRotationCanonicalReceiptPayload -Journal ([pscustomobject]$journal) -CredentialSha256 $hashB
if ($receipt.Count -ne 27 -or -not [bool]$receipt.machine_credential_matches_proved_password -or
    -not [bool]$receipt.published_after_identity_proof -or [string]$receipt.identity_probe_logon_type -cne 'Password' -or
    [string]$receipt.identity_probe_run_level -cne 'Limited') {
    throw 'Recovery canonical receipt builder drifted from the exact 27-field proof schema.'
}

$resumeText = Get-QmRecoveryFunctionText -Name 'Invoke-QmRotationResumeFinalize'
foreach ($forbidden in @('Set-LocalUser', 'Enable-LocalUser', 'Register-ScheduledTask', 'Import-Clixml')) {
    if ($resumeText.Contains($forbidden, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Resume-finalize may not rotate/re-enable/register/import credentials: $forbidden"
    }
}
foreach ($required in @(
        'Assert-QmRotationIdentityProofBindings', 'Assert-QmRotationCleanupLeaseBindings',
        'Invoke-QmRotationRecoveryContainment', 'Read-QmDev1MachineCredentialEnvelope',
        'credential_generation_id', 'Write-QmRotationJournalExact',
        'Assert-QmRotationReceiptExact', 'password_rotated_by_resume = $false',
        'Recovery cleanup failure archive set differs from its sealed final journal bindings.'
    )) {
    if (-not $resumeText.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Resume-finalize proof/containment marker is missing: $required"
    }
}

$rollbackBranchIndex = $resumeText.IndexOf("if (`$rollbackRecovery)", [System.StringComparison]::Ordinal)
$rollbackReturnIndex = if ($rollbackBranchIndex -ge 0) {
    $resumeText.IndexOf('        return', $rollbackBranchIndex, [System.StringComparison]::Ordinal)
} else { -1 }
$resumeDecryptIndex = $resumeText.IndexOf('Get-QmDev1MachineCredential -CredentialPath', [System.StringComparison]::Ordinal)
foreach ($marker in @(
        "mode = 'ROLLBACK_CONTAINMENT_REPAIR'", 'retry_clear_for_fresh_apply = $true',
        'canonical_credential_published = $false', 'canonical_receipt_published = $false',
        'password_rotated_by_resume = $false'
    )) {
    if (-not $resumeText.Contains($marker, [System.StringComparison]::Ordinal)) {
        throw "Containment-only password-rollback recovery marker is missing: $marker"
    }
}
if ($rollbackBranchIndex -lt 0 -or $rollbackReturnIndex -le $rollbackBranchIndex -or
    $resumeDecryptIndex -le $rollbackReturnIndex) {
    throw 'Password-rollback recovery can reach credential decrypt/publication instead of returning containment-only.'
}

$rotationText = Get-Content -LiteralPath $rotationPath -Raw -ErrorAction Stop
$cleanupText = Get-Content -LiteralPath $cleanupPath -Raw -ErrorAction Stop

& {
    $targetUserName = 'QMDev1'
    $testSid = 'S-1-5-21-111-222-333-1005'
    $script:testEnabled = $true
    $script:disableCalls = 0
    $script:stopCalls = 0
    $script:testProcessCount = 0
    function Get-LocalUser {
        param([object]$SID, [object]$ErrorAction)
        if ($SID.Value -cne $testSid) { throw 'Unexpected SID in pre-migration containment test.' }
        return [pscustomobject]@{
            Name = $targetUserName
            SID = [pscustomobject]@{ Value = $testSid }
            Enabled = [bool]$script:testEnabled
            PasswordRequired = $true
        }
    }
    function Disable-LocalUser {
        param([object]$SID, [object]$ErrorAction)
        if ($SID.Value -cne $testSid) { throw 'Unexpected SID in pre-migration disable test.' }
        $script:disableCalls++
        $script:testEnabled = $false
        # Model the narrow enabled-account race: one final target process appears
        # while Disable-LocalUser is completing and must be swept before return.
        $script:testProcessCount = 1
    }
    function Stop-QmRotationTargetProcesses {
        param([string]$TargetSid)
        if ($TargetSid -cne $testSid) { throw 'Unexpected SID in pre-migration process sweep.' }
        $script:stopCalls++
        $script:testProcessCount = 0
    }
    function Get-QmRotationDev1Processes {
        param([string]$TargetSid)
        if ($TargetSid -cne $testSid) { throw 'Unexpected SID in pre-migration process reassertion.' }
        if ($script:testProcessCount -eq 0) { return @() }
        return @(1..$script:testProcessCount | ForEach-Object { [pscustomobject]@{ ProcessId = $_ } })
    }
    Invoke-Expression (Get-QmRecoveryFunctionText -Name 'Ensure-QmRotationTargetDisabledAtRest')
    $simulatedCrashObserved = $false
    try {
        if (-not (Ensure-QmRotationTargetDisabledAtRest -TargetSid $testSid)) {
            throw 'Enabled legacy DEV1 state was not reported as normalized.'
        }
        throw 'SIMULATED_CRASH_AFTER_PRE_MIGRATION_DISABLE'
    } catch {
        if ($_.Exception.Message -cne 'SIMULATED_CRASH_AFTER_PRE_MIGRATION_DISABLE') { throw }
        $simulatedCrashObserved = $true
    }
    if (-not $simulatedCrashObserved -or $script:testEnabled -or $script:disableCalls -ne 1 -or
        $script:testProcessCount -ne 0 -or $script:stopCalls -ne 1) {
        throw 'Crash after DEV1 pre-migration normalization did not leave exact disabled/process-free state.'
    }
    if (Ensure-QmRotationTargetDisabledAtRest -TargetSid $testSid) {
        throw 'Already-disabled DEV1 state was not handled idempotently.'
    }
    if ($script:testEnabled -or $script:disableCalls -ne 1 -or $script:testProcessCount -ne 0 -or
        $script:stopCalls -ne 2) {
        throw 'Idempotent DEV1 pre-migration containment changed the disabled state twice.'
    }
}

$preparedPhaseIndex = $rotationText.IndexOf("phase = 'PREPARED'", [System.StringComparison]::Ordinal)
$preparedWriteIndex = if ($preparedPhaseIndex -ge 0) {
    $rotationText.IndexOf('Write-QmRotationJournalExact -Path $journalPath -Payload $journal',
        $preparedPhaseIndex, [System.StringComparison]::Ordinal)
} else { -1 }
$cleanupRegisterIndex = $rotationText.IndexOf(
    'Register-ScheduledTask -TaskName $cleanupTaskName', [System.StringComparison]::Ordinal
)
$cleanupContractIndex = if ($cleanupRegisterIndex -ge 0) {
    $rotationText.IndexOf('Assert-QmRotationCleanupTaskContract -Task $registeredCleanupTask',
        $cleanupRegisterIndex, [System.StringComparison]::Ordinal)
} else { -1 }
$armedPhaseIndex = $rotationText.IndexOf(
    "`$journal.phase = 'CLEANUP_LEASE_ARMED'", [System.StringComparison]::Ordinal
)
$armedWriteIndex = if ($armedPhaseIndex -ge 0) {
    $rotationText.IndexOf('Write-QmRotationJournalExact -Path $journalPath -Payload $journal -Replace',
        $armedPhaseIndex, [System.StringComparison]::Ordinal)
} else { -1 }
if ($preparedPhaseIndex -lt 0 -or $preparedWriteIndex -le $preparedPhaseIndex -or
    $cleanupRegisterIndex -le $preparedWriteIndex -or $cleanupContractIndex -le $cleanupRegisterIndex -or
    $armedPhaseIndex -le $cleanupContractIndex -or $armedWriteIndex -le $armedPhaseIndex) {
    throw 'Cleanup-task registration is not bracketed by PREPARED and CLEANUP_LEASE_ARMED durable journal writes.'
}
$freshHistoryIndex = $rotationText.IndexOf('$null = Assert-QmRotationFreshApplyHistory', [System.StringComparison]::Ordinal)
$mainMutexIndex = $rotationText.IndexOf('$mutexAcquired = $mutex.WaitOne(0)', [System.StringComparison]::Ordinal)
$mainTaskPreflightIndex = if ($freshHistoryIndex -ge 0) {
    $rotationText.IndexOf('    Assert-QmRotationNoTasks', $freshHistoryIndex,
        [System.StringComparison]::Ordinal)
} else { -1 }
$mainProcessPreflightIndex = if ($mainTaskPreflightIndex -ge 0) {
    $rotationText.IndexOf("throw 'DEV1 rotation requires zero target-SID and DEV1-root processes before pre-migration containment.'",
        $mainTaskPreflightIndex, [System.StringComparison]::Ordinal)
} else { -1 }
$containmentStartedIndex = if ($armedWriteIndex -ge 0) {
    $rotationText.IndexOf('$preMigrationContainmentStarted = $true', $armedWriteIndex,
        [System.StringComparison]::Ordinal)
} else { -1 }
$migrationDisableIndex = if ($containmentStartedIndex -ge 0) {
    $rotationText.IndexOf('$targetDisabledByMigration = Ensure-QmRotationTargetDisabledAtRest -TargetSid $targetSid',
        $containmentStartedIndex, [System.StringComparison]::Ordinal)
} else { -1 }
$passwordGenerationIndex = $rotationText.IndexOf('    $passwordText = New-QmRotationPassword', [System.StringComparison]::Ordinal)
$passwordMutationIndex = if ($migrationDisableIndex -ge 0) {
    $rotationText.IndexOf(
        'Set-LocalUser -SID (New-Object System.Security.Principal.SecurityIdentifier($targetSid)) -Password $securePassword',
        $migrationDisableIndex, [System.StringComparison]::Ordinal
    )
} else { -1 }
if ($mainMutexIndex -lt 0 -or $freshHistoryIndex -le $mainMutexIndex -or
    $mainTaskPreflightIndex -le $freshHistoryIndex -or $mainProcessPreflightIndex -le $mainTaskPreflightIndex -or
    $passwordGenerationIndex -le $mainProcessPreflightIndex -or $cleanupRegisterIndex -le $passwordGenerationIndex -or
    $containmentStartedIndex -le $armedWriteIndex -or $migrationDisableIndex -le $containmentStartedIndex -or
    $passwordMutationIndex -le $migrationDisableIndex) {
    throw 'Fresh Apply does not durably arm SYSTEM cleanup before disable/process normalization and password mutation.'
}
$failureCaptureIndex = $rotationText.IndexOf('$primaryError = $_', $passwordMutationIndex, [System.StringComparison]::Ordinal)
$failureContainmentGuardIndex = if ($failureCaptureIndex -ge 0) {
    $rotationText.IndexOf(
        'if ($preMigrationContainmentStarted -and -not [string]::IsNullOrWhiteSpace($targetSid))',
        $failureCaptureIndex, [System.StringComparison]::Ordinal
    )
} else { -1 }
$failureLocalStopIndex = if ($failureContainmentGuardIndex -ge 0) {
    $rotationText.IndexOf('Stop-QmRotationTargetProcesses -TargetSid $targetSid', $failureContainmentGuardIndex,
        [System.StringComparison]::Ordinal)
} else { -1 }
$failureHelperStartIndex = if ($failureCaptureIndex -ge 0) {
    $rotationText.IndexOf('Start-ScheduledTask -TaskName $cleanupTaskName', $failureCaptureIndex,
        [System.StringComparison]::Ordinal)
} else { -1 }
if ($failureCaptureIndex -le $passwordMutationIndex -or
    $failureContainmentGuardIndex -le $failureCaptureIndex -or
    $failureLocalStopIndex -le $failureContainmentGuardIndex -or
    $failureHelperStartIndex -le $failureCaptureIndex) {
    throw 'An error after cleanup lease arm does not retain/start the bound SYSTEM helper in final containment.'
}
if ($rotationText.Contains('[System.IO.File]::ReadAllBytes', [System.StringComparison]::Ordinal)) {
    throw 'Rotation still parses or executes an unbound ReadAllBytes buffer.'
}
$resumeHelperReadIndex = $rotationText.IndexOf(
    '$sealedHelperRecord = Read-QmRotationBoundFileBytes', [System.StringComparison]::Ordinal
)
$resumeHelperCreateIndex = $rotationText.IndexOf(
    '[scriptblock]::Create($sealedHelperText)', [System.StringComparison]::Ordinal
)
if ($resumeHelperReadIndex -lt 0 -or $resumeHelperCreateIndex -le $resumeHelperReadIndex) {
    throw 'Resume does not create the helper ScriptBlock from exact journal-bound bytes.'
}
$identityBindingText = Get-QmRecoveryFunctionText -Name 'Assert-QmRotationIdentityProofBindings'
if (-not $identityBindingText.Contains('-ExpectedValueKinds $requestValueKinds', [System.StringComparison]::Ordinal) -or
    -not $identityBindingText.Contains('-ExpectedValueKinds $resultValueKinds', [System.StringComparison]::Ordinal)) {
    throw 'Rotation identity request/result validation lacks exact primitive ValueKind contracts.'
}
$containmentText = Get-QmRecoveryFunctionText -Name 'Invoke-QmRotationRecoveryContainment'
$targetDrainIndex = $containmentText.IndexOf(
    'Remove-QmRotationScheduledTaskBounded -TaskName ([string]$Journal.target_task_name)',
    [System.StringComparison]::Ordinal
)
$preFenceContainmentIndex = $containmentText.IndexOf(
    'Invoke-QmRotationHostContainmentPass -Journal $Journal -AllowBoundCleanupTask',
    [System.StringComparison]::Ordinal
)
$cleanupDrainIndex = $containmentText.IndexOf(
    'Remove-QmRotationScheduledTaskBounded -TaskName ([string]$Journal.cleanup_task_name) -DisableBeforeStop',
    [System.StringComparison]::Ordinal
)
$actionFenceIndex = $containmentText.IndexOf(
    'Enter-QmRotationCleanupActionMutex -Name ([string]$Journal.cleanup_action_mutex)',
    [System.StringComparison]::Ordinal
)
$postFenceContainmentIndex = $containmentText.LastIndexOf(
    'Invoke-QmRotationHostContainmentPass -Journal $Journal', [System.StringComparison]::Ordinal
)
$evidenceIndex = $containmentText.IndexOf('Resolve-QmRotationCleanupEvidence', [System.StringComparison]::Ordinal)
if ($targetDrainIndex -lt 0 -or $preFenceContainmentIndex -le $targetDrainIndex -or
    $cleanupDrainIndex -le $preFenceContainmentIndex -or
    $actionFenceIndex -le $cleanupDrainIndex -or $postFenceContainmentIndex -le $actionFenceIndex -or
    $evidenceIndex -le $postFenceContainmentIndex) {
    throw 'Recovery must contain the host before lease removal, then fence and repeat containment before evidence.'
}
$helperAcquireIndex = $cleanupText.LastIndexOf(
    '$cleanupActionMutexAcquired = Enter-QmCleanupActionMutex', [System.StringComparison]::Ordinal
)
$helperPrecontainIndex = $cleanupText.LastIndexOf(
    '$null = Invoke-QmCleanupLeaseAction -ContainmentOnly', [System.StringComparison]::Ordinal
)
$helperInvokeIndex = $cleanupText.LastIndexOf('Invoke-QmCleanupLeaseAction', [System.StringComparison]::Ordinal)
$helperReleaseIndex = $cleanupText.LastIndexOf('$cleanupActionMutexHandle.ReleaseMutex()', [System.StringComparison]::Ordinal)
$selfUnregisterIndex = $cleanupText.IndexOf(
    'Unregister-QmTaskExact -TaskName $CleanupTaskName', [System.StringComparison]::Ordinal
)
$disarmWriteIndex = $cleanupText.IndexOf(
    'Write-QmAtomicResult -Path $disarmResultPath -Payload $disarmPayload', [System.StringComparison]::Ordinal
)
if ($helperPrecontainIndex -lt 0 -or $helperAcquireIndex -le $helperPrecontainIndex -or
    $helperInvokeIndex -le $helperAcquireIndex -or
    $helperReleaseIndex -le $helperInvokeIndex -or $selfUnregisterIndex -lt 0 -or
    $disarmWriteIndex -le $selfUnregisterIndex) {
    throw 'Cleanup action is not fenced across self-unregister and durable disarm publication.'
}
if (-not $cleanupText.Contains('Invoke-QmCleanupLeaseAction -AllowControllerDisarmedNoOp', [System.StringComparison]::Ordinal) -or
    -not $cleanupText.Contains('Test-QmCleanupControllerDisarmedNoOpState', [System.StringComparison]::Ordinal)) {
    throw 'Post-fence cleanup lacks the exact controller-disarmed no-op path for a delayed pre-fence helper.'
}
& {
    $script:TaskPath = '\'
    $TargetTaskName = 'QM_DEV1_SMOKE_' + ('4' * 32)
    $script:unexpectedTaskMutation = $false
    function Get-ScheduledTask {
        param([string]$TaskName, [string]$TaskPath, [object]$ErrorAction)
        return $null
    }
    function Stop-ScheduledTask { $script:unexpectedTaskMutation = $true; throw 'Absent target task was stopped.' }
    function Unregister-ScheduledTask { $script:unexpectedTaskMutation = $true; throw 'Absent target task was unregistered.' }
    Invoke-Expression (Get-QmCleanupFunctionText -Name 'Stop-QmTargetTaskExact')
    Invoke-Expression (Get-QmCleanupFunctionText -Name 'Unregister-QmTaskExact')
    Stop-QmTargetTaskExact
    Unregister-QmTaskExact -TaskName $TargetTaskName
    if ($script:unexpectedTaskMutation) {
        throw 'Cleanup helper does not handle an absent pre-migration target task idempotently.'
    }
}
$resumePreflightAdminIndex = $resumeText.IndexOf(
    'Assert-QmRotationTargetNonAdministrator -TargetSid ([string]$journal.target_sid)',
    [System.StringComparison]::Ordinal
)
$resumeContainmentIndex = $resumeText.IndexOf('Invoke-QmRotationRecoveryContainment', [System.StringComparison]::Ordinal)
$resumeMoveIndex = $resumeText.IndexOf('[System.IO.File]::Move([string]$journal.credential_staged_path', [System.StringComparison]::Ordinal)
$resumeFinalAdminIndex = $resumeText.LastIndexOf(
    'Assert-QmRotationTargetNonAdministrator -TargetSid ([string]$journal.target_sid)',
    [System.StringComparison]::Ordinal
)
$resumeCanonicalIndex = $resumeText.IndexOf('Write-QmCanonicalRotationReceipt', [System.StringComparison]::Ordinal)
$resumeFenceReleaseIndex = $resumeText.LastIndexOf(
    'Exit-QmRotationCleanupActionMutex -Fence $recoveryContainment.CleanupActionFence',
    [System.StringComparison]::Ordinal
)
if ($resumePreflightAdminIndex -lt 0 -or $resumeContainmentIndex -le $resumePreflightAdminIndex -or
    $resumeMoveIndex -le $resumeContainmentIndex -or $resumeFinalAdminIndex -le $resumeMoveIndex -or
    $resumeCanonicalIndex -le $resumeFinalAdminIndex -or $resumeFenceReleaseIndex -le $resumeCanonicalIndex) {
    throw 'Resume does not reassert non-administrator membership before mutation and canonical publication.'
}
$mainMoveIndex = $rotationText.IndexOf('[System.IO.File]::Move($pendingCredentialPath, $credentialPath, $false)', [System.StringComparison]::Ordinal)
$mainPublishAdminIndex = $rotationText.LastIndexOf(
    'Assert-QmRotationTargetNonAdministrator -TargetSid $targetSid', $mainMoveIndex, [System.StringComparison]::Ordinal
)
if ($mainMoveIndex -lt 0 -or $mainPublishAdminIndex -lt 0 -or $mainPublishAdminIndex -ge $mainMoveIndex) {
    throw 'Initial rotation does not reassert non-administrator membership immediately before credential publication.'
}
$mainCanonicalIndex = $rotationText.LastIndexOf('Write-QmCanonicalRotationReceipt', [System.StringComparison]::Ordinal)
$mainFenceReleaseIndex = $rotationText.LastIndexOf(
    'Exit-QmRotationCleanupActionMutex -Fence $finalContainment.CleanupActionFence',
    [System.StringComparison]::Ordinal
)
if ($mainCanonicalIndex -lt 0 -or $mainFenceReleaseIndex -le $mainCanonicalIndex) {
    throw 'Initial rotation releases its cleanup action fence before canonical receipt sealing.'
}
$rollbackIntentIndex = $rotationText.IndexOf(
    "`$journal.phase = 'PASSWORD_ROLLBACK_INTENT_FORENSICALLY_BOUND'", [System.StringComparison]::Ordinal
)
$rollbackIntentWriteIndex = if ($rollbackIntentIndex -ge 0) {
    $rotationText.IndexOf('Write-QmRotationJournalExact -Path $journalPath -Payload $journal -Replace',
        $rollbackIntentIndex, [System.StringComparison]::Ordinal)
} else { -1 }
$rollbackQuarantineIndex = if ($rollbackIntentIndex -ge 0) {
    $rotationText.IndexOf(
        '[System.IO.File]::Move($credentialPath, $failedCredentialPath, $false)',
        $rollbackIntentIndex,
        [System.StringComparison]::Ordinal
    )
} else { -1 }
$rollbackPasswordSetIndex = if ($rollbackIntentIndex -ge 0) {
    $rotationText.IndexOf(
        'Set-LocalUser -SID (New-Object System.Security.Principal.SecurityIdentifier($targetSid))',
        $rollbackIntentIndex, [System.StringComparison]::Ordinal
    )
} else { -1 }
$rollbackCompletePhaseIndex = if ($rollbackPasswordSetIndex -ge 0) {
    $rotationText.IndexOf(
        "`$journal.phase = 'PASSWORD_ROLLED_BACK_TO_LEGACY_PENDING_FORENSICALLY_BOUND'",
        $rollbackPasswordSetIndex,
        [System.StringComparison]::Ordinal
    )
} else { -1 }
if ($rollbackIntentIndex -lt 0 -or $rollbackIntentWriteIndex -le $rollbackIntentIndex -or
    $rollbackQuarantineIndex -le $rollbackIntentWriteIndex -or
    $rollbackPasswordSetIndex -le $rollbackQuarantineIndex -or
    $rollbackCompletePhaseIndex -le $rollbackPasswordSetIndex) {
    throw 'Rollback intent is not durably write-ahead of quarantine and legacy-password mutation.'
}

& {
    function ConvertTo-QmRotationFullPath { param([string]$Path) [System.IO.Path]::GetFullPath($Path) }
    function Assert-QmRotationNoReparseComponents { param([string]$Path) }
    Invoke-Expression (Get-QmRecoveryFunctionText -Name 'Read-QmRotationBoundFileBytes')
    Invoke-Expression (Get-QmRecoveryFunctionText -Name 'Read-QmRotationExactJsonFile')
    $temporaryRoot = [System.IO.Path]::GetFullPath(
        (Join-Path 'C:\QM\tmp' ('dev1-exact-bytes-test-' + [guid]::NewGuid().ToString('N')))
    )
    if (-not $temporaryRoot.StartsWith('C:\QM\tmp\dev1-exact-bytes-test-', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Exact-byte test root escaped its fixed temporary prefix.'
    }
    [void][System.IO.Directory]::CreateDirectory($temporaryRoot)
    try {
        $path = Join-Path $temporaryRoot 'bound.json'
        $kinds = [ordered]@{ name = 'String'; schema_version = 'Int32' }
        $validJson = '{"schema_version":1,"name":"bound"}'
        [System.IO.File]::WriteAllText($path, $validJson, [System.Text.UTF8Encoding]::new($false))
        $validSha = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        $record = Read-QmRotationExactJsonFile -Path $path -ExpectedFields @('schema_version', 'name') `
            -ExpectedSha256 $validSha -ExpectedValueKinds $kinds -MaximumBytes 4096
        if ([string]$record.Sha256 -cne $validSha -or [string]$record.Json -cne $validJson) {
            throw 'Exact JSON reader did not bind the parsed JSON to the exact byte-buffer SHA-256.'
        }
        $wrongHashRejected = $false
        try {
            $null = Read-QmRotationExactJsonFile -Path $path -ExpectedFields @('schema_version', 'name') `
                -ExpectedSha256 ('0' * 64) -ExpectedValueKinds $kinds -MaximumBytes 4096
        } catch { $wrongHashRejected = $true }
        if (-not $wrongHashRejected) { throw 'Exact JSON reader accepted bytes outside the expected hash binding.' }
        foreach ($malformedJson in @(
                '{"schema_version":true,"name":"bound"}',
                '{"schema_version":"1","name":"bound"}',
                '{"schema_version":1,"name":["bound"]}',
                '{"schema_version":1,"schema_version":1,"name":"bound"}'
            )) {
            [System.IO.File]::WriteAllText($path, $malformedJson, [System.Text.UTF8Encoding]::new($false))
            $malformedSha = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
            $malformedRejected = $false
            try {
                $null = Read-QmRotationExactJsonFile -Path $path -ExpectedFields @('schema_version', 'name') `
                    -ExpectedSha256 $malformedSha -ExpectedValueKinds $kinds -MaximumBytes 4096
            } catch { $malformedRejected = $true }
            if (-not $malformedRejected) { throw 'Exact JSON reader accepted type confusion or a duplicate property.' }
        }
    } finally {
        if (Test-Path -LiteralPath $temporaryRoot) { Remove-Item -LiteralPath $temporaryRoot -Recurse -Force }
    }
}

& {
    $credentialPath = 'C:\ProgramData\QM\DEV1\credential.machine-dpapi.json'
    $canonicalRotationReceiptPath = 'C:\ProgramData\QM\DEV1\credential.machine-dpapi.rotation-receipt.json'
    $script:history = @()
    function Get-QmRotationJournalHistory { param([switch]$RequireExactAcl) return $script:history }
    function ConvertTo-QmRotationFullPath { param([string]$Path) [System.IO.Path]::GetFullPath($Path) }
    function Assert-QmRotationCleanupEvidenceHashBindings { param([object]$Journal) }
    function Test-Path { param([string]$LiteralPath, [object]$PathType) return $false }
    Invoke-Expression (Get-QmRecoveryFunctionText -Name 'Test-QmRotationRetryClearPhase')
    Invoke-Expression (Get-QmRecoveryFunctionText -Name 'Assert-QmRotationFreshApplyHistory')
    $attemptA = [pscustomobject]@{
        rotation_id = '20260720T000000Z_' + ('1' * 32)
        phase = 'IDENTITY_PROVED'
        credential_final_path = $credentialPath
        canonical_receipt_path = $canonicalRotationReceiptPath
    }
    $script:history = @([pscustomobject]@{ Journal = $attemptA })
    $attemptBRejected = $false
    try { $null = Assert-QmRotationFreshApplyHistory } catch { $attemptBRejected = $true }
    if (-not $attemptBRejected) { throw 'Attempt B was allowed while Attempt A remained identity-proved and unresolved.' }
    $attemptA.phase = 'PROOF_INVALIDATED_CONTAINED_RETRY_CLEAR'
    if ((Assert-QmRotationFreshApplyHistory) -ne 1) {
        throw 'Attempt B was not allowed after Attempt A reached explicit containment-only retry-clear.'
    }
}

& {
    function ConvertTo-QmRotationFullPath { param([string]$Path) [System.IO.Path]::GetFullPath($Path) }
    $currentRun = 'D:\QM\reports\dev1\credential-rotation\20260720T000000Z_' + ('1' * 32)
    $current = [pscustomobject]@{
        rotation_id = '20260720T000000Z_' + ('1' * 32)
        created_utc = [DateTimeOffset]::UtcNow.AddMinutes(-2).ToString('o')
    }
    $later = [pscustomobject]@{
        rotation_id = '20260720T000100Z_' + ('2' * 32)
        created_utc = [DateTimeOffset]::UtcNow.AddMinutes(-1).ToString('o')
    }
    $script:history = @(
        [pscustomobject]@{ RunDirectory = $currentRun; Journal = $current },
        [pscustomobject]@{ RunDirectory = 'D:\QM\reports\dev1\credential-rotation\later'; Journal = $later }
    )
    function Get-QmRotationJournalHistory { param([switch]$RequireExactAcl) return $script:history }
    Invoke-Expression (Get-QmRecoveryFunctionText -Name 'Assert-QmRotationResumeHasNoLaterAttempt')
    $staleResumeRejected = $false
    try {
        Assert-QmRotationResumeHasNoLaterAttempt -CurrentJournal $current -CurrentRunDirectory $currentRun
    } catch { $staleResumeRejected = $true }
    if (-not $staleResumeRejected) { throw 'Attempt A proof could be resumed after later Attempt B existed.' }
    $later.created_utc = [DateTimeOffset]::UtcNow.AddMinutes(-3).ToString('o')
    Assert-QmRotationResumeHasNoLaterAttempt -CurrentJournal $current -CurrentRunDirectory $currentRun
}

$existingResultGuardIndex = $cleanupText.IndexOf(
    'Existing cleanup containment evidence requires fenced recovery; helper retry refuses to overwrite it.',
    [System.StringComparison]::Ordinal
)
$cleanupActionStartIndex = $cleanupText.IndexOf('try { Stop-QmTargetTaskExact }', [System.StringComparison]::Ordinal)
$cleanupResultWriteIndex = $cleanupText.IndexOf(
    'Write-QmAtomicResult -Path $resultPath -Payload $containmentPayload', [System.StringComparison]::Ordinal
)
if ($existingResultGuardIndex -le $cleanupActionStartIndex -or
    $cleanupResultWriteIndex -le $existingResultGuardIndex) {
    throw 'Cleanup retry can overwrite pre-existing Result evidence instead of deferring to fenced recovery.'
}

& {
    $script:memberSid = $sid
    function Get-LocalGroup { param([object]$SID, [object]$ErrorAction) [pscustomobject]@{ Name = 'Administrators' } }
    function Get-LocalGroupMember {
        param([object]$Group, [object]$ErrorAction)
        if ($null -eq $script:memberSid) { return @() }
        return [pscustomobject]@{ SID = [pscustomobject]@{ Value = $script:memberSid } }
    }
    Invoke-Expression (Get-QmRecoveryFunctionText -Name 'Assert-QmRotationTargetNonAdministrator')
    $adminDriftRejected = $false
    try { Assert-QmRotationTargetNonAdministrator -TargetSid $sid } catch { $adminDriftRejected = $true }
    if (-not $adminDriftRejected) { throw 'BUILTIN\Administrators drift was accepted.' }
    $script:memberSid = $null
    Assert-QmRotationTargetNonAdministrator -TargetSid $sid
}

& {
    $taskPath = '\'
    $taskPrefix = 'QM_DEV1_SMOKE_'
    $compileTaskPrefix = 'QM_DEV1_COMPILE_'
    $cleanupPrefix = 'QM_DEV1_CLEANUP_'
    $profileTaskPrefix = 'QM_DEV1_PROFILE_INIT_'
    $script:staleTaskName = 'QM_DEV1_PROFILE_INIT_' + ('9' * 32)
    function Get-ScheduledTask {
        param([string]$TaskPath, [object]$ErrorAction)
        return [pscustomobject]@{ TaskName = $script:staleTaskName }
    }
    Invoke-Expression (Get-QmRecoveryFunctionText -Name 'Assert-QmRotationNoTasks')
    foreach ($case in @(
            @{ Name = 'QM_DEV1_PROFILE_INIT_' + ('9' * 32); Label = 'PROFILE_INIT' },
            @{ Name = 'QM_DEV1_COMPILE_QM20002_' + ('8' * 32); Label = 'COMPILE' }
        )) {
        $script:staleTaskName = $case.Name
        $taskRejected = $false
        try { Assert-QmRotationNoTasks } catch { $taskRejected = $true }
        if (-not $taskRejected) { throw "A stale DEV1 $($case.Label) task passed rotation preflight." }
    }
}

& {
    $taskPath = '\'
    $taskPrefix = 'QM_DEV1_SMOKE_'
    $compileTaskPrefix = 'QM_DEV1_COMPILE_'
    $cleanupPrefix = 'QM_DEV1_CLEANUP_'
    $profileTaskPrefix = 'QM_DEV1_PROFILE_INIT_'
    $targetUserName = 'QMDev1'
    $script:containmentEnabled = $true
    $script:containmentEvents = New-Object System.Collections.Generic.List[string]
    function Stop-QmRotationTargetProcesses {
        param([string]$TargetSid)
        $script:containmentEvents.Add('STOP_PROCESSES')
    }
    function ConvertTo-QmRotationFullPath { param([string]$Path) [System.IO.Path]::GetFullPath($Path) }
    function Assert-QmRotationNoReparseComponents { param([string]$Path) }
    function Get-LocalUser {
        param([object]$SID, [object]$ErrorAction)
        return [pscustomobject]@{
            Name = 'QMDev1'
            SID = [pscustomobject]@{ Value = $sid }
            Enabled = $script:containmentEnabled
            PasswordRequired = $true
        }
    }
    function Disable-LocalUser {
        param([object]$SID, [object]$ErrorAction)
        $script:containmentEvents.Add('DISABLE_ACCOUNT')
        $script:containmentEnabled = $false
    }
    function Get-ScheduledTask {
        param([string]$TaskPath, [object]$ErrorAction)
        return [pscustomobject]@{ TaskName = 'QM_DEV1_CLEANUP_' + ('2' * 32) }
    }
    function Get-QmRotationDev1Processes { param([string]$TargetSid) return @() }
    Invoke-Expression (Get-QmRecoveryFunctionText -Name 'Invoke-QmRotationHostContainmentPass')
    $temporaryRoot = [System.IO.Path]::GetFullPath(
        (Join-Path 'C:\QM\tmp' ('dev1-prefence-containment-test-' + [guid]::NewGuid().ToString('N')))
    )
    if (-not $temporaryRoot.StartsWith('C:\QM\tmp\dev1-prefence-containment-test-', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Pre-fence containment test root escaped its fixed temporary prefix.'
    }
    [void][System.IO.Directory]::CreateDirectory($temporaryRoot)
    try {
        $source = Join-Path $temporaryRoot 'canonical.txt'
        $target = Join-Path $temporaryRoot 'active.txt'
        [System.IO.File]::WriteAllText($source, 'canonical-groups', [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText($target, 'drifted-groups', [System.Text.UTF8Encoding]::new($false))
        $containmentJournal = [pscustomobject]@{
            target_sid = $sid
            cleanup_task_name = 'QM_DEV1_CLEANUP_' + ('2' * 32)
            tester_groups_source_path = $source
            tester_groups_target_path = $target
            tester_groups_sha256 = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
        }
        Invoke-QmRotationHostContainmentPass -Journal $containmentJournal -AllowBoundCleanupTask
        if ($script:containmentEnabled -or
            (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant() -cne
                [string]$containmentJournal.tester_groups_sha256 -or
            $script:containmentEvents.IndexOf('STOP_PROCESSES') -lt 0 -or
            $script:containmentEvents.IndexOf('DISABLE_ACCOUNT') -lt 0) {
            throw 'Pre-fence containment did not establish disabled/process-free/restored host state.'
        }
    } finally {
        if (Test-Path -LiteralPath $temporaryRoot) {
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
        }
    }
}

& {
    $script:CleanupActionMutexWaitMilliseconds = 100
    Invoke-Expression (Get-QmCleanupFunctionText -Name 'Enter-QmCleanupActionMutex')
    $timeoutMutex = [pscustomobject]@{}
    $timeoutMutex | Add-Member -MemberType ScriptMethod -Name WaitOne -Value { param([int]$Milliseconds) return $false }
    $timeoutRejected = $false
    try { $null = Enter-QmCleanupActionMutex -Mutex $timeoutMutex -TimeoutMilliseconds 10 } catch { $timeoutRejected = $true }
    if (-not $timeoutRejected) { throw 'Cleanup action mutex timeout did not fail closed.' }
    $abandonedMutex = [pscustomobject]@{}
    $abandonedMutex | Add-Member -MemberType ScriptMethod -Name WaitOne -Value {
        param([int]$Milliseconds)
        throw [System.Threading.AbandonedMutexException]::new('simulated cleanup crash')
    }
    if (-not (Enter-QmCleanupActionMutex -Mutex $abandonedMutex -TimeoutMilliseconds 10)) {
        throw 'An abandoned cleanup action mutex was not safely taken over.'
    }
}

& {
    Invoke-Expression (Get-QmCleanupFunctionText -Name 'Test-QmCleanupControllerDisarmedNoOpState')
    if (-not (Test-QmCleanupControllerDisarmedNoOpState -CleanupTaskPresent $false `
            -ResultPresent $false -DisarmPresent $false -ContainmentFailureCount 0)) {
        throw 'Delayed pre-fence helper did not no-op after exact controller disarm and successful containment.'
    }
    foreach ($state in @(
            @{ Task = $true; Result = $false; Disarm = $false; Failures = 0 },
            @{ Task = $false; Result = $true; Disarm = $false; Failures = 0 },
            @{ Task = $false; Result = $false; Disarm = $true; Failures = 0 },
            @{ Task = $false; Result = $false; Disarm = $false; Failures = 1 }
        )) {
        if (Test-QmCleanupControllerDisarmedNoOpState -CleanupTaskPresent $state.Task `
            -ResultPresent $state.Result -DisarmPresent $state.Disarm `
            -ContainmentFailureCount $state.Failures) {
            throw 'Controller-disarmed no-op accepted task/evidence/failure state drift.'
        }
    }
}

& {
    $script:evidencePayload = $null
    function Read-QmRotationExactJsonFile {
        param([string]$Path, [string[]]$ExpectedFields, [string]$ExpectedSha256, [int]$MaximumBytes)
        return [pscustomobject]@{
            Payload = $script:evidencePayload
            Sha256 = '7' * 64
            Json = ($script:evidencePayload | ConvertTo-Json -Depth 8 -Compress)
        }
    }
    function Set-QmDev1CredentialExactAcl { param([string]$Path) }
    function ConvertTo-QmRotationFullPath { param([string]$Path) return [System.IO.Path]::GetFullPath($Path) }
    Invoke-Expression (Get-QmRecoveryFunctionText -Name 'Assert-QmRotationCleanupEvidenceReceipt')
    $evidenceJournal = [pscustomobject]@{
        target_sid = $sid
        target_task_name = 'QM_DEV1_SMOKE_' + ('1' * 32)
        cleanup_task_name = 'QM_DEV1_CLEANUP_' + ('2' * 32)
        cleanup_result_path = 'C:\QM\tmp\cleanup.result.json'
    }
    function New-QmFailureEvidencePayload {
        return [pscustomobject]@{
            schema_version = [long]1
            artifact_type = 'QM_DEV1_ACCOUNT_CLEANUP_RESULT'
            completed_utc = [DateTimeOffset]::UtcNow.ToString('o')
            success = $false
            containment_verified = $false
            lease_disarmed = $false
            expected_sid = $sid
            target_task_name = 'QM_DEV1_SMOKE_' + ('1' * 32)
            cleanup_task_name = 'QM_DEV1_CLEANUP_' + ('2' * 32)
            manifest_valid = $false
            account_restored_disabled = $false
            owner_process_count = [long]-1
            dev1_root_process_count = [long]-1
            target_task_registered = $true
            cleanup_task_registered = $true
            failures = [object[]]@('simulated failure')
        }
    }
    function Copy-QmEvidencePayload {
        param([object]$Payload)
        $copy = [ordered]@{}
        foreach ($property in $Payload.PSObject.Properties) { $copy[$property.Name] = $property.Value }
        return [pscustomobject]$copy
    }
    $script:evidencePayload = New-QmFailureEvidencePayload
    $null = Assert-QmRotationCleanupEvidenceReceipt -Path 'C:\QM\tmp\unused.json' `
        -ArtifactType 'QM_DEV1_ACCOUNT_CLEANUP_RESULT' -Journal $evidenceJournal -AllowFailure
    foreach ($malformed in @(
            @{ Field = 'failures'; Value = 'scalar-not-array' },
            @{ Field = 'failures'; Value = [object[]]@([long]7) },
            @{ Field = 'failures'; Value = [object[]]@() },
            @{ Field = 'owner_process_count'; Value = '-1' },
            @{ Field = 'owner_process_count'; Value = [double]1.0 },
            @{ Field = 'owner_process_count'; Value = [long]-2 },
            @{ Field = 'dev1_root_process_count'; Value = [long]2147483648 }
        )) {
        $candidate = Copy-QmEvidencePayload -Payload (New-QmFailureEvidencePayload)
        $candidate.($malformed.Field) = $malformed.Value
        $script:evidencePayload = $candidate
        $malformedRejected = $false
        try {
            $null = Assert-QmRotationCleanupEvidenceReceipt -Path 'C:\QM\tmp\unused.json' `
                -ArtifactType 'QM_DEV1_ACCOUNT_CLEANUP_RESULT' -Journal $evidenceJournal -AllowFailure
        } catch { $malformedRejected = $true }
        if (-not $malformedRejected) { throw "Malformed cleanup failure evidence was accepted: $($malformed.Field)" }
    }
    $successPayload = New-QmFailureEvidencePayload
    $successPayload.success = $true
    $successPayload.containment_verified = $true
    $successPayload.manifest_valid = $true
    $successPayload.account_restored_disabled = $true
    $successPayload.owner_process_count = [long]0
    $successPayload.dev1_root_process_count = [long]0
    $successPayload.target_task_registered = $false
    $successPayload.cleanup_task_registered = $false
    $successPayload.failures = [object[]]@()
    $script:evidencePayload = $successPayload
    $null = Assert-QmRotationCleanupEvidenceReceipt -Path 'C:\QM\tmp\unused.json' `
        -ArtifactType 'QM_DEV1_ACCOUNT_CLEANUP_RESULT' -Journal $evidenceJournal
}

& {
    $ExpectedSid = $sid
    $TargetTaskName = 'QM_DEV1_SMOKE_' + ('1' * 32)
    $CleanupTaskName = 'QM_DEV1_CLEANUP_' + ('2' * 32)
    Invoke-Expression (Get-QmCleanupFunctionText -Name 'ConvertTo-QmFullPath')
    Invoke-Expression (Get-QmCleanupFunctionText -Name 'Assert-QmExistingCleanupDisarmReceipt')
    $temporaryRoot = [System.IO.Path]::GetFullPath(
        (Join-Path 'C:\QM\tmp' ('dev1-cleanup-disarm-test-' + [guid]::NewGuid().ToString('N')))
    )
    if (-not $temporaryRoot.StartsWith('C:\QM\tmp\dev1-cleanup-disarm-test-', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Cleanup disarm validator test root escaped its fixed temporary prefix.'
    }
    [void][System.IO.Directory]::CreateDirectory($temporaryRoot)
    try {
        $resultPath = Join-Path $temporaryRoot 'cleanup_lease.result.json'
        $disarmPath = Join-Path $temporaryRoot 'cleanup_lease.disarm.result.json'
        $payload = [ordered]@{
            schema_version = 1
            artifact_type = 'QM_DEV1_ACCOUNT_CLEANUP_DISARM_RESULT'
            completed_utc = [DateTimeOffset]::UtcNow.ToString('o')
            success = $true
            containment_result_path = $resultPath
            containment_verified = $true
            lease_disarmed = $true
            expected_sid = $ExpectedSid
            target_task_name = $TargetTaskName
            cleanup_task_name = $CleanupTaskName
            account_restored_disabled = $true
            owner_process_count = 0
            dev1_root_process_count = 0
            target_task_registered = $false
            cleanup_task_registered = $false
            failures = @()
        }
        $json = $payload | ConvertTo-Json -Depth 6 -Compress
        if (-not $json.Contains('"failures":[]', [System.StringComparison]::Ordinal)) {
            throw 'Cleanup disarm regression fixture did not preserve a literal empty JSON array.'
        }
        [System.IO.File]::WriteAllText($disarmPath, $json, [System.Text.UTF8Encoding]::new($false))
        $validated = Assert-QmExistingCleanupDisarmReceipt -Path $disarmPath `
            -ExpectedContainmentResultPath $resultPath
        if (-not [bool]$validated.success -or -not [bool]$validated.lease_disarmed) {
            throw 'Helper rejected its own valid success-disarm receipt with failures=[].'
        }
    } finally {
        if (Test-Path -LiteralPath $temporaryRoot) {
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
        }
    }
}

& {
    $taskPath = '\'
    $script:getCount = 0
    $script:events = New-Object System.Collections.Generic.List[string]
    function Get-ScheduledTask {
        param([string]$TaskName, [string]$TaskPath, [object]$ErrorAction)
        $script:getCount++
        $state = switch ($script:getCount) {
            1 { 'Running' }
            2 { 'Running' }
            3 { 'Running' }
            4 { 'Ready' }
            default { $null }
        }
        if ($null -eq $state) { return $null }
        return [pscustomobject]@{ TaskName = $TaskName; TaskPath = $TaskPath; State = $state }
    }
    function Disable-ScheduledTask {
        param([string]$TaskName, [string]$TaskPath, [object]$ErrorAction)
        $script:events.Add('DISABLE')
        return [pscustomobject]@{}
    }
    function Stop-ScheduledTask {
        param([string]$TaskName, [string]$TaskPath, [object]$ErrorAction)
        $script:events.Add('STOP')
    }
    function Unregister-ScheduledTask {
        param([string]$TaskName, [string]$TaskPath, [bool]$Confirm, [object]$ErrorAction)
        $script:events.Add('UNREGISTER')
    }
    function Start-Sleep {
        param([int]$Milliseconds)
        $script:events.Add('POLL')
    }
    Invoke-Expression (Get-QmRecoveryFunctionText -Name 'Remove-QmRotationScheduledTaskBounded')
    Remove-QmRotationScheduledTaskBounded -TaskName ('QM_DEV1_CLEANUP_' + ('3' * 32)) `
        -DisableBeforeStop -TimeoutMilliseconds 1000 -PollMilliseconds 1
    $disableIndex = $script:events.IndexOf('DISABLE')
    $stopIndex = $script:events.IndexOf('STOP')
    $unregisterIndex = $script:events.IndexOf('UNREGISTER')
    if ($disableIndex -lt 0 -or $stopIndex -le $disableIndex -or $unregisterIndex -le $stopIndex -or
        $script:events.IndexOf('POLL') -le $stopIndex) {
        throw "Bounded cleanup task drain order drifted: $([string]::Join(',', $script:events))"
    }
}

& {
    $taskPath = '\'
    $script:unregistered = $false
    function Get-ScheduledTask {
        param([string]$TaskName, [string]$TaskPath, [object]$ErrorAction)
        return [pscustomobject]@{ TaskName = $TaskName; TaskPath = $TaskPath; State = 'Running' }
    }
    function Disable-ScheduledTask { param([string]$TaskName, [string]$TaskPath, [object]$ErrorAction) [pscustomobject]@{} }
    function Stop-ScheduledTask { param([string]$TaskName, [string]$TaskPath, [object]$ErrorAction) }
    function Unregister-ScheduledTask {
        param([string]$TaskName, [string]$TaskPath, [bool]$Confirm, [object]$ErrorAction)
        $script:unregistered = $true
    }
    function Start-Sleep { param([int]$Milliseconds) }
    Invoke-Expression (Get-QmRecoveryFunctionText -Name 'Remove-QmRotationScheduledTaskBounded')
    $rejected = $false
    try {
        Remove-QmRotationScheduledTaskBounded -TaskName ('QM_DEV1_CLEANUP_' + ('4' * 32)) `
            -DisableBeforeStop -TimeoutMilliseconds 10 -PollMilliseconds 1
    } catch { $rejected = $true }
    if (-not $rejected -or $script:unregistered) {
        throw 'Bounded cleanup task drain did not fail closed on a persistent Running state.'
    }
}

$lateWriterRejected = $false
try {
    Assert-QmRotationCleanupEvidenceSnapshot -ExpectedSuccessSha256 $hashA -ActualSuccessSha256 $hashB `
        -ExpectedArchiveSha256 $null -ActualArchiveSha256 $null
} catch { $lateWriterRejected = $true }
if (-not $lateWriterRejected) { throw 'Late cleanup-evidence writer drift was accepted.' }

& {
    function ConvertTo-QmRotationFullPath { param([string]$Path) [System.IO.Path]::GetFullPath($Path) }
    function Assert-QmDev1CredentialExactAcl { param([string]$Path) }
    function Assert-QmRotationCleanupEvidenceReceipt {
        param([string]$Path, [string]$ArtifactType, [object]$Journal, [switch]$AllowFailure)
        $sha = (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        $text = [System.IO.File]::ReadAllText($Path)
        $success = $text -ceq 'PASS'
        if (-not $success -and -not $AllowFailure.IsPresent) { throw 'failure not allowed' }
        return [pscustomobject]@{ Payload = [pscustomobject]@{}; Sha256 = $sha; Success = $success }
    }
    Invoke-Expression (Get-QmRecoveryFunctionText -Name 'Resolve-QmRotationCleanupEvidence')
    $temporaryRoot = [System.IO.Path]::GetFullPath(
        (Join-Path 'C:\QM\tmp' ('dev1-rotation-recovery-test-' + [guid]::NewGuid().ToString('N')))
    )
    if (-not $temporaryRoot.StartsWith('C:\QM\tmp\dev1-rotation-recovery-test-', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Recovery archive test root escaped its fixed temporary prefix.'
    }
    [void][System.IO.Directory]::CreateDirectory($temporaryRoot)
    try {
        $canonical = Join-Path $temporaryRoot 'cleanup_lease.result.json'
        [System.IO.File]::WriteAllText($canonical, 'FAIL', [System.Text.UTF8Encoding]::new($false))
        $failureSha = (Get-FileHash -LiteralPath $canonical -Algorithm SHA256).Hash.ToLowerInvariant()
        $first = Resolve-QmRotationCleanupEvidence -CanonicalPath $canonical -ArtifactType 'TEST' -Journal ([pscustomobject]@{})
        $archive = Join-Path $temporaryRoot "cleanup_lease.result.failed.$failureSha.json"
        if ((Test-Path -LiteralPath $canonical) -or -not (Test-Path -LiteralPath $archive) -or
            $first.FailureArchiveSha256 -cne $failureSha -or $null -ne $first.SuccessSha256) {
            throw 'Historical cleanup failure was not atomically archived before fresh evidence.'
        }
        $afterCrash = Resolve-QmRotationCleanupEvidence -CanonicalPath $canonical -ArtifactType 'TEST' `
            -Journal ([pscustomobject]@{}) -ExpectedFailureArchiveSha256 $failureSha
        if ($afterCrash.FailureArchiveSha256 -cne $failureSha -or $null -ne $afterCrash.SuccessSha256) {
            throw 'Crash-after-archive state was not idempotently recognized.'
        }
        [System.IO.File]::WriteAllText($canonical, 'PASS', [System.Text.UTF8Encoding]::new($false))
        $repaired = Resolve-QmRotationCleanupEvidence -CanonicalPath $canonical -ArtifactType 'TEST' `
            -Journal ([pscustomobject]@{}) -ExpectedFailureArchiveSha256 $failureSha
        $rerun = Resolve-QmRotationCleanupEvidence -CanonicalPath $canonical -ArtifactType 'TEST' `
            -Journal ([pscustomobject]@{}) -ExpectedFailureArchiveSha256 $failureSha
        if ([string]::IsNullOrWhiteSpace([string]$repaired.SuccessSha256) -or
            $rerun.SuccessSha256 -cne $repaired.SuccessSha256 -or $rerun.FailureArchiveSha256 -cne $failureSha) {
            throw 'Fresh cleanup repair evidence was not idempotently accepted with its failure archive.'
        }
        [System.IO.File]::WriteAllText($archive, 'TAMPER', [System.Text.UTF8Encoding]::new($false))
        $archiveTamperRejected = $false
        try {
            $null = Resolve-QmRotationCleanupEvidence -CanonicalPath $canonical -ArtifactType 'TEST' `
                -Journal ([pscustomobject]@{}) -ExpectedFailureArchiveSha256 $failureSha
        } catch { $archiveTamperRejected = $true }
        if (-not $archiveTamperRejected) { throw 'Tampered cleanup failure archive was accepted.' }
    } finally {
        if (Test-Path -LiteralPath $temporaryRoot) {
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
        }
    }
}

Write-Host 'PASS Test-Dev1RotationRecovery'
