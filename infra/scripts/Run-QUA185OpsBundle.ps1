[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$DriveCheckScript = "C:\QM\repo\infra\monitoring\Test-DriveGitExclusion.ps1",
    [string]$TransitionPayloadScript = "C:\QM\repo\infra\scripts\New-QUA185IssueTransitionPayload.ps1",
    [string]$OutPath = "C:\QM\repo\docs\ops\QUA-185_OPS_BUNDLE_2026-04-27.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-ParentDirectory {
    param([string]$Path)
    $parent = Split-Path -Path $Path -Parent
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Run
    )
    $started = Get-Date
    try {
        $output = & $Run
        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode) { $exitCode = 0 }
        return [pscustomobject]@{
            name = $Name
            status = if ($exitCode -eq 0) { "ok" } else { "failed" }
            exit_code = $exitCode
            started_at_local = $started.ToString("o")
            finished_at_local = (Get-Date).ToString("o")
            output = (($output | Out-String).Trim())
        }
    }
    catch {
        return [pscustomobject]@{
            name = $Name
            status = "failed"
            exit_code = 1
            started_at_local = $started.ToString("o")
            finished_at_local = (Get-Date).ToString("o")
            output = $_.Exception.Message
        }
    }
}

$steps = @()
$steps += Invoke-Step -Name "drive_git_hard_fence_check" -Run {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $DriveCheckScript -PrimaryRepoForWorktrees $RepoRoot -IncludeGitWorktrees
}
$steps += Invoke-Step -Name "qua185_transition_payload_regen" -Run {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $TransitionPayloadScript
}

$overall = if (@($steps | Where-Object { $_.status -eq "failed" }).Count -gt 0) { "failed" } else { "ok" }

$result = [ordered]@{
    issue = "QUA-185"
    generated_at_local = (Get-Date).ToString("o")
    overall_status = $overall
    steps = @($steps)
}

Ensure-ParentDirectory -Path $OutPath
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutPath -Encoding ASCII
$result | ConvertTo-Json -Depth 8

if ($overall -eq "ok") { exit 0 }
exit 2
