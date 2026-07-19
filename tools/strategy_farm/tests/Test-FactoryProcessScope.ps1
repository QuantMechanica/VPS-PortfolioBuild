param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$script:PassCount = 0
$script:Failures = New-Object System.Collections.Generic.List[string]

function Assert-QmTrue {
    param([bool]$Condition, [string]$Name)
    if ($Condition) {
        $script:PassCount++
    } else {
        [void]$script:Failures.Add("FAIL: $Name")
    }
}

function Assert-QmFalse {
    param([bool]$Condition, [string]$Name)
    Assert-QmTrue -Condition (-not $Condition) -Name $Name
}

function Assert-QmEqual {
    param($Expected, $Actual, [string]$Name)
    Assert-QmTrue -Condition ($Expected -eq $Actual) -Name ("{0} (expected='{1}', actual='{2}')" -f $Name, $Expected, $Actual)
}

$strategyFarmRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$helperPath = Join-Path $strategyFarmRoot 'factory_process_scope.ps1'
$factoryOffPath = Join-Path $strategyFarmRoot 'Factory_OFF.ps1'
$factoryOnPath = Join-Path $strategyFarmRoot 'Factory_ON.ps1'
$testWindowOffPath = Join-Path $strategyFarmRoot 'TestWindow_OFF.ps1'

. $helperPath

Assert-QmEqual -Expected 1 -Actual $script:QmFactoryProcessScopeVersion -Name 'scope helper version'

# Exact MT5 image-path contract.
$acceptedImages = @(
    @('D:\QM\mt5\T1\terminal64.exe', 'terminal64.exe'),
    @('D:\QM\mt5\T10\terminal64.exe', 'terminal64.exe'),
    @('d:\qm\MT5\t7\TERMINAL64.EXE', 'terminal64.exe'),
    @('D:/QM/mt5/T1/metatester64.exe', 'metatester64.exe'),
    @('D:\QM\mt5\T10\metatester64.exe', 'metatester64.exe')
)
foreach ($case in $acceptedImages) {
    Assert-QmTrue -Condition (Test-QmFactoryMt5ImagePath -Path $case[0] -ImageName $case[1]) `
        -Name "accept exact factory image $($case[0])"
}

$rejectedImages = @(
    @('D:\QM\mt5\DEV1\terminal64.exe', 'terminal64.exe'),
    @('D:\QM\mt5\DEV2\terminal64.exe', 'terminal64.exe'),
    @('D:\QM\mt5\DEV20\terminal64.exe', 'terminal64.exe'),
    @('D:\QM\mt5\T_Live\terminal64.exe', 'terminal64.exe'),
    @('D:\QM\mt5\T_Export\terminal64.exe', 'terminal64.exe'),
    @('D:\QM\mt5\T0\terminal64.exe', 'terminal64.exe'),
    @('D:\QM\mt5\T01\terminal64.exe', 'terminal64.exe'),
    @('D:\QM\mt5\T11\terminal64.exe', 'terminal64.exe'),
    @('D:\QM\mt5\T1_backup\terminal64.exe', 'terminal64.exe'),
    @('D:\QM\mt5\T1\nested\terminal64.exe', 'terminal64.exe'),
    @('C:\QM\mt5\T1\terminal64.exe', 'terminal64.exe'),
    @('D:\QM\mt5\T1\metaeditor64.exe', 'metaeditor64.exe'),
    @('D:\QM\mt5\T1\metatester64.exe', 'terminal64.exe'),
    @('D:\QM\mt5\T1\..\DEV1\terminal64.exe', 'terminal64.exe'),
    @('\\server\share\D\QM\mt5\T1\terminal64.exe', 'terminal64.exe'),
    @('\\?\D:\QM\mt5\T1\terminal64.exe', 'terminal64.exe'),
    @('T1\terminal64.exe', 'terminal64.exe'),
    @('', 'terminal64.exe'),
    @($null, 'terminal64.exe')
)
foreach ($case in $rejectedImages) {
    Assert-QmFalse -Condition (Test-QmFactoryMt5ImagePath -Path $case[0] -ImageName $case[1]) `
        -Name "reject non-factory image $($case[0])"
}

