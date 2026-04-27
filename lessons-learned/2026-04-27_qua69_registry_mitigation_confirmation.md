# 2026-04-27 - QUA-69 registry mitigation confirmation

Issue link: `QUA-69` (`DEVOPS-009`)

## What was added

- New idempotent evidence script:
  - `infra/scripts/Confirm-DwxRegistryMitigation.ps1`
- New machine-readable evidence artifact:
  - `lessons-learned/evidence/qua69_registry_mitigation_confirmation.json`

## Command

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Confirm-DwxRegistryMitigation.ps1 -FailOnInsufficientEvidence
```

## Current result (run on 2026-04-27)

- `verdict=pass`
- successful terminal close events (`Fix_DWX_Spec_v3`) = `6` (threshold `>=3`)
- throttling markers (`BATCH|processed=5|sleep_ms=200`) = `28`
- `symbols.custom.dat` size = `20480` bytes (safe floor `16384`)
- baseline corrupted backup (`symbols.custom.dat.bak.before-recovery.20260426`) remains `8192` bytes for forensic contrast

## Notes

- This confirms the mitigation pattern is active and non-truncated on current logs/state.
- If future runs ever pass below safe size or evidence count, the script exits non-zero with `-FailOnInsufficientEvidence`; escalate to MetaQuotes per the incident lesson.
