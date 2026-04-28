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

# Only treat as co-owner closeout when commit message indicates
# pipeline dispatch behavior and setfile path consumption.
$hits = @(
    $lines | Where-Object {
        ($_ -match '(?i)(pipeline-operator|pipeline-op|dispatcher|dispatch)') -and
        ($_ -match '(?i)(setfile_path|setfile path|setfile)') -and
        ($_ -match '(?i)(consume|consumption|enforce|required|require)')
    }
)

if ($hits.Count -gt 0) {
    [pscustomobject]@{
        status = "READY"
        issue = "QUA-415"
        matches = $hits
    } | ConvertTo-Json -Depth 6
    exit 0
}

[pscustomobject]@{
    status = "BLOCKED"
    issue = "QUA-415"
    unblock_owner = "Pipeline-Operator"
    unblock_action = "Post workflow confirmation commit hash proving active setfile_path dispatch consumption."
    recent_matches = @($lines | Select-Object -First 20)
} | ConvertTo-Json -Depth 6
exit 2
