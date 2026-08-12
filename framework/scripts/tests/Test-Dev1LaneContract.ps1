[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$paths = [ordered]@{
    contract = Join-Path $repoRoot 'framework\registry\dev1_lane_contract.json'
    controller = Join-Path $repoRoot 'framework\scripts\run_dev1_smoke.ps1'
    child = Join-Path $repoRoot 'framework\scripts\invoke_dev1_smoke_task.ps1'
    credential_helper = Join-Path $repoRoot 'framework\scripts\dev1_machine_credential.ps1'
    credential_probe = Join-Path $repoRoot 'framework\scripts\probe_dev1_machine_credential.ps1'
    credential_rotate = Join-Path $repoRoot 'framework\scripts\rotate_dev1_machine_credential.ps1'
    identity_probe = Join-Path $repoRoot 'framework\scripts\invoke_dev1_identity_probe.ps1'
    cleanup = Join-Path $repoRoot 'framework\scripts\cleanup_dev1_account_lease.ps1'
}

foreach ($path in $paths.Values) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing DEV1 V3 lane dependency: $path"
    }
}
foreach ($path in @($paths.Values | Where-Object { $_.EndsWith('.ps1', [StringComparison]::OrdinalIgnoreCase) })) {
    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
    if (@($errors).Count -ne 0) { throw "PowerShell parse errors in '$path': $($errors | Out-String)" }
}

