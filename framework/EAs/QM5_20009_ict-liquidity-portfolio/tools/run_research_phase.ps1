#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet(
        'DEV', 'DEV_SMOKE_2022',
        'OOS_2023_H1', 'OOS_2023_H2', 'OOS_2024_H1', 'OOS_2024_H2',
        'OOS_2025_H1', 'OOS_2025_H2', 'RETRO_HOLDOUT_2026_H1'
    )]
    [string]$Phase,
    [Parameter(Mandatory = $true)]
    [ValidateSet('NDX.DWX', 'GDAXI.DWX', 'GBPUSD.DWX', 'EURUSD.DWX')]
    [string]$Symbol,
    [Parameter(Mandatory = $true)]
    [ValidateSet('M1', 'M5')]
    [string]$Timeframe,
    [Parameter(Mandatory = $true)]
    [ValidateSet(
        'center', 'pivot_low', 'pivot_high', 'reclaim_low', 'reclaim_high',
        'mss_low', 'mss_high', 'fvg_low', 'fvg_high', 'stop_low', 'stop_high',
        'rr_low', 'rr_high'
    )]
    [string]$Variant,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9]{4}-[0-9]{2}-[0-9]{2}$')]
    [string]$FromDate,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9]{4}-[0-9]{2}-[0-9]{2}$')]
    [string]$ToDate,
    [ValidateSet(1, 2)]
    [int]$Runs = 2,
    [ValidateRange(60, 28800)]
    [int]$TimeoutSeconds = 7200
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'EA20009 research launcher requires PowerShell 7.' }

$launcherPath = [System.IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)
$toolsRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$eaRoot = [System.IO.Path]::GetFullPath((Join-Path $toolsRoot '..'))
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $eaRoot '..\..\..'))
$supportPath = Join-Path $toolsRoot 'research_launcher_support.psm1'
Import-Module -Name $supportPath -Force -ErrorAction Stop

$protocolPath = Join-Path $eaRoot 'docs\research_protocol_v5.json'
# DEV_SMOKE_2022 has no prior-verdict dependency and remains independently runnable.
# Binding OOS unlock stays fail-closed until the separately owned v5 adjudicator
# verdict schema is integrated into validate_research_run.py; no legacy verdict
# fields are synthesized by this launcher.
$validatorPath = Join-Path $toolsRoot 'validate_research_run.py'
$pythonCommands = @(Get-Command python.exe -All -CommandType Application -ErrorAction Stop)
if ($pythonCommands.Count -lt 1) { throw 'No Python application is available for the fixed research tools.' }
$pythonPath = [System.IO.Path]::GetFullPath([string]$pythonCommands[0].Source)
if (-not (Test-Path -LiteralPath $pythonPath -PathType Leaf)) {
    throw "Selected Python application is missing: $pythonPath"
}
$pwshPath = Join-Path $PSHOME 'pwsh.exe'

function ConvertFrom-QmProcessJson {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$ProcessResult,
        [Parameter(Mandatory = $true)][string]$Label
    )
    if ([int]$ProcessResult.exit_code -ne 0) {
        throw "$Label rejected (exit=$($ProcessResult.exit_code)): $($ProcessResult.stderr) $($ProcessResult.stdout)"
    }
    try {
        return ([string]$ProcessResult.stdout | ConvertFrom-Json -AsHashtable -DateKind String -ErrorAction Stop)
    } catch {
        throw "$Label returned non-JSON stdout: $($ProcessResult.stdout)"
    }
}

function Get-QmSnapshotRoleBinding {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$RoleBindings,
        [Parameter(Mandatory = $true)][string]$Role
    )
    if (-not $RoleBindings.Contains($Role) -or
        $RoleBindings[$Role] -isnot [System.Collections.IDictionary]) {
        throw "Runtime snapshot is missing role binding: $Role"
    }
    return $RoleBindings[$Role]
}

