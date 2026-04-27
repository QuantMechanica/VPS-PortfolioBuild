# QUA-95 Infra Audit Integration Proof (2026-04-27)

Issue: `QUA-95`  
Scope: confirm `QM_QUA95_BlockerRefresh` health is present in central infra audit output.

## Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Invoke-InfraAudit.ps1
```

Observed run output:

```text
Infra audit completed: status=critical, checks=13, issues=2
Report: C:\QM\repo\infra\reports\infra_audit_latest.json
```

## Extracted check entry

From `infra/reports/infra_audit_latest.json`:

```json
{
  "name": "qua95_blocker_task_health",
  "status": "ok",
  "meta": {
    "task_name": "QM_QUA95_BlockerRefresh",
    "max_age_minutes": 125,
    "exit_code": 0
  }
}
```

## Interpretation

- QUA-95 scheduler health is now audited in the same report as disk, terminal liveness, Drive sync, and stale index-lock checks.
- The audit can stay overall `critical` for unrelated checks while QUA-95 task health remains independently visible as `ok`.
