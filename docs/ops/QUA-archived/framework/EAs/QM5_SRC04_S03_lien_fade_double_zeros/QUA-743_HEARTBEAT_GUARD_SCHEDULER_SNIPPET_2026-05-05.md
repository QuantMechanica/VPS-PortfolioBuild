## QUA-743 Heartbeat Guard Scheduler Snippet

Purpose:
- Keep blocked-state evidence fresh while waiting on R-and-D/CEO approvals.

Guard script:
- `C:/QM/repo/framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/run_qua743_heartbeat_guard.ps1`

### Windows Task Scheduler (hourly) — command snippet

```powershell
schtasks /Create /TN "QUA-743-Heartbeat-Guard" /SC HOURLY /MO 1 /TR "pwsh -NoProfile -File C:\QM\repo\framework\EAs\QM5_SRC04_S03_lien_fade_double_zeros\run_qua743_heartbeat_guard.ps1" /F
```

### Manual one-shot run

```powershell
pwsh -NoProfile -File C:\QM\repo\framework\EAs\QM5_SRC04_S03_lien_fade_double_zeros\run_qua743_heartbeat_guard.ps1
```

### Expected outputs

- `QUA-743_STATUS_SNAPSHOT_2026-05-05.json` refreshed
- `QUA-743_HEARTBEAT_AUDIT_LOG_2026-05-05.md` appended
- validator/hash verifier must both remain `PASS`
