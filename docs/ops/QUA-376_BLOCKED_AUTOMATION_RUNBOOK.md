# QUA-376 Blocked Automation Runbook

Last updated: 2026-04-28
Scope: blocked-phase operational maintenance for `QUA-376 SRC05_S01` until CTO/Dev delivers strategy binary + registry activation.

## Canonical One-Command Refresh

```powershell
.\infra\scripts\Run-QUA376BlockedBundle.ps1 -EmitTimestampedTick
```

Outputs produced in `docs/ops/`:
- `QUA-376_HEARTBEAT_TICK_<timestamp>.json`
- `QUA-376_ISSUE_STATUS_UPDATE_2026-04-28.json`
- `QUA-376_BLOCKED_COMMENT_2026-04-28.md`
- `QUA-376_BLOCKER_WATCH_<timestamp>.json`

## Component Scripts

1. `infra/scripts/Write-QUA376HeartbeatTick.ps1`
- Emits heartbeat state snapshot (queue depth, terminal health, readiness, ack counts, unblock owner/action).

2. `infra/scripts/Run-QUA376BlockedBundle.ps1`
- Runs the tick script and refreshes blocked issue artifacts.
- Also emits blocker-watch JSON (binary presence + active registry check).

3. `infra/scripts/Invoke-QUA376ProxyPairReadiness.ps1`
- Runs proxy-pair readiness preflight (`XAUUSD.DWX` / `XTIUSD.DWX`) with isolated terminal handling and dedup-safe nonce configs.
- Writes `artifacts/qua-376/proxy_pair_readiness.json`.

## When CTO/Dev Reports Unblock Completed

1. Validate binary + registry claims with blocker watch:
```powershell
.\infra\scripts\Run-QUA376BlockedBundle.ps1 -EmitTimestampedTick
```

2. Validate readiness remains `ready`:
```powershell
.\infra\scripts\Invoke-QUA376ProxyPairReadiness.ps1
Get-Content artifacts\qua-376\proxy_pair_readiness.json -Raw
```

3. If binary present on T1-T5 and registry active, transition issue from blocked and execute first pair-mapped queue run per:
- `docs/ops/QUA-376_FIRST_PAIR_RUN_REQUEST_2026-04-28.json`
- `docs/ops/QUA-376_OWNER_COMPLETION_CHECKLIST_2026-04-28.md`

## Unblock Dependency (Authoritative)

- Owner: `CTO/Dev`
- Required action: deploy `QM5_SRC05_S01_chan_at_bb_pair.ex5` to T1-T5 and activate matching registry row.
