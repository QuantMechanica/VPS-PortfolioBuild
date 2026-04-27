# QUA-95 Blocked Heartbeat Wrapper Test (2026-04-27)

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\monitoring\Test-QUA95BlockedHeartbeatWrapper.ps1
```

Observed output:

```text
status=ok gate_state=blocked audit_status=critical checks_count=15
```

Notes:
- Test runs `Invoke-QUA95BlockedHeartbeat.ps1` with `-SkipRefresh -SkipAudit` to avoid recursive audit invocation.
- Validates consolidated heartbeat JSON fields:
  - `issue == QUA-95`
  - gate section exists and `recommended_state == blocked`
  - `bars_got == 0`
  - `tail_shortfall_seconds > 0`
  - infra audit section exists and has `overall_status`.
