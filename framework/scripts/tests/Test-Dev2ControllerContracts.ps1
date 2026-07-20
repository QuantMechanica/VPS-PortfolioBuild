[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$controllerPath = Join-Path $repoRoot 'framework\scripts\run_dev2_smoke.ps1'
$childPath = Join-Path $repoRoot 'framework\scripts\invoke_dev2_smoke_task.ps1'
$cleanupPath = Join-Path $repoRoot 'framework\scripts\cleanup_dev2_account_lease.ps1'

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
Invoke-Expression (Get-QmFunctionTextFromAst -Ast $controllerAst -Name 'Get-QmMinimumDev2ControllerTimeoutSeconds')
$controllerMinimum = Get-QmMinimumDev2ControllerTimeoutSeconds `
    -MaximumRunAttempts 4 -RunTimeoutSeconds 28800
if ($controllerMinimum -ne 118200) {
    throw "Controller timeout arithmetic drifted: $controllerMinimum"
}
if ((Get-QmMinimumDev2ControllerTimeoutSeconds -MaximumRunAttempts 10 -RunTimeoutSeconds 28800) -le 172800) {
    throw 'An underbudgeted ten-attempt maximum was not above the controller hard limit.'
}

Remove-Item -LiteralPath Function:\Get-QmMinimumDev2ControllerTimeoutSeconds -ErrorAction Stop
Invoke-Expression (Get-QmFunctionTextFromAst -Ast $childAst -Name 'Get-QmMinimumDev2ControllerTimeoutSeconds')
$childMinimum = Get-QmMinimumDev2ControllerTimeoutSeconds `
    -MaximumRunAttempts 4 -RunTimeoutSeconds 28800
if ($childMinimum -ne $controllerMinimum) {
    throw "Controller/child timeout arithmetic differs: controller=$controllerMinimum child=$childMinimum"
}

Invoke-Expression (Get-QmFunctionTextFromAst -Ast $controllerAst -Name 'ConvertTo-QmFullPath')
Invoke-Expression (Get-QmFunctionTextFromAst -Ast $controllerAst -Name 'Assert-QmImmediateCleanupDisarmReceipt')
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

$controllerText = Get-Content -LiteralPath $controllerPath -Raw -ErrorAction Stop
$cleanupText = Get-Content -LiteralPath $cleanupPath -Raw -ErrorAction Stop
foreach ($marker in @(
    "Join-Path `$controlDirectory 'cleanup_lease.result.json'",
    "Join-Path `$controlDirectory 'cleanup_lease.disarm.result.json'",
    'Immediate SYSTEM cleanup lease failed independent host containment postchecks.'
)) {
    if (-not $controllerText.Contains($marker, [System.StringComparison]::Ordinal)) {
        throw "Protected cleanup controller marker is missing: $marker"
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