function Assert-QmRuntimeFileBinding {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Binding,
        [Parameter(Mandatory = $true)][string]$Label,
        [string]$RequiredRoot
    )
    foreach ($field in @('path', 'size_bytes', 'sha256')) {
        if (-not $Binding.Contains($field)) { throw "$Label binding lacks $field" }
    }
    $expectedPath = [System.IO.Path]::GetFullPath([string]$Binding['path'])
    if (-not [string]::IsNullOrWhiteSpace($RequiredRoot) -and
        -not (Test-QmPathWithin -Path $expectedPath -Root $RequiredRoot)) {
        throw "$Label binding escaped required root: $expectedPath"
    }
    $actual = Get-QmFileBinding -Path $expectedPath
    if (-not ([string]$actual['path']).Equals($expectedPath, [System.StringComparison]::OrdinalIgnoreCase) -or
        [int64]$actual['size'] -ne [int64]$Binding['size_bytes'] -or
        [string]$actual['sha256'] -cne [string]$Binding['sha256']) {
        throw "$Label binding drifted after PRE: $expectedPath"
    }
}

function Assert-QmPreboundRuntimeClosure {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Snapshot,
        [Parameter(Mandatory = $true)][System.Collections.IEnumerable]$ExternalRuntime,
        [Parameter(Mandatory = $true)][string]$SnapshotRepoRoot,
        [Parameter(Mandatory = $true)][string]$PreReceiptPath,
        [Parameter(Mandatory = $true)][string]$PreReceiptSha256
    )
    if ((Get-QmSha256 -Path $PreReceiptPath) -cne $PreReceiptSha256) {
        throw 'PRE receipt differs from the launcher in-memory identity'
    }
    $roles = $Snapshot['role_bindings']
    if ($roles -isnot [System.Collections.IDictionary]) {
        throw 'Runtime snapshot role binding closure is malformed'
    }
    foreach ($role in @($roles.Keys)) {
        $binding = $roles[$role]
        if ($binding -isnot [System.Collections.IDictionary]) {
            throw "Runtime snapshot role binding is malformed: $role"
        }
        Assert-QmRuntimeFileBinding -Binding $binding -Label "runtime role $role" `
            -RequiredRoot $SnapshotRepoRoot
    }
    $manifestBinding = [ordered]@{
        path = [string]$Snapshot['manifest_path']
        size_bytes = [int64]$Snapshot['manifest_size_bytes']
        sha256 = [string]$Snapshot['manifest_sha256']
    }
    Assert-QmRuntimeFileBinding -Binding $manifestBinding -Label 'runtime snapshot manifest'
    $sidecarPath = [string]$Snapshot['manifest_sidecar_path']
    if ((Get-QmSha256 -Path $sidecarPath) -cne [string]$Snapshot['manifest_sidecar_sha256']) {
        throw 'Runtime snapshot manifest sidecar drifted after PRE'
    }
    $externalRoles = @{}
    foreach ($raw in @($ExternalRuntime)) {
        if ($raw -isnot [System.Collections.IDictionary]) {
            throw 'External runtime binding is malformed'
        }
        $role = [string]$raw['role']
        if ([string]::IsNullOrWhiteSpace($role) -or $externalRoles.ContainsKey($role)) {
            throw "External runtime role is empty/duplicated: $role"
        }
        $externalRoles[$role] = $true
        Assert-QmRuntimeFileBinding -Binding $raw -Label "external runtime $role"
    }
    if ($externalRoles.Count -ne 7) { throw 'External runtime role closure count drifted' }
}

$contract = Get-QmResearchContract -Phase $Phase -Symbol $Symbol -Timeframe $Timeframe `
    -Variant $Variant -FromDate $FromDate -ToDate $ToDate -Runs $Runs
$safeSymbol = $Symbol.Replace('.', '_')
$setName = 'QM5_20009_{0}_{1}_{2}_{3}.set' -f $safeSymbol, $Timeframe, ([string]$contract['kind']), $Variant
$setPath = Join-Path $eaRoot "sets\$setName"

$receiptBase = [System.IO.Path]::GetFullPath('D:\QM\reports\dev1\QM5_20009\research_launcher')
$runId = '{0}_{1}_{2}_{3}_{4}' -f (
    (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'),
    $Phase,
    $safeSymbol,
    $Variant,
    [guid]::NewGuid().ToString('N')
)
$receiptDirectory = Join-Path $receiptBase $runId
New-Item -ItemType Directory -Path $receiptDirectory -ErrorAction Stop | Out-Null

$preReceiptPath = Join-Path $receiptDirectory 'validator_pre.json'
$postReceiptPath = Join-Path $receiptDirectory 'validator_post.json'
$finalSnapshotReceiptPath = Join-Path $receiptDirectory 'validator_final_snapshot.json'
$runnerResultPath = Join-Path $receiptDirectory 'runner_result.json'
$costAuditTemporary = Join-Path $receiptDirectory ('.cost_audit.{0}.tmp' -f [guid]::NewGuid().ToString('N'))
$costAuditPath = Join-Path $receiptDirectory 'cost_audit.json'
$finalReceiptPath = Join-Path $receiptDirectory 'research_run_receipt.json'
$prePayload = $null
$postPayload = $null
$finalSnapshotPayload = $null
$snapshotBinding = $null
$snapshotRoleBindings = $null
$preReceiptSha256 = $null
$runnerProcess = $null
$runnerException = $null
$postException = $null

try {
    $validatorArguments = @(
        '--phase', $Phase,
        '--symbol', $Symbol,
        '--timeframe', $Timeframe,
        '--set-file', $setPath,
        '--from', $FromDate,
        '--to', $ToDate
    )

    $preProcess = Invoke-QmCapturedProcess -FilePath $pythonPath `
        -Arguments @(
            @('-B', $validatorPath) + $validatorArguments + @(
                '--run-id', $runId,
                '--powershell-path', $pwshPath,
                '--receipt', $preReceiptPath
            )
        ) -WorkingDirectory $repoRoot
    $preOutput = ConvertFrom-QmProcessJson -ProcessResult $preProcess -Label 'research PRE validator'
    if ([string]$preOutput['status'] -cne 'PASS' -or
        -not (Test-Path -LiteralPath $preReceiptPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath ($preReceiptPath + '.sha256') -PathType Leaf)) {
        throw 'Research PRE validator did not produce a PASS receipt'
    }
    $prePayload = $preOutput
    $preReceiptSha256 = Get-QmSha256 -Path $preReceiptPath
    $snapshotBinding = $prePayload['runtime_snapshot']
    if ($snapshotBinding -isnot [System.Collections.IDictionary] -or
        $snapshotBinding['role_bindings'] -isnot [System.Collections.IDictionary]) {
        throw 'Research PRE validator omitted the immutable runtime snapshot binding'
    }
    $snapshotRoleBindings = $snapshotBinding['role_bindings']
    $snapshotRepoRoot = [System.IO.Path]::GetFullPath([string]$snapshotBinding['repo_root'])
    $requiredSnapshotRoles = @(
        'launcher', 'launcher_support', 'validator', 'generator', 'report_auditor',
        'protocol', 'sets_manifest', 'sets_manifest_detached', 'selected_set', 'ea_binary',
        'runner_dev1_controller', 'runner_dev1_child', 'runner_smoke',
        'runner_dispatch_resolver', 'runner_dispatch_pipeline', 'runner_dispatch_gates',
        'tester_defaults', 'tester_groups_canonical'
    )
    if ($snapshotRoleBindings.Count -ne $requiredSnapshotRoles.Count) {
        throw 'Runtime snapshot role closure count drifted'
    }
    foreach ($runtimeRole in $requiredSnapshotRoles) {
        $runtimeBinding = Get-QmSnapshotRoleBinding -RoleBindings $snapshotRoleBindings -Role $runtimeRole
        $runtimePath = [string]$runtimeBinding['path']
        if (-not (Test-QmPathWithin -Path $runtimePath -Root $snapshotRepoRoot) -or
            -not (Test-Path -LiteralPath $runtimePath -PathType Leaf)) {
            throw "Runtime snapshot role escaped/is missing from snapshot repo: $runtimeRole=$runtimePath"
        }
    }
    Assert-QmPreboundRuntimeClosure -Snapshot $snapshotBinding `
        -ExternalRuntime $prePayload['external_runtime'] -SnapshotRepoRoot $snapshotRepoRoot `
        -PreReceiptPath $preReceiptPath -PreReceiptSha256 $preReceiptSha256
    $snapshotValidatorPath = [string](Get-QmSnapshotRoleBinding -RoleBindings $snapshotRoleBindings -Role 'validator')['path']
    $snapshotRunDev1Path = [string](Get-QmSnapshotRoleBinding -RoleBindings $snapshotRoleBindings -Role 'runner_dev1_controller')['path']
    $snapshotRunSmokePath = [string](Get-QmSnapshotRoleBinding -RoleBindings $snapshotRoleBindings -Role 'runner_smoke')['path']
    $snapshotChildPath = [string](Get-QmSnapshotRoleBinding -RoleBindings $snapshotRoleBindings -Role 'runner_dev1_child')['path']
    $snapshotSetPath = [string](Get-QmSnapshotRoleBinding -RoleBindings $snapshotRoleBindings -Role 'selected_set')['path']
    $snapshotEaBinaryPath = [string](Get-QmSnapshotRoleBinding -RoleBindings $snapshotRoleBindings -Role 'ea_binary')['path']
    $snapshotAuditPath = [string](Get-QmSnapshotRoleBinding -RoleBindings $snapshotRoleBindings -Role 'report_auditor')['path']
    $setInputs = Read-QmSetInputs -Path $snapshotSetPath
    $runnerArguments = @(
        '-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
        '-File', $snapshotRunDev1Path,
        '-EAId', '20009',
        '-Symbol', $Symbol,
        '-Year', $FromDate.Substring(0, 4),
        '-FromDate', $FromDate.Replace('-', '.'),
        '-ToDate', $ToDate.Replace('-', '.'),
        '-Expert', 'QM\QM5_20009_ict-liquidity-portfolio',
        '-Period', $Timeframe,
        '-Runs', ([string]$Runs),
        '-MinTrades', '0',
        '-Model', '4',
        '-TimeoutSeconds', ([string]$TimeoutSeconds),
        '-SetFile', $snapshotSetPath,
        '-CommissionPerLot', '0',
        '-CommissionPerSideNative', '0',
        '-TesterCurrencyOverride', 'USD',
        '-TesterDepositOverride', '100000',
        '-SmokeMode'
    )
    $postValidatorArguments = @(
        '-B', $snapshotValidatorPath,
        '--phase', $Phase,
        '--symbol', $Symbol,
        '--timeframe', $Timeframe,
        '--set-file', $snapshotSetPath,
        '--from', $FromDate,
        '--to', $ToDate,
        '--run-id', $runId,
        '--powershell-path', $pwshPath,
        '--postflight-receipt', $preReceiptPath,
        '--preflight-receipt-sha256', $preReceiptSha256
    )

    # PRE validated the entire moving freeze, then sealed the only repository
    # runtime closure authorized below. Workspace edits after this point are irrelevant.
    try {
        $runnerProcess = Invoke-QmCapturedProcess -FilePath $pwshPath `
            -Arguments $runnerArguments -WorkingDirectory $snapshotRepoRoot
    } catch {
        $runnerException = $_
    } finally {
        # POST runs even if the controller throws or returns non-zero. It verifies
        # the immutable snapshot plus PRE-bound selected data/external runtime only.
        try {
            Assert-QmPreboundRuntimeClosure -Snapshot $snapshotBinding `
                -ExternalRuntime $prePayload['external_runtime'] -SnapshotRepoRoot $snapshotRepoRoot `
                -PreReceiptPath $preReceiptPath -PreReceiptSha256 $preReceiptSha256
            $postProcess = Invoke-QmCapturedProcess -FilePath $pythonPath `
                -Arguments @($postValidatorArguments + @('--receipt', $postReceiptPath)) `
                -WorkingDirectory $snapshotRepoRoot
            $postPayload = ConvertFrom-QmProcessJson -ProcessResult $postProcess -Label 'research POST validator'
            if ([string]$postPayload['status'] -cne 'PASS' -or
                -not (Test-Path -LiteralPath $postReceiptPath -PathType Leaf) -or
                -not (Test-Path -LiteralPath ($postReceiptPath + '.sha256') -PathType Leaf)) {
                throw 'Research POST validator did not produce a canonical PASS receipt'
            }
        } catch {
            $postException = $_
        }
    }
    if ($null -ne $postException) { throw $postException }
    if ($null -ne $runnerException) { throw $runnerException }
    if ($null -eq $runnerProcess) { throw 'DEV1 runner produced no process result' }
    $runnerPayload = ConvertFrom-QmProcessJson -ProcessResult $runnerProcess -Label 'DEV1 research runner'
    if ($runnerPayload['success'] -isnot [bool] -or -not [bool]$runnerPayload['success']) {
        throw 'DEV1 controller result is not success=true'
    }
    $canonicalGroupsHash = [string](Get-QmSnapshotRoleBinding `
        -RoleBindings $snapshotRoleBindings -Role 'tester_groups_canonical')['sha256']
    foreach ($field in @('tester_groups_post_child_sha256', 'tester_groups_restored_sha256')) {
        if ([string]$runnerPayload[$field] -ine $canonicalGroupsHash) {
            throw "DEV1 controller $field does not equal frozen canonical Groups hash"
        }
    }
    Write-QmAtomicJson -Path $runnerResultPath -Payload $runnerPayload

    $runLogPath = [System.IO.Path]::GetFullPath([string]$runnerPayload['log_path'])
    $runnerOutputRoot = Split-Path -Parent $runLogPath
    if (-not (Test-QmPathWithin -Path $runnerOutputRoot -Root 'D:\QM\reports\dev1\runs')) {
        throw "DEV1 runner output escaped the isolated runs root: $runnerOutputRoot"
    }
    $smokeRoot = Join-Path $runnerOutputRoot 'smoke'
    $summaries = @(Get-ChildItem -LiteralPath $smokeRoot -Filter 'summary.json' -File -Recurse -ErrorAction Stop)
    if ($summaries.Count -ne 1) { throw "Expected exactly one DEV1 summary.json, found $($summaries.Count)" }
    $summaryPath = $summaries[0].FullName
    $summary = Get-Content -LiteralPath $summaryPath -Raw -Encoding utf8 |
        ConvertFrom-Json -AsHashtable -DateKind String -ErrorAction Stop
    $summaryEvidence = Assert-QmResearchSummary -Summary $summary -Contract $contract
    $reportPaths = [string[]]@($summaryEvidence['reports'])
    $testerIniPaths = [string[]]@($summaryEvidence['tester_inis'])
    $testerLogPaths = [string[]]@($summaryEvidence['tester_logs'])

    $auditArguments = New-Object System.Collections.Generic.List[string]
    $auditArguments.Add('-B')
    $auditArguments.Add($snapshotAuditPath)
    $auditArguments.Add($reportPaths[0])
    foreach ($duplicate in @($reportPaths | Select-Object -Skip 1)) {
        $auditArguments.Add('--duplicate-report')
        $auditArguments.Add($duplicate)
    }
    foreach ($pair in @(
        @('--receipt', $costAuditTemporary),
        @('--expected-symbol', $Symbol),
        @('--expected-timeframe', $Timeframe),
        @('--expected-from', $FromDate),
        @('--expected-to', $ToDate),
        @('--expected-deposit', '100000'),
        @('--expected-currency', 'USD')
    )) {
        $auditArguments.Add([string]$pair[0])
        $auditArguments.Add([string]$pair[1])
    }
    $auditProcess = Invoke-QmCapturedProcess -FilePath $pythonPath `
        -Arguments $auditArguments.ToArray() -WorkingDirectory $snapshotRepoRoot
    $auditOutput = ConvertFrom-QmProcessJson -ProcessResult $auditProcess -Label 'native MT5 cost/report audit'
    if ([string]$auditOutput['status'] -cne 'PASS' -or
        -not (Test-Path -LiteralPath $costAuditTemporary -PathType Leaf)) {
        throw 'Native MT5 audit did not produce a PASS receipt'
    }
    [System.IO.File]::Move($costAuditTemporary, $costAuditPath, $true)
    $costAudit = Get-Content -LiteralPath $costAuditPath -Raw -Encoding utf8 |
        ConvertFrom-Json -AsHashtable -DateKind String -ErrorAction Stop
    $auditObservations = Assert-QmCostAudit -Audit $costAudit -Contract $contract -SetInputs $setInputs `
        -ExpectedReports $reportPaths

    # The report auditor is also snapshot-resident. Reverify the same PRE-bound
    # closure after it completes so no late snapshot mutation can back a receipt.
    Assert-QmPreboundRuntimeClosure -Snapshot $snapshotBinding `
        -ExternalRuntime $prePayload['external_runtime'] -SnapshotRepoRoot $snapshotRepoRoot `
        -PreReceiptPath $preReceiptPath -PreReceiptSha256 $preReceiptSha256
    $finalSnapshotProcess = Invoke-QmCapturedProcess -FilePath $pythonPath `
        -Arguments @($postValidatorArguments + @('--receipt', $finalSnapshotReceiptPath)) `
        -WorkingDirectory $snapshotRepoRoot
    $finalSnapshotPayload = ConvertFrom-QmProcessJson `
        -ProcessResult $finalSnapshotProcess -Label 'research final snapshot validator'
    if ([string]$finalSnapshotPayload['status'] -cne 'PASS' -or
        -not (Test-Path -LiteralPath $finalSnapshotReceiptPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath ($finalSnapshotReceiptPath + '.sha256') -PathType Leaf)) {
        throw 'Final runtime snapshot verification did not produce a canonical PASS receipt'
    }
    if (($postPayload | ConvertTo-Json -Depth 100 -Compress) -cne
        ($finalSnapshotPayload | ConvertTo-Json -Depth 100 -Compress)) {
        throw 'Final runtime snapshot identity differs from immediate POST identity'
    }

    $artifactBindings = [ordered]@{
        validator_pre = Get-QmFileBinding -Path $preReceiptPath
        validator_post = Get-QmFileBinding -Path $postReceiptPath
        runner_result = Get-QmFileBinding -Path $runnerResultPath
        runner_summary = Get-QmFileBinding -Path $summaryPath
        cost_audit = Get-QmFileBinding -Path $costAuditPath
        raw_reports = @($reportPaths | ForEach-Object { Get-QmFileBinding -Path $_ })
        tester_inis = @($testerIniPaths | ForEach-Object { Get-QmFileBinding -Path $_ })
        tester_logs = @($testerLogPaths | ForEach-Object { Get-QmFileBinding -Path $_ })
    }
    $receipt = [ordered]@{
        schema_version = 1
        artifact_type = 'QM5_20009_FAIL_CLOSED_RESEARCH_LAUNCHER_RECEIPT'
        status = 'PASS'
        created_utc = (Get-Date).ToUniversalTime().ToString('o')
        run_id = $runId
        protocol_id = 'QM5_20009_RESEARCH_FREEZE_V5'
        request = $contract
        fixed_tester_contract = [ordered]@{
            model = 4
            initial_deposit = 100000
            currency = 'USD'
            commission_per_lot = 0
            commission_per_side_native = 0
            terminal_entrypoint = $snapshotRunDev1Path
            snapshot_working_directory = $snapshotRepoRoot
            direct_terminal_start_forbidden = $true
        }
        evidence_policy = [ordered]@{
            only_accepted_chain = 'THIS_LAUNCHER_PRE_SEALED_SNAPSHOT_DEV1_RUNNER_POST_VALIDATOR_SNAPSHOT_AUDITOR_FINAL_SNAPSHOT_VALIDATOR'
            direct_runner_output_is_not_verdict_evidence = $true
            separate_recorded_phase_verdict_is_required = $true
            verdict = 'NOT_ADJUDICATED'
            eligible_to_back_later_verdict = [bool]$contract.binding
            pass_candidate = [bool]$auditObservations['pass_candidate']
            candidate_block_reasons = $auditObservations['candidate_block_reasons']
            observed_result_flags = $auditObservations
            infrastructure_only = [bool]$contract.infrastructure_only
            dev_smoke_may_never_satisfy_verdict_gate = [bool]$contract.infrastructure_only
        }
        freeze_identity = [ordered]@{
            freeze_inputs_sha256 = [string]$prePayload['freeze_inputs_sha256']
            manifest_sha256 = [string]$prePayload['manifest_sha256']
            set_sha256 = [string]$prePayload['set_sha256']
            selected_data_sha256 = [string]$prePayload['selected_data_sha256']
            phase_unlock_records = $prePayload['phase_unlock_records']
            postflight_exact_match = $true
        }
        duplicate_identity = [ordered]@{
            required_runs = [int]$contract.runs
            canonical_deal_sequence_sha256 = [string]$costAudit['canonical_deal_sequence_sha256']
            run_fingerprint_sha256 = [string]$costAudit['run_fingerprint_sha256']
            duplicate_fingerprint_check = [string]$costAudit['duplicate_fingerprint_check']
        }
        toolchain = [ordered]@{
            runtime_snapshot = $snapshotBinding
            external_runtime = $prePayload['external_runtime']
            postflight = $postPayload
            final_snapshot_verification = $finalSnapshotPayload
        }
        artifacts = $artifactBindings
    }
    $finalBinding = Write-QmDetachedJsonReceipt -Path $finalReceiptPath -Payload $receipt
    Write-Output ([ordered]@{
        status = 'PASS'
        receipt = $finalBinding
        detached_sha256 = $finalReceiptPath + '.sha256'
        verdict = 'NOT_ADJUDICATED'
        infrastructure_only = [bool]$contract.infrastructure_only
    } | ConvertTo-Json -Depth 10)
} catch {
    $failure = [ordered]@{
        schema_version = 1
        artifact_type = 'QM5_20009_FAIL_CLOSED_RESEARCH_LAUNCHER_REJECTION'
        status = 'REJECT'
        created_utc = (Get-Date).ToUniversalTime().ToString('o')
        run_id = $runId
        request = $contract
        verdict = 'NOT_ELIGIBLE'
        error = $_.Exception.Message
        pre_validator_completed = ($null -ne $prePayload)
        post_validator_completed = ($null -ne $postPayload)
        runtime_snapshot = if ($null -ne $prePayload) { $prePayload['runtime_snapshot'] } else { $null }
        runtime_snapshot_retained = ($null -ne $snapshotBinding)
    }
    try {
        [void](Write-QmDetachedJsonReceipt -Path (Join-Path $receiptDirectory 'research_rejection.json') -Payload $failure)
    } catch {
        Write-Warning "Could not persist atomic rejection evidence: $($_.Exception.Message)"
    }
    throw
} finally {
    foreach ($temporary in @($costAuditTemporary)) {
        if (Test-Path -LiteralPath $temporary -PathType Leaf) {
            Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
        }
    }
}
