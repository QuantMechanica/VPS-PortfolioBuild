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
$allowlistPath = Join-Path $strategyFarmRoot 'phase_runner_allowlist.v1.json'
$farmctlPath = Join-Path $strategyFarmRoot 'farmctl.py'

. $helperPath

Assert-QmEqual -Expected 2 -Actual $script:QmFactoryProcessScopeVersion -Name 'scope helper version'

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
    'PYTHON.EXE -u C:\QM\REPO\tools\strategy_farm\terminal_worker.py --terminal t7 --root d:\qm\strategy_farm',
    'python.exe -X utf8 C:\QM\repo\tools\strategy_farm\terminal_worker.py --terminal T2 --root D:\QM\strategy_farm',
    'pythonw.exe -Xutf8 -u C:\QM\repo\tools\strategy_farm\terminal_worker.py --terminal T9 --root D:\QM\strategy_farm',
    'python.exe -u -X utf8 C:\QM\repo\tools\strategy_farm\terminal_worker.py --terminal T10 --root D:\QM\strategy_farm'
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
    'pythonw.exe -O C:\QM\repo\tools\strategy_farm\terminal_worker.py --terminal T1 --root D:\QM\strategy_farm',
    'pythonw.exe -X dev C:\QM\repo\tools\strategy_farm\terminal_worker.py --terminal T1 --root D:\QM\strategy_farm',
    'pythonw.exe -Xutf8=1 C:\QM\repo\tools\strategy_farm\terminal_worker.py --terminal T1 --root D:\QM\strategy_farm',
    'pythonw.exe -u -u C:\QM\repo\tools\strategy_farm\terminal_worker.py --terminal T1 --root D:\QM\strategy_farm',
    'pythonw.exe -Xutf8 -X utf8 C:\QM\repo\tools\strategy_farm\terminal_worker.py --terminal T1 --root D:\QM\strategy_farm',
    'pythonw.exe -X C:\QM\repo\tools\strategy_farm\terminal_worker.py --terminal T1 --root D:\QM\strategy_farm',
    'pythonw.exe -U C:\QM\repo\tools\strategy_farm\terminal_worker.py --terminal T1 --root D:\QM\strategy_farm',
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

# MNT-046: the shared, versioned allowlist is the sole phase-runner inventory.
$allowlist = Get-Content -LiteralPath $allowlistPath -Raw | ConvertFrom-Json
Assert-QmEqual -Expected 'qm-phase-runner-allowlist/v1' -Actual $allowlist.schema_version `
    -Name 'phase-runner allowlist schema is pinned'
Assert-QmEqual -Expected 16 -Actual @($allowlist.entries).Count `
    -Name 'all canonical PHASE_RUNNER_SCRIPTS entries are pinned'
Assert-QmTrue -Condition ([System.IO.File]::ReadAllText($farmctlPath).Contains('phase_runner_allowlist.v1.json')) `
    -Name 'farmctl consumes the shared phase-runner allowlist'

$originalDisabledTerminalsPath = $script:QmFactoryDisabledTerminalsPath
$workerPolicyFixture = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($workerPolicyFixture, '')
$script:QmFactoryDisabledTerminalsPath = $workerPolicyFixture
Assert-QmEqual -Expected 10 -Actual @(Get-QmFactoryWorkerPolicyTerminals).Count `
    -Name 'zero-disabled worker policy exposes all ten phase-runner terminals'

$runnerRoot = 'D:\QM\reports\work_items\000034e8-7161-430b-be4f-e140cb99789b'
foreach ($entry in @($allowlist.entries)) {
    $scriptPath = 'C:\QM\repo\' + ([string]$entry.repo_relative_path).Replace('/', '\')
    $commandLine = "python.exe `"$scriptPath`" --out-prefix `"$runnerRoot`""
    if ([string]$entry.terminal_selector -eq 'required') {
        $commandLine += ' --terminal T1'
    }
    $classification = Get-QmFactoryPhaseRunnerClassification -CommandLine $commandLine
    Assert-QmTrue -Condition (Test-QmFactoryPhaseRunnerCommandLine -CommandLine $commandLine) `
        -Name "accept allowlisted phase runner $($entry.phase)"
    Assert-QmEqual -Expected 'FACTORY_OWNED' -Actual $classification.Disposition `
        -Name "classify allowlisted phase runner $($entry.phase)"
    Assert-QmEqual -Expected ([string]$entry.phase) -Actual $classification.Phase `
        -Name "bind allowlisted phase $($entry.phase)"
    Assert-QmEqual -Expected $workItemId -Actual $classification.WorkItemId `
        -Name "bind work-item UUID for $($entry.phase)"
}

