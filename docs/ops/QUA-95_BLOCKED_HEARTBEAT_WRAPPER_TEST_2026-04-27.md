# QUA-95 Blocked Heartbeat Wrapper Test (2026-04-27)

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\monitoring\Test-QUA95BlockedHeartbeatWrapper.ps1
```

Observed output:

```text
status=ok gate_state=blocked audit_status=critical checks_count=21 automation_health=ok qua95_issues=1 non_qua95_issues=2
```

Notes:
- Test runs `Invoke-QUA95BlockedHeartbeat.ps1` with `-SkipRefresh -SkipAudit` to avoid recursive audit invocation.
- Pass `-RunRefresh` to include refresh execution in validator runs when needed.
- Validates consolidated heartbeat JSON fields:
  - `issue == QUA-95`
  - gate section exists and `recommended_state == blocked`
  - `bars_got == 0`
  - `tail_shortfall_seconds > 0`
  - infra audit section exists and has `overall_status`
  - automation-health artifact exists and is `overall_status == ok`
  - audit-signal artifact exists and has valid QUA-95/non-QUA95 issue counts.
