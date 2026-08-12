[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$scriptPath = Join-Path $repoRoot "framework\scripts\run_smoke.ps1"

$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $scriptPath,
    [ref]$tokens,
    [ref]$errors
)
if (@($errors).Count -gt 0) {
    throw "run_smoke.ps1 parse errors: $($errors | Out-String)"
}

$rootGuardAst = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq "Test-FarmWorkItemReportRoot"
}, $true)
if (-not $rootGuardAst) {
    throw "Test-FarmWorkItemReportRoot function not found."
}
Invoke-Expression $rootGuardAst.Extent.Text

$positiveCases = @(
    "D:\QM\reports\work_items",
    "D:\QM\reports\work_items\abc-123",
    "d:\qm\REPORTS\WORK_ITEMS\abc-123\QM5_20240"
)
foreach ($candidate in $positiveCases) {
    if (-not (Test-FarmWorkItemReportRoot -ResolvedReportRoot $candidate)) {
        throw "Factory work-item report root was not recognized: $candidate"
    }
}

$negativeCases = @(
    "D:\QM\reports\work_items-old",
    "D:\QM\reports\smoke",
    "D:\QM\reports\work_items\..\smoke"
)
foreach ($candidate in $negativeCases) {
    if (Test-FarmWorkItemReportRoot -ResolvedReportRoot $candidate) {
        throw "Non-work-item report root crossed the pump isolation boundary: $candidate"
    }
}

$scriptText = [System.IO.File]::ReadAllText($scriptPath)
$branchMarker = 'elseif (Test-FarmWorkItemReportRoot -ResolvedReportRoot $resolvedReportRoot)'
$skipMarker = 'post_run_pump_skipped (work-item worker owns completion)'
$pumpSpawnMarker = 'Start-Process -FilePath $pumpExe'
$branchIndex = $scriptText.IndexOf($branchMarker, [System.StringComparison]::Ordinal)
$skipIndex = $scriptText.IndexOf($skipMarker, [System.StringComparison]::Ordinal)
$pumpSpawnIndex = $scriptText.IndexOf($pumpSpawnMarker, [System.StringComparison]::Ordinal)
if ($branchIndex -lt 0 -or $skipIndex -lt 0 -or $pumpSpawnIndex -lt 0) {
    throw "Work-item post-run pump isolation markers are incomplete."
}
if ($skipIndex -lt $branchIndex -or $pumpSpawnIndex -lt $skipIndex) {
    throw "Work-item pump isolation no longer precedes the detached pump spawn."
}

Write-Output "Test-RunSmokeWorkItemPumpIsolation: PASS"
