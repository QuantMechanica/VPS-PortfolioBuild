param(
    [string]$EnvPath = "C:/QM/paperclip/tools/ops/.env",
    [string]$ExpectedRunId = "",
    [string]$OutPath = "",
    [switch]$PreferProcessEnvToken = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-EnvMap {
    param([string]$Path)
    $map = @{}
    if (-not (Test-Path -LiteralPath $Path)) { return $map }
    foreach ($raw in Get-Content -LiteralPath $Path) {
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith("#")) { continue }
        $eq = $line.IndexOf("=")
        if ($eq -lt 1) { continue }
        $k = $line.Substring(0, $eq).Trim()
        $v = $line.Substring($eq + 1).Trim().Trim('"').Trim("'")
        $map[$k] = $v
    }
    return $map
}

function Decode-JwtPayload {
    param([string]$Token)
    $parts = $Token.Split(".")
    if ($parts.Count -lt 2) { throw "invalid_jwt_shape" }
    $payload = $parts[1].Replace("-", "+").Replace("_", "/")
    while (($payload.Length % 4) -ne 0) { $payload += "=" }
    $json = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload))
    return $json | ConvertFrom-Json
}

$envMap = Get-EnvMap -Path $EnvPath
$token = $null
$tokenSource = $null

if ($PreferProcessEnvToken -and $env:PAPERCLIP_BEARER_TOKEN) {
    $token = [string]$env:PAPERCLIP_BEARER_TOKEN
    $tokenSource = "process_env"
}

if (-not $token) {
    $token = $envMap["PAPERCLIP_BEARER_TOKEN"]
    if ($token) {
        $tokenSource = "env_file"
    }
}

if (-not $token) { throw "missing_token_in_process_env_and_env_file" }

$payload = Decode-JwtPayload -Token $token
$tokenRunId = [string]$payload.run_id

$isMatch = $false
if ($ExpectedRunId -ne "") {
    $isMatch = ($ExpectedRunId -eq $tokenRunId)
}

$result = [ordered]@{
    ts_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    env_path = $EnvPath
    token_source = $tokenSource
    expected_run_id = $ExpectedRunId
    token_run_id = $tokenRunId
    match = $isMatch
}

$json = $result | ConvertTo-Json -Depth 4
if ($OutPath -ne "") {
    $dir = Split-Path -Parent $OutPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($OutPath, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
}

Write-Output $json
