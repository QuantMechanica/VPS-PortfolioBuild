[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$GoogleDriveRoot = "G:\QM_Backups",
    [string]$PaperclipDbPath = "C:\QM\paperclip\data\instances\default\paperclip.sqlite",
    [string]$LastCheckStatePath = "C:\QM\last_check_state.json",
    [string]$NotionExportRoot = "C:\QM\notion-exports",
    [string]$RecentLogsRoot = "C:\QM\logs",
    [string]$WeeklyGitLfsRoot = "C:\QM\repo\infra\backups\weekly",
    [string]$MonthlyStrategiesRoot = "C:\QM\repo\strategies",
    [string]$MonthlyReportsRoot = "D:\QM\reports",
    [int]$DailyRetentionDays = 14,
    [int]$WeeklyRetentionWeeks = 8,
    [int]$MonthlyRetentionMonths = 12
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-IsoLikeWeekTag {
    param([datetime]$DateUtc)
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $calendar = $culture.Calendar
    $weekRule = [System.Globalization.CalendarWeekRule]::FirstFourDayWeek
    $firstDay = [System.DayOfWeek]::Monday
    $week = $calendar.GetWeekOfYear($DateUtc, $weekRule, $firstDay)
    return "{0}-W{1:d2}" -f $DateUtc.ToString("yyyy"), $week
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Copy-IfExists {
    param(
        [string]$SourcePath,
        [string]$DestinationPath
    )

    if (-not (Test-Path -LiteralPath $SourcePath)) {
        Write-Warning "Missing source, skipped: $SourcePath"
        return $false
    }

    $parent = Split-Path -Path $DestinationPath -Parent
    Ensure-Directory -Path $parent

    if ($PSCmdlet.ShouldProcess($DestinationPath, "Copy from $SourcePath")) {
        Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Recurse -Force
    }
    return $true
}

function Remove-OldDirectories {
    param(
        [string]$RootPath,
        [datetime]$Cutoff
    )
    if (-not (Test-Path -LiteralPath $RootPath)) { return }
    Get-ChildItem -LiteralPath $RootPath -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTimeUtc -lt $Cutoff.ToUniversalTime() } |
        ForEach-Object {
            if ($PSCmdlet.ShouldProcess($_.FullName, "Remove old backup directory")) {
                Remove-Item -LiteralPath $_.FullName -Recurse -Force
            }
        }
}

function Remove-OldFiles {
    param(
        [string]$RootPath,
        [datetime]$Cutoff
    )
    if (-not (Test-Path -LiteralPath $RootPath)) { return }
    Get-ChildItem -LiteralPath $RootPath -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTimeUtc -lt $Cutoff.ToUniversalTime() } |
        ForEach-Object {
            if ($PSCmdlet.ShouldProcess($_.FullName, "Remove old backup file")) {
                Remove-Item -LiteralPath $_.FullName -Force
            }
        }
}

$utcNow = [datetime]::UtcNow
$todayTag = $utcNow.ToString("yyyy-MM-dd")
$isoWeekTag = Get-IsoLikeWeekTag -DateUtc $utcNow
$monthTag = $utcNow.ToString("yyyy-MM")

$dailyRoot = Join-Path $GoogleDriveRoot "daily"
$weeklyRoot = Join-Path $GoogleDriveRoot "weekly"
$monthlyRoot = Join-Path $GoogleDriveRoot "monthly"

Ensure-Directory -Path $dailyRoot
Ensure-Directory -Path $weeklyRoot
Ensure-Directory -Path $monthlyRoot
Ensure-Directory -Path $WeeklyGitLfsRoot

# Daily backup set
$dailyTarget = Join-Path $dailyRoot $todayTag
Ensure-Directory -Path $dailyTarget
Copy-IfExists -SourcePath $LastCheckStatePath -DestinationPath (Join-Path $dailyTarget "last_check_state.json") | Out-Null
Copy-IfExists -SourcePath $PaperclipDbPath -DestinationPath (Join-Path $dailyTarget "paperclip.sqlite") | Out-Null
Copy-IfExists -SourcePath $NotionExportRoot -DestinationPath (Join-Path $dailyTarget "notion-exports") | Out-Null

if (Test-Path -LiteralPath $RecentLogsRoot) {
    $dailyLogsTarget = Join-Path $dailyTarget "logs_recent"
    Ensure-Directory -Path $dailyLogsTarget
    Get-ChildItem -LiteralPath $RecentLogsRoot -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTimeUtc -ge $utcNow.AddDays(-1) } |
        ForEach-Object {
            $relative = $_.FullName.Substring($RecentLogsRoot.Length).TrimStart('\')
            $destination = Join-Path $dailyLogsTarget $relative
            Copy-IfExists -SourcePath $_.FullName -DestinationPath $destination | Out-Null
        }
}

# Weekly DB dump for Git LFS and Drive
$dayOfWeek = [int](Get-Date).DayOfWeek
if ($dayOfWeek -eq [int][System.DayOfWeek]::Sunday) {
    $weeklyFileName = "paperclip_db_$isoWeekTag.sqlite"
    $weeklyDriveFile = Join-Path $weeklyRoot $weeklyFileName
    $weeklyLfsFile = Join-Path $WeeklyGitLfsRoot $weeklyFileName
    Copy-IfExists -SourcePath $PaperclipDbPath -DestinationPath $weeklyDriveFile | Out-Null
    Copy-IfExists -SourcePath $PaperclipDbPath -DestinationPath $weeklyLfsFile | Out-Null
}

# Monthly rolling snapshot of strategies + reports
$dayOfMonth = (Get-Date).Day
if ($dayOfMonth -eq 1) {
    $monthlyTarget = Join-Path $monthlyRoot $monthTag
    Ensure-Directory -Path $monthlyTarget
    Copy-IfExists -SourcePath $MonthlyStrategiesRoot -DestinationPath (Join-Path $monthlyTarget "strategies") | Out-Null
    Copy-IfExists -SourcePath $MonthlyReportsRoot -DestinationPath (Join-Path $monthlyTarget "reports") | Out-Null
}

# Retention
Remove-OldDirectories -RootPath $dailyRoot -Cutoff $utcNow.AddDays(-$DailyRetentionDays)
Remove-OldFiles -RootPath $weeklyRoot -Cutoff $utcNow.AddDays(-7 * $WeeklyRetentionWeeks)
Remove-OldFiles -RootPath $WeeklyGitLfsRoot -Cutoff $utcNow.AddDays(-7 * $WeeklyRetentionWeeks)
Remove-OldDirectories -RootPath $monthlyRoot -Cutoff $utcNow.AddMonths(-$MonthlyRetentionMonths)

$manifest = [ordered]@{
    generated_at_utc = $utcNow.ToString("o")
    retention = @{
        daily_days = $DailyRetentionDays
        weekly_weeks = $WeeklyRetentionWeeks
        monthly_months = $MonthlyRetentionMonths
    }
    targets = @{
        daily = $dailyTarget
        weekly_drive = $weeklyRoot
        weekly_git_lfs = $WeeklyGitLfsRoot
        monthly = $monthlyRoot
    }
}

$manifestPath = Join-Path $dailyTarget "backup_manifest.json"
if ($PSCmdlet.ShouldProcess($manifestPath, "Write backup manifest")) {
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
}

Write-Host "Backup workflow completed."
