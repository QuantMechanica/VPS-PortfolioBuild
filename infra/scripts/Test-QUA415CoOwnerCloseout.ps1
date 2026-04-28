param(
    [string]$RepoRoot = "C:\QM\repo",
    [int]$RecentCommits = 80
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Push-Location $RepoRoot
try {
    $lines = git log --oneline -n $RecentCommits
} finally {
    Pop-Location
}

$hits = @($lines | Where-Object { $_ -match 'setfile|dispatch|QUA-415|pipeline' })
$knownDevops = @('21cc3e6','fc52012','591e9af','a19c7cf','f28df74','61699e2','bc87ec0','b655daa','4139caf','abd7a4f','e7bd317','659df32')
$nonDevops = @(
    $hits | Where-Object {
        $hash = ($_ -split '\s+')[0]
        ($knownDevops -notcontains $hash) -and
        ($_ -notmatch 'docs:|infra:|DevOps|hold note|readiness|manifest|handoff|blocked|final status')
    }
)

if ($nonDevops.Count -gt 0) {
    [pscustomobject]@{
        status = "READY"
        issue = "QUA-415"
        matches = $nonDevops
    } | ConvertTo-Json -Depth 6
    exit 0
}

[pscustomobject]@{
    status = "BLOCKED"
    issue = "QUA-415"
    unblock_owner = "Pipeline-Operator"
    unblock_action = "Post workflow confirmation commit hash proving active setfile_path dispatch consumption."
    recent_matches = $hits
} | ConvertTo-Json -Depth 6
exit 2
