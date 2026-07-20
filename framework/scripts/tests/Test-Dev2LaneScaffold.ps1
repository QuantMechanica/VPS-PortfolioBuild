[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$paths = [ordered]@{
    contract = Join-Path $repoRoot 'framework\registry\dev2_lane_contract.json'
    provision = Join-Path $repoRoot 'framework\scripts\provision_dev2_lane.ps1'
    initialize = Join-Path $repoRoot 'framework\scripts\initialize_dev2_profile.ps1'
    controller = Join-Path $repoRoot 'framework\scripts\run_dev2_smoke.ps1'
    cleanup = Join-Path $repoRoot 'framework\scripts\cleanup_dev2_account_lease.ps1'
    child = Join-Path $repoRoot 'framework\scripts\invoke_dev2_smoke_task.ps1'
    lsa = Join-Path $repoRoot 'framework\scripts\dev2_lsa_rights.ps1'
    complete = Join-Path $repoRoot 'framework\scripts\complete_dev2_postclone.ps1'
    core = Join-Path $repoRoot 'framework\scripts\run_smoke.ps1'
}

function Get-QmParsedScript {
    param([Parameter(Mandatory = $true)][string]$Path)
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if (@($errors).Count -gt 0) { throw "PowerShell parse errors in '$Path': $($errors | Out-String)" }
    return $ast
}

foreach ($path in $paths.Values) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing DEV2 scaffold dependency: $path" }
}
$provisionAst = Get-QmParsedScript -Path $paths.provision
$null = Get-QmParsedScript -Path $paths.initialize
$controllerAst = Get-QmParsedScript -Path $paths.controller
$cleanupAst = Get-QmParsedScript -Path $paths.cleanup
$childAst = Get-QmParsedScript -Path $paths.child
$lsaAst = Get-QmParsedScript -Path $paths.lsa
$completeAst = Get-QmParsedScript -Path $paths.complete
$null = Get-QmParsedScript -Path $paths.core

$contract = Get-Content -LiteralPath $paths.contract -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
if ([int]$contract.schema_version -ne 2 -or [string]$contract.contract_id -cne 'QM_DEV2_ISOLATED_MT5_LANE_V2' -or
    [string]$contract.identity.local_user -cne 'QMDev2' -or
    [string]$contract.paths.source_terminal_root -cne 'D:/QM/mt5/DEV1' -or
    [string]$contract.paths.terminal_root -cne 'D:/QM/mt5/DEV2' -or
    [string]$contract.paths.report_root -cne 'D:/QM/reports/dev2' -or
    [string]$contract.coordination.controller_mutex -cne 'Global\QM_DEV2_SMOKE_CONTROLLER' -or
    [string]$contract.coordination.source_quiescence_mutex -cne 'Global\QM_DEV1_SMOKE_CONTROLLER' -or
    [string]$contract.coordination.task_prefix -cne 'QM_DEV2_SMOKE_') {
    throw 'DEV2 lane identity/path/coordination contract drifted.'
}
if ([bool]$contract.agent_port_contract.source_agents_dat_copied -or
    -not [bool]$contract.agent_port_contract.require_runtime_listener_proof -or
    -not [bool]$contract.agent_port_contract.require_exact_dev2_metatester_path -or
    -not [bool]$contract.agent_port_contract.require_no_concurrent_overlapping_endpoint_owner -or
    -not [bool]$contract.agent_port_contract.allow_released_baseline_endpoint_reuse) {
    throw 'DEV2 agent-port contract is not fail-closed.'
}
$exception = $contract.copy_contract.documented_exception
if ([string]$exception.relative_path -cne 'Bases/Custom/history/GBPUSD.DWX/2026.hcc' -or
    -not [bool]$exception.copy_current_bytes -or [bool]$exception.claim_old_dev1_manifest_hash) {
    throw 'DEV2 2026 HCC exception is not documented exactly.'
}

