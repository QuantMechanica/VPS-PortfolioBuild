<#
.SYNOPSIS
  Durability push of the factory repo to origin (branch + FF main).

.DESCRIPTION
  The pump's deterministic auto-commit (_auto_commit_build_artifacts) commits
  build artifacts LOCALLY but never pushes, so origin/main drifts behind as the
  factory produces .ex5/set/registry/public-data output. This task pushes the
  current branch to origin and fast-forwards main, keeping GitHub durable.

  Token from GH_TOKEN (Machine env) via url.insteadOf rewrite (headless-safe;
  same pattern as the pump). Token is masked from all output. Branch push is the
  essential durability step; main FF is best-effort (a non-FF never fails the task).
  Registered as scheduled task QM_Repo_Push (DAILY). OWNER 2026-06-04.
#>
$ErrorActionPreference = 'Continue'
$repo = 'C:\QM\repo'
$tok = [Environment]::GetEnvironmentVariable('GH_TOKEN','Machine')
if (-not $tok) { Write-Warning 'GH_TOKEN (Machine) not set - cannot push'; exit 1 }
$rw = "url.https://x-access-token:$tok@github.com/.insteadOf=https://github.com/"
function Mask([string]$s){ $s -replace [regex]::Escape($tok),'***' }

$branch = (& git -C $repo rev-parse --abbrev-ref HEAD 2>&1).Trim()
$ahead  = (& git -C $repo rev-list --count "origin/main..HEAD" 2>&1).Trim()
Write-Host "branch=$branch ahead-of-origin/main=$ahead"
if ($ahead -as [int] -le 0) { Write-Host 'nothing to push'; exit 0 }

# Essential: push the current branch.
$out = & git -C $repo -c $rw push origin "HEAD:$branch" 2>&1
Write-Host (Mask ($out -join "`n"))
$branchExit = $LASTEXITCODE

# Best-effort: fast-forward main (never fails the task on a non-FF).
$outMain = & git -C $repo -c $rw push origin "HEAD:main" 2>&1
Write-Host (Mask ($outMain -join "`n"))
if ($LASTEXITCODE -ne 0) { Write-Warning "main FF push non-fatal (exit $LASTEXITCODE)" }

exit $branchExit
