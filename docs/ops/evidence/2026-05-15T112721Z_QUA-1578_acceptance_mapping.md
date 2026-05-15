# QUA-1578 Acceptance Mapping (2026-05-15T112721Z)

## Criterion 1
Get-ScheduledTask QM_MT5_Worker_T* shows 5 tasks healthy.

Observed now:
- QM_MT5_Worker_T1: Running
- QM_MT5_Worker_T2: Running
- QM_MT5_Worker_T3: Running
- QM_MT5_Worker_T4: Running
- QM_MT5_Worker_T5: Running

Result: PASS

## Criterion 2
After 5 minutes, worker_heartbeat stays fresh across T1..T5.

Evidence:
- Sustained 5-minute post-fix verification:
  - docs/ops/evidence/2026-05-15T112438Z_QUA-1578_final_acceptance_snapshot.md
- Closure-ready ping:
  - docs/ops/evidence/2026-05-15T112621Z_QUA-1578_closure_ready_ping.md

Current values (latest ping):
- T1 age_sec ~10, current_job_id=NULL, jobs_completed=2
- T2 age_sec ~10, current_job_id=NULL, jobs_completed=0
- T3 age_sec ~10, current_job_id=NULL, jobs_completed=0
- T4 age_sec ~10, current_job_id=NULL, jobs_completed=0
- T5 age_sec ~10, current_job_id=NULL, jobs_completed=0

Result: PASS

## Required implementation artifacts
- ramework/ops/scheduled_tasks/QM_MT5_Worker_T1.xml
- ramework/ops/scheduled_tasks/QM_MT5_Worker_T2.xml
- ramework/ops/scheduled_tasks/QM_MT5_Worker_T3.xml
- ramework/ops/scheduled_tasks/QM_MT5_Worker_T4.xml
- ramework/ops/scheduled_tasks/QM_MT5_Worker_T5.xml
- ramework/scripts/register_mt5_workers.ps1

Result: PASS

## Runtime correctness proof (scheduled-task path)
- Job cb284374-aa7b-448b-bd73-3a3c38da23ca transitioned queued -> running -> done.
- worker_heartbeat.T1.jobs_completed incremented 1 -> 2.
- Evidence: docs/ops/evidence/2026-05-15T111832Z_QUA-1578_scheduled_writeback_fix_verified.md

Result: PASS

## Hard rule
No QM_MT5_Worker_T6 task created/touched.

Result: PASS

## Closure recommendation
Pipeline-operator scope is complete and closure-ready.
