# QUA-1578 Scheduled Write-Back Fix Verified (2026-05-15T111832Z)

## Root cause
Worker task XML used ExecutionTimeLimit=PT59S, which could terminate long worker cycles before DB finalization (mark_done / mark_failed). This caused rows to remain status='running' despite artifacts on disk.

## Fix applied
- Updated worker task XML definitions QM_MT5_Worker_T1..T5:
  - ExecutionTimeLimit: PT59S -> PT0S (disabled/no time limit)
- Re-registered tasks via:
  - ramework/scripts/register_mt5_workers.ps1
- Cleaned stale running row from prior failed proof:
  - job_id=f6b248d8-d5c0-4395-b0ae-3760cdf19f75 -> marked ailed with reason stale_running_cleanup_after_exec_limit_fix

## Scheduled-runtime proof (post-fix)
Inserted fresh queued job:
- job_id=cb284374-aa7b-448b-bd73-3a3c38da23ca

Observed transitions under Scheduled Task runtime:
1. queued
2. unning (claimed_by=T1, claimed_at=2026-05-15T11:18:01Z)
3. done (erdict=FAIL, invalidation_reason=run_smoke_fail, inished_at=2026-05-15T11:18:15Z)

Result artifact:
- D:\QM\reports\pipeline\QM5_1003\20260515_111802\summary.json

Heartbeat counter verification:
- Before: T1 jobs_completed=1
- After: T1 jobs_completed=2

This confirms claim/run/write-back and heartbeat increment work under scheduled-task runtime after the fix.

## Hard rule
- No T6 task created or modified.
