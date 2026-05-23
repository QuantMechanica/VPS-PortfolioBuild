# Windows Scheduled Tasks — Cull List

**Date:** 2026-05-09
**Author:** Board Advisor
**Trigger:** HoP+CTO keepalive loop on QUA-712/fa0c3fa3 burned ~2h of Codex+Claude tokens. Investigation surfaced 30+ `QM_*` Windows scheduled tasks; several reference closed/cancelled QUA issues but still fire every 15-60 min.

## Inventory

Full inventory: `docs/ops/windows_tasks_inventory_2026-05-09.json` (31 `QM_*` tasks).

## Cull list (6 tasks firing for closed/cancelled work)

| Task | QUA-Ref | Issue Status | Last Run | Action |
|------|---------|--------------|----------|--------|
| `QM_QUA207_RuntimeHeartbeat_30min` | QUA-207 | **done** | 2026-05-09 21:04 | **Disable** |
| `QM_QUA774_ExternalUnblockOpsSuite_60min` | QUA-774 | **cancelled** | 2026-05-09 20:36 | **Disable** |
| `QM_QUA774_ExternalUnblockStatus_60min` | QUA-774 | **cancelled** | 2026-05-09 20:31 | **Disable** |
| `QM_QUA95_TaskHealth_15min` | QUA-95 | **done** | 2026-05-09 21:02 (lastresult=2 fail) | **Disable** |
| `QM_QUA1016_OpsCycle_15min` | QUA-1016 | **done** | 2026-05-09 21:01 | **Disable** |
| `QM_QUA1023_OpsCycle_15min` | QUA-1023 | **done** | 2026-05-09 21:01 | **Disable** |

Combined firing-load cut: ~5 invocations / 15 min = ~480 cron-driven Paperclip API hits per day removed.

## Keep (referenced issue still open)

| Task | QUA-Ref | Status |
|------|---------|--------|
| `QM_QUA1006_OpsCycle_15min` | QUA-1006 | in_review |
| `QM_QUA945_BlockedHeartbeat_30min` | QUA-945 | blocked |

These can stay for now but should be re-evaluated once their referenced issues close.

## How to disable (DevOps)

```powershell
@(
  'QM_QUA207_RuntimeHeartbeat_30min',
  'QM_QUA774_ExternalUnblockOpsSuite_60min',
  'QM_QUA774_ExternalUnblockStatus_60min',
  'QM_QUA95_TaskHealth_15min',
  'QM_QUA1016_OpsCycle_15min',
  'QM_QUA1023_OpsCycle_15min'
) | ForEach-Object { Disable-ScheduledTask -TaskName $_ -ErrorAction Continue }
```

`Disable-ScheduledTask` is reversible — task definitions remain, only execution stops. Safer than `Unregister-ScheduledTask`.

## Process recommendation

When a QUA issue closes, the closeout step should include `Disable-ScheduledTask` for any `QM_QUA<N>_*` tasks created for it. Add to closeout checklist (CEO + Doc-KM territory).

Alternatively, codify under DL-062 (Single Wake Source) — see `decisions/2026-05-09_DL-062_single_wake_source.md`.
