param(
    [string]$EaId = "QM5_1014",
    [string]$EaLabel = "QM5_1014_lien_channels"
)

$ErrorActionPreference = 'Stop'

Write-Host "[QUA-1075] preflight P2 guard for $EaLabel"
python C:/QM/repo/framework/scripts/skill_p2_baseline_guard.py --ea-label $EaLabel
if ($LASTEXITCODE -ne 0) {
    Write-Host "[QUA-1075] STOP: P2 prerequisites not satisfied"
    exit $LASTEXITCODE
}

Write-Host "[QUA-1075] preflight P3 guard for $EaId"
python C:/QM/repo/framework/scripts/skill_p3_sweep_guard.py --ea-id $EaId
if ($LASTEXITCODE -ne 0) {
    Write-Host "[QUA-1075] STOP: P3 prerequisites not satisfied"
    exit $LASTEXITCODE
}

Write-Host "[QUA-1075] launch P3 sweep for $EaId"
python C:/QM/repo/framework/scripts/p3_param_sweep.py --ea $EaId
exit $LASTEXITCODE
