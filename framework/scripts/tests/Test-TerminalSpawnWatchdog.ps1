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
        $node.Name -eq "Wait-TerminalSpawn"
}, $true)

if (-not $functionAst) {
    throw "Wait-TerminalSpawn function not found."
}

Invoke-Expression $functionAst.Extent.Text

$terminalExe = "C:\MT5\T1\terminal64.exe"
$iniPath = "C:\QM\reports\smoke\run_01\tester.ini"
$spawnedAt = (Get-Date).AddSeconds(-1)
$script:mockProcesses = @(
    [pscustomobject]@{
        Id = 4242
        Path = $terminalExe
        StartTime = $spawnedAt
    }
)

function Get-Process {
    param(
        [string]$Name,
        [object]$ErrorAction
    )
    return $script:mockProcesses
}

function Start-Sleep {
    param(
        [int]$Milliseconds
    )
}

$confirmed = Wait-TerminalSpawn `
    -TerminalExe $terminalExe `
    -IniPath $iniPath `
    -SpawnWaitSeconds 1 `
    -PollMilliseconds 1 `
    -StartedAfter (Get-Date).AddSeconds(-30)

if ($confirmed.Id -ne 4242) {
    throw "Expected spawned terminal PID 4242, got $($confirmed.Id)."
}

$script:mockProcesses = @()
$failed = $false
try {
    Wait-TerminalSpawn `
        -TerminalExe $terminalExe `
        -IniPath $iniPath `
        -TerminalName "T1" `
        -SpawnWaitSeconds 0 `
        -PollMilliseconds 1 `
        -StartedAfter (Get-Date).AddSeconds(-30) | Out-Null
} catch {
    $failed = $true
    if ($_.Exception.Message -notmatch "TERMINAL_SPAWN_FAILURE") {
        throw "Expected TERMINAL_SPAWN_FAILURE, got: $($_.Exception.Message)"
    }
    if ($_.Exception.Message -notmatch [regex]::Escape($terminalExe)) {
        throw "Failure did not include terminal path: $($_.Exception.Message)"
    }
    if ($_.Exception.Message -notmatch "terminal=T1") {
        throw "Failure did not include terminal name: $($_.Exception.Message)"
    }
    if ($_.Exception.Message -notmatch [regex]::Escape($iniPath)) {
        throw "Failure did not include ini path: $($_.Exception.Message)"
    }
}

if (-not $failed) {
    throw "Missing terminal process did not fail."
}

Write-Host "PASS Test-TerminalSpawnWatchdog"
