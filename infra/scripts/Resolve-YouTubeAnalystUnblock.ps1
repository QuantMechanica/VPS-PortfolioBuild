[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$VideoUrl,
    [string]$OutputRoot = "C:\QM\repo\docs\ops\youtube-transcripts",
    [switch]$Apply,
    [switch]$ForceFallback,
    [switch]$ForceRefresh,
    [string[]]$YtDlpExtraArgs = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-VideoId {
    param([string]$Url)
    if ($Url -match 'youtu\.be\/([A-Za-z0-9_-]{6,})') { return $Matches[1] }
    if ($Url -match '[\?\&]v=([A-Za-z0-9_-]{6,})') { return $Matches[1] }
    if ($Url -match '\/shorts\/([A-Za-z0-9_-]{6,})') { return $Matches[1] }
    throw "Unsupported YouTube URL format: $Url"
}

function Test-ClaudeVideoMcpAvailable {
    param([switch]$ForceFallback)
    if ($ForceFallback) { return $false }

    $flag = [Environment]::GetEnvironmentVariable("QM_CLAUDE_VIDEO_MCP_AVAILABLE")
    if ($flag -eq "1") { return $true }
    if ($flag -eq "0") { return $false }

    return $false
}

function Convert-VttToText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VttPath,
        [Parameter(Mandatory = $true)]
        [string]$OutTxtPath
    )

    $lines = Get-Content -LiteralPath $VttPath
    $clean = New-Object System.Collections.Generic.List[string]
    foreach ($line in $lines) {
        $trim = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trim)) { continue }
        if ($trim -eq "WEBVTT") { continue }
        if ($trim -match '^\d+$') { continue }
        if ($trim -match '^\d{2}:\d{2}:\d{2}\.\d{3}\s+-->\s+\d{2}:\d{2}:\d{2}\.\d{3}') { continue }
        if ($trim -match '^\d{2}:\d{2}\.\d{3}\s+-->\s+\d{2}:\d{2}\.\d{3}') { continue }
        if ($trim -match '^NOTE\b') { continue }
        $clean.Add($trim)
    }
    $clean | Set-Content -LiteralPath $OutTxtPath -Encoding UTF8
}

function Resolve-YtDlpRunner {
    $ytDlpCmd = Get-Command yt-dlp -ErrorAction SilentlyContinue
    if ($null -ne $ytDlpCmd) {
        return [ordered]@{
            Kind = "exe"
            Command = $ytDlpCmd.Source
            ArgsPrefix = @()
        }
    }

    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($null -ne $pythonCmd) {
        return [ordered]@{
            Kind = "python_module"
            Command = $pythonCmd.Source
            ArgsPrefix = @("-m", "yt_dlp")
        }
    }

    return $null
}

function Invoke-TranscriptApiFallback {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VideoId,
        [Parameter(Mandatory = $true)]
        [string]$OutTxtPath
    )

    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($null -eq $pythonCmd) {
        return [ordered]@{ ok = $false; reason = "python_missing" }
    }

    $script = @'
import json
import sys

try:
    from youtube_transcript_api import YouTubeTranscriptApi
except Exception as exc:
    print(json.dumps({"ok": False, "reason": "module_missing", "error": str(exc)}))
    sys.exit(0)

video_id = sys.argv[1]
out_path = sys.argv[2]
try:
    api = YouTubeTranscriptApi()
    rows = api.fetch(video_id, languages=["en"])
    with open(out_path, "w", encoding="utf-8") as handle:
        for row in rows:
            text = (row.get("text") or "").strip()
            if text:
                handle.write(text + "\n")
    print(json.dumps({"ok": True, "segments": len(rows)}))
except Exception as exc:
    print(json.dumps({"ok": False, "reason": "fetch_failed", "error": str(exc)}))
'@

    $raw = $script | & $pythonCmd.Source - $VideoId $OutTxtPath
    try {
        return ($raw | ConvertFrom-Json)
    }
    catch {
        return [ordered]@{ ok = $false; reason = "invalid_python_output"; output = ($raw -join "`n") }
    }
}

function Invoke-YoutubeScriptsMirrorFallback {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VideoId,
        [Parameter(Mandatory = $true)]
        [string]$OutTxtPath
    )

    $mirrorUrl = "https://www.youtube-scripts.com/t/$VideoId"
    try {
        $resp = Invoke-WebRequest -Uri $mirrorUrl -UseBasicParsing -TimeoutSec 45
    }
    catch {
        return [ordered]@{ ok = $false; reason = "mirror_fetch_failed"; error = $_.Exception.Message; url = $mirrorUrl }
    }

    $pat = '\{\\"text\\":\\"(.*?)\\",\\"offset\\":'
    $matches = [regex]::Matches($resp.Content, $pat)
    if ($matches.Count -le 0) {
        return [ordered]@{ ok = $false; reason = "mirror_no_segments"; url = $mirrorUrl }
    }

    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($m in $matches) {
        $t = $m.Groups[1].Value
        $t = $t.Replace('\u0026#39;', "'")
        $t = $t.Replace('\u0026quot;', '"')
        $t = $t.Replace('\u0026amp;', '&')
        $t = $t.Replace('\n', ' ')
        $t = [System.Net.WebUtility]::HtmlDecode($t)
        if (-not [string]::IsNullOrWhiteSpace($t)) {
            $lines.Add($t.Trim())
        }
    }
    if ($lines.Count -le 0) {
        return [ordered]@{ ok = $false; reason = "mirror_segments_empty"; url = $mirrorUrl }
    }

    [string]::Join(' ', $lines) | Set-Content -LiteralPath $OutTxtPath -Encoding UTF8
    return [ordered]@{ ok = $true; segments = $lines.Count; url = $mirrorUrl }
}

