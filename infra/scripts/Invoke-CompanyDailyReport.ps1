[CmdletBinding()]
param(
    [string]$VaultPath = "C:\QM\obsidian\QuantMechanica",
    [string]$SnapshotRoot = "C:\QM\backups\obsidian-vault",
    [string]$StatePath = "C:\QM\state\company_daily_report_state.json",
    [int]$RetentionDays = 14,
    [string]$RoutineWebhookUrl = $(if ($env:PAPERCLIP_DAILY_REPORT_ROUTINE_URL) { $env:PAPERCLIP_DAILY_REPORT_ROUTINE_URL } else { "" }),
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-Directory {
    param([Parameter(Mandatory = $true)] [string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Read-State {
    param([Parameter(Mandatory = $true)] [string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        return $null
    }
}

function Write-State {
    param(
        [Parameter(Mandatory = $true)] [string]$Path,
        [Parameter(Mandatory = $true)] [object]$State
    )
    $parent = Split-Path -Parent $Path
    if ($parent) { Ensure-Directory -Path $parent }
    $json = $State | ConvertTo-Json -Depth 8
    $tmp = "$Path.tmp"
    $json | Set-Content -LiteralPath $tmp -Encoding UTF8
    Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function Invoke-RoutineWebhook {
    param(
        [Parameter(Mandatory = $true)] [string]$Url,
        [Parameter(Mandatory = $true)] [object]$Payload
    )
    Invoke-RestMethod `
        -Method Post `
        -Uri $Url `
        -ContentType "application/json" `
        -Body ($Payload | ConvertTo-Json -Depth 8) `
        -TimeoutSec 30 | Out-Null
}

$localNow = Get-Date
$localDate = $localNow.ToString("yyyy-MM-dd")
$utcNow = [datetime]::UtcNow

$result = [ordered]@{
    check = "company_daily_report"
    local_date = $localDate
    generated_at_utc = $utcNow.ToString("o")
    vault_path = $VaultPath
    snapshot_root = $SnapshotRoot
    snapshot_path = $null
    routine_triggered = $false
    status = "unknown"
    message = ""
}

$state = Read-State -Path $StatePath
if (-not $Force -and $state -and $state.last_success_local_date -eq $localDate) {
    $result.status = "ok"
    $result.message = "Already completed for local date; skipping (idempotent)."
    $result.snapshot_path = $state.last_snapshot_path
    $result.routine_triggered = [bool]$state.last_routine_triggered
    $result | ConvertTo-Json -Depth 8
    exit 0
}

if (-not (Test-Path -LiteralPath $VaultPath)) {
    $result.status = "critical"
    $result.message = "Vault path not found: $VaultPath"
    $result | ConvertTo-Json -Depth 8
    exit 2
}

Ensure-Directory -Path $SnapshotRoot

$snapshotName = "obsidian-vault-$($localNow.ToString('yyyyMMdd_HHmmss')).zip"
$snapshotPath = Join-Path $SnapshotRoot $snapshotName
if (Test-Path -LiteralPath $snapshotPath) {
    Remove-Item -LiteralPath $snapshotPath -Force
}

Compress-Archive -Path (Join-Path $VaultPath "*") -DestinationPath $snapshotPath -CompressionLevel Optimal -Force
$result.snapshot_path = $snapshotPath

$cutoff = (Get-Date).AddDays(-1 * [math]::Abs($RetentionDays))
Get-ChildItem -LiteralPath $SnapshotRoot -File -Filter "*.zip" -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt $cutoff } |
    ForEach-Object {
        Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop
    }

if (-not [string]::IsNullOrWhiteSpace($RoutineWebhookUrl)) {
    $payload = [ordered]@{
        source = "scheduler:QM_CompanyReport_Daily_2300"
        local_date = $localDate
        generated_at_utc = $utcNow.ToString("o")
        snapshot_path = $snapshotPath
        timezone = "W. Europe Standard Time"
    }
    Invoke-RoutineWebhook -Url $RoutineWebhookUrl -Payload $payload
    $result.routine_triggered = $true
}

$result.status = "ok"
$result.message = if ($result.routine_triggered) { "Vault snapshot complete; routine trigger sent." } else { "Vault snapshot complete; routine webhook not configured." }

$newState = [ordered]@{
    last_success_local_date = $localDate
    last_run_utc = $utcNow.ToString("o")
    last_snapshot_path = $snapshotPath
    last_routine_triggered = $result.routine_triggered
}
Write-State -Path $StatePath -State $newState

$result | ConvertTo-Json -Depth 8
exit 0
