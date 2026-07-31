[CmdletBinding()]
param(
    [int]$MaxMinutes = 20
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$deadline = (Get-Date).AddMinutes($MaxMinutes)
$seen = [System.Collections.Generic.HashSet[int]]::new()
$captures = [System.Collections.Generic.List[object]]::new()
$captureByPid = @{}
$ownerByPid = @{}
$requiredChildren = @{
    AgyGovernor = $false
    CodexFleetPacer = $false
    GeminiOrchestration = $false
}

function Get-TargetLabel {
    param([Parameter(Mandatory = $true)][string]$CommandLine)

    if ($CommandLine -match 'agy_governor\.py') {
        return 'AgyGovernor'
    }
    if ($CommandLine -match 'codex_fleet_pacer\.py') {
        return 'CodexFleetPacer'
    }
    if (
        $CommandLine -match 'run_agent_orchestration_task\.py' -and
        $CommandLine -match '--agent\s+gemini'
    ) {
        return 'GeminiOrchestration'
    }
    return ''
}

$eventSource = 'MNT003ProcessStartTrace'
Unregister-Event -SourceIdentifier $eventSource -ErrorAction SilentlyContinue
Register-WmiEvent -Class Win32_ProcessStartTrace -SourceIdentifier $eventSource | Out-Null
try {
    while ((Get-Date) -lt $deadline -and $requiredChildren.Values -contains $false) {
        foreach ($event in @(Get-Event -SourceIdentifier $eventSource -ErrorAction SilentlyContinue)) {
            $eventProcess = $event.SourceEventArgs.NewEvent
            $eventPid = [int]$eventProcess.ProcessID
            $owner = 'UNKNOWN'
            try {
                $sid = [System.Security.Principal.SecurityIdentifier]::new(
                    [byte[]]$eventProcess.Sid,
                    0
                )
                $owner = $sid.Translate(
                    [System.Security.Principal.NTAccount]
                ).Value
            } catch {
                $owner = 'UNKNOWN'
            }
            $ownerByPid[$eventPid] = $owner
            if ($captureByPid.ContainsKey($eventPid)) {
                $row = $captureByPid[$eventPid]
                # ProcessStartTrace.Sid can identify the creating token. Keep a
                # successful Win32_Process.GetOwner result for the child token;
                # use the event SID only when the direct lookup lost a very
                # short-lived process.
                if ([string]($row.owner) -like 'UNKNOWN*') {
                    $row.owner = $owner
                }
                if (
                    $owner -match '\\qm-admin$' -and
                    [int]$row.session_id -eq 1 -and
                    [string]$row.name -in @('python.exe', 'pythonw.exe')
                ) {
                    $requiredChildren[[string]$row.target] = $true
                }
            }
            Remove-Event -EventIdentifier $event.EventIdentifier -ErrorAction SilentlyContinue
        }

        $processes = Get-CimInstance Win32_Process -Filter (
            "Name='powershell.exe' OR Name='python.exe' OR Name='pythonw.exe'"
        )
        foreach ($process in $processes) {
            $commandLine = [string]$process.CommandLine
            if (-not $commandLine) {
                continue
            }
            $label = Get-TargetLabel -CommandLine $commandLine
            if (-not $label) {
                continue
            }
            $pidValue = [int]$process.ProcessId
            if (-not $seen.Add($pidValue)) {
                continue
            }

            $owner = if ($ownerByPid.ContainsKey($pidValue)) {
                [string]$ownerByPid[$pidValue]
            } else {
                'UNKNOWN'
            }
            if ($owner -eq 'UNKNOWN') {
                try {
                    $ownerResult = Invoke-CimMethod `
                        -InputObject $process `
                        -MethodName GetOwner `
                        -ErrorAction Stop
                    if ([int]$ownerResult.ReturnValue -eq 0) {
                        $owner = if ($ownerResult.Domain) {
                            "$($ownerResult.Domain)\$($ownerResult.User)"
                        } else {
                            [string]$ownerResult.User
                        }
                    }
                } catch {
                    $owner = 'UNKNOWN_TRANSIENT_EXIT'
                }
            }

            $row = [pscustomobject]@{
                observed_at = (Get-Date).ToString('o')
                target = $label
                pid = $pidValue
                parent_pid = [int]$process.ParentProcessId
                session_id = [int]$process.SessionId
                owner = $owner
                name = [string]$process.Name
                command_line = $commandLine
                contains_apostrophe = $commandLine.Contains("'")
            }
            $captures.Add($row)
            $captureByPid[$pidValue] = $row
            Write-Output ("CAPTURE " + ($row | ConvertTo-Json -Compress))

            if (
                $owner -match '\\qm-admin$' -and
                [int]$process.SessionId -eq 1 -and
                [string]$process.Name -in @('python.exe', 'pythonw.exe')
            ) {
                $requiredChildren[$label] = $true
            }
        }
        Start-Sleep -Milliseconds 25
    }
} finally {
    Unregister-Event -SourceIdentifier $eventSource -ErrorAction SilentlyContinue
    Get-Job | Where-Object Name -eq $eventSource | Remove-Job -Force -ErrorAction SilentlyContinue
}

[pscustomobject]@{
    schema = 'qm.mnt003.process-trace/v1'
    observed_until = (Get-Date).ToString('o')
    complete = -not ($requiredChildren.Values -contains $false)
    required_children = $requiredChildren
    captures = @($captures)
} | ConvertTo-Json -Depth 8

if ($requiredChildren.Values -contains $false) {
    exit 2
}
