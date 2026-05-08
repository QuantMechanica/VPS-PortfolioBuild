param(
    [string]$EaDir = "C:\QM\repo\framework\EAs\QM5_SRC04_S03_lien_fade_double_zeros",
    [string]$OutZip = "C:\QM\repo\artifacts\QUA-743_signoff_bundle_2026-05-05.zip"
)

$ErrorActionPreference = "Stop"

$files = @(
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

$paths = @()
foreach ($f in $files) {
    $p = Join-Path $EaDir $f
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) {
        throw "Missing required file: $p"
    }
    $paths += $p
}

$outDir = Split-Path -Parent $OutZip
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
if (Test-Path -LiteralPath $OutZip) {
    Remove-Item -LiteralPath $OutZip -Force
}

Compress-Archive -Path $paths -DestinationPath $OutZip -CompressionLevel Optimal -Force
Write-Output "bundle_created=$OutZip"
