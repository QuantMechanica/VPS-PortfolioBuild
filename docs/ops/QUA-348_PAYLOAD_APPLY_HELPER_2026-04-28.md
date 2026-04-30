# QUA-348 Payload Apply Helper (2026-04-28)

Use this helper to finalize manifest fields and run both validators in one step.

Script:
- `artifacts/qua-348/apply_src04_s09_payload.ps1`

Dry-run preflight (no manifest changes):
```powershell
& C:\QM\repo\artifacts\qua-348\apply_src04_s09_payload.ps1 \
  -EAName "QM5_1234_lien_perfect_order" \
  -SetfilePath "framework/EAs/QM5_1234_lien_perfect_order/sets/QM5_1234_EURUSD.DWX_D1_backtest.set" \
  -DryRun
```

Apply + validate:
```powershell
& C:\QM\repo\artifacts\qua-348\apply_src04_s09_payload.ps1 \
  -EAName "QM5_1234_lien_perfect_order" \
  -SetfilePath "framework/EAs/QM5_1234_lien_perfect_order/sets/QM5_1234_EURUSD.DWX_D1_backtest.set" \
  -FromDate "2017.01.01" \
  -ToDate "2022.12.31"
```

Outputs refreshed by apply:
- `artifacts/qua-348/src04_s09_build_handoff_validation.json`
- `artifacts/qua-348/src04_s09_readiness_latest.json`