$rawContract = [IO.File]::ReadAllText($paths.contract)
if ($rawContract.Contains('DEV2', [StringComparison]::OrdinalIgnoreCase) -or
    $rawContract.Contains('QMDev2', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'DEV1 lane contract retains a DEV2 identity/path token.'
}
$contract = $rawContract | ConvertFrom-Json -DateKind String -ErrorAction Stop
$topFields = @($contract.PSObject.Properties.Name | Sort-Object)
$expectedTopFields = @(
    'agent_port_contract', 'allowed_symbols', 'contract_id', 'coordination', 'copy_contract',
    'firewall', 'identity', 'lane', 'paths', 'program_sha256', 'schema_version', 'source_lane'
) | Sort-Object
if ([string]::Join('|', $topFields) -cne [string]::Join('|', $expectedTopFields)) {
    throw 'DEV1 V3 lane contract top-level fields drifted.'
}
if ([int]$contract.schema_version -ne 3 -or
    [string]$contract.contract_id -cne 'QM_DEV1_ISOLATED_MT5_LANE_V3' -or
    [string]$contract.lane -cne 'DEV1' -or [string]$contract.source_lane -cne 'DEV1' -or
    [string]$contract.identity.local_user -cne 'QMDev1' -or
    [string]$contract.identity.profile -cne 'C:/Users/QMDev1' -or
    [string]$contract.identity.credential -cne 'C:/ProgramData/QM/DEV1/credential.machine-dpapi.json' -or
    [string]$contract.identity.credential_format -cne 'QM_DEV1_MACHINE_DPAPI_CREDENTIAL' -or
    [string]$contract.identity.dpapi_scope -cne 'LocalMachine' -or
    -not [bool]$contract.identity.limited_non_admin -or
    [string]$contract.paths.terminal_root -cne 'D:/QM/mt5/DEV1' -or
    [string]$contract.paths.report_root -cne 'D:/QM/reports/dev1' -or
    [string]$contract.coordination.controller_mutex -cne 'Global\QM_DEV1_SMOKE_CONTROLLER' -or
    [string]$contract.coordination.task_prefix -cne 'QM_DEV1_SMOKE_' -or
    [string]$contract.coordination.compile_task_prefix -cne 'QM_DEV1_COMPILE_' -or
    [string]$contract.coordination.profile_task_prefix -cne 'QM_DEV1_PROFILE_INIT_') {
    throw 'DEV1 V3 lane identity/path/coordination contract drifted.'
}
$credentialAcl = $contract.identity.credential_acl
if (-not [bool]$credentialAcl.inheritance_protected -or
    [string]$credentialAcl.owner_sid -cne 'S-1-5-32-544' -or
    [bool]$credentialAcl.additional_readers -or
    [string]::Join('|', @($credentialAcl.exact_full_control_sids | Sort-Object)) -cne
        'S-1-5-18|S-1-5-32-544') {
    throw 'DEV1 machine credential ACL contract is not exact Admin/SYSTEM FullControl.'
}
$port = $contract.agent_port_contract
if ([bool]$port.source_agents_dat_copied -or -not [bool]$port.require_runtime_listener_proof -or
    -not [bool]$port.require_exact_dev1_metatester_path -or
    -not [bool]$port.require_no_concurrent_overlapping_endpoint_owner -or
    -not [bool]$port.allow_released_baseline_endpoint_reuse -or
    [int]$port.minimum_port -ne 3000 -or [int]$port.maximum_port -ne 65535) {
    throw 'DEV1 agent-port proof contract is not fail-closed.'
}
$expectedSymbols = @('GDAXI.DWX', 'GBPUSD.DWX', 'EURUSD.DWX', 'NDX.DWX', 'USDJPY.DWX', 'XAUUSD.DWX') | Sort-Object
$actualSymbols = @($contract.allowed_symbols | ForEach-Object { [string]$_ } | Sort-Object)
if ([string]::Join('|', $actualSymbols) -cne [string]::Join('|', $expectedSymbols)) {
    throw 'DEV1 .DWX symbol allowlist drifted.'
}

$programFields = @($contract.program_sha256.PSObject.Properties.Name | Sort-Object)
$expectedPrograms = @('MetaEditor64.exe', 'metatester64.exe', 'terminal64.exe') | Sort-Object
if ([string]::Join('|', $programFields) -cne [string]::Join('|', $expectedPrograms)) {
    throw 'DEV1 program binding set is not exact.'
}
foreach ($name in $expectedPrograms) {
    $expectedHash = ([string]$contract.program_sha256.$name).ToLowerInvariant()
    if ($expectedHash -notmatch '^[0-9a-f]{64}$') { throw "Invalid DEV1 program SHA-256: $name" }
    $programPath = Join-Path 'D:\QM\mt5\DEV1' $name
    $actualHash = (Get-FileHash -LiteralPath $programPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    if ($actualHash -cne $expectedHash) {
        throw "DEV1 program bytes differ from the V3 contract: $name"
    }
}

$controllerAstTokens = $null
$controllerAstErrors = $null
$controllerAst = [Management.Automation.Language.Parser]::ParseFile(
    $paths.controller, [ref]$controllerAstTokens, [ref]$controllerAstErrors
)
$parameterNames = @($controllerAst.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
foreach ($requiredParameter in @('ExpectedCredentialSha256', 'ExpectedHelperSha256')) {
    if ($parameterNames -notcontains $requiredParameter) {
        throw "DEV1 controller lacks mandatory stale-attempt hash binding: $requiredParameter"
    }
    $parameter = $controllerAst.ParamBlock.Parameters | Where-Object {
        $_.Name.VariablePath.UserPath -eq $requiredParameter
    }
    $mandatory = $parameter.Attributes | Where-Object {
        $_ -is [Management.Automation.Language.AttributeAst] -and $_.TypeName.FullName -eq 'Parameter' -and
        $_.NamedArguments.ArgumentName -contains 'Mandatory'
    }
    if ($null -eq $mandatory) { throw "DEV1 controller hash binding is not mandatory: $requiredParameter" }
}

$planText = (& pwsh -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $paths.credential_rotate) -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'DEV1 rotation plan-only invocation failed.' }
$plan = $planText | ConvertFrom-Json -DateKind String -ErrorAction Stop
if ([string]$plan.status -cne 'PLAN_ONLY' -or $plan.mutates_host -isnot [bool] -or
    [bool]$plan.mutates_host) {
    throw 'DEV1 rotation default mode is not read-only plan-only.'
}

Write-Host 'PASS Test-Dev1LaneContract'
