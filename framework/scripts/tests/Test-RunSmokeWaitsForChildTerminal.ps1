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
        $node.Name -eq "Start-TesterRun"
}, $true)

if (-not $functionAst) {
    throw "Start-TesterRun function not found."
}

Invoke-Expression $functionAst.Extent.Text

function New-FakeProcess {
    param(
        [int]$Id,
        [int]$ExitCode,
        [bool]$WaitResult
    )

    $obj = [pscustomobject]@{
        Id = $Id
        ExitCode = $ExitCode
        HasExitedValue = $true
        HasExitedCalls = 0
        StartTime = Get-Date
        WaitCalls = 0
        WaitResult = $WaitResult
    }
    $obj | Add-Member -MemberType ScriptProperty -Name HasExited -Value {
        $this.HasExitedCalls += 1
        return $this.HasExitedValue
    } -Force
    $obj | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value {
        param([int]$Milliseconds)
        $this.WaitCalls += 1
        return $this.WaitResult
    } -Force
    return $obj
}

$script:launcherProcess = New-FakeProcess -Id 1111 -ExitCode -1 -WaitResult $true
$script:childTerminalProcess = New-FakeProcess -Id 2222 -ExitCode 0 -WaitResult $true

function Start-Process {
    param(
        [string]$FilePath,
        [object[]]$ArgumentList,
        [switch]$PassThru,
        [object]$WindowStyle
    )
    return $script:launcherProcess
}

function Wait-TerminalSpawn {
    param(
        [string]$TerminalExe,
        [string]$IniPath,
        [string]$TerminalName,
        [datetime]$StartedAfter
    )
    return $script:childTerminalProcess
}

$result = Start-TesterRun `
    -TerminalExe "C:\MT5\T1\terminal64.exe" `
    -IniPath "C:\QM\reports\smoke\run_01\tester.ini" `
    -TimeoutSec 1 `
    -TerminalName "T1"

if ($script:childTerminalProcess.HasExitedCalls -lt 1) {
    throw "Expected Start-TesterRun to poll the spawned terminal, got $($script:childTerminalProcess.HasExitedCalls) polls."
}

if ($script:launcherProcess.WaitCalls -ne 0) {
    throw "Start-TesterRun waited on launcher process instead of spawned terminal."
}

if ($result.exit_code -ne 0) {
    throw "Expected child terminal exit code 0, got $($result.exit_code)."
}

if ($result.terminal_pid -ne 2222) {
    throw "Expected terminal_pid 2222, got $($result.terminal_pid)."
}

Write-Host "PASS Test-RunSmokeWaitsForChildTerminal"
