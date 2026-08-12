[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$scriptPath = Join-Path $repoRoot "framework\scripts\run_smoke.ps1"

$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
if (@($errors).Count -gt 0) {
    throw "run_smoke.ps1 parse errors: $($errors | Out-String)"
}

$functionAst = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq "Remove-TesterJournalBombArtifacts"
}, $true)

if (-not $functionAst) {
    throw "Remove-TesterJournalBombArtifacts function not found."
}

Invoke-Expression $functionAst.Extent.Text

$tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("qm-run-smoke-logbomb-cleanup-{0}" -f [guid]::NewGuid())
$testerRoot = Join-Path $tmpRoot "Tester"
$agentLogs = Join-Path $testerRoot "Agent-127.0.0.1-3007\logs"
$dispatcherLogs = Join-Path $testerRoot "logs"
$outsideRoot = Join-Path $tmpRoot "outside"
New-Item -ItemType Directory -Path $agentLogs, $dispatcherLogs, $outsideRoot -Force | Out-Null

$primaryPath = Join-Path $agentLogs "20260728.log"
$siblingPath = Join-Path $dispatcherLogs "20260728.log"
$smallPath = Join-Path $dispatcherLogs "20260727.log"
$outsidePath = Join-Path $outsideRoot "20260728.log"

try {
    [System.IO.File]::WriteAllBytes($primaryPath, (New-Object byte[] 256))
    [System.IO.File]::WriteAllBytes($siblingPath, (New-Object byte[] 300))
    [System.IO.File]::WriteAllBytes($smallPath, (New-Object byte[] 64))
    [System.IO.File]::WriteAllBytes($outsidePath, (New-Object byte[] 300))
    $script:LogBombHardCeilBytes = 128

    $result = @(Remove-TesterJournalBombArtifacts `
        -ScanDirs @($testerRoot) `
        -PrimaryPath $primaryPath `
        -RetryCount 1 `
        -RetryDelayMilliseconds 0)

    if (Test-Path -LiteralPath $primaryPath) {
        throw "Detected Agent-* journal was not reclaimed."
    }
    if (Test-Path -LiteralPath $siblingPath) {
        throw "Oversized dispatcher sibling journal was not reclaimed."
    }
    if (-not (Test-Path -LiteralPath $smallPath)) {
        throw "Below-cap diagnostic journal was incorrectly removed."
    }
    if (-not (Test-Path -LiteralPath $outsidePath)) {
        throw "Journal outside the terminal scan root was incorrectly removed."
    }
    if ($result.Count -ne 2 -or @($result | Where-Object { -not $_.removed }).Count -ne 0) {
        throw "Expected two successful journal reclaims; got $($result | ConvertTo-Json -Compress)."
    }
} finally {
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "PASS Test-RunSmokeLogBombSiblingCleanup"
