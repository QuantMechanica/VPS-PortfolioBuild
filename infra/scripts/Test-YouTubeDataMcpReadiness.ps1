[CmdletBinding()]
param(
    [string]$PackageName = "youtube-data-mcp-server"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$apiKey = [Environment]::GetEnvironmentVariable("YOUTUBE_API_KEY")
$status = "ready"
$unblockOwner = $null
$unblockAction = $null
$missing = @()

$npmCmd = Get-Command npm -ErrorAction SilentlyContinue
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if ($null -eq $npmCmd) { $missing += "npm" }
if ($null -eq $nodeCmd) { $missing += "node" }
if ([string]::IsNullOrWhiteSpace($apiKey)) { $missing += "YOUTUBE_API_KEY" }

if ($missing.Count -gt 0) {
    $status = "blocked"
    $unblockOwner = "OWNER"
    $unblockAction = "Provide missing prerequisites: $($missing -join ', ')"
}

$result = [ordered]@{
    issue = "QUA-914"
    checked_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    package = $PackageName
    status = $status
    missing = $missing
    unblock_owner = $unblockOwner
    unblock_action = $unblockAction
    sample_probe = "npx -y $PackageName --help"
}

$result | ConvertTo-Json -Depth 6

if ($status -eq "blocked") { exit 1 }
exit 0
