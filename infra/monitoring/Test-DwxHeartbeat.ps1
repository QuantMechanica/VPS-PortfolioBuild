[CmdletBinding()]
param(
    [string]$HeartbeatPath = "D:\QM\mt5\T1\MQL5\Files\imports\service_heartbeat.txt",
    [int]$MaxAgeMinutes = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Parse-HeartbeatFields {
    param([string]$RawText)

    $fields = @{}
    foreach ($line in ($RawText -split "`r?`n")) {
        $trimmed = $line.Trim()
        if (-not $trimmed) { continue }
        if (-not $trimmed.Contains("=")) { continue }

        $parts = $trimmed -split "=", 2
        $key = $parts[0].Trim()
        $value = $parts[1].Trim()
        if ($key) {
            $fields[$key] = $value
        }
    }

    return $fields
}

function Try-ParseUtc {
    param([string]$Value)

    if (-not $Value) { return $null }

    [datetimeoffset]$dto = [datetimeoffset]::MinValue
    if ([datetimeoffset]::TryParse($Value, [ref]$dto)) {
        return $dto.UtcDateTime
    }

    $epoch = 0L
    if ([long]::TryParse($Value, [ref]$epoch)) {
        return [datetimeoffset]::FromUnixTimeSeconds($epoch).UtcDateTime
    }

    return $null
}

$now = [datetime]::UtcNow
$status = [ordered]@{
    check = "dwx_service_heartbeat"
    status = "unknown"
    heartbeat_path = $HeartbeatPath
    generated_at_utc = $now.ToString("o")
    heartbeat_at_utc = $null
    heartbeat_source = $null
    has_wall_clock_utc_field = $false
    age_minutes = $null
    max_age_minutes = $MaxAgeMinutes
    message = ""
}

if (-not (Test-Path -LiteralPath $HeartbeatPath)) {
    $status.status = "critical"
    $status.message = "Heartbeat file missing."
    $status | ConvertTo-Json -Depth 6
    exit 2
}

$raw = Get-Content -LiteralPath $HeartbeatPath -Raw -ErrorAction Stop
$fields = Parse-HeartbeatFields -RawText $raw
$status.has_wall_clock_utc_field = $fields.ContainsKey("wall_clock_utc")

$ts = $null
$source = $null

if ($fields.ContainsKey("wall_clock_utc")) {
    $ts = Try-ParseUtc -Value $fields["wall_clock_utc"]
    $source = "wall_clock_utc"
}
if ($null -eq $ts -and $fields.ContainsKey("heartbeat_utc")) {
    $ts = Try-ParseUtc -Value $fields["heartbeat_utc"]
    $source = "heartbeat_utc"
}
if ($null -eq $ts -and $fields.ContainsKey("utc_epoch")) {
    $ts = Try-ParseUtc -Value $fields["utc_epoch"]
    $source = "utc_epoch"
}

if ($null -eq $ts) {
    $status.status = "critical"
    $status.message = "Heartbeat UTC timestamp not parseable (expected wall_clock_utc/heartbeat_utc/utc_epoch)."
    $status | ConvertTo-Json -Depth 6
    exit 2
}

$age = [math]::Round(($now - $ts).TotalMinutes, 2)
$status.heartbeat_at_utc = $ts.ToString("o")
$status.heartbeat_source = $source
$status.age_minutes = $age

if ($age -le $MaxAgeMinutes) {
    if ($status.has_wall_clock_utc_field) {
        $status.status = "ok"
        $status.message = "Heartbeat fresh; wall_clock_utc present."
        $status | ConvertTo-Json -Depth 6
        exit 0
    }

    $status.status = "warn"
    $status.message = "Heartbeat fresh, but wall_clock_utc field missing."
    $status | ConvertTo-Json -Depth 6
    exit 1
}

$status.status = "critical"
$status.message = "Heartbeat stale."
$status | ConvertTo-Json -Depth 6
exit 2
