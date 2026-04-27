param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$CandidateLog = 'C:\QM\repo\infra\smoke\verify_import_candidate_run_2026-04-27_091415_all_symbols.log'
)

$ErrorActionPreference = 'Stop'

$verifyScript = Join-Path $RepoRoot 'infra\scripts\Verify-HandoffIntegrity.ps1'
$summaryScript = Join-Path $RepoRoot 'infra\scripts\summarize_verify_candidate_log.py'

Write-Host "[1/2] Verifying handoff artifact integrity..."
powershell -NoProfile -ExecutionPolicy Bypass -File $verifyScript

Write-Host "[2/2] Summarizing candidate verifier log..."
python $summaryScript $CandidateLog
