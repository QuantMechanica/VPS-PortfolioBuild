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

$protocolPath = Join-Path $eaRoot 'docs\research_protocol_v3.json'
$generatorPath = Join-Path $toolsRoot 'generate_research_sets.py'
$validatorPath = Join-Path $toolsRoot 'validate_research_run.py'
$auditPath = Join-Path $toolsRoot 'audit_mt5_report.py'
$runDev1Path = Join-Path $repoRoot 'framework\scripts\run_dev1_smoke.ps1'
$runSmokePath = Join-Path $repoRoot 'framework\scripts\run_smoke.ps1'
$invokeDev1Path = Join-Path $repoRoot 'framework\scripts\invoke_dev1_smoke_task.ps1'
$canonicalGroupsPath = Join-Path $repoRoot 'framework\registry\tester_groups\Darwinex-Live_real.canonical.txt'
$eaBinaryPath = Join-Path $eaRoot 'QM5_20009_ict-liquidity-portfolio.ex5'
$manifestPath = Join-Path $eaRoot 'sets\manifest.json'
$manifestShaPath = Join-Path $eaRoot 'sets\manifest.sha256'
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

function Get-QmToolchainBindings {
    $paths = [ordered]@{
        launcher = $launcherPath
        launcher_support = $supportPath
        protocol = $protocolPath
        generator = $generatorPath
        validator = $validatorPath
        report_auditor = $auditPath
        selected_set = $setPath
        sets_manifest = $manifestPath
        sets_manifest_detached_sha256 = $manifestShaPath
        runner_dev1_controller = $runDev1Path
        runner_smoke = $runSmokePath
        runner_dev1_child = $invokeDev1Path
        tester_groups_canonical = $canonicalGroupsPath
        ea_binary = $eaBinaryPath
        python = $pythonPath
        powershell7 = $pwshPath
    }
    $bindings = [ordered]@{}
    foreach ($entry in $paths.GetEnumerator()) {
        $bindings[$entry.Key] = Get-QmFileBinding -Path ([string]$entry.Value)
    }
    return $bindings
}

function Assert-QmToolchainUnchanged {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Before,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$After
    )
    $beforeJson = $Before | ConvertTo-Json -Depth 20 -Compress
    $afterJson = $After | ConvertTo-Json -Depth 20 -Compress
    if ($beforeJson -cne $afterJson) { throw 'Research tool/set/protocol/runner chain changed during execution' }
}

$contract = Get-QmResearchContract -Phase $Phase -Symbol $Symbol -Timeframe $Timeframe `
    -Variant $Variant -FromDate $FromDate -ToDate $ToDate -Runs $Runs
$safeSymbol = $Symbol.Replace('.', '_')
$setName = 'QM5_20009_{0}_{1}_{2}_{3}.set' -f $safeSymbol, $Timeframe, ([string]$contract['kind']), $Variant
$setPath = Join-Path $eaRoot "sets\$setName"
$setInputs = Read-QmSetInputs -Path $setPath

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
$runnerResultPath = Join-Path $receiptDirectory 'runner_result.json'
$costAuditTemporary = Join-Path $receiptDirectory ('.cost_audit.{0}.tmp' -f [guid]::NewGuid().ToString('N'))
$costAuditPath = Join-Path $receiptDirectory 'cost_audit.json'
$finalReceiptPath = Join-Path $receiptDirectory 'research_run_receipt.json'
$toolchainBefore = $null
$prePayload = $null
$postPayload = $null
$runnerProcess = $null
$runnerException = $null
$postException = $null

try {
    $toolchainBefore = Get-QmToolchainBindings

    $validatorArguments = @(
        $validatorPath,
        '--phase', $Phase,
        '--symbol', $Symbol,
        '--timeframe', $Timeframe,
        '--set-file', $setPath,
        '--from', $FromDate,
        '--to', $ToDate
    )
    $runnerArguments = @(
        '-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
        '-File', $runDev1Path,
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
        '-SetFile', $setPath,
        '-CommissionPerLot', '0',
        '-CommissionPerSideNative', '0',
        '-TesterCurrencyOverride', 'USD',
        '-TesterDepositOverride', '100000',
        '-SmokeMode'
    )

    $preProcess = Invoke-QmCapturedProcess -FilePath $pythonPath `
        -Arguments @($validatorArguments + @('--receipt', $preReceiptPath)) -WorkingDirectory $repoRoot
    $preOutput = ConvertFrom-QmProcessJson -ProcessResult $preProcess -Label 'research PRE validator'
    if ([string]$preOutput['status'] -cne 'PASS' -or
        -not (Test-Path -LiteralPath $preReceiptPath -PathType Leaf)) {
        throw 'Research PRE validator did not produce a PASS receipt'
    }
    $prePayload = $preOutput

    # No mutable-evidence operation occurs between the successful PRE and the
    # only authorized terminal path below.
    try {
        $runnerProcess = Invoke-QmCapturedProcess -FilePath $pwshPath `
            -Arguments $runnerArguments -WorkingDirectory $repoRoot
    } catch {
        $runnerException = $_
    } finally {
        # POST runs even if the controller throws or returns non-zero. It rehashes
        # selected HCC/TKC data and all frozen mutable news/Groups evidence.
        try {
            $postProcess = Invoke-QmCapturedProcess -FilePath $pythonPath `
                -Arguments @($validatorArguments + @('--postflight-receipt', $preReceiptPath)) `
                -WorkingDirectory $repoRoot
            $postPayload = ConvertFrom-QmProcessJson -ProcessResult $postProcess -Label 'research POST validator'
            if ([string]$postPayload['status'] -cne 'PASS') { throw 'Research POST validator did not PASS' }
            Write-QmAtomicJson -Path $postReceiptPath -Payload $postPayload
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
    $canonicalGroupsHash = [string]$toolchainBefore['tester_groups_canonical']['sha256']
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

    $auditArguments = New-Object System.Collections.Generic.List[string]
    $auditArguments.Add($auditPath)
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
        -Arguments $auditArguments.ToArray() -WorkingDirectory $repoRoot
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

    $toolchainAfter = Get-QmToolchainBindings
    Assert-QmToolchainUnchanged -Before $toolchainBefore -After $toolchainAfter

    $artifactBindings = [ordered]@{
        validator_pre = Get-QmFileBinding -Path $preReceiptPath
        validator_post = Get-QmFileBinding -Path $postReceiptPath
        runner_result = Get-QmFileBinding -Path $runnerResultPath
        runner_summary = Get-QmFileBinding -Path $summaryPath
        cost_audit = Get-QmFileBinding -Path $costAuditPath
        raw_reports = @($reportPaths | ForEach-Object { Get-QmFileBinding -Path $_ })
    }
    $receipt = [ordered]@{
        schema_version = 1
        artifact_type = 'QM5_20009_FAIL_CLOSED_RESEARCH_LAUNCHER_RECEIPT'
        status = 'PASS'
        created_utc = (Get-Date).ToUniversalTime().ToString('o')
        run_id = $runId
        protocol_id = 'QM5_20009_RESEARCH_FREEZE_V3'
        request = $contract
        fixed_tester_contract = [ordered]@{
            model = 4
            initial_deposit = 100000
            currency = 'USD'
            commission_per_lot = 0
            commission_per_side_native = 0
            terminal_entrypoint = $runDev1Path
            direct_terminal_start_forbidden = $true
        }
        evidence_policy = [ordered]@{
            only_accepted_chain = 'THIS_LAUNCHER_PRE_VALIDATOR_DEV1_RUNNER_POST_VALIDATOR_NATIVE_REPORT_AUDIT'
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
        toolchain = $toolchainBefore
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
