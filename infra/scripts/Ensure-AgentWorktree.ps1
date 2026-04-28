[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$WorktreeRoot = "C:\QM\worktrees",
    [string]$AgentKey = "devops",
    [string]$BranchPrefix = "agents",
    [switch]$CreateBranchIfMissing
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($AgentKey)) {
    throw "AgentKey must be non-empty."
}

$resolvedRepo = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\')
$gitDir = Join-Path $resolvedRepo ".git"
if (-not (Test-Path -LiteralPath $gitDir)) {
    throw "Repo does not contain .git directory: $resolvedRepo"
}

$resolvedWorktreeRoot = [IO.Path]::GetFullPath($WorktreeRoot).TrimEnd('\')
if (-not (Test-Path -LiteralPath $resolvedWorktreeRoot)) {
    New-Item -ItemType Directory -Path $resolvedWorktreeRoot -Force | Out-Null
}

$targetPath = Join-Path $resolvedWorktreeRoot $AgentKey
$branchName = "$BranchPrefix/$AgentKey"

$worktreeList = & git -C $resolvedRepo worktree list --porcelain
if ($LASTEXITCODE -ne 0) {
    throw "Failed to list git worktrees for repo: $resolvedRepo"
}

$registeredPaths = @()
foreach ($line in $worktreeList) {
    if ($line -like "worktree *") {
        $registeredPaths += $line.Substring(9).Trim()
    }
}

$alreadyRegistered = $registeredPaths | Where-Object {
    [IO.Path]::GetFullPath($_).TrimEnd('\') -eq $targetPath
}

$action = "already_present"
if (-not $alreadyRegistered) {
    if ((Test-Path -LiteralPath $targetPath) -and (Get-ChildItem -LiteralPath $targetPath -Force | Select-Object -First 1)) {
        throw "Target path exists and is not an empty directory: $targetPath"
    }

    $branchExists = $false
    & git -C $resolvedRepo show-ref --verify --quiet "refs/heads/$branchName"
    if ($LASTEXITCODE -eq 0) { $branchExists = $true }

    if (-not $branchExists -and $CreateBranchIfMissing.IsPresent) {
        & git -C $resolvedRepo branch $branchName HEAD
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create branch '$branchName'."
        }
        $branchExists = $true
    }

    if (-not $branchExists) {
        throw "Branch '$branchName' does not exist. Re-run with -CreateBranchIfMissing."
    }

    & git -C $resolvedRepo worktree add $targetPath $branchName
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to add worktree at '$targetPath' for branch '$branchName'."
    }
    $action = "created"
}

$result = [ordered]@{
    check = "agent_worktree_isolation"
    generated_at_utc = [datetime]::UtcNow.ToString("o")
    status = "ok"
    action = $action
    repo_root = $resolvedRepo
    agent_key = $AgentKey
    branch = $branchName
    worktree_path = $targetPath
}

$result | ConvertTo-Json -Depth 6
exit 0
