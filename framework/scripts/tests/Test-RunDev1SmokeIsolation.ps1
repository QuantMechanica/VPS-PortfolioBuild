[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$controllerPath = Join-Path $repoRoot 'framework\scripts\run_dev1_smoke.ps1'
$childPath = Join-Path $repoRoot 'framework\scripts\invoke_dev1_smoke_task.ps1'
$runSmokePath = Join-Path $repoRoot 'framework\scripts\run_smoke.ps1'

function Get-ScriptAst {
    param([Parameter(Mandatory = $true)][string]$Path)
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if (@($errors).Count -gt 0) {
        throw "PowerShell parse errors in '$Path': $($errors | Out-String)"
    }
    return $ast
}

function Import-AstFunction {
    param(
        [Parameter(Mandatory = $true)][object]$Ast,
        [Parameter(Mandatory = $true)][string]$Name
    )
    $functionAst = $Ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $Name
    }, $true)
    if (-not $functionAst) { throw "Function '$Name' was not found." }
    $definition = $functionAst.Extent.Text -replace ("^function\s+{0}" -f [regex]::Escape($Name)), "function script:$Name"
    Invoke-Expression $definition
}

$controllerAst = Get-ScriptAst -Path $controllerPath
$childAst = Get-ScriptAst -Path $childPath
$runSmokeAst = Get-ScriptAst -Path $runSmokePath
$controllerText = Get-Content -LiteralPath $controllerPath -Raw
$childText = Get-Content -LiteralPath $childPath -Raw
$runSmokeText = Get-Content -LiteralPath $runSmokePath -Raw

# The public controller deliberately has no way to select a factory/live terminal,
# override the report root, permit an existing process, or submit raw arguments.
$controllerParameters = @($controllerAst.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
foreach ($forbiddenParameter in @('Terminal', 'ReportRoot', 'AllowRunningTerminal', 'ArgumentList', 'CredentialPath', 'Command')) {
    if ($controllerParameters -contains $forbiddenParameter) {
        throw "Controller exposes forbidden parameter '$forbiddenParameter'."
    }
}
$symbolParameter = $controllerAst.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'Symbol' }
$symbolValidateSet = $symbolParameter.Attributes | Where-Object {
    $_ -is [System.Management.Automation.Language.AttributeAst] -and $_.TypeName.FullName -eq 'ValidateSet'
}
$actualSymbols = @($symbolValidateSet.PositionalArguments | ForEach-Object { [string]$_.SafeGetValue() } | Sort-Object)
$expectedSymbols = @('NDX.DWX', 'GDAXI.DWX', 'EURUSD.DWX', 'GBPUSD.DWX', 'USDJPY.DWX', 'XAUUSD.DWX' | Sort-Object)
if ([string]::Join('|', $actualSymbols) -cne [string]::Join('|', $expectedSymbols)) {
    throw "DEV1 symbol allowlist drifted: $([string]::Join(',', $actualSymbols))"
}

foreach ($textContract in @(
    @{ Text = $controllerText; Marker = 'C:\ProgramData\QM\DEV1\credential.clixml' },
    @{ Text = $controllerText; Marker = 'Register-ScheduledTask' },
    @{ Text = $controllerText; Marker = 'Unregister-ScheduledTask' },
    @{ Text = $controllerText; Marker = 'MultipleInstances IgnoreNew' },
    @{ Text = $controllerText; Marker = '-RunLevel Limited' },
    @{ Text = $controllerText; Marker = 'Stop-QmDev1ProcessesExact' },
    @{ Text = $childText; Marker = 'System.Diagnostics.ProcessStartInfo' },
    @{ Text = $childText; Marker = "ArgumentList.Add('DEV1')" },
    @{ Text = $childText; Marker = 'Clear-QmInheritedEnvironment' },
    @{ Text = $childText; Marker = 'ConvertFrom-Json -AsHashtable' }
)) {
    if (-not $textContract.Text.Contains($textContract.Marker, [System.StringComparison]::Ordinal)) {
        throw "Missing DEV1 launcher contract marker: $($textContract.Marker)"
    }
}

