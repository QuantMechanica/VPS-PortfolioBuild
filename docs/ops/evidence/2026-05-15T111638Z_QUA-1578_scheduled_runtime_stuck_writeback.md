# QUA-1578 Scheduled Runtime Proof Attempt — Stuck Write-Back (2026-05-15T111638Z)

## Action executed
- Kept QM_MT5_Worker_T1..T5 running under Scheduled Tasks.
- Enqueued one fresh proof job in jobs table:
  - job_id=f6b248d8-d5c0-4395-b0ae-3760cdf19f75
  - a_id=QM5_1003, symbol=EURUSD.DWX, period=H1, year=2024
- Observed scheduler claim/run transition:
  - status=running, claimed_by=T1, claimed_at=2026-05-15T11:08:32Z

## Filesystem truth (artifacts present)
Under D:/QM/reports/pipeline/QM5_1003/20260515_110832:
- summary.json exists (LastWriteTime=2026-05-15 13:09:25)
- aw/run_01/report.htm and aw/run_02/report.htm exist
- aw/run_01/20260515.log and aw/run_02/20260515.log exist

## Tracker/DB truth mismatch
Despite artifacts present:
- jobs.status stayed unning for 6b248d8-d5c0-4395-b0ae-3760cdf19f75
- inished_at and esult_path remained NULL
- worker_heartbeat for T1 had current_job_id=NULL, jobs_completed=1 (no increment)

This is a filesystem-vs-tracker discrepancy requiring worker write-back handling fix.

## Additional intervention attempted
- Stopped T1 	erminal64.exe process once to unblock completion.
- Result: DB row still remained unning.

## Next action
- Unblock owner: Dev-Codex/CTO
- Required fix: in mt5_worker.py, enforce terminal subprocess timeout/exit handling and guaranteed final DB transition (done/ailed) when summary/report artifacts already exist.
- After patch, rerun one scheduled-task proof job and verify jobs_completed increments under scheduler runtime.
