# QUA-95 Infra Audit Integration Proof (2026-04-27)

Issue: `QUA-95`  
Scope: confirm blocker task health, task-health action wiring, combined automation health, issue-transition payload consistency, blocked invariant enforcement, handoff integrity, blocked assertion freshness, unblock-readiness freshness, audit-signal consistency, direct-verifier proof consistency, canonical-snapshot consistency, ops-bundle manifest integrity, and blocked-heartbeat wrapper validation are present in central infra audit output.

## Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Invoke-InfraAudit.ps1
```

Observed run output:

```text
Infra audit completed: status=critical, checks=13, issues=2
Report: C:\QM\repo\infra\reports\infra_audit_latest.json
```

Latest integration run:

```text
Infra audit completed: status=critical, checks=25, issues=2
Report: C:\QM\repo\infra\reports\infra_audit_latest.json
```

## Extracted check entries

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

```json
{
  "name": "qua95_task_health_action_wiring",
  "status": "ok",
  "meta": {
    "task_name": "QM_QUA95_TaskHealth_15min"
  }
}
```

```json
{
  "name": "qua95_automation_health",
  "status": "ok",
  "meta": {
    "exit_code": 0
  }
}
```

```json
{
  "name": "qua95_transition_payload_consistency",
  "status": "ok",
  "meta": {
    "exit_code": 0
  }
}
```

```json
{
  "name": "qua95_blocked_invariant",
  "status": "ok",
  "meta": {
    "exit_code": 0
  }
}
```

```json
{
  "name": "qua95_handoff_integrity",
  "status": "ok",
  "meta": {
    "exit_code": 0
  }
}
```

```json
{
  "name": "qua95_blocked_assertion_freshness",
  "status": "ok",
  "meta": {
    "lag_minutes": 0.31
  }
}
```

```json
{
  "name": "qua95_unblock_readiness_freshness",
  "status": "ok",
  "meta": {
    "exit_code": 0
  }
}
```

```json
{
  "name": "qua95_audit_signal",
  "status": "ok",
  "meta": {
    "exit_code": 0
  }
}
```

```json
{
  "name": "qua95_direct_verifier_proof",
  "status": "ok",
  "meta": {
    "exit_code": 0
  }
}
```

```json
{
  "name": "qua95_canonical_snapshot",
  "status": "ok",
  "meta": {
    "exit_code": 0
  }
}
```

```json
{
  "name": "qua95_ops_bundle_manifest",
  "status": "ok",
  "meta": {
    "exit_code": 0
  }
}
```

```json
{
  "name": "qua95_blocked_heartbeat_wrapper",
  "status": "ok",
  "meta": {
    "exit_code": 0
  }
}
```

## Interpretation

- QUA-95 scheduler health, task-health action wiring, combined automation health, transition payload consistency, blocked invariant enforcement, handoff integrity, blocked assertion freshness, unblock-readiness freshness, audit-signal consistency, direct-verifier proof consistency, canonical-snapshot consistency, ops-bundle manifest integrity, and blocked-heartbeat wrapper validation are now audited in the same report as disk, terminal liveness, Drive sync, and stale index-lock checks.
- The audit can stay overall `critical` for unrelated checks while QUA-95 task health remains independently visible as `ok`.
- Latest run shows all QUA-95 checks `ok`; the remaining audit issues are outside QUA-95 scope.
