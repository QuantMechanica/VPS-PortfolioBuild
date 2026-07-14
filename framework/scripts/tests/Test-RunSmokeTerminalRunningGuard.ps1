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
        $node.Name -eq "Test-TerminalAlreadyRunning"
}, $true)

if (-not $functionAst) {
    throw "Test-TerminalAlreadyRunning function not found."
}

Invoke-Expression $functionAst.Extent.Text

$tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("qm-run-smoke-terminal-guard-{0}" -f [guid]::NewGuid())
$terminalRoot = Join-Path $tmpRoot "T4"
New-Item -ItemType Directory -Path $terminalRoot -Force | Out-Null
$terminalExe = Join-Path $terminalRoot "terminal64.exe"
New-Item -ItemType File -Path $terminalExe -Force | Out-Null
$resolvedTerminalExe = (Resolve-Path -LiteralPath $terminalExe).Path

$script:mockTerminalProcesses = @()
function Get-CimInstance {
    param(
        [string]$ClassName,
        [string]$Filter,
        [object]$ErrorAction
    )
    return $script:mockTerminalProcesses
}

try {
    $script:mockTerminalProcesses = @(
        [pscustomobject]@{
            ExecutablePath = $resolvedTerminalExe
            CommandLine = $null
        }
    )
    if (-not (Test-TerminalAlreadyRunning -TerminalRoot $terminalRoot)) {
        throw "Matching ExecutablePath with empty CommandLine was not detected."
    }

    $script:mockTerminalProcesses = @(
        [pscustomobject]@{
            ExecutablePath = $null
            CommandLine = "`"$resolvedTerminalExe`" /portable"
        }
    )
    if (-not (Test-TerminalAlreadyRunning -TerminalRoot $terminalRoot)) {
        throw "Matching CommandLine was not detected."
    }

    $script:mockTerminalProcesses = @(
        [pscustomobject]@{
            ExecutablePath = "C:\Other\T4\terminal64.exe"
            CommandLine = '"C:\Other\T4\terminal64.exe" /portable'
        }
    )
    if (Test-TerminalAlreadyRunning -TerminalRoot $terminalRoot) {
        throw "Unrelated terminal path was incorrectly detected."
    }

    $neighborRoot = "${terminalRoot}0"
    $script:mockTerminalProcesses = @(
        [pscustomobject]@{
            ExecutablePath = (Join-Path $neighborRoot "terminal64.exe")
            CommandLine = "`"$(Join-Path $neighborRoot 'terminal64.exe')`" /portable"
        }
    )
    if (Test-TerminalAlreadyRunning -TerminalRoot $terminalRoot) {
        throw "Adjacent terminal name (for example T1 versus T10) was incorrectly detected."
    }
} finally {
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "PASS Test-RunSmokeTerminalRunningGuard"
