# QUA-95 Canonical Snapshot Runner Proof (2026-04-27)

Runner:
- `infra/scripts/Run-QUA95CanonicalSnapshot.ps1`

## Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Run-QUA95CanonicalSnapshot.ps1
```

## Observed output highlights

```text
disposition=defer
verify_exit_code=1
isolated_custom_bars_visibility_failure=True
status=ok task=QM_QUA95_TaskHealth_15min
Infra audit completed: status=critical, checks=27, issues=2
status=ok qua95_issues=0 non_qua95_issues=2
status=ok flow=qua95_canonical_snapshot
```

## Notes

- This runner executes:
  1. `Run-QUA95DirectVerifierProof.ps1`
  2. `Run-QUA95CustomVisibilityProof.ps1`
  3. `Invoke-QUA95BlockedHeartbeat.ps1`
  4. `Test-QUA95HeartbeatCustomVisibility.ps1`
  5. `Test-QUA95TaskHealthActionWiring.ps1`
  6. `Update-QUA95OpsBundleManifest.ps1`
  7. `Test-QUA95OpsBundleManifest.ps1`
- It is the preferred one-command path for producing a post-run manifest-consistent QUA-95 blocked-state artifact set.