foreach ($forbiddenText in @('farmctl', 'pipeline_dispatcher', 'run_pump_task.py', 'FACTORY_OFF.flag', 'Start-Transcript', 'Export-Clixml')) {
    if ($controllerText.Contains($forbiddenText, [System.StringComparison]::OrdinalIgnoreCase) -or
        $childText.Contains($forbiddenText, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "DEV1 launcher contains forbidden factory/pump/secret-persistence token '$forbiddenText'."
    }
}
foreach ($isolationMarker in @(
    'PasswordRequired=True', 'must not be a member of BUILTIN\Administrators', 'AreAccessRulesProtected', "LinkType -eq 'HardLink'",
    'Get-NetFirewallProfile -PolicyStore ActiveStore', 'Get-NetFirewallRule -PolicyStore ActiveStore',
    'Get-NetFirewallApplicationFilter -AssociatedNetFirewallRule',
    'QM_DEV1_BLOCK_TERMINAL_OUT', 'D:\QM\mt5\DEV1\terminal64.exe',
    'QM_DEV1_BLOCK_METATESTER_OUT', 'D:\QM\mt5\DEV1\metatester64.exe',
    'QM_DEV1_BLOCK_METAEDITOR_OUT', 'D:\QM\mt5\DEV1\MetaEditor64.exe'
)) {
    if (-not $controllerText.Contains($isolationMarker, [System.StringComparison]::Ordinal)) {
        throw "Controller isolation marker is missing: $isolationMarker"
    }
}
if ($controllerText.Contains('CommandLine', [System.StringComparison]::OrdinalIgnoreCase) -or
    $childText.Contains('CommandLine', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'DEV1 process safety must never identify or kill a process from CommandLine text.'
}
if ($childText.Contains('credential.clixml', [System.StringComparison]::OrdinalIgnoreCase) -or
    $childText.Contains('Import-Clixml', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'The QMDev1 child must never read the Administrator-bound credential file.'
}
if ($controllerText -match '(?im)^\s*(Write-(?:Host|Output)|Out-File|Set-Content).*plainPassword' -or
    $childText -match '(?i)(Get-ChildItem\s+Env:|ConvertTo-Json[^\r\n]*Environment|Start-Transcript)') {
    throw 'Credential or inherited-environment persistence pattern detected.'
}

$registerCommands = @($controllerAst.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Register-ScheduledTask'
}, $true))
if ($registerCommands.Count -ne 1) { throw 'Expected exactly one Register-ScheduledTask call.' }
$registerElements = @($registerCommands[0].CommandElements | ForEach-Object { $_.Extent.Text })
if ($registerElements -contains '-Force' -or $registerElements -contains '-Trigger') {
    throw 'Ephemeral DEV1 task registration must not overwrite a task or add a trigger.'
}
$stopCommands = @($controllerAst.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Stop-Process'
}, $true))
if ($stopCommands.Count -ne 1) { throw 'Expected exactly one tightly scoped Stop-Process call.' }
$stopParent = $stopCommands[0].Parent
while ($null -ne $stopParent -and $stopParent -isnot [System.Management.Automation.Language.FunctionDefinitionAst]) {
    $stopParent = $stopParent.Parent
}
if ($null -eq $stopParent -or $stopParent.Name -ne 'Stop-QmDev1ProcessesExact') {
    throw 'Stop-Process escaped Stop-QmDev1ProcessesExact.'
}
if (@($childAst.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Stop-Process'
}, $true)).Count -ne 0) {
    throw 'QMDev1 child must leave process termination to the controller/core exact-path guards.'
}

# Basic path-boundary behavior: adjacent DEV10/T1 roots and traversal must not match.
Import-AstFunction -Ast $controllerAst -Name 'ConvertTo-QmFullPath'
Import-AstFunction -Ast $controllerAst -Name 'Test-QmPathWithin'
if (-not (Test-QmPathWithin -Path 'D:\QM\mt5\DEV1\terminal64.exe' -Root 'D:\QM\mt5\DEV1')) {
    throw 'Exact DEV1 child path was rejected.'
}
foreach ($outside in @('D:\QM\mt5\DEV10\terminal64.exe', 'D:\QM\mt5\T1\terminal64.exe', 'D:\QM\mt5\DEV1\..\T1\terminal64.exe')) {
    if (Test-QmPathWithin -Path $outside -Root 'D:\QM\mt5\DEV1') {
        throw "Outside/adjacent path was accepted as DEV1: $outside"
    }
}

