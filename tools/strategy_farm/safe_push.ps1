param(
    [string]$Branch = "agents/board-advisor-session-2026-05-17"
)

$ErrorActionPreference = "Stop"

git fetch origin $Branch
$head = git rev-parse HEAD
$remote = git rev-parse "origin/$Branch" 2>$null

if ($remote -and $head -ne $remote) {
    git merge --no-ff "origin/$Branch" -m "merge origin/$Branch into HEAD" 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) {
        Write-Host "safe_push.merge_conflict_detected - manual review needed"
        exit 2
    }
}

git push origin "HEAD:$Branch"
