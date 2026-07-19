# Keeps an interactive Codex CLI thread alive across hard child-process exits.
# Non-interactive Codex subcommands are passed through unchanged.

$ErrorActionPreference = 'Stop'
$realCodex = if ($env:QM_CODEX_REAL_LAUNCHER) {
    $env:QM_CODEX_REAL_LAUNCHER
} else {
    Join-Path $env:APPDATA 'npm\codex.cmd'
}
$logPath = if ($env:QM_CODEX_SUPERVISOR_LOG) {
    $env:QM_CODEX_SUPERVISOR_LOG
} else {
    'D:\QM\strategy_farm\logs\codex_session_supervisor.jsonl'
}
$initialArgs = @($args | ForEach-Object { [string]$_ })
$continuationPrompt = @'
Die lokale Codex-CLI wurde nach einem unerwarteten Prozessabbruch automatisch mit demselben Thread fortgesetzt. Setze den zuletzt laufenden Arbeitsauftrag selbstständig fort. Prüfe zuerst den aktuellen Workspace-Zustand, übernimm bereits erledigte Arbeit und wiederhole keine abgeschlossenen Schritte.
'@.Trim()

if (-not (Test-Path -LiteralPath $realCodex)) {
    throw "Codex CLI launcher not found: $realCodex"
}

function Write-SupervisorEvent {
    param(
        [string]$Event,
        [hashtable]$Data = @{}
    )
    try {
        $parent = Split-Path -Parent $logPath
        if (-not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        $record = [ordered]@{
            ts_utc = (Get-Date).ToUniversalTime().ToString('o')
            event = $Event
            supervisor_pid = $PID
            cwd = (Get-Location).Path
        }
        foreach ($entry in $Data.GetEnumerator()) {
            $record[$entry.Key] = $entry.Value
        }
        Add-Content -LiteralPath $logPath -Value ($record | ConvertTo-Json -Compress -Depth 5) -Encoding UTF8
    } catch {
        # Logging must never break the user's terminal session.
    }
}

$script:lastCodexExitCode = 0

function Invoke-RealCodex {
    param([string[]]$LaunchArgs)
    try {
        & $realCodex @LaunchArgs
        $script:lastCodexExitCode = [int]$LASTEXITCODE
    } catch {
        Write-SupervisorEvent -Event 'launcher_exception' -Data @{ error = $_.Exception.Message }
        $script:lastCodexExitCode = 1
    }
}

function Get-InvocationSubcommand {
    param([string[]]$InvocationArgs)
    $optionsWithValue = @(
        '-c', '--config', '--enable', '--disable', '--remote',
        '--remote-auth-token-env', '-m', '--model', '--local-provider',
        '-p', '--profile', '-s', '--sandbox', '-C', '--cd', '--add-dir',
        '-a', '--ask-for-approval'
    )
    for ($index = 0; $index -lt $InvocationArgs.Count; $index++) {
        $argument = [string]$InvocationArgs[$index]
        if ($argument -in $optionsWithValue) {
            $index++
            continue
        }
        if ($argument.StartsWith('-')) { continue }
        return $argument
    }
    return $null
}

function Get-LatestRootSessionId {
    param(
        [string]$WorkingDirectory,
        [datetime]$NotOlderThan
    )
    try {
        $codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
        $sessionRoot = Join-Path $codexHome 'sessions'
        if (-not (Test-Path -LiteralPath $sessionRoot)) { return $null }
        $candidates = Get-ChildItem -LiteralPath $sessionRoot -Recurse -Filter '*.jsonl' -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTimeUtc -ge $NotOlderThan.ToUniversalTime() } |
            Sort-Object LastWriteTimeUtc -Descending |
            Select-Object -First 300
        foreach ($file in $candidates) {
            try {
                $meta = (Get-Content -LiteralPath $file.FullName -TotalCount 1 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop).payload
                if ($meta.originator -ne 'codex-tui') { continue }
                if ([string]$meta.cwd -ne $WorkingDirectory) { continue }
                if ($meta.thread_source -eq 'subagent' -or $meta.agent_path) { continue }
                $sessionId = [string]$meta.session_id
                if (-not $sessionId) { $sessionId = [string]$meta.id }
                if ($sessionId) { return $sessionId }
            } catch {
                continue
            }
        }
    } catch {
        return $null
    }
    return $null
}

