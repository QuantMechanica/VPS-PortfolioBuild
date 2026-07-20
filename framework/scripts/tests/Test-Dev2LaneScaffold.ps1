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
    child = Join-Path $repoRoot 'framework\scripts\invoke_dev2_smoke_task.ps1'
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
$childAst = Get-QmParsedScript -Path $paths.child
$null = Get-QmParsedScript -Path $paths.core

$contract = Get-Content -LiteralPath $paths.contract -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
if ([int]$contract.schema_version -ne 1 -or [string]$contract.contract_id -cne 'QM_DEV2_ISOLATED_MT5_LANE_V1' -or
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
    -not [bool]$contract.agent_port_contract.require_no_preexisting_port_owner) {
    throw 'DEV2 agent-port contract is not fail-closed.'
}
$exception = $contract.copy_contract.documented_exception
if ([string]$exception.relative_path -cne 'Bases/Custom/history/GBPUSD.DWX/2026.hcc' -or
    -not [bool]$exception.copy_current_bytes -or [bool]$exception.claim_old_dev1_manifest_hash) {
    throw 'DEV2 2026 HCC exception is not documented exactly.'
}

$provisionText = Get-Content -LiteralPath $paths.provision -Raw -ErrorAction Stop
$controllerText = Get-Content -LiteralPath $paths.controller -Raw -ErrorAction Stop
$childText = Get-Content -LiteralPath $paths.child -Raw -ErrorAction Stop
$coreText = Get-Content -LiteralPath $paths.core -Raw -ErrorAction Stop
foreach ($marker in @(
    'Global\QM_DEV1_SMOKE_CONTROLLER', 'Assert-QmSourceQuiescent', '.DEV2.stage.',
    'Config\agents.dat', 'verify_all_copied_files_sha256', 'old_dev1_manifest_hash_claimed = $false',
    'mutex_held_for_copy = $sourceAcquired', "smoke_status = 'PENDING'"
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
    'previously-unowned metatester listener proof'
)) {
    if (-not $controllerText.Contains($marker, [System.StringComparison]::Ordinal)) {
        throw "DEV2 controller binding marker is missing: $marker"
    }
}
foreach ($marker in @(
    '[int]$Request.schema_version -ne 2', 'Get-QmListenerBaseline', 'Update-QmDev2AgentListenerProof',
    "Name = 'metatester64.exe'", 'Get-NetTCPConnection -State Listen',
    'Exact-path DEV2 metatester', 'preexisting_port_owner = $false', '$runner.Kill($true)'
)) {
    if (-not $childText.Contains($marker, [System.StringComparison]::Ordinal)) {
        throw "DEV2 child runtime-proof marker is missing: $marker"
    }
}
foreach ($forbidden in @('credential.clixml', 'Import-Clixml', 'farmctl', 'pipeline_dispatcher', 'run_pump_task.py', 'CommandLine')) {
    if ($childText.Contains($forbidden, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "DEV2 limited child contains forbidden token: $forbidden"
    }
}
$stopCommands = @($controllerAst.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Stop-Process'
}, $true))
if ($stopCommands.Count -ne 1) { throw 'DEV2 controller must contain exactly one exact-path Stop-Process call.' }
$stopParent = $stopCommands[0].Parent
while ($null -ne $stopParent -and $stopParent -isnot [System.Management.Automation.Language.FunctionDefinitionAst]) {
    $stopParent = $stopParent.Parent
}
if ($null -eq $stopParent -or $stopParent.Name -ne 'Stop-QmDev2ProcessesExact') {
    throw 'DEV2 Stop-Process escaped Stop-QmDev2ProcessesExact.'
}
if (@($childAst.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Stop-Process'
}, $true)).Count -ne 0) {
    throw 'DEV2 child must not use Stop-Process.'
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