# Request validation rechecks the allowlist and rejects injection/control fields.
Remove-Item Function:\ConvertTo-QmFullPath -ErrorAction SilentlyContinue
Remove-Item Function:\Test-QmPathWithin -ErrorAction SilentlyContinue
foreach ($functionName in @('ConvertTo-QmFullPath', 'Test-QmPathWithin', 'Assert-QmRequestSchema')) {
    Import-AstFunction -Ast $childAst -Name $functionName
}
$script:ReportsRoot = 'D:\QM\reports\dev1'
$script:Dev1Root = 'D:\QM\mt5\DEV1'
$script:AllowedSymbols = @('NDX.DWX', 'GDAXI.DWX', 'EURUSD.DWX', 'GBPUSD.DWX', 'USDJPY.DWX', 'XAUUSD.DWX')
$script:AllowedParameterOrder = @(
    'EAId', 'EALabel', 'Symbol', 'Year', 'FromDate', 'ToDate', 'Expert', 'Period', 'Runs',
    'MinTrades', 'Model', 'TimeoutSeconds', 'SetFile', 'AllowMissingRealTicksLogMarker',
    'CommissionPerLot', 'TesterCurrencyOverride', 'TesterDepositOverride', 'SmokeMode'
)
$validRequest = @{
    schema_version = 1
    run_id = '20260719T200000Z_0123456789abcdef0123456789abcdef'
    nonce = 'abcdefabcdefabcdefabcdefabcdefab'
    created_utc = [DateTimeOffset]::UtcNow.ToString('o')
    expires_utc = [DateTimeOffset]::UtcNow.AddHours(1).ToString('o')
    expected_account = 'MACHINE\QMDev1'
    expected_sid = 'S-1-5-21-1-2-3-1005'
    expected_profile = 'C:\Users\QMDev1'
    expected_common_path = 'C:\Users\QMDev1\AppData\Roaming\MetaQuotes\Terminal\Common'
    dev1_root = 'D:\QM\mt5\DEV1'
    reports_root = 'D:\QM\reports\dev1'
    smoke_report_root = 'D:\QM\reports\dev1\runs\test\output\smoke'
    run_smoke_path = 'C:\QM\repo\framework\scripts\run_smoke.ps1'
    run_smoke_sha256 = ('A' * 64)
    smoke_parameters = @{
        EAId = 1001; Symbol = 'USDJPY.DWX'; Year = 2024; Expert = 'QM\QM5_1001_framework_smoke'
        Period = 'H1'; Runs = 2; MinTrades = 0; Model = 4; TimeoutSeconds = 1800; SmokeMode = $true
    }
}
Assert-QmRequestSchema -Request $validRequest -ExpectedRunDirectory 'D:\QM\reports\dev1\runs\test'

foreach ($mutation in @('Terminal', 'ReportRoot', 'AllowRunningTerminal')) {
    $copy = $validRequest | ConvertTo-Json -Depth 8 | ConvertFrom-Json -AsHashtable
    $copy.smoke_parameters[$mutation] = if ($mutation -eq 'Terminal') { 'any' } else { $true }
    try {
        Assert-QmRequestSchema -Request $copy -ExpectedRunDirectory 'D:\QM\reports\dev1\runs\test'
        throw "Request schema accepted forbidden parameter '$mutation'."
    } catch {
        if ($_.Exception.Message -like 'Request schema accepted*') { throw }
    }
}
$badSymbol = $validRequest | ConvertTo-Json -Depth 8 | ConvertFrom-Json -AsHashtable
$badSymbol.smoke_parameters.Symbol = 'T1'
try {
    Assert-QmRequestSchema -Request $badSymbol -ExpectedRunDirectory 'D:\QM\reports\dev1\runs\test'
    throw 'Request schema accepted a non-allowlisted symbol.'
} catch {
    if ($_.Exception.Message -like 'Request schema accepted*') { throw }
}
$badExpert = $validRequest | ConvertTo-Json -Depth 8 | ConvertFrom-Json -AsHashtable
$badExpert.smoke_parameters.Expert = "QM\safe`r`n-ReportRoot D:\QM\reports\framework"
try {
    Assert-QmRequestSchema -Request $badExpert -ExpectedRunDirectory 'D:\QM\reports\dev1\runs\test'
    throw 'Request schema accepted CR/LF argument injection.'
} catch {
    if ($_.Exception.Message -like 'Request schema accepted*') { throw }
}

