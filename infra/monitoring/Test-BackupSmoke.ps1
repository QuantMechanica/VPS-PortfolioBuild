[CmdletBinding()]
param(
    [string]$Workspace = "C:\QM\repo\infra\smoke\backup"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$sourceRoot = Join-Path $Workspace "source"
$driveRoot = Join-Path $Workspace "drive"
$weeklyLfsRoot = Join-Path $Workspace "weekly_lfs"

Remove-Item -LiteralPath $Workspace -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $sourceRoot, $driveRoot, $weeklyLfsRoot -Force | Out-Null

$paperclipDb = Join-Path $sourceRoot "paperclip.sqlite"
$lastCheck = Join-Path $sourceRoot "last_check_state.json"
$notionExport = Join-Path $sourceRoot "notion-exports"
$logsRoot = Join-Path $sourceRoot "logs"
$strategies = Join-Path $sourceRoot "strategies"
$reports = Join-Path $sourceRoot "reports"

New-Item -ItemType Directory -Path $notionExport, $logsRoot, $strategies, $reports -Force | Out-Null
Set-Content -Path $paperclipDb -Value "sqlite-smoke" -Encoding ASCII
Set-Content -Path $lastCheck -Value "{}" -Encoding ASCII
Set-Content -Path (Join-Path $notionExport "export.json") -Value "{}" -Encoding ASCII
Set-Content -Path (Join-Path $logsRoot "latest.log") -Value "log" -Encoding ASCII
Set-Content -Path (Join-Path $strategies "s1.txt") -Value "strategy" -Encoding ASCII
Set-Content -Path (Join-Path $reports "r1.txt") -Value "report" -Encoding ASCII

& powershell -NoProfile -ExecutionPolicy Bypass -File "C:\QM\repo\infra\backup.ps1" `
    -GoogleDriveRoot $driveRoot `
    -PaperclipDbPath $paperclipDb `
    -LastCheckStatePath $lastCheck `
    -NotionExportRoot $notionExport `
    -RecentLogsRoot $logsRoot `
    -WeeklyGitLfsRoot $weeklyLfsRoot `
    -MonthlyStrategiesRoot $strategies `
    -MonthlyReportsRoot $reports `
    -DailyRetentionDays 14 `
    -WeeklyRetentionWeeks 8 `
    -MonthlyRetentionMonths 12

$todayTag = [datetime]::UtcNow.ToString("yyyy-MM-dd")
$manifestPath = Join-Path $driveRoot ("daily\{0}\backup_manifest.json" -f $todayTag)

$result = [ordered]@{
    check = "backup_smoke"
    generated_at_utc = [datetime]::UtcNow.ToString("o")
    workspace = $Workspace
    manifest_path = $manifestPath
    manifest_exists = (Test-Path -LiteralPath $manifestPath)
    copied_last_check = (Test-Path -LiteralPath (Join-Path $driveRoot ("daily\{0}\last_check_state.json" -f $todayTag)))
    copied_paperclip_db = (Test-Path -LiteralPath (Join-Path $driveRoot ("daily\{0}\paperclip.sqlite" -f $todayTag)))
    status = "unknown"
}

if ($result.manifest_exists -and $result.copied_last_check -and $result.copied_paperclip_db) {
    $result.status = "ok"
    $result.message = "Backup smoke passed."
    $result | ConvertTo-Json -Depth 6
    exit 0
}

$result.status = "critical"
$result.message = "Backup smoke failed. Missing expected artifacts."
$result | ConvertTo-Json -Depth 6
exit 2
