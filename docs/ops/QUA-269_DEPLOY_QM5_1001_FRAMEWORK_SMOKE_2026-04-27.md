# QUA-269 T1 Smoke Expert Deploy (2026-04-27)

Status: done (idempotent deploy converged)

## Scope
- Issue: `QUA-269`
- Artifact: `C:\QM\repo\framework\tests\smoke\QM5_1001_framework_smoke.ex5`
- Destination: `D:\QM\mt5\T1\MQL5\Experts\QM\QM5_1001_framework_smoke.ex5`

## Execution
- Command:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Deploy-QM5SmokeExpertToT1.ps1 -EvidenceJsonPath C:\QM\repo\docs\ops\QUA-269_DEPLOY_QM5_1001_FRAMEWORK_SMOKE_2026-04-27.json`
- Result:
  - `status=unchanged`
  - `hash_match_after=true`
  - `sha256=2795DBEA6E49ED2CEA4DED4A03096BCFA40278F114689A83D030071920CB500B`
  - `deployed_at_local=2026-04-27T19:35:42.8391709+02:00`

## Notes
- Deployment path is already converged; no binary drift detected.
- Script refuses T6 targets by default.

## Next action
- Pipeline-Operator can run the Step 22 smoke rerun on T1 using `QM\\QM5_1001_framework_smoke`.
