[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$SnapshotPath = 'docs\ops\QUA-95_CANONICAL_SNAPSHOT_2026-04-27.json',
    [int]$MaxAgeMinutes = 180
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    Write-Host $Message
    exit 1
}

$snapshotFull = Join-Path $RepoRoot $SnapshotPath
if (-not (Test-Path -LiteralPath $snapshotFull)) {
    Fail ("missing_file=" + $snapshotFull)
}

$snapshot = Get-Content -LiteralPath $snapshotFull -Raw | ConvertFrom-Json
if ([string]$snapshot.issue -ne 'QUA-95') { Fail 'snapshot_issue_mismatch' }
if ([string]$snapshot.flow -ne 'qua95_canonical_snapshot') { Fail 'snapshot_flow_mismatch' }

$generatedRaw = [string]$snapshot.generated_at_local
if ([string]::IsNullOrWhiteSpace($generatedRaw)) { Fail 'snapshot_generated_at_missing' }

$generatedAt = [DateTimeOffset]::MinValue
if (-not [DateTimeOffset]::TryParse($generatedRaw, [ref]$generatedAt)) {
    Fail 'snapshot_generated_at_invalid'
}

$ageMinutes = [math]::Round(((Get-Date).ToUniversalTime() - $generatedAt.UtcDateTime).TotalMinutes, 2)
if ($ageMinutes -lt 0) { Fail 'snapshot_generated_at_in_future' }
if ($ageMinutes -gt $MaxAgeMinutes) {
    Fail ("snapshot_too_old age_minutes={0} max_minutes={1}" -f $ageMinutes, $MaxAgeMinutes)
}

Write-Host ("status=ok snapshot_age_minutes={0} max_age_minutes={1}" -f $ageMinutes, $MaxAgeMinutes)
exit 0