$provisionText = Get-Content -LiteralPath $paths.provision -Raw -ErrorAction Stop
$controllerText = Get-Content -LiteralPath $paths.controller -Raw -ErrorAction Stop
$cleanupText = Get-Content -LiteralPath $paths.cleanup -Raw -ErrorAction Stop
$childText = Get-Content -LiteralPath $paths.child -Raw -ErrorAction Stop
$lsaText = Get-Content -LiteralPath $paths.lsa -Raw -ErrorAction Stop
$completeText = Get-Content -LiteralPath $paths.complete -Raw -ErrorAction Stop
$coreText = Get-Content -LiteralPath $paths.core -Raw -ErrorAction Stop
foreach ($marker in @(
    'Global\QM_DEV1_SMOKE_CONTROLLER', 'Assert-QmSourceQuiescent', '.DEV2.stage.',
    'Config\agents.dat', 'verify_all_copied_files_sha256', 'old_dev1_manifest_hash_claimed = $false',
    'mutex_held_for_copy = $sourceAcquired', "smoke_status = 'PENDING'",
    'ResumeExactPartialUser', 'ExpectedPartialUserSid', 'Assert-QmExactPartialUserState',
    'Set-QmPasswordRequired', 'Disable-LocalUser', 'Enable-LocalUser'
)) {
    if (-not $provisionText.Contains($marker, [System.StringComparison]::Ordinal)) {
        throw "Provisioner safety marker is missing: $marker"
    }
}
if ($provisionText.Contains('Remove-Item', [System.StringComparison]::OrdinalIgnoreCase) -or
    $provisionText.Contains('D:\QM\mt5\T1', [System.StringComparison]::OrdinalIgnoreCase) -or
    $provisionText.Contains('Stop-Process', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Provisioner contains a destructive or factory-terminal operation.'
}
$applyParameter = $provisionAst.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'Apply' }
if ($null -eq $applyParameter) { throw 'Provisioner lacks explicit -Apply opt-in.' }

