# QUA-95 Blocked Automation Runbook (2026-04-27)

Issue: `QUA-95`  
State target: keep `blocked/defer` synchronized and auditable until acceptance is met.

## Primary command

Canonical snapshot (recommended single command):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Run-QUA95CanonicalSnapshot.ps1
```

This command runs blocked-heartbeat, then forces ops-bundle manifest resync and validation to avoid post-heartbeat drift.

## Diagnostic commands

Refresh pipeline (single run):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Run-QUA95BlockerRefresh.ps1
```

Blocked heartbeat (refresh + audit + assertion sync + ops-suite snapshot):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Invoke-QUA95BlockedHeartbeat.ps1
```

Infra audit:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Invoke-InfraAudit.ps1
```

Ops suite snapshot:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Write-QUA95OpsSuiteSnapshot.ps1
```

Direct verifier proof (acceptance-focused evidence):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Run-QUA95DirectVerifierProof.ps1
```

## Monitoring checks

Blocker task health:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\monitoring\Test-QUA95BlockerTaskHealth.ps1 -MaxAgeMinutes 125
```

Blocked-heartbeat wrapper validator (non-recursive default):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\monitoring\Test-QUA95BlockedHeartbeatWrapper.ps1
```

## Canonical artifacts

- `docs/ops/QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json`
- `docs/ops/QUA-95_GATE_DECISION_2026-04-27.json`
- `docs/ops/QUA-95_ISSUE_TRANSITION_PAYLOAD_2026-04-27.json`
- `docs/ops/QUA-95_BLOCKED_STATE_ASSERTION_2026-04-27.md`
- `docs/ops/QUA-95_BLOCKED_HEARTBEAT_2026-04-27.json`
- `docs/ops/QUA-95_OPS_SUITE_2026-04-27.json`

## Unblock owners

1. `runtime_custom_symbol_owner`
- Restore `XTIUSD.DWX` M1 bars visibility (`copy_rates_range` / `copy_rates_from_pos` non-zero).

2. `verifier_implementation_owner`
- Re-run verifier post-runtime fix and prove `bars_got > 0` with aligned tail.
