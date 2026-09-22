[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ThreadId,
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$StateDir = 'D:\QM\reports\state\codex_factory_chat',
    [string]$Pythonw = 'C:\Python311\pythonw.exe',
    [switch]$RunNow
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$null = [guid]::Parse($ThreadId)
$taskName = 'QM_Codex_FactoryChat_Hourly'
$scriptPath = Join-Path $RepoRoot 'tools\strategy_farm\codex_factory_chat_hourly.py'
$promptPath = Join-Path $RepoRoot 'docs\ops\CODEX_FACTORY_CHAT_HOURLY_PROMPT.md'
$queueDb = Join-Path $env:USERPROFILE '.codex\queue_1.sqlite'
$codexExe = Join-Path $env:APPDATA 'npm\node_modules\@openai\codex\node_modules\@openai\codex-win32-x64\vendor\x86_64-pc-windows-msvc\bin\codex.exe'
foreach ($required in @($scriptPath, $promptPath, $Pythonw, $codexExe, $queueDb)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Missing required file: $required" }
}
# Bind to the existing user's profile and interactive session. SYSTEM would
# resolve a different Codex home. No password, new agent, or console window.
$userId = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Limited
New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
$configPath = Join-Path $StateDir 'config.json'
$config = [ordered]@{
    thread_id = $ThreadId; repo_root = $RepoRoot; state_dir = $StateDir
    queue_db = $queueDb; codex_exe = $codexExe; prompt_file = $promptPath
}
[System.IO.File]::WriteAllText($configPath, ($config | ConvertTo-Json), [System.Text.UTF8Encoding]::new($false))
$now = Get-Date
$firstRun = $now.Date.AddHours($now.Hour + 1)
$trigger = New-ScheduledTaskTrigger -Once -At $firstRun -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
$action = New-ScheduledTaskAction -Execute $Pythonw -Argument "-X utf8 `"$scriptPath`" --config `"$configPath`"" -WorkingDirectory $RepoRoot
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force -Description 'OWNER 2026-09-22: hourly Factory inspection and German update in the existing Codex CLI thread via codex queue; no email.' | Out-Null
Enable-ScheduledTask -TaskName $taskName | Out-Null
if ($RunNow) { Start-ScheduledTask -TaskName $taskName }
Get-ScheduledTask -TaskName $taskName | Select-Object TaskName, State, @{N='NextRun';E={(Get-ScheduledTaskInfo -TaskName $taskName).NextRunTime}}