# Timeout cleanup may kill only a freshly revalidated ExecutablePath beneath the
# exact DEV1 root and owned by the nonce-bound QMDev1 SID. Adjacent/null paths are
# ignored; a wrong-owner DEV1 process is left alive and makes cleanup fail closed.
foreach ($functionName in @('ConvertTo-QmFullPath', 'Test-QmPathWithin', 'Get-QmProcessOwnerSid',
    'Get-QmDev1Processes', 'Stop-QmDev1ProcessesExact')) {
    Import-AstFunction -Ast $controllerAst -Name $functionName
}
$script:Dev1Root = 'D:\QM\mt5\DEV1'
$script:expectedOwnerSid = 'S-1-5-21-1-2-3-1005'
$script:stoppedPids = New-Object System.Collections.Generic.List[int]
$script:mockProcesses = @(
    [pscustomobject]@{ ProcessId = 101; ExecutablePath = 'D:\QM\mt5\DEV1\terminal64.exe'; CreationDate = 'A'; OwnerSid = $script:expectedOwnerSid },
    [pscustomobject]@{ ProcessId = 102; ExecutablePath = 'D:\QM\mt5\DEV10\terminal64.exe'; CreationDate = 'B'; OwnerSid = $script:expectedOwnerSid },
    [pscustomobject]@{ ProcessId = 103; ExecutablePath = 'D:\QM\mt5\T1\terminal64.exe'; CreationDate = 'C'; OwnerSid = $script:expectedOwnerSid },
    [pscustomobject]@{ ProcessId = 104; ExecutablePath = $null; CreationDate = 'D'; OwnerSid = $script:expectedOwnerSid }
)
function Get-CimInstance {
    param([string]$ClassName, [string]$Filter, [object]$ErrorAction)
    if (-not [string]::IsNullOrWhiteSpace($Filter) -and $Filter -match 'ProcessId\s*=\s*(?<pid>[0-9]+)') {
        return @($script:mockProcesses | Where-Object { $_.ProcessId -eq [int]$Matches.pid })
    }
    return @($script:mockProcesses)
}
function Invoke-CimMethod {
    param([object]$InputObject, [string]$MethodName, [object]$ErrorAction)
    return [pscustomobject]@{ ReturnValue = 0; Sid = $InputObject.OwnerSid }
}
function Stop-Process {
    param([int]$Id, [switch]$Force, [object]$ErrorAction)
    $script:stoppedPids.Add($Id)
    $script:mockProcesses = @($script:mockProcesses | Where-Object { $_.ProcessId -ne $Id })
}
function Start-Sleep { param([int]$Seconds) }

Stop-QmDev1ProcessesExact -ExpectedOwnerSid $script:expectedOwnerSid
if ([string]::Join('|', $script:stoppedPids) -cne '101') {
    throw "Timeout cleanup targeted unexpected PIDs: $([string]::Join(',', $script:stoppedPids))"
}

$script:stoppedPids.Clear()
$script:mockProcesses = @(
    [pscustomobject]@{ ProcessId = 201; ExecutablePath = 'D:\QM\mt5\DEV1\metatester64.exe'; CreationDate = 'E'; OwnerSid = 'S-1-5-18' }
)
try {
    Stop-QmDev1ProcessesExact -ExpectedOwnerSid $script:expectedOwnerSid
    throw 'Timeout cleanup killed or accepted a wrong-owner DEV1 process.'
} catch {
    if ($_.Exception.Message -like 'Timeout cleanup killed or accepted*') { throw }
}
if ($script:stoppedPids.Count -ne 0) {
    throw 'Timeout cleanup sent Stop-Process to a wrong-owner DEV1 process.'
}

# The core runner must retain the non-bypassable identity/report/pump gates.
foreach ($marker in @('DEV1 requires the isolated', 'DEV1 ReportRoot must stay under',
    'Join-Path $resolvedReportRoot "_framework_evidence\22"', 'post_run_pump_skipped (DEV1 isolation)')) {
    if (-not $runSmokeText.Contains($marker, [System.StringComparison]::Ordinal)) {
        throw "Core run_smoke DEV1 boundary missing: $marker"
    }
}
$coreIdentityIndex = $runSmokeText.IndexOf('DEV1 requires the isolated', [System.StringComparison]::Ordinal)
$coreMutationIndex = $runSmokeText.IndexOf('Set-BacktestTerminalConfig -TerminalRoot', [System.StringComparison]::Ordinal)
if ($coreIdentityIndex -lt 0 -or $coreMutationIndex -lt 0 -or $coreIdentityIndex -gt $coreMutationIndex) {
    throw 'Core DEV1 identity guard does not precede terminal mutation.'
}

# The child keeps only a small system/profile allowlist. Prove a synthetic secret
# name is removed without ever persisting or printing its value.
Import-AstFunction -Ast $childAst -Name 'Clear-QmInheritedEnvironment'
$script:PwshPath = 'C:\Program Files\PowerShell\7\pwsh.exe'
$env:QM_DEV1_STATIC_SECRET_SENTINEL = 'redacted-test-value'
Clear-QmInheritedEnvironment -ExpectedProfile 'C:\Users\QMDev1'
if ([System.Environment]::GetEnvironmentVariables('Process').Contains('QM_DEV1_STATIC_SECRET_SENTINEL')) {
    throw 'Child environment allowlist retained a synthetic secret variable.'
}

Write-Host 'PASS Test-RunDev1SmokeIsolation'
