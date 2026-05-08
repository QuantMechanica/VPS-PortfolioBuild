[CmdletBinding()]
param(
    [string]$ScriptPath = "C:\QM\repo\infra\scripts\Resolve-YouTubeAnalystUnblock.ps1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ScriptPath)) {
    throw "Missing script: $ScriptPath"
}

$tmpRoot = Join-Path $env:TEMP ("yt-unblock-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmpRoot -Force | Out-Null
try {
    $videoUrl = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"

    $env:QM_CLAUDE_VIDEO_MCP_AVAILABLE = "0"
    $outFallback = & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath -VideoUrl $videoUrl -OutputRoot $tmpRoot 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Expected fallback preview success; exit=$LASTEXITCODE output=$($outFallback -join ' | ')"
    }
    $jsonFallback = ($outFallback -join "`n") | ConvertFrom-Json
    if ($jsonFallback.decision.path -ne "transcript_fallback") {
        throw "Expected transcript_fallback path; got '$($jsonFallback.decision.path)'"
    }

    $env:QM_CLAUDE_VIDEO_MCP_AVAILABLE = "1"
    $outMcp = & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath -VideoUrl $videoUrl -OutputRoot $tmpRoot 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Expected MCP preview success; exit=$LASTEXITCODE output=$($outMcp -join ' | ')"
    }
    $jsonMcp = ($outMcp -join "`n") | ConvertFrom-Json
    if ($jsonMcp.decision.path -ne "claude_video_mcp") {
        throw "Expected claude_video_mcp path; got '$($jsonMcp.decision.path)'"
    }

    Write-Host "PASS: YouTube Analyst unblock routing contract validated."
}
finally {
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item Env:QM_CLAUDE_VIDEO_MCP_AVAILABLE -ErrorAction SilentlyContinue
}
