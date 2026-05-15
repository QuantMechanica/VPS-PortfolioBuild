# QUA-1578 Worker Task Rollout Evidence (2026-05-15T103407Z)

## Scope
- Registered Scheduled Tasks: QM_MT5_Worker_T1 .. QM_MT5_Worker_T5
- Entry script: C:/QM/repo/framework/scripts/register_mt5_workers.ps1
- XML definitions: C:/QM/repo/framework/ops/scheduled_tasks/QM_MT5_Worker_T*.xml

## Runtime artifact check
- ramework/scripts/mt5_worker.py: present
- ramework/scripts/gate_evaluator.py: present

## Registration command
`powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:/QM/repo/framework/scripts/register_mt5_workers.ps1 -RepoRoot C:/QM/repo
`

## Verification snapshot
All worker tasks are present and State=Ready:
- QM_MT5_Worker_T1: Ready, Run As qm-admin, Repeat every 1 minute
- QM_MT5_Worker_T2: Ready, Run As qm-admin, Repeat every 1 minute
- QM_MT5_Worker_T3: Ready, Run As qm-admin, Repeat every 1 minute
- QM_MT5_Worker_T4: Ready, Run As qm-admin, Repeat every 1 minute
- QM_MT5_Worker_T5: Ready, Run As qm-admin, Repeat every 1 minute

## Notes
- Installer behavior changed to delete then recreate each task to guarantee trigger updates; plain /Create /F did not fully overwrite prior repeat metadata for T2-T5.
- No T6 task created.

## Next action
- Run 5-minute smoke verification and capture worker_heartbeat recency rows from D:/QM/reports/pipeline/mt5_queue.db for all T1-T5.