# terminal_worker.py must be the fixed script, farm root, and a T1..T10 lane.
$acceptedWorkers = @(
    'pythonw.exe -u C:\QM\repo\tools\strategy_farm\terminal_worker.py --terminal T1 --root D:\QM\strategy_farm',
    '"C:\Program Files\Python311\python.exe" "C:\QM\repo\tools\strategy_farm\terminal_worker.py" --root "D:\QM\strategy_farm" --terminal T10',
    'PYTHON.EXE -u C:\QM\REPO\tools\strategy_farm\terminal_worker.py --terminal t7 --root d:\qm\strategy_farm'
)
foreach ($commandLine in $acceptedWorkers) {
    Assert-QmTrue -Condition (Test-QmFactoryWorkerCommandLine -CommandLine $commandLine) `
        -Name "accept factory worker: $commandLine"
}

$rejectedWorkers = @(
    'pythonw.exe -u C:\QM\repo\tools\strategy_farm\terminal_worker.py --terminal DEV1 --root D:\QM\strategy_farm',
    'pythonw.exe -u C:\QM\repo\tools\strategy_farm\terminal_worker.py --terminal DEV2 --root D:\QM\strategy_farm',
    'pythonw.exe -u C:\QM\repo\tools\strategy_farm\terminal_worker.py --terminal T11 --root D:\QM\strategy_farm',
    'pythonw.exe -u C:\QM\repo\tools\strategy_farm\terminal_worker.py --terminal T01 --root D:\QM\strategy_farm',
    'pythonw.exe -u C:\QM\repo\tools\strategy_farm\terminal_worker.py --terminal T1evil --root D:\QM\strategy_farm',
    'pythonw.exe -u C:\Temp\terminal_worker.py --terminal T1 --root D:\QM\strategy_farm',
    'pythonw.exe -u tools\strategy_farm\terminal_worker.py --terminal T1 --root D:\QM\strategy_farm',
    'pythonw.exe -u C:\QM\repo\tools\strategy_farm\terminal_worker.py --terminal T1 --root D:\QM\strategy_farm_evil',
    'pythonw.exe -u C:\QM\repo\tools\strategy_farm\terminal_worker.py --terminal T1',
    'pythonw.exe -u C:\QM\repo\tools\strategy_farm\terminal_worker.py --terminal T1 --terminal T2 --root D:\QM\strategy_farm',
    'pythonw.exe inspect.py C:\QM\repo\tools\strategy_farm\terminal_worker.py --terminal T1 --root D:\QM\strategy_farm',
    'pythonw.exe -c "print(''C:\QM\repo\tools\strategy_farm\terminal_worker.py --terminal T1 --root D:\QM\strategy_farm'')"',
    'pwsh.exe C:\QM\repo\tools\strategy_farm\terminal_worker.py --terminal T1 --root D:\QM\strategy_farm',
    '',
    $null
)
foreach ($commandLine in $rejectedWorkers) {
    Assert-QmFalse -Condition (Test-QmFactoryWorkerCommandLine -CommandLine $commandLine) `
        -Name "reject non-factory worker: $commandLine"
}

