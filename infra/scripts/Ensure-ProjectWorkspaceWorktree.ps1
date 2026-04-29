[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [Parameter(Mandatory = $true)]
    [string]$ProjectWorkspacePath,
    [Parameter(Mandatory = $true)]
    [string]$BranchName,
    [string]$StartPoint = "HEAD",
    [switch]$CreateBranchIfMissing
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectWorkspacePath)) {
    throw "ProjectWorkspacePath must be non-empty."
}
if ([string]::IsNullOrWhiteSpace($BranchName)) {
    throw "BranchName must be non-empty."
}

$resolvedRepo = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\')
$gitDir = Join-Path $resolvedRepo ".git"
if (-not (Test-Path -LiteralPath $gitDir)) {
    throw "Repo does not contain .git directory: $resolvedRepo"
}

$targetPath = [IO.Path]::GetFullPath($ProjectWorkspacePath).TrimEnd('\')
if (-not (Test-Path -LiteralPath $targetPath)) {
    New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
}

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
    $targetEntries = Get-ChildItem -LiteralPath $targetPath -Force -ErrorAction SilentlyContinue
    if ($targetEntries -and $targetEntries.Count -gt 0) {
        throw "Target path exists and is not an empty directory: $targetPath"
    }

    $branchExists = $false
    & git -C $resolvedRepo show-ref --verify --quiet "refs/heads/$BranchName"
    if ($LASTEXITCODE -eq 0) { $branchExists = $true }

    if (-not $branchExists -and $CreateBranchIfMissing.IsPresent) {
        & git -C $resolvedRepo branch $BranchName $StartPoint
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create branch '$BranchName' from '$StartPoint'."
        }
        $branchExists = $true
    }

    if (-not $branchExists) {
        throw "Branch '$BranchName' does not exist. Re-run with -CreateBranchIfMissing."
    }

    & git -C $resolvedRepo worktree add $targetPath $BranchName
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to add worktree at '$targetPath' for branch '$BranchName'."
    }
    $action = "created"
}

$resolvedTop = & git -C $targetPath rev-parse --show-toplevel
$resolvedBranch = & git -C $targetPath branch --show-current

$result = [ordered]@{
    check = "project_workspace_worktree"
    generated_at_utc = [datetime]::UtcNow.ToString("o")
    status = "ok"
    action = $action
    repo_root = $resolvedRepo
    branch = $resolvedBranch.Trim()
    workspace_path = $targetPath
    toplevel = $resolvedTop.Trim()
}

$result | ConvertTo-Json -Depth 6
exit 0
