# QUA-1578 Final Acceptance Snapshot (2026-05-15T112438Z)

## Scope checkpoint
- Worker scheduled tasks: QM_MT5_Worker_T1..T5
- Cadence: every 1 minute
- RunAs: qm-admin (S4U)
- T6 untouched

## Verification step 1 (t0)
- Get-ScheduledTask QM_MT5_Worker_T*:
  - T1 Running
  - T2 Running
  - T3 Running
  - T4 Running
  - T5 Running
- worker_heartbeat rows: 5
  - T1 age_sec=6
  - T2 age_sec=6
  - T3 age_sec=6
  - T4 age_sec=6
  - T5 age_sec=6

## Verification step 2 (t0 + 5m10s)
- Get-ScheduledTask QM_MT5_Worker_T*:
  - T1 Running
  - T2 Running
  - T3 Running
  - T4 Running
  - T5 Running
- worker_heartbeat rows: 5
  - T1 age_sec=9
  - T2 age_sec=23
  - T3 age_sec=23
  - T4 age_sec=23
  - T5 age_sec=23

## Acceptance mapping
1. Scheduled tasks exist and are healthy on T1..T5: PASS
2. After 5 minutes, heartbeats remain fresh for all terminals: PASS

## Related remediation already verified
- Worker task ExecutionTimeLimit fixed to PT0S to prevent forced termination before DB write-back.
- Scheduled-runtime proof job cb284374-aa7b-448b-bd73-3a3c38da23ca completed queued -> running -> done, with T1 jobs_completed increment from 1 to 2.

## Hard rule
- No QM_MT5_Worker_T6 definition created.
