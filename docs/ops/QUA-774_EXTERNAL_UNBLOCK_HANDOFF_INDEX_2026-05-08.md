# QUA-774 External Unblock Handoff Index (2026-05-08)

## Current state

- Issue: `QUA-774`
- Status: `blocked`
- Failure flags: `REPORT_MISSING;INCOMPLETE_RUNS`
- Blocked unblock owner: `DWX source acquisition + import pipeline owner`

## Canonical handoff command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Invoke-QUA774ExternalUnblockHandoff.ps1
```

Expected while blocked:
- `package_check.status = ok`
- `signal_check.status = waiting_external_signal`

## Handoff artifact set

- `docs/ops/QUA-774_EXTERNAL_UNBLOCK_SIGNAL.json`
- `docs/ops/QUA-774_EXTERNAL_UNBLOCK_CHILD_PAYLOAD_2026-05-08.json`
- `docs/ops/QUA-774_EXTERNAL_UNBLOCK_ESCALATION_2026-05-08.md`
- `docs/ops/QUA-774_BLOCKED_HEARTBEAT_RUNBOOK_2026-05-08.md`

## External unblock checklist

1. Import `US500.DWX` history/ticks into `T1`.
2. Sync `US500.DWX` from `T1` to `T2..T5`.
3. Re-run `QM5_1004` P2 and produce `H1/H4/D1` reports.
4. Set `docs/ops/QUA-774_EXTERNAL_UNBLOCK_SIGNAL.json` -> `ready_to_resume=true`.
5. Trigger guarded heartbeat:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Invoke-QUA774BlockedHeartbeat.ps1 -RequireExternalSignal
```