$videoId = Get-VideoId -Url $VideoUrl
$stamp = (Get-Date).ToString("yyyy-MM-ddTHHmmss")
$targetDir = Join-Path $OutputRoot $videoId
$txtPath = Join-Path $targetDir ("transcript_" + $videoId + ".txt")
$mcpAvailable = Test-ClaudeVideoMcpAvailable -ForceFallback:$ForceFallback

$decision = if ($mcpAvailable) { "claude_video_mcp" } else { "transcript_fallback" }

$result = [ordered]@{
    issue = "QUA-914"
    checked_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    decision = [ordered]@{
        path = $decision
        apply = [bool]$Apply
        mcp_available = [bool]$mcpAvailable
    }
    input = [ordered]@{
        video_url = $VideoUrl
        video_id = $videoId
    }
    output = [ordered]@{
        output_root = $OutputRoot
        target_dir = $targetDir
        transcript_txt = $txtPath
    }
}

if (-not $Apply) {
    $result["next_action"] = if ($decision -eq "claude_video_mcp") {
        "Run analyst flow through claude-video MCP for this URL."
    } else {
        "Re-run with -Apply to fetch transcript fallback via yt-dlp."
    }
    $result | ConvertTo-Json -Depth 8
    exit 0
}

if (-not (Test-Path -LiteralPath $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

if ($decision -eq "claude_video_mcp") {
    $result["status"] = "mcp_available_no_fallback_run"
    $result | ConvertTo-Json -Depth 8
    exit 0
}

if ((Test-Path -LiteralPath $txtPath) -and -not $ForceRefresh) {
    $result["status"] = "transcript_already_present"
    $result | ConvertTo-Json -Depth 8
    exit 0
}

$ytDlpRunner = Resolve-YtDlpRunner
if ($null -eq $ytDlpRunner) {
    throw "yt-dlp is required for transcript fallback but is not installed (executable or python module)."
}

$outTemplate = Join-Path $targetDir ($videoId + ".%(ext)s")
$args = @(
    "--skip-download",
    "--write-auto-subs",
    "--write-subs",
    "--sub-langs", "en.*,en",
    "--sub-format", "vtt",
    "-o", $outTemplate,
    $VideoUrl
)
if ($YtDlpExtraArgs.Count -gt 0) {
    $args += $YtDlpExtraArgs
}

$invokeArgs = @()
$invokeArgs += $ytDlpRunner.ArgsPrefix
$invokeArgs += $args
& $ytDlpRunner.Command @invokeArgs | Out-Null
$ytDlpExit = $LASTEXITCODE
if ($ytDlpExit -eq 0) {
    $vtt = Get-ChildItem -LiteralPath $targetDir -File -Filter "*.vtt" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($null -eq $vtt) {
        throw "Transcript fallback completed but no .vtt subtitle file was produced."
    }

    Convert-VttToText -VttPath $vtt.FullName -OutTxtPath $txtPath
    $result["status"] = "transcript_fallback_generated"
    $result["output"]["subtitle_vtt"] = $vtt.FullName
    $result["fallback_engine"] = "yt-dlp"
}
else {
    $apiFallback = Invoke-TranscriptApiFallback -VideoId $videoId -OutTxtPath $txtPath
    if ($apiFallback.ok -eq $true -and (Test-Path -LiteralPath $txtPath)) {
        $result["status"] = "transcript_fallback_generated"
        $result["fallback_engine"] = "youtube-transcript-api"
        $result["fallback_details"] = $apiFallback
    }
    else {
        $mirrorFallback = Invoke-YoutubeScriptsMirrorFallback -VideoId $videoId -OutTxtPath $txtPath
        if ($mirrorFallback.ok -eq $true -and (Test-Path -LiteralPath $txtPath)) {
            $result["status"] = "transcript_fallback_generated"
            $result["fallback_engine"] = "youtube-scripts-mirror"
            $result["fallback_details"] = $mirrorFallback
        }
        else {
            throw "Transcript fallback failed: yt-dlp exit=$ytDlpExit; transcript-api reason=$($apiFallback.reason); mirror reason=$($mirrorFallback.reason)"
        }
    }
}
$result | ConvertTo-Json -Depth 8