function Test-InteractiveInvocation {
    param([string[]]$InvocationArgs)
    if ($env:QM_CODEX_SESSION_SUPERVISOR -eq '0') { return $false }
    if ($env:QM_CODEX_SESSION_SUPERVISOR_FORCE -ne '1' -and
        ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected)) {
        return $false
    }
    if ($InvocationArgs -contains '--help' -or $InvocationArgs -contains '-h' -or
        $InvocationArgs -contains '--version' -or $InvocationArgs -contains '-V') {
        return $false
    }
    $directSubcommands = @(
        'app', 'app-server', 'apply', 'a', 'archive', 'cloud', 'cloud-tasks',
        'completion', 'debug', 'delete', 'doctor', 'exec', 'e', 'execpolicy',
        'features', 'login', 'logout', 'mcp', 'mcp-server', 'plugin',
        'remote-control', 'review', 'sandbox', 'unarchive', 'update'
    )
    $subcommand = Get-InvocationSubcommand -InvocationArgs $InvocationArgs
    if ($subcommand -in $directSubcommands) { return $false }
    return $true
}

if (-not (Test-InteractiveInvocation -InvocationArgs $initialArgs)) {
    Invoke-RealCodex -LaunchArgs $initialArgs
    $exitCode = $script:lastCodexExitCode
    exit $exitCode
}

$launchArgs = $initialArgs
$sessionId = $null
$restartAttempt = 0
$maxConsecutiveFailures = 12
# Windows `os.kill(pid, 0)` is implemented as TerminateProcess(..., 0), so an
# externally killed Codex can report exit code 0.  Only explicit console-break
# codes stop the continuity loop.  To end a supervised interactive session,
# use Ctrl+C; `/exit` may be treated as recoverable and reopen the thread.
$intentionalExitCodes = @(130, -1073741510, 3221225786)
Write-SupervisorEvent -Event 'interactive_session_started' -Data @{
    argument_count = $initialArgs.Count
}

while ($true) {
    $startedAt = Get-Date
    Invoke-RealCodex -LaunchArgs $launchArgs
    $exitCode = $script:lastCodexExitCode
    $runtimeSeconds = [math]::Round(((Get-Date) - $startedAt).TotalSeconds, 3)

    if ($exitCode -in $intentionalExitCodes) {
        Write-SupervisorEvent -Event 'interactive_session_ended' -Data @{
            exit_code = $exitCode
            runtime_seconds = $runtimeSeconds
            intentional = $true
        }
        exit $exitCode
    }

    if ($runtimeSeconds -ge 60) {
        $restartAttempt = 1
    } else {
        $restartAttempt++
    }
    Write-SupervisorEvent -Event 'unexpected_exit' -Data @{
        exit_code = $exitCode
        runtime_seconds = $runtimeSeconds
        restart_attempt = $restartAttempt
    }

    $capturedSessionId = Get-LatestRootSessionId `
        -WorkingDirectory (Get-Location).Path `
        -NotOlderThan $startedAt.AddMinutes(-2)
    if ($capturedSessionId) {
        $sessionId = $capturedSessionId
    }

    if ($restartAttempt -gt $maxConsecutiveFailures) {
        Write-Error "Codex konnte nach $maxConsecutiveFailures Versuchen nicht stabil fortgesetzt werden. Details: $logPath"
        exit $exitCode
    }

    $delaySeconds = [math]::Min(30, [math]::Pow(2, [math]::Min(4, $restartAttempt - 1)))
    Write-Warning "Codex-Prozess endete unerwartet (Code $exitCode). Thread wird in $delaySeconds s automatisch fortgesetzt (Versuch $restartAttempt/$maxConsecutiveFailures)."
    Start-Sleep -Seconds $delaySeconds
    if ($sessionId) {
        $launchArgs = @('resume', $sessionId, $continuationPrompt)
    } else {
        $launchArgs = @('resume', '--last', $continuationPrompt)
    }
}
