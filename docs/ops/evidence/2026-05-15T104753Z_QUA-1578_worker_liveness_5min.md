# QUA-1578 5-Min Worker Liveness Evidence (2026-05-15T104753Z)

## What changed in this heartbeat
1. Fixed S4U runtime resolution issue (LastTaskResult=2147942402) by switching task XML command from python to __PYTHON_EXE__ placeholder and injecting absolute path at registration.
2. Updated installer ramework/scripts/register_mt5_workers.ps1 to resolve Python executable and replace __PYTHON_EXE__ when rendering XML.
3. Re-registered QM_MT5_Worker_T1..T5 (+ QM_GateEvaluator_5min) with delete+recreate semantics.
4. Initialized queue schema on existing DB (jobs, worker_heartbeat) via queue_init.py to resolve legacy-only DB drift (mt5_job_queue table was present without worker tables).

## Verification commands
- python C:/QM/repo/framework/scripts/queue_init.py --sqlite D:/QM/reports/pipeline/mt5_queue.db
- powershell -NoProfile -ExecutionPolicy Bypass -File C:/QM/repo/framework/scripts/register_mt5_workers.ps1 -RepoRoot C:/QM/repo
- Start tasks and wait >5 min, then query:
  - SELECT terminal_id,last_seen_utc,pid,current_job_id,jobs_completed,last_error FROM worker_heartbeat ORDER BY terminal_id
  - Get-ScheduledTask QM_MT5_Worker_T*
  - Get-ScheduledTaskInfo QM_MT5_Worker_T1..T5

## 5-minute liveness snapshot (UTC)
worker_heartbeat rows: 5
- T1: last_seen_utc=2026-05-15T10:47:03Z, age_sec=25, pid=9928, current_job_id=NULL, jobs_completed=0, last_error=""
- T2: last_seen_utc=2026-05-15T10:47:03Z, age_sec=25, pid=22884, current_job_id=NULL, jobs_completed=0, last_error=""
- T3: last_seen_utc=2026-05-15T10:47:04Z, age_sec=24, pid=13812, current_job_id=NULL, jobs_completed=0, last_error=""
- T4: last_seen_utc=2026-05-15T10:47:03Z, age_sec=25, pid=3668, current_job_id=NULL, jobs_completed=0, last_error=""
- T5: last_seen_utc=2026-05-15T10:47:03Z, age_sec=25, pid=24976, current_job_id=NULL, jobs_completed=0, last_error=""

## Scheduled task snapshot
- QM_MT5_Worker_T1..T5 present.
- Trigger repeat interval: every 1 minute on all 5.
- Run As User: qm-admin.
- Task action uses absolute Python path: C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe framework/scripts/mt5_worker.py --terminal Tn.

## Hard-rule check
- No QM_MT5_Worker_T6 created.

## Note
- LastTaskResult currently reports 267009 while liveness rows are healthy; this requires follow-up semantic decode against Task Scheduler result mapping but does not block heartbeat proof (fresh rows within 25s across all T1-T5).

## Next action
- Run one queued smoke/baseline job to validate jobs_completed increments and end-to-end claim/execution transition under scheduled-task runtime.