foreach ($marker in @(
    "schema_version = 2", 'lane_contract_sha256', 'child_sha256', 'program_sha256',
    'Global\QM_DEV2_SMOKE_CONTROLLER', 'QM_DEV2_SMOKE_', 'agent_port_proof',
    'runtime-exclusive metatester listener proof', 'Get-QmDev2ControllerAccountState',
    'Enable-QmDev2ControllerAccountState',
    'Restore-QmDev2ControllerAccountState', 'dev2_account_initially_enabled',
    'dev2_account_enabled_by_controller', 'dev2_account_restored_disabled',
    'QM_DEV2_CLEANUP_', 'cleanup_lease_registered', 'cleanup_lease_disarmed',
    'cleanup_helper_sha256', 'New-ScheduledTaskTrigger -AtStartup',
    '-RepetitionInterval (New-TimeSpan -Minutes 5)', '-RestartCount 3',
    'ExpectedExpiryUtc', 'AllowHardTerminate', 'Get-QmDev2IdentityProcesses',
    'try { Stop-QmDev2ProcessesExact', '$maximumRunAttempts',
    '$minimumControllerTimeout', 'maximum_run_attempts',
    'controller_timeout_seconds', 'above the 172800-second hard limit',
    'cleanup_lease_immediate_start', 'Get-QmMinimumDev2ControllerTimeoutSeconds',
    '$script:PerAttemptOverheadSeconds = 600',
    '$script:ControllerFinalizationMarginSeconds = 600',
    "Join-Path `$controlDirectory 'cleanup_lease.result.json'",
    "Join-Path `$controlDirectory 'cleanup_lease.disarm.result.json'",
    'Assert-QmImmediateCleanupDisarmReceipt',
    'independent host containment postchecks'
)) {
    if (-not $controllerText.Contains($marker, [System.StringComparison]::Ordinal)) {
        throw "DEV2 controller binding marker is missing: $marker"
    }
}
foreach ($marker in @(
    'require_runtime_listener_proof', 'require_exact_dev2_metatester_path',
    'require_no_concurrent_overlapping_endpoint_owner', 'allow_released_baseline_endpoint_reuse'
)) {
    if (-not $completeText.Contains($marker, [System.StringComparison]::Ordinal)) {
        throw "DEV2 post-clone completion port-contract marker is missing: $marker"
    }
}
foreach ($marker in @(
    'QM_DEV2_ACCOUNT_CLEANUP_LEASE', 'QM_DEV2_ACCOUNT_CLEANUP_RESULT',
    'QM_DEV2_ACCOUNT_CLEANUP_DISARM_RESULT', 'Stop-QmTargetTaskExact',
    'Stop-QmDev2ProcessesExact', 'Get-QmDev2IdentityProcesses',
    'account_restored_disabled', 'containment_verified', 'lease_disarmed',
    'tester_groups_sha256', 'Disable-LocalUser',
    "control\cleanup_lease.result.json", "control\cleanup_lease.disarm.result.json"
)) {
    if (-not $cleanupText.Contains($marker, [System.StringComparison]::Ordinal)) {
        throw "DEV2 cleanup-lease safety marker is missing: $marker"
    }
}
foreach ($marker in @(
    '[int]$Request.schema_version -ne 2', 'Get-QmListenerBaseline', 'Update-QmDev2AgentListenerProof',
    'Test-QmListenerAddressesOverlap', 'NO_CONCURRENT_OVERLAPPING_ENDPOINT_OWNER',
    "Name = 'metatester64.exe'", 'Get-NetTCPConnection -State Listen',
    'Exact-path DEV2 metatester', 'preexisting_port_owner = $false',
    'concurrent_port_owner = $false', 'released_baseline_owner_count', '$runner.Kill($true)',
    'maximum_run_attempts', 'controller_timeout_seconds', '$expectedMaximumAttempts',
    '$minimumControllerTimeout', 'per_attempt_overhead_seconds',
    'controller_finalization_margin_seconds',
    'Get-QmMinimumDev2ControllerTimeoutSeconds',
    '$script:PerAttemptOverheadSeconds = 600',
    '$script:ControllerFinalizationMarginSeconds = 600'
)) {
    if (-not $childText.Contains($marker, [System.StringComparison]::Ordinal)) {
        throw "DEV2 child runtime-proof marker is missing: $marker"
    }
}
if ($controllerText.Contains('[Math]::Min(172800', [System.StringComparison]::Ordinal) -or
    $childText.Contains('[Math]::Min(172800', [System.StringComparison]::Ordinal)) {
    throw 'DEV2 controller/child may not silently cap an underbudgeted attempt timeout.'
}
foreach ($forbidden in @('credential.clixml', 'Import-Clixml', 'farmctl', 'pipeline_dispatcher', 'run_pump_task.py', 'CommandLine')) {
    if ($childText.Contains($forbidden, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "DEV2 limited child contains forbidden token: $forbidden"
    }
}
$cleanupForbidden = @('credential.clixml', 'Import-Clixml', 'farmctl', 'pipeline_dispatcher', 'run_pump_task.py', 'CommandLine', 'Enable-LocalUser')
foreach ($forbidden in $cleanupForbidden) {
    if ($cleanupText.Contains($forbidden, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "DEV2 cleanup helper contains forbidden token: $forbidden"
    }
}
$stopCommands = @($controllerAst.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Stop-Process'
}, $true))
if ($stopCommands.Count -ne 1) { throw 'DEV2 controller must contain exactly one exact-identity Stop-Process call.' }
$stopParent = $stopCommands[0].Parent
while ($null -ne $stopParent -and $stopParent -isnot [System.Management.Automation.Language.FunctionDefinitionAst]) {
    $stopParent = $stopParent.Parent
}
if ($null -eq $stopParent -or $stopParent.Name -ne 'Stop-QmDev2ProcessesExact') {
    throw 'DEV2 Stop-Process escaped Stop-QmDev2ProcessesExact.'
}
$cleanupStopCommands = @($cleanupAst.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Stop-Process'
}, $true))
if ($cleanupStopCommands.Count -ne 1) { throw 'DEV2 cleanup helper must contain exactly one exact-identity Stop-Process call.' }
$cleanupStopParent = $cleanupStopCommands[0].Parent
while ($null -ne $cleanupStopParent -and $cleanupStopParent -isnot [System.Management.Automation.Language.FunctionDefinitionAst]) {
    $cleanupStopParent = $cleanupStopParent.Parent
}
if ($null -eq $cleanupStopParent -or $cleanupStopParent.Name -ne 'Stop-QmDev2ProcessesExact') {
    throw 'DEV2 cleanup-helper Stop-Process escaped Stop-QmDev2ProcessesExact.'
}
foreach ($accountContract in @(
    @{ Command = 'Enable-LocalUser'; Count = 1 },
    @{ Command = 'Disable-LocalUser'; Count = 2 }
)) {
    $accountCommand = [string]$accountContract.Command
    $commands = @($controllerAst.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq $accountCommand
    }, $true))
    if ($commands.Count -ne [int]$accountContract.Count) {
        throw "DEV2 controller account lifecycle has an unexpected $accountCommand count."
    }
    foreach ($command in $commands) {
        if (@($command.CommandElements | ForEach-Object { $_.Extent.Text }) -notcontains '-SID') {
            throw "DEV2 controller $accountCommand must mutate only the captured immutable SID."
        }
    }
}
$cleanupDisableCommands = @($cleanupAst.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Disable-LocalUser'
}, $true))
if ($cleanupDisableCommands.Count -ne 1) {
    throw 'DEV2 cleanup helper must contain exactly one Disable-LocalUser call.'
}
if (@($cleanupDisableCommands[0].CommandElements | ForEach-Object { $_.Extent.Text }) -notcontains '-SID') {
    throw 'DEV2 cleanup helper must disable only the captured immutable SID.'
}
$processAsts = @($controllerAst, $cleanupAst, $childAst)
foreach ($processAst in $processAsts) {
    $processQueries = @($processAst.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -eq 'Get-CimInstance' -and
        $node.Extent.Text.Contains('Win32_Process', [System.StringComparison]::Ordinal)
    }, $true))
    foreach ($query in $processQueries) {
        if (-not $query.Extent.Text.Contains('-Property ProcessId,ExecutablePath,CreationDate', [System.StringComparison]::Ordinal)) {
            throw 'Every DEV2 Win32_Process query must explicitly exclude unused sensitive properties.'
        }
    }
}
$controllerRegisters = @($controllerAst.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Register-ScheduledTask'
}, $true))
if ($controllerRegisters.Count -ne 2) {
    throw 'DEV2 controller must register exactly one cleanup lease and one smoke task.'
}
$cleanupRegisterIndex = $controllerText.IndexOf('Register-ScheduledTask -TaskName $cleanupTaskName', [System.StringComparison]::Ordinal)
$enableIndex = $controllerText.IndexOf('$dev2AccountEnabledByController = Enable-QmDev2ControllerAccountState', [System.StringComparison]::Ordinal)
$smokeRegisterIndex = $controllerText.IndexOf('Register-ScheduledTask -TaskName $taskName', [System.StringComparison]::Ordinal)
if ($cleanupRegisterIndex -lt 0 -or $enableIndex -le $cleanupRegisterIndex -or $smokeRegisterIndex -le $enableIndex) {
    throw 'DEV2 controller must arm its SYSTEM cleanup lease before just-in-time account enable and smoke-task registration.'
}
if ($controllerText.Contains('Write-Warning', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'DEV2 controller may not mask containment/disarm failures as warnings.'
}
$cleanupFailureIndex = $controllerText.IndexOf('if ($cleanupErrors.Count -gt 0 -and $cleanupTaskRegistered', [System.StringComparison]::Ordinal)
$immediateCleanupStartIndex = if ($cleanupFailureIndex -ge 0) {
    $controllerText.IndexOf('Start-ScheduledTask -TaskName $cleanupTaskName', $cleanupFailureIndex, [System.StringComparison]::Ordinal)
} else { -1 }
if ($cleanupFailureIndex -lt 0 -or $immediateCleanupStartIndex -le $cleanupFailureIndex) {
    throw 'DEV2 controller must immediately start its armed SYSTEM cleanup lease after any containment failure.'
}
$containmentPersistIndex = $cleanupText.IndexOf('Write-QmAtomicResult -Path $resultPath -Payload $containmentPayload', [System.StringComparison]::Ordinal)
$selfUnregisterIndex = $cleanupText.IndexOf('    Unregister-QmTaskExact -TaskName $CleanupTaskName', [System.StringComparison]::Ordinal)
if ($containmentPersistIndex -lt 0 -or $selfUnregisterIndex -le $containmentPersistIndex) {
    throw 'DEV2 cleanup helper must durably persist containment proof before self-unregistering its retry lease.'
}
if (@($childAst.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Stop-Process'
}, $true)).Count -ne 0) {
    throw 'DEV2 child must not use Stop-Process.'
}
foreach ($marker in @('LsaAddAccountRights', 'LsaEnumerateAccountRights', "[Qm.Dev2.LsaRights]::Add(`$Sid, 'SeBatchLogonRight')",
        "added = @(`$after | Where-Object { `$_ -notin `$before })")) {
    if (-not $lsaText.Contains($marker, [System.StringComparison]::Ordinal)) {
        throw "DEV2 LSA helper marker is missing: $marker"
    }
}
if ($lsaText.Contains('LsaRemoveAccountRights', [System.StringComparison]::Ordinal) -or
    $lsaText.Contains('SeRemoteInteractiveLogonRight', [System.StringComparison]::Ordinal) -or
    $lsaText.Contains('SeInteractiveLogonRight', [System.StringComparison]::Ordinal)) {
    throw 'DEV2 LSA helper can alter a right outside the exact batch-logon grant.'
}
foreach ($marker in @('ExpectedFailedTaskName', '2147943785', 'ERROR_LOGON_TYPE_NOT_GRANTED',
        'Grant-QmDev2BatchLogonRight', "added[0] -cne 'SeBatchLogonRight'", 'LastTaskResult',
        '$eventIds -contains 100', '$eventIds -contains 102', 'mt5_smoke_started = $false',
        "runtime_listener_proof_status = 'PENDING_FIRST_AUTHORIZED_SMOKE'",
        'ResumeExactCompletedProfileTask', 'ExpectedSuccessfulTaskName', 'Get-QmCompletedProfileTaskEvidence',
        'TASK_SCHEDULER_EVENT_201_RESULT_0_AND_EVENT_102_SUCCESS', 'Get-QmTaskCimTimeProof',
        'RAW_CLOCK_IS_UTC', 'ready_but_disarmed = $true')) {
    if (-not $completeText.Contains($marker, [System.StringComparison]::Ordinal)) {
        throw "DEV2 post-clone completion marker is missing: $marker"
    }
}
foreach ($forbidden in @('Add-LocalGroupMember', 'Remove-LocalUser', 'Remove-NetFirewallRule', 'Remove-Item')) {
    if ($completeText.Contains($forbidden, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "DEV2 post-clone completion contains forbidden mutation: $forbidden"
    }
}
$completeRegisters = @($completeAst.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Register-ScheduledTask'
}, $true))
if ($completeRegisters.Count -ne 1) { throw 'Post-clone completion must register exactly one ephemeral profile task.' }
$registerParts = @($completeRegisters[0].CommandElements | ForEach-Object { $_.Extent.Text })
if ($registerParts -contains '-Force' -or $registerParts -contains '-Trigger') {
    throw 'Post-clone completion task may not overwrite or add a trigger.'
}
$timeFunction = $completeAst.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-QmTaskCimTimeProof'
}, $true)
if ($null -eq $timeFunction) { throw 'Get-QmTaskCimTimeProof was not found.' }
Invoke-Expression $timeFunction.Extent.Text
$reference = [DateTimeOffset]::Parse('2026-07-20T01:20:33Z')
$misTaggedUtcClock = [DateTime]::SpecifyKind([DateTime]::new(2026, 7, 20, 1, 20, 31), [DateTimeKind]::Local)
$misTaggedProof = Get-QmTaskCimTimeProof -CimDateTime $misTaggedUtcClock -ReferenceUtc $reference -ToleranceSeconds 5
$correctLocalClock = [DateTime]::SpecifyKind($reference.AddSeconds(-2).LocalDateTime, [DateTimeKind]::Local)
$correctLocalProof = Get-QmTaskCimTimeProof -CimDateTime $correctLocalClock -ReferenceUtc $reference -ToleranceSeconds 5
foreach ($proof in @($misTaggedProof, $correctLocalProof)) {
    if ([string]$proof.status -cne 'PASS' -or [double]$proof.delta_seconds -gt 5) {
        throw 'Task CIM timezone normalization regression failed.'
    }
}
foreach ($marker in @('DEV2 requires the isolated', 'DEV2 ReportRoot must stay under', 'post_run_pump_skipped (DEV2 isolation)')) {
    if (-not $coreText.Contains($marker, [System.StringComparison]::Ordinal)) {
        throw "Core DEV2 isolation hook is missing: $marker"
    }
}

# Default execution is deliberately read-only, even while DEV1 is active.
$planText = & $paths.provision
if ($LASTEXITCODE -ne 0) { throw "DEV2 plan mode failed with exit code $LASTEXITCODE" }
$plan = $planText | ConvertFrom-Json -ErrorAction Stop
if ([string]$plan.status -cne 'PLAN_ONLY' -or [bool]$plan.mutates_host -or
    [string]$plan.target_root -cne 'D:\QM\mt5\DEV2') {
    throw 'DEV2 provisioner default mode is not a read-only fixed-target plan.'
}

# The executable contract is checked against the current DEV1 source without
# reading mutable history/tick files or touching either lane.
foreach ($property in @($contract.program_sha256.PSObject.Properties)) {
    $sourceProgram = Join-Path 'D:\QM\mt5\DEV1' ([string]$property.Name)
    $actualHash = (Get-FileHash -LiteralPath $sourceProgram -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    if ($actualHash -cne ([string]$property.Value).ToLowerInvariant()) {
        throw "DEV1 source program no longer matches DEV2 contract: $($property.Name)"
    }
}

Write-Host 'PASS Test-Dev2LaneScaffold'
