# QUA-522 Heartbeat Update (2026-04-29)

## Scope
- Issue: QUA-522 Child A (DevOps + CTO)
- Deliverable: `infra/scripts/Run-RuntimeHealthScan.ps1` runtime execution hardening for 15-min autonomous scan path.

## Code Commit
- `cd1c8aea` — `infra: harden runtime health scan output assembly`

## Verification
Command:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File infra\scripts\Run-RuntimeHealthScan.ps1 -PaperclipApiUrl http://127.0.0.1:1 -ApiKey dummy -CompanyId dummy -DryRun -OutputPath C:\QM\repo\infra\reports\runtime_health_scan_test.json
```

Result:
- exit code `0`
- output JSON emitted with:
  - `check = runtime_health_scan`
  - `overall_status = ok`
  - all 5 detector buckets present (`hot_poll`, `stuck_session`, `bottleneck`, `token_budget`, `recursive_wake`)

## Scheduler Wiring Check
- `infra/tasks/Register-QMInfraTasks.ps1` already converges task `QM_RuntimeHealthScan_15min` when `Run-RuntimeHealthScan.ps1` exists.
- `infra/scripts/Install-RuntimeHealthScanTask.ps1` tracked and available for direct idempotent task registration.
