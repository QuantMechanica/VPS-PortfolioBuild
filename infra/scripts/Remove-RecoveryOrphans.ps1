[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$RootPath = "D:\QM",
    [string]$NamePattern = "_recovery_orphans_*",
    [int]$MinAgeHours = 24,
    [string]$LogDirectory = "D:\QM\reports\infra\recovery_orphans",
    [switch]$FailOnDeleteError
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Remove-DirectoryWithRetry {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$RetryCount = 3,
        [int]$DelaySeconds = 2
    )

    $lastError = $null
    foreach ($attempt in 1..$RetryCount) {
        try {
            if (-not (Test-Path -LiteralPath $Path)) {
                return $true
            }
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
            return $true
        }
        catch {
            $lastError = $_
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    if ($null -ne $lastError) {
        throw $lastError
    }
    return $false
}

$utcNow = [datetime]::UtcNow
$threshold = $utcNow.AddHours(-1 * $MinAgeHours)
$results = @()

if (-not (Test-Path -LiteralPath $RootPath)) {
    throw "RootPath does not exist: $RootPath"
}

$candidates = @(Get-ChildItem -LiteralPath $RootPath -Directory -Force |
    Where-Object { $_.Name -like $NamePattern })

foreach ($dir in $candidates) {
    $itemUtc = $dir.LastWriteTimeUtc
    $eligible = $itemUtc -le $threshold
    $status = "skipped"
    $message = "Retention window not reached."

    if ($eligible) {
        if ($PSCmdlet.ShouldProcess($dir.FullName, "Remove recovery orphan directory")) {
            try {
                Remove-DirectoryWithRetry -Path $dir.FullName | Out-Null
                $status = "deleted"
                $message = "Deleted."
            }
            catch {
                $status = "delete_error"
                $message = $_.Exception.Message
                if ($FailOnDeleteError) {
                    throw
                }
            }
        }
        else {
            $status = "whatif"
            $message = "Would delete (WhatIf)."
        }
    }

    $results += [pscustomobject]@{
        path = $dir.FullName
        last_write_utc = $itemUtc.ToString("o")
        eligible_before_utc = $threshold.ToString("o")
        status = $status
        message = $message
    }
}

$summary = [pscustomobject]@{
    timestamp_utc = $utcNow.ToString("o")
    root_path = $RootPath
    pattern = $NamePattern
    min_age_hours = $MinAgeHours
    scanned_count = $candidates.Count
    deleted_count = @($results | Where-Object { $_.status -eq "deleted" }).Count
    pending_count = @($results | Where-Object { $_.status -eq "skipped" }).Count
    error_count = @($results | Where-Object { $_.status -eq "delete_error" }).Count
    entries = $results
}

Ensure-Directory -Path $LogDirectory
$logName = "recovery_orphans_cleanup_{0}.json" -f (Get-Date -Format "yyyyMMdd_HHmmss")
$logPath = Join-Path $LogDirectory $logName
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $logPath -Encoding ASCII

$summary | ConvertTo-Json -Depth 6
