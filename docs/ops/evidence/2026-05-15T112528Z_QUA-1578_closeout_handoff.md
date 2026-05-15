# QUA-1578 Closeout Handoff (2026-05-15T112528Z)

## Current runtime status
- Worker tasks QM_MT5_Worker_T1..T5: all Running
- Heartbeat rows: 5/5 fresh (ge_sec ~13s)
- current_job_id: NULL on all terminals
- jobs_completed: T1=2, T2=0, T3=0, T4=0, T5=0

## Scheduler result code note
- LastTaskResult currently 2147946720 on T1..T5 while tasks are Running and heartbeats are fresh.
- This is consistent with minute-trigger attempts while an instance is already active (MultipleInstancesPolicy=IgnoreNew) and does not indicate worker failure in this configuration.

## Implemented artifacts
- ramework/ops/scheduled_tasks/QM_MT5_Worker_T1.xml
- ramework/ops/scheduled_tasks/QM_MT5_Worker_T2.xml
- ramework/ops/scheduled_tasks/QM_MT5_Worker_T3.xml
- ramework/ops/scheduled_tasks/QM_MT5_Worker_T4.xml
- ramework/ops/scheduled_tasks/QM_MT5_Worker_T5.xml
- ramework/scripts/register_mt5_workers.ps1
- ramework/scripts/mt5_worker.py (EA id parse fix)

## Evidence chain
- 2026-05-15T104753Z_QUA-1578_worker_liveness_5min.md
- 2026-05-15T110800Z_QUA-1578_single_job_e2e_proof.md
- 2026-05-15T111638Z_QUA-1578_scheduled_runtime_stuck_writeback.md
- 2026-05-15T111832Z_QUA-1578_scheduled_writeback_fix_verified.md
- 2026-05-15T112438Z_QUA-1578_final_acceptance_snapshot.md

## Hard rule
- No T6 worker/task created.
