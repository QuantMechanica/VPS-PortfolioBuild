param(
    [datetime]$StartUtc = (Get-Date).ToUniversalTime().AddHours(-6),
    [datetime]$EndUtc = (Get-Date).ToUniversalTime(),
    [string]$PythonRoot = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311",
    [string]$DriveLogDir = "C:\ProgramData\Google\DriveFS\Logs",
    [string]$OutDir = "C:\QM\repo\lessons-learned\evidence"
)

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$stamp = (Get-Date).ToString("yyyy-MM-dd_HHmmss")
$outJson = Join-Path $OutDir ("python_runtime_incident_evidence_{0}.json" -f $stamp)

$result = [ordered]@{
    collected_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    window_utc = @{
        start = $StartUtc.ToString("o")
        end = $EndUtc.ToString("o")
    }
    python_root = $PythonRoot
    python_root_exists = (Test-Path -LiteralPath $PythonRoot)
    python_root_snapshot = @()
    security_delete_events = @()
    security_query_error = $null
    security_delete_events_count = 0
    defender_events = @()
    defender_query_error = $null
    defender_events_count = 0
    drive_logs = @()
    drive_logs_count = 0
}

if (Test-Path -LiteralPath $PythonRoot) {
    $result.python_root_snapshot = @(
        Get-ChildItem -LiteralPath $PythonRoot -Force -ErrorAction SilentlyContinue |
            Select-Object Name, FullName, LastWriteTimeUtc, Length, Mode
    )
}

try {
    $securityEvents = Get-WinEvent -FilterHashtable @{
        LogName = "Security"
        Id = 4663
        StartTime = $StartUtc.ToLocalTime()
        EndTime = $EndUtc.ToLocalTime()
    } -ErrorAction Stop

    $result.security_delete_events = @(
        $securityEvents |
            Where-Object { $_.Message -like "*$PythonRoot*" } |
            Select-Object TimeCreated, Id, ProviderName, LevelDisplayName, Message
    )
    $result.security_delete_events_count = @($result.security_delete_events).Count
} catch {
    $result.security_query_error = [pscustomobject]@{
        code = "security_log_unavailable_or_access_denied"
        detail = $_.Exception.Message
    }
}

try {
    $defenderEvents = Get-WinEvent -FilterHashtable @{
        LogName = "Microsoft-Windows-Windows Defender/Operational"
        StartTime = $StartUtc.ToLocalTime()
        EndTime = $EndUtc.ToLocalTime()
    } -ErrorAction Stop

    $result.defender_events = @(
        $defenderEvents |
            Where-Object { $_.Message -like "*$PythonRoot*" -or $_.Message -like "*python311*" } |
            Select-Object TimeCreated, Id, ProviderName, LevelDisplayName, Message
    )
    $result.defender_events_count = @($result.defender_events).Count
} catch {
    $result.defender_query_error = [pscustomobject]@{
        code = "defender_log_unavailable"
        detail = $_.Exception.Message
    }
}

if (Test-Path -LiteralPath $DriveLogDir) {
    $result.drive_logs = @(
        Get-ChildItem -LiteralPath $DriveLogDir -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTimeUtc -ge $StartUtc -and $_.LastWriteTimeUtc -le $EndUtc } |
            Select-Object Name, FullName, LastWriteTimeUtc, Length
    )
    $result.drive_logs_count = @($result.drive_logs).Count
}

$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outJson -Encoding ASCII
Write-Host ("evidence_file={0}" -f $outJson)
