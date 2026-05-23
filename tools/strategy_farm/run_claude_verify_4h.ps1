[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$FarmRoot = "D:\QM\strategy_farm",
    [int]$StaleMinutes = 240,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$logDir = Join-Path $FarmRoot "logs"
$lockDir = Join-Path $FarmRoot "locks"
$disableFlag = Join-Path $FarmRoot "CLAUDE_DISABLED.flag"
$promptPath = Join-Path $RepoRoot "tools\strategy_farm\prompts\claude_farm_verify_4h.md"
$claudeFallback = "C:\Users\Administrator\AppData\Roaming\npm\claude.cmd"
$agentUserHome = "C:\Users\Administrator"
$lockPath = Join-Path $lockDir "claude_verify_4h.lock"
$stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$liveLog = Join-Path $logDir "claude_verify_4h_$stamp.live.log"
$jsonlLog = Join-Path $logDir "claude_verify_4h_$stamp.jsonl"
$resultPath = Join-Path $logDir "claude_verify_4h_$stamp.json"
$heartbeat = Join-Path $logDir "claude_verify_4h_current.heartbeat"

New-Item -ItemType Directory -Force -Path $logDir, $lockDir | Out-Null

function Write-Result {
    param([hashtable]$Payload)
    $Payload.finished_at = (Get-Date).ToUniversalTime().ToString("o")
    $Payload.result_path = $resultPath
    $Payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resultPath -Encoding UTF8
}

function Test-ProcessAlive {
    param([int]$Pid)
    if ($Pid -le 0) { return $false }
    try {
        Get-Process -Id $Pid -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

if (Test-Path -LiteralPath $disableFlag) {
    $payload = @{
        ok = $true
        skipped = $true
        reason = "CLAUDE_DISABLED.flag present"
        disable_flag = $disableFlag
        started_at = (Get-Date).ToUniversalTime().ToString("o")
        returncode = 0
    }
    Write-Result $payload
    exit 0
}

if (-not (Test-Path -LiteralPath $promptPath)) {
    throw "Prompt file not found: $promptPath"
}

$claudeCmd = (Get-Command "claude.cmd" -ErrorAction SilentlyContinue)
if (-not $claudeCmd) {
    $claudeCmd = (Get-Command "claude" -ErrorAction SilentlyContinue)
}
if (-not $claudeCmd -and (Test-Path -LiteralPath $claudeFallback)) {
    $claudeExe = $claudeFallback
} elseif ($claudeCmd) {
    $claudeExe = $claudeCmd.Source
} else {
    throw "claude CLI not found on PATH"
}

if (Test-Path -LiteralPath $lockPath) {
    $age = (Get-Date) - (Get-Item -LiteralPath $lockPath).LastWriteTime
    $lockPayload = $null
    try {
        $lockPayload = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
    } catch {
        $lockPayload = $null
    }
    $pid = 0
    if ($lockPayload -and ($lockPayload.PSObject.Properties.Name -contains "pid")) {
        $pid = [int]$lockPayload.pid
    }
    if ($age.TotalMinutes -lt $StaleMinutes -and (Test-ProcessAlive -Pid $pid)) {
        $payload = @{
            ok = $true
            skipped = $true
            reason = "previous_run_active"
            pid = $pid
            lock_path = $lockPath
            lock_age_minutes = [Math]::Round($age.TotalMinutes, 1)
            started_at = (Get-Date).ToUniversalTime().ToString("o")
            returncode = 0
        }
        Write-Result $payload
        exit 0
    }
}

@{
    pid = $PID
    started_at = (Get-Date).ToUniversalTime().ToString("o")
    runner = "claude_verify_4h"
} | ConvertTo-Json | Set-Content -LiteralPath $lockPath -Encoding UTF8

$prompt = Get-Content -LiteralPath $promptPath -Raw
$env:USERPROFILE = $agentUserHome
$env:HOME = $agentUserHome
$env:HOMEDRIVE = "C:"
$env:HOMEPATH = "\Users\Administrator"
$env:APPDATA = Join-Path $agentUserHome "AppData\Roaming"
$env:LOCALAPPDATA = Join-Path $agentUserHome "AppData\Local"
$payload = @{
    ok = $false
    dry_run = [bool]$DryRun
    prompt_path = $promptPath
    live_log = $liveLog
    jsonl_log = $jsonlLog
    lock_path = $lockPath
    started_at = (Get-Date).ToUniversalTime().ToString("o")
    command = @($claudeExe, "-p", "<prompt>", "--permission-mode", "bypassPermissions", "--output-format", "stream-json", "--verbose", "--add-dir", $RepoRoot, "--add-dir", $FarmRoot, "--add-dir", "G:\My Drive\QuantMechanica - Company Reference")
}

try {
    if ($DryRun.IsPresent) {
        $payload.ok = $true
        $payload.returncode = 0
        $payload.dry_run_verified = $true
        Write-Result $payload
        exit 0
    }

    Set-Content -LiteralPath $heartbeat -Value "$((Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")) STARTED"
    Push-Location $RepoRoot
    try {
        & $claudeExe -p $prompt `
            --permission-mode bypassPermissions `
            --output-format stream-json `
            --verbose `
            --add-dir $RepoRoot `
            --add-dir $FarmRoot `
            --add-dir "G:\My Drive\QuantMechanica - Company Reference" `
            2>&1 | ForEach-Object {
                $_ | Add-Content -LiteralPath $jsonlLog
                $_ | Add-Content -LiteralPath $liveLog
                $line = [string]$_
                $prefix = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
                Set-Content -LiteralPath $heartbeat -Value ("{0} {1}" -f $prefix, $line.Substring(0, [Math]::Min(200, $line.Length)))
            }
        $payload.returncode = $LASTEXITCODE
        $payload.ok = ($LASTEXITCODE -eq 0)
    } finally {
        Pop-Location
    }
    Set-Content -LiteralPath $heartbeat -Value "$((Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")) EXITED exit=$($payload.returncode)"
    Write-Result $payload
    exit ([int]$payload.returncode)
} catch {
    $payload.ok = $false
    $payload.returncode = 1
    $payload.error = $_.Exception.Message
    Write-Result $payload
    exit 1
} finally {
    Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
}
