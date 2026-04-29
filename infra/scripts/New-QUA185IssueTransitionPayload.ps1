[CmdletBinding()]
param(
    [string]$IssueId = "QUA-185",
    [string]$DateStamp = "2026-04-27",
    [string]$CloseoutPath = "C:\QM\repo\docs\ops\QUA-185_CLOSEOUT_2026-04-27.md",
    [string]$RunbookPath = "C:\QM\repo\infra\drive-git-exclusion-runbook.md",
    [string]$SnapshotPath = "C:\QM\repo\docs\ops\PC1-00_DRIVE_GIT_HARD_FENCE_EVIDENCE_2026-04-27.md",
    [string]$RuntimeJsonPath = "C:\QM\logs\infra\health\drive_git_exclusion_latest.json",
    [string]$OutPath = "C:\QM\repo\docs\ops\QUA-185_ISSUE_TRANSITION_PAYLOAD_2026-04-27.json"
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

function Get-RepoRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$TargetPath
    )
    $repoFull = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\')
    $targetFull = [IO.Path]::GetFullPath($TargetPath)

    if ($targetFull.StartsWith("$repoFull\", [System.StringComparison]::OrdinalIgnoreCase)) {
        return $targetFull.Substring($repoFull.Length + 1).Replace('\', '/')
    }
    if ($targetFull.Equals($repoFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        return "."
    }
    return $targetFull.Replace('\', '/')
}

if (-not (Test-Path -LiteralPath $CloseoutPath -PathType Leaf)) {
    throw "Closeout artifact missing: $CloseoutPath"
}
if (-not (Test-Path -LiteralPath $RunbookPath -PathType Leaf)) {
    throw "Runbook missing: $RunbookPath"
}
if (-not (Test-Path -LiteralPath $SnapshotPath -PathType Leaf)) {
    throw "Snapshot artifact missing: $SnapshotPath"
}

$payload = [ordered]@{
    issue_id = $IssueId
    updated_at_local = (Get-Date).ToString("o")
    target_status = "in_review"
    reason = "pc1_00_drive_git_hard_fence_operationalized"
    summary = "Drive-sync exclusion hard fence is implemented for repo + worktree git pointers with recurring task wiring, evidence path, and failure alert routing."
    evidence = [ordered]@{
        closeout_markdown = Get-RepoRelativePath -RepoRoot "C:\QM\repo" -TargetPath $CloseoutPath
        runbook = Get-RepoRelativePath -RepoRoot "C:\QM\repo" -TargetPath $RunbookPath
        runtime_json_path = $RuntimeJsonPath
        snapshot_markdown = Get-RepoRelativePath -RepoRoot "C:\QM\repo" -TargetPath $SnapshotPath
    }
    commits = @(
        "bc9c382",
        "d5efef3",
        "905a20b",
        "491f5d4",
        "c563004",
        "bb11060",
        "e76124c",
        "4f07534"
    )
    notes = @(
        "Install-DriveGitExclusionTask.ps1 supports PreviewOnly mode for non-mutating validation.",
        "Cleanup commits removed accidental non-infra staged-file carryover from early QUA-185 commits."
    )
}

Ensure-ParentDirectory -Path $OutPath
$payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutPath -Encoding ASCII
$payload | ConvertTo-Json -Depth 6
