param(
    [string]$BaseCommit = "847dabad"
)

$branch = git rev-parse --abbrev-ref HEAD
$head = git rev-parse --short HEAD
$count = git rev-list --count "$BaseCommit^..HEAD"
$time = Get-Date -Format o

Write-Host "TIME=$time"
Write-Host "BRANCH=$branch"
Write-Host "HEAD=$head"
Write-Host "RANGE=$BaseCommit^..HEAD"
Write-Host "COUNT=$count"
Write-Host ""
Write-Host "CTO review commands:"
Write-Host "git log --oneline --reverse $BaseCommit^..HEAD"
Write-Host "git show --stat --name-only $BaseCommit^..HEAD"