# run_smoke wrappers need the fixed runner and a positive factory selector.
$workItemId = '000034e8-7161-430b-be4f-e140cb99789b'
$acceptedWrappers = @(
    'pwsh.exe -NoProfile -File C:\QM\repo\framework\scripts\run_smoke.ps1 -Terminal T1 -ReportRoot D:\QM\reports\work_items\000034e8-7161-430b-be4f-e140cb99789b',
    '"C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile -File "C:\QM\repo\framework\scripts\run_smoke.ps1" -ReportRoot "D:\QM\reports\work_items\000034e8-7161-430b-be4f-e140cb99789b" -Terminal T10',
    'powershell.exe -Terminal t6 -File C:\QM\REPO\framework\scripts\run_smoke.ps1',
    'pwsh.exe -File C:/QM/repo/framework/scripts/run_smoke.ps1 -Terminal any -ReportRoot D:/QM/reports/work_items/000034e8-7161-430b-be4f-e140cb99789b'
)
foreach ($commandLine in $acceptedWrappers) {
    Assert-QmTrue -Condition (Test-QmFactoryRunSmokeCommandLine -CommandLine $commandLine) `
        -Name "accept factory wrapper: $commandLine"
}

$rejectedWrappers = @(
    'pwsh.exe -File C:\QM\repo\framework\scripts\run_smoke.ps1 -Terminal DEV1 -ReportRoot D:\QM\reports\dev1',
    'pwsh.exe -File C:\QM\repo\framework\scripts\run_smoke.ps1 -Terminal DEV2 -ReportRoot D:\QM\reports\dev2',
    'pwsh.exe -File C:\QM\repo\framework\scripts\run_smoke.ps1 -Terminal T_Live',
    'pwsh.exe -File C:\QM\repo\framework\scripts\run_smoke.ps1 -Terminal T_Export',
    'pwsh.exe -File C:\QM\repo\framework\scripts\run_smoke.ps1 -Terminal T11',
    'pwsh.exe -File C:\QM\repo\framework\scripts\run_smoke.ps1 -Terminal T01',
    'pwsh.exe -File C:\QM\repo\framework\scripts\run_smoke.ps1 -Terminal T1evil',
    'pwsh.exe -File C:\QM\repo\framework\scripts\run_smoke.ps1 -NotTerminal T1',
    'pwsh.exe -File C:\QM\repo\framework\scripts\run_smoke.ps1 -Terminal T1 -Terminal DEV1',
    'pwsh.exe -File C:\QM\repo\framework\scripts\run_smoke.ps1 -File C:\Temp\run_smoke.ps1 -Terminal T1',
    'pwsh.exe -File C:\Temp\run_smoke.ps1 -Terminal T1',
    'pwsh.exe -File framework\scripts\run_smoke.ps1 -Terminal T1',
    'pwsh.exe -Terminal T1',
    'pwsh.exe -Command "Write-Host ''-File C:\QM\repo\framework\scripts\run_smoke.ps1 -Terminal T1''"',
    'python.exe -File C:\QM\repo\framework\scripts\run_smoke.ps1 -Terminal T1',
    'pwsh.exe -File C:\QM\repo\framework\scripts\run_smoke.ps1 -Terminal any',
    'pwsh.exe -File C:\QM\repo\framework\scripts\run_smoke.ps1 -Terminal any -ReportRoot D:\QM\reports\dev1\000034e8-7161-430b-be4f-e140cb99789b',
    'pwsh.exe -File C:\QM\repo\framework\scripts\run_smoke.ps1 -Terminal any -ReportRoot D:\QM\reports\dev2\000034e8-7161-430b-be4f-e140cb99789b',
    'pwsh.exe -File C:\QM\repo\framework\scripts\run_smoke.ps1 -Terminal any -ReportRoot D:\QM\reports\work_items_evil\000034e8-7161-430b-be4f-e140cb99789b',
    'pwsh.exe -File C:\QM\repo\framework\scripts\run_smoke.ps1 -Terminal any -ReportRoot D:\QM\reports\work_items\_archive_twin_stale_20260702',
    'pwsh.exe -File C:\QM\repo\framework\scripts\run_smoke.ps1 -Terminal any -ReportRoot D:\QM\reports\work_items\000034e8-7161-430b-be4f-e140cb99789b\nested',
    'pwsh.exe -File C:\QM\repo\framework\scripts\run_smoke.ps1 -Terminal any -ReportRoot D:\QM\reports\work_items\000034e8-7161-430b-be4f-e140cb99789b\..\..\dev1',
    '',
    $null
)
foreach ($commandLine in $rejectedWrappers) {
    Assert-QmFalse -Condition (Test-QmFactoryRunSmokeCommandLine -CommandLine $commandLine) `
        -Name "reject non-factory wrapper: $commandLine"
}

Assert-QmTrue -Condition (Test-QmDirectFactoryWorkItemReportRoot -Path "D:\QM\reports\work_items\$workItemId") `
    -Name 'accept direct UUID factory work-item report root'
Assert-QmFalse -Condition (Test-QmDirectFactoryWorkItemReportRoot -Path 'D:\QM\reports\work_items\not-a-guid') `
    -Name 'reject non-UUID factory work-item report root'

# Pump matching is exact despite the one known repository-relative launch form.
$acceptedPumps = @(
    'pythonw.exe C:\QM\repo\tools\strategy_farm\run_pump_task.py',
    'python.exe -u "C:\QM\repo\tools\strategy_farm\run_pump_task.py"',
    'pythonw.exe tools/strategy_farm/run_pump_task.py'
)
foreach ($commandLine in $acceptedPumps) {
    Assert-QmTrue -Condition (Test-QmFactoryPumpCommandLine -CommandLine $commandLine) `
        -Name "accept factory pump: $commandLine"
}

$rejectedPumps = @(
    'pythonw.exe C:\Temp\run_pump_task.py',
    'pythonw.exe C:\QM\repo\tools\strategy_farm\run_pump_task.py extra',
    'pythonw.exe tools\strategy_farm\run_pump_task.py.bak',
    'pythonw.exe inspect.py C:\QM\repo\tools\strategy_farm\run_pump_task.py',
    'pythonw.exe -c "print(''run_pump_task.py'')"',
    'pwsh.exe C:\QM\repo\tools\strategy_farm\run_pump_task.py',
    '',
    $null
)
foreach ($commandLine in $rejectedPumps) {
    Assert-QmFalse -Condition (Test-QmFactoryPumpCommandLine -CommandLine $commandLine) `
        -Name "reject non-factory pump: $commandLine"
}

# Parse every changed operational script without executing it.
foreach ($path in @($helperPath, $factoryOffPath, $factoryOnPath, $testWindowOffPath)) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$parseErrors)
    Assert-QmEqual -Expected 0 -Actual @($parseErrors).Count -Name "PowerShell parser accepts $path"
}

