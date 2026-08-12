[CmdletBinding()]
param(
    [string]$ScriptPath = "C:\QM\repo\infra\scripts\Test-YouTubeDataMcpReadiness.ps1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ScriptPath)) {
    throw "Missing script: $ScriptPath"
}

$prevKey = [Environment]::GetEnvironmentVariable("YOUTUBE_API_KEY", "Process")
[Environment]::SetEnvironmentVariable("YOUTUBE_API_KEY", $null, "Process")

try {
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath 2>&1
    if ($LASTEXITCODE -ne 1) {
        throw "Expected blocked exit=1 when YOUTUBE_API_KEY missing; got exit=$LASTEXITCODE output=$($out -join ' | ')"
    }
    $json = ($out -join "`n") | ConvertFrom-Json
    if ($json.status -ne "blocked") { throw "Expected status=blocked; got '$($json.status)'" }
    if ($json.unblock_owner -ne "OWNER") { throw "Expected unblock_owner OWNER; got '$($json.unblock_owner)'" }

    Write-Host "PASS: YouTube Data MCP readiness blocked contract validated."
}
finally {
    [Environment]::SetEnvironmentVariable("YOUTUBE_API_KEY", $prevKey, "Process")
}