$worktreeRunners = @(
    'pythonw.exe -u C:\QM\worktrees\mnt-20260729-integration\framework\scripts\q07_multiseed.py --out-prefix D:\QM\reports\work_items\000034e8-7161-430b-be4f-e140cb99789b --terminal T10',
    'pythonw.exe -X utf8 C:\QM\worktrees\mnt-20260729-integration\framework\scripts\q07_multiseed.py --out-prefix D:\QM\reports\work_items\000034e8-7161-430b-be4f-e140cb99789b --terminal T10',
    'python.exe -u -Xutf8 C:\QM\repo\framework\scripts\q07_multiseed.py --out-prefix D:\QM\reports\work_items\000034e8-7161-430b-be4f-e140cb99789b --terminal T1'
)
foreach ($worktreeRunner in $worktreeRunners) {
    Assert-QmTrue -Condition (Test-QmFactoryPhaseRunnerCommandLine -CommandLine $worktreeRunner) `
        -Name "accept exact allowlisted runner with bounded Python prefix: $worktreeRunner"
}
$t5PolicyEnabled = Get-QmFactoryPhaseRunnerClassification -CommandLine `
    "python.exe C:\QM\repo\framework\scripts\q07_multiseed.py --out-prefix $runnerRoot --terminal T5"
Assert-QmEqual -Expected 'FACTORY_OWNED' -Actual $t5PolicyEnabled.Disposition `
    -Name 'T5 phase runner is factory-owned when live worker policy enables T5'

$runnerNegativeCases = @(
    @{ Name='basename only'; Command='python.exe q07_multiseed.py --out-prefix D:\QM\reports\work_items\000034e8-7161-430b-be4f-e140cb99789b --terminal T1'; Review=$true },
    @{ Name='foreign root'; Command='python.exe C:\Temp\q07_multiseed.py --out-prefix D:\QM\reports\work_items\000034e8-7161-430b-be4f-e140cb99789b --terminal T1'; Review=$true },
    @{ Name='T_Live selector'; Command='python.exe C:\QM\repo\framework\scripts\q07_multiseed.py --out-prefix D:\QM\reports\work_items\000034e8-7161-430b-be4f-e140cb99789b --terminal T_Live'; Review=$true },
    @{ Name='duplicate out-prefix'; Command='python.exe C:\QM\repo\framework\scripts\q07_multiseed.py --out-prefix D:\QM\reports\work_items\000034e8-7161-430b-be4f-e140cb99789b --out-prefix D:\QM\reports\work_items\100034e8-7161-430b-be4f-e140cb99789b --terminal T1'; Review=$true },
    @{ Name='duplicate terminal'; Command='python.exe C:\QM\repo\framework\scripts\q07_multiseed.py --out-prefix D:\QM\reports\work_items\000034e8-7161-430b-be4f-e140cb99789b --terminal T1 --terminal T2'; Review=$true },
    @{ Name='required terminal missing'; Command='python.exe C:\QM\repo\framework\scripts\q07_multiseed.py --out-prefix D:\QM\reports\work_items\000034e8-7161-430b-be4f-e140cb99789b'; Review=$true },
    @{ Name='work_items evil'; Command='python.exe C:\QM\repo\framework\scripts\q07_multiseed.py --out-prefix D:\QM\reports\work_items_evil\000034e8-7161-430b-be4f-e140cb99789b --terminal T1'; Review=$true },
    @{ Name='non UUID'; Command='python.exe C:\QM\repo\framework\scripts\q07_multiseed.py --out-prefix D:\QM\reports\work_items\not-a-guid --terminal T1'; Review=$true },
    @{ Name='nested below UUID'; Command='python.exe C:\QM\repo\framework\scripts\q07_multiseed.py --out-prefix D:\QM\reports\work_items\000034e8-7161-430b-be4f-e140cb99789b\nested --terminal T1'; Review=$true },
    @{ Name='relative script'; Command='python.exe framework\scripts\q07_multiseed.py --out-prefix D:\QM\reports\work_items\000034e8-7161-430b-be4f-e140cb99789b --terminal T1'; Review=$true },
    @{ Name='unknown interpreter optimization flag'; Command='python.exe -O C:\QM\repo\framework\scripts\q07_multiseed.py --out-prefix D:\QM\reports\work_items\000034e8-7161-430b-be4f-e140cb99789b --terminal T1'; Review=$true },
    @{ Name='unknown X option'; Command='python.exe -X dev C:\QM\repo\framework\scripts\q07_multiseed.py --out-prefix D:\QM\reports\work_items\000034e8-7161-430b-be4f-e140cb99789b --terminal T1'; Review=$true },
    @{ Name='duplicate utf8 option'; Command='python.exe -Xutf8 -X utf8 C:\QM\repo\framework\scripts\q07_multiseed.py --out-prefix D:\QM\reports\work_items\000034e8-7161-430b-be4f-e140cb99789b --terminal T1'; Review=$true },
    @{ Name='wrong interpreter'; Command='pwsh.exe C:\QM\repo\framework\scripts\q07_multiseed.py --out-prefix D:\QM\reports\work_items\000034e8-7161-430b-be4f-e140cb99789b --terminal T1'; Review=$false }
)
foreach ($case in $runnerNegativeCases) {
    $classification = Get-QmFactoryPhaseRunnerClassification -CommandLine $case.Command
    Assert-QmFalse -Condition (Test-QmFactoryPhaseRunnerCommandLine -CommandLine $case.Command) `
        -Name "never reap phase-runner negative: $($case.Name)"
    $expectedDisposition = $(if ($case.Review) { 'REVIEW_REQUIRED' } else { 'NOT_FACTORY' })
    Assert-QmEqual -Expected $expectedDisposition -Actual $classification.Disposition `
        -Name "near-match disposition: $($case.Name)"
}
[System.IO.File]::WriteAllText($workerPolicyFixture, "T5`n")
$t5PolicyDisabled = Get-QmFactoryPhaseRunnerClassification -CommandLine `
    "python.exe C:\QM\repo\framework\scripts\q07_multiseed.py --out-prefix $runnerRoot --terminal T5"
Assert-QmEqual -Expected 'REVIEW_REQUIRED' -Actual $t5PolicyDisabled.Disposition `
    -Name 'T5 phase runner is outside reap scope when live worker policy disables T5'
$script:QmFactoryDisabledTerminalsPath = $originalDisabledTerminalsPath
Remove-Item -LiteralPath $workerPolicyFixture -Force -ErrorAction SilentlyContinue

# Pre-deploy legacy runners with an exact known identity must never disappear
# from OFF verification merely because they predate the UUID marker. They are
# visible REVIEW_REQUIRED near-matches and remain outside reap ownership.
$legacyRunnerCases = @(
    @{
        Name = 'exact q07 script without lineage marker'
        Command = 'python.exe C:\QM\repo\framework\scripts\q07_multiseed.py --ea QM5_9999 --terminal T1'
        Phase = 'Q07'
        Reason = 'out_prefix_missing'
    },
    @{
        Name = 'exact p2 script with non-work-item output root'
        Command = 'python.exe C:\QM\repo\framework\scripts\p2_baseline.py --ea QM5_9999 --out-prefix D:\QM\reports\pipeline --terminal T1'
        Phase = 'Q02'
        Reason = 'out_prefix_not_direct_work_item_uuid'
    },
    @{
        Name = 'historical P3 module invocation'
        Command = 'python.exe -m framework.scripts.p3_param_sweep --ea QM5_9999 --symbols EURUSD.DWX'
        Phase = 'Q03'
        Reason = 'legacy_module_runner_without_exact_uuid_lineage'
    },
    @{
        Name = 'deprecated P4 direct runner'
        Command = 'python.exe C:\QM\repo\framework\scripts\p4_walk_forward.py --ea QM5_9999'
        Phase = 'P4'
        Reason = 'deprecated_legacy_runner_not_reap_allowlisted'
    },
    @{
        Name = 'pre-rewrite Q09 direct runner'
        Command = 'python.exe C:\QM\repo\framework\scripts\q09_news_mode.py --ea QM5_9999'
        Phase = 'Q09_LEGACY'
        Reason = 'deprecated_legacy_runner_not_reap_allowlisted'
    }
)
foreach ($case in $legacyRunnerCases) {
    $classification = Get-QmFactoryPhaseRunnerClassification -CommandLine $case.Command
    Assert-QmEqual -Expected 'REVIEW_REQUIRED' -Actual $classification.Disposition `
        -Name "legacy runner visible for review: $($case.Name)"
    Assert-QmEqual -Expected $case.Phase -Actual $classification.Phase `
        -Name "legacy runner phase retained: $($case.Name)"
    Assert-QmEqual -Expected $case.Reason -Actual $classification.MatcherReason `
        -Name "legacy runner review reason: $($case.Name)"
    Assert-QmFalse -Condition (Test-QmFactoryPhaseRunnerCommandLine -CommandLine $case.Command) `
        -Name "legacy runner is never reap-owned: $($case.Name)"
}
$foreignModule = Get-QmFactoryPhaseRunnerClassification `
    -CommandLine 'python.exe -m framework.scripts.p3_param_sweep_evil --ea QM5_9999'
Assert-QmEqual -Expected 'NOT_FACTORY' -Actual $foreignModule.Disposition `
    -Name 'near module name is not promoted to legacy runner review'
$foreignLegacyPath = Get-QmFactoryPhaseRunnerClassification `
    -CommandLine 'python.exe C:\Temp\p4_walk_forward.py --ea QM5_9999'
Assert-QmEqual -Expected 'NOT_FACTORY' -Actual $foreignLegacyPath.Disposition `
    -Name 'foreign legacy runner basename remains outside Factory scope'

$zeroScanA = [pscustomobject]@{
    scanned_at='2026-07-29T10:00:00.000Z'; worker_daemons=@(); phase_runners=@();
    smoke_wrappers=@(); terminal64=@(); metatester64=@(); review_required=@()
}
$zeroScanB = [pscustomobject]@{
    scanned_at='2026-07-29T10:00:02.000Z'; worker_daemons=@(); phase_runners=@();
    smoke_wrappers=@(); terminal64=@(); metatester64=@(); review_required=@()
}
$nonNullScan = [pscustomobject]@{
    scanned_at='2026-07-29T10:00:04.000Z'; worker_daemons=@(); phase_runners=@([pscustomobject]@{pid=42});
    smoke_wrappers=@(); terminal64=@(); metatester64=@(); review_required=@()
}
Assert-QmTrue -Condition (Test-QmStableFactoryNullScans -Scans @($zeroScanA,$zeroScanB)) `
    -Name 'two distinct consecutive null scans establish stable process quiescence'
Assert-QmFalse -Condition (Test-QmStableFactoryNullScans -Scans @($zeroScanA)) `
    -Name 'one null scan is insufficient'
Assert-QmFalse -Condition (Test-QmStableFactoryNullScans -Scans @($zeroScanA,$zeroScanA)) `
    -Name 'same scan cannot be counted twice'
Assert-QmFalse -Condition (Test-QmStableFactoryNullScans -Scans @($zeroScanA,$nonNullScan)) `
    -Name 'phase runner breaks stable null-scan contract'

# Pump matching is exact despite the one known repository-relative launch form.
$acceptedPumps = @(
    'pythonw.exe C:\QM\repo\tools\strategy_farm\run_pump_task.py',
    'python.exe -u "C:\QM\repo\tools\strategy_farm\run_pump_task.py"',
    'python.exe -X utf8 "C:\QM\repo\tools\strategy_farm\run_pump_task.py"',
    'pythonw.exe -Xutf8 -u tools/strategy_farm/run_pump_task.py',
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
    'pythonw.exe -O C:\QM\repo\tools\strategy_farm\run_pump_task.py',
    'pythonw.exe -X dev C:\QM\repo\tools\strategy_farm\run_pump_task.py',
    'pythonw.exe -Xutf8=1 C:\QM\repo\tools\strategy_farm\run_pump_task.py',
    'pythonw.exe -u -u C:\QM\repo\tools\strategy_farm\run_pump_task.py',
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
    @($factoryOnPath, 'FACTORY ON ABORTED before mutation', "`n    Stop-FactoryProcesses"),
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
Assert-QmTrue -Condition ($offText.Contains("Test-QmFactoryMt5ImagePath -Path `$process.ExecutablePath -ImageName 'terminal64.exe'")) `
    -Name 'Factory_OFF uses exact terminal classifier'
Assert-QmTrue -Condition ($offText.Contains("Test-QmFactoryMt5ImagePath -Path `$process.ExecutablePath -ImageName 'metatester64.exe'")) `
    -Name 'Factory_OFF uses exact metatester classifier'
Assert-QmTrue -Condition ($offText.Contains('Test-QmFactoryRunSmokeCommandLine -CommandLine $process.CommandLine')) `
    -Name 'Factory_OFF uses exact wrapper classifier'
Assert-QmTrue -Condition ($offText.Contains('Get-QmFactoryPhaseRunnerClassification -CommandLine $process.CommandLine')) `
    -Name 'Factory_OFF uses exact phase-runner classifier'
Assert-QmTrue -Condition ($offText.Contains('REVIEW_REQUIRED near-matches are evidence only')) `
    -Name 'Factory_OFF makes near-match no-reap policy explicit'
Assert-QmTrue -Condition ($offText.Contains("schema_version = 'mnt046-factory-off-quiescence/v1'")) `
    -Name 'Factory_OFF writes versioned MNT-046 evidence'
Assert-QmTrue -Condition ($offText.Contains('Wait-FactoryStableNullScans -TimeoutSeconds 20 -IntervalSeconds 2')) `
    -Name 'Factory_OFF requires bounded consecutive stable scans'
Assert-QmTrue -Condition ($offText.Contains('stable_null_scan_count')) `
    -Name 'Factory_OFF evidence records stable null-scan count'
$phaseReapIndex = $offText.IndexOf('Stop-EvidencedFactoryProcesses -EvidenceRecords $beforeProcessScan.phase_runners', [System.StringComparison]::Ordinal)
$workerReapIndex = $offText.IndexOf('Stop-EvidencedFactoryProcesses -EvidenceRecords $beforeProcessScan.worker_daemons', [System.StringComparison]::Ordinal)
$wrapperReapIndex = $offText.IndexOf('Stop-EvidencedFactoryProcesses -EvidenceRecords $beforeProcessScan.smoke_wrappers', [System.StringComparison]::Ordinal)
$terminalReapIndex = $offText.IndexOf('Stop-EvidencedFactoryProcesses -EvidenceRecords $beforeProcessScan.terminal64', [System.StringComparison]::Ordinal)
Assert-QmTrue -Condition (
    $phaseReapIndex -ge 0 -and $phaseReapIndex -lt $workerReapIndex -and
    $workerReapIndex -lt $wrapperReapIndex -and $wrapperReapIndex -lt $terminalReapIndex
) -Name 'Factory_OFF reap order is phase-runner then worker/wrapper then MT5 children'
Assert-QmTrue -Condition ($onText.Contains("Test-QmFactoryMt5ImagePath -Path `$_.ExecutablePath -ImageName 'terminal64.exe'")) `
    -Name 'Factory_ON uses exact terminal classifier'
Assert-QmTrue -Condition ($onText.Contains("`$snapshot.phase_runners + `$snapshot.daemons + `$snapshot.wrappers")) `
    -Name 'Factory_ON stale drain includes phase runners in safe order'
Assert-QmTrue -Condition ($onText.Contains('no ambiguous process was reaped')) `
    -Name 'Factory_ON refuses REVIEW_REQUIRED near-matches without reaping'
Assert-QmTrue -Condition ($windowText.Contains("Name='factory terminal64 (T1..T10)=0'")) `
    -Name 'TestWindow reports factory-only terminal scope'
Assert-QmTrue -Condition ($windowText.Contains('Test-QmFactoryPumpCommandLine -CommandLine $_.CommandLine')) `
    -Name 'TestWindow uses exact pump classifier'
Assert-QmTrue -Condition ($windowText.Contains("Name='factory phase runners=0'")) `
    -Name 'TestWindow verifies phase-runner quiescence'
Assert-QmTrue -Condition ($windowText.Contains("Name='phase-runner near-matches REVIEW_REQUIRED=0'")) `
    -Name 'TestWindow surfaces unresolved phase-runner near-matches'

if ($script:Failures.Count -gt 0) {
    $script:Failures | ForEach-Object { Write-Error $_ }
    throw "Factory process-scope tests failed: $($script:Failures.Count) failure(s), $($script:PassCount) pass(es)."
}

Write-Output "Factory process-scope tests PASS ($($script:PassCount) assertions)."
