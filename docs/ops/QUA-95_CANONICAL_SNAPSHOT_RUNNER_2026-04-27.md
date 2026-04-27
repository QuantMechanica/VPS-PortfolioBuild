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
Infra audit completed: status=critical, checks=22, issues=2
status=ok qua95_issues=0 non_qua95_issues=2
status=ok flow=qua95_canonical_snapshot
```

## Notes

- This runner executes:
  1. `Invoke-QUA95BlockedHeartbeat.ps1`
  2. `Update-QUA95OpsBundleManifest.ps1`
  3. `Test-QUA95OpsBundleManifest.ps1`
- It is the preferred one-command path for producing a post-run manifest-consistent QUA-95 blocked-state artifact set.