# The helper itself must remain side-effect-free.
$helperTokens = $null
$helperParseErrors = $null
$helperAst = [System.Management.Automation.Language.Parser]::ParseFile($helperPath, [ref]$helperTokens, [ref]$helperParseErrors)
$helperCommands = @($helperAst.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.CommandAst]
}, $true) | ForEach-Object { $_.GetCommandName() } | Where-Object { $_ })
foreach ($forbiddenCommand in @(
    'Stop-Process', 'Start-Process', 'Stop-ScheduledTask', 'Start-ScheduledTask',
    'Disable-ScheduledTask', 'Enable-ScheduledTask', 'Set-Content', 'Remove-Item'
)) {
    Assert-QmFalse -Condition ($helperCommands -contains $forbiddenCommand) `
        -Name "helper has no side-effect command $forbiddenCommand"
}

# Call sites must load the guard before their first destructive operation and
# must not retain any historical broad path/sub-string process classifier.
$staticCases = @(
    @($factoryOffPath, 'FACTORY OFF ABORTED before mutation', 'Stop-ScheduledTask'),
    @($factoryOnPath, 'FACTORY ON ABORTED before mutation', 'Remove-Item -Path $factoryOffFlagPath'),
    @($testWindowOffPath, 'TEST WINDOW OFF ABORTED before mutation', "& (Join-Path `$PSScriptRoot 'Factory_OFF.ps1')")
)
foreach ($case in $staticCases) {
    $text = [System.IO.File]::ReadAllText($case[0])
    $guardIndex = $text.IndexOf($case[1], [System.StringComparison]::Ordinal)
    $mutationIndex = $text.IndexOf($case[2], [System.StringComparison]::Ordinal)
    Assert-QmTrue -Condition ($guardIndex -ge 0 -and $mutationIndex -gt $guardIndex) `
        -Name "guard loads before first mutation in $($case[0])"
    Assert-QmTrue -Condition ($text.Contains("Join-Path `$PSScriptRoot 'factory_process_scope.ps1'")) `
        -Name "scope helper is loaded by $($case[0])"

    foreach ($forbiddenPattern in @(
        "ExecutablePath -like 'D:\QM\mt5\*'",
        "CommandLine -match 'D:\\QM\\mt5\\'",
        "CommandLine -notmatch 'T_Live'",
        "CommandLine -match 'terminal_worker\.py'",
        "CommandLine -match 'run_pump_task\.py'",
        "CommandLine -match [regex]::Escape('framework\scripts\run_smoke.ps1')"
    )) {
        Assert-QmFalse -Condition ($text.Contains($forbiddenPattern)) `
            -Name "no historical broad classifier '$forbiddenPattern' in $($case[0])"
    }
}

$offText = [System.IO.File]::ReadAllText($factoryOffPath)
$onText = [System.IO.File]::ReadAllText($factoryOnPath)
$windowText = [System.IO.File]::ReadAllText($testWindowOffPath)
Assert-QmTrue -Condition ($offText.Contains("Test-QmFactoryMt5ImagePath -Path `$_.ExecutablePath -ImageName 'terminal64.exe'")) `
    -Name 'Factory_OFF uses exact terminal classifier'
Assert-QmTrue -Condition ($offText.Contains("Test-QmFactoryMt5ImagePath -Path `$_.ExecutablePath -ImageName 'metatester64.exe'")) `
    -Name 'Factory_OFF uses exact metatester classifier'
Assert-QmTrue -Condition ($offText.Contains('Test-QmFactoryRunSmokeCommandLine -CommandLine $_.CommandLine')) `
    -Name 'Factory_OFF uses exact wrapper classifier'
Assert-QmTrue -Condition ($onText.Contains("Test-QmFactoryMt5ImagePath -Path `$_.ExecutablePath -ImageName 'terminal64.exe'")) `
    -Name 'Factory_ON uses exact terminal classifier'
Assert-QmTrue -Condition ($windowText.Contains("Name='factory terminal64 (T1..T10)=0'")) `
    -Name 'TestWindow reports factory-only terminal scope'
Assert-QmTrue -Condition ($windowText.Contains('Test-QmFactoryPumpCommandLine -CommandLine $_.CommandLine')) `
    -Name 'TestWindow uses exact pump classifier'

if ($script:Failures.Count -gt 0) {
    $script:Failures | ForEach-Object { Write-Error $_ }
    throw "Factory process-scope tests failed: $($script:Failures.Count) failure(s), $($script:PassCount) pass(es)."
}

Write-Output "Factory process-scope tests PASS ($($script:PassCount) assertions)."
