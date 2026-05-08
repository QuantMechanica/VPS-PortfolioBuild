param(
    [string]$Issue = "QUA-212",
    [string]$Assignee = "cto",
    [string]$OutDir = "C:/QM/repo/docs/ops",
    [string]$LatestPath = "C:/QM/repo/docs/ops/QUA-212_KANBAN_DISPATCH_STATUS_latest.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ts = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$out = Join-Path $OutDir ("QUA-212_KANBAN_DISPATCH_STATUS_" + $ts + ".json")

$checker = "C:/QM/repo/scripts/ops/check_kanban_dispatch_gap.py"
$resultJson = & python $checker --issue $Issue --assignee $Assignee
$result = $resultJson | ConvertFrom-Json

$payload = [ordered]@{
    ts_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    checker = "scripts/ops/check_kanban_dispatch_gap.py"
    issue = $Issue
    assignee = $Assignee
    result = $result
}

$dir = Split-Path -Parent $out
if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}
$json = $payload | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText($out, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))

$latestDir = Split-Path -Parent $LatestPath
if ($latestDir -and -not (Test-Path -LiteralPath $latestDir)) {
    New-Item -ItemType Directory -Path $latestDir -Force | Out-Null
}
[System.IO.File]::WriteAllText($LatestPath, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))

Write-Output $out
Write-Output $LatestPath
