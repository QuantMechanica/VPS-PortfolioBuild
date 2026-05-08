param(
    [string]$EaDir = "C:\QM\repo\framework\EAs\QM5_SRC04_S03_lien_fade_double_zeros"
)

$ErrorActionPreference = "Stop"

$required = @(
    "QM-00011_CTO_REVIEW_PASS_2026-05-05.md",
    "QUA-743_EVIDENCE_INDEX_2026-05-05.md",
    "ZT_RootCause_QM5_SRC04_S03_20260505.md",
    "QUA-743_ZT_COHORT_EVIDENCE_20260505.csv",
    "QUA-743_ZT_RECOVERY_SIGNOFF_PACKET_2026-05-05.md",
    "QUA-743_ZT_SIGNOFF_DECISION_FORM_2026-05-05.md",
    "QUA-743_V2_BUILD_READY_CHANGE_SPEC_2026-05-05.md",
    "QUA-743_V2_POST_APPROVAL_RUNBOOK_2026-05-05.md",
    "QUA-743_STATUS_SNAPSHOT_2026-05-05.json",
    "QUA-743_WAITING_SIGNOFF_2026-05-05.md"
)

$missing = @()
foreach ($name in $required) {
    $p = Join-Path $EaDir $name
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) {
        $missing += $name
    }
}

if ($missing.Count -gt 0) {
    Write-Output "status=FAIL"
    Write-Output ("missing_count={0}" -f $missing.Count)
    $missing | ForEach-Object { Write-Output ("missing={0}" -f $_) }
    exit 1
}

Write-Output "status=PASS"
Write-Output ("checked_count={0}" -f $required.Count)
