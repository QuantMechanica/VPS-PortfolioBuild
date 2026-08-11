[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$scriptPath = Join-Path $repoRoot "framework\scripts\compile_one.ps1"

$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
if (@($errors).Count -gt 0) {
    throw "compile_one.ps1 parse errors: $($errors | Out-String)"
}

$functionAst = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq "Resolve-TerminalIncludeTargets"
}, $true)
if (-not $functionAst) {
    throw "Resolve-TerminalIncludeTargets function not found."
}
Invoke-Expression $functionAst.Extent.Text

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("qm-compile-include-targets-" + [guid]::NewGuid())
try {
    $metaEditorRoot = Join-Path $testRoot "T1"
    $metaEditorPath = Join-Path $metaEditorRoot "metaeditor64.exe"
    $terminalRoot = Join-Path $testRoot "Administrator\AppData\Roaming\MetaQuotes\Terminal"
    $matchingHash = Join-Path $terminalRoot "MATCHING"
    $foreignHash = Join-Path $terminalRoot "FOREIGN"
    $matchingInclude = Join-Path $matchingHash "MQL5\Include"
    $foreignInclude = Join-Path $foreignHash "MQL5\Include"

    New-Item -ItemType Directory -Path $metaEditorRoot,$matchingInclude,$foreignInclude -Force | Out-Null
    New-Item -ItemType File -Path $metaEditorPath -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $matchingHash "origin.txt") -Value $metaEditorRoot
    Set-Content -LiteralPath (Join-Path $foreignHash "origin.txt") -Value (Join-Path $testRoot "unrelated-terminal")

    $targets = @(Resolve-TerminalIncludeTargets `
        -MetaEditorPath $metaEditorPath `
        -AdditionalTerminalRoots @($terminalRoot))
    $resolvedMatching = (Resolve-Path -LiteralPath $matchingInclude).Path
    $resolvedForeign = (Resolve-Path -LiteralPath $foreignInclude).Path

    if ($targets -notcontains $resolvedMatching) {
        throw "Matching cross-profile MetaEditor include root was not discovered."
    }
    if ($targets -contains $resolvedForeign) {
        throw "Unrelated terminal profile include root was incorrectly selected."
    }
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}

Write-Host "PASS Test-CompileOneIncludeTargets"
