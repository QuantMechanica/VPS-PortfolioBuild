# QUA-1540 Production Run-Liveness Evidence (2026-05-15T04:44:11Z)

## Actions
1. Enqueued one real row into production queue DB:
   - `python C:/QM/repo/framework/scripts/mt5_queue_enqueue.py --sqlite D:/QM/reports/pipeline/mt5_queue.db --job-json C:/QM/repo/.scratch/qua1540/job_qua1540_prod.json`
2. Ran production adapter tick (non-dry):
   - `python C:/QM/paperclip/tools/ops/multi_ea_scheduler.py --once --evidence-out D:/QM/reports/pipeline/mt5_saturation_scheduler_summary_prod_20260515_liveness1_retry.json`

## Results
- Scheduler summary:
  - `status=ok`
  - `dry_run=false`
  - `queued_scanned=1`
  - `scheduled=1`
  - `queue_delta={queued:-1, dispatched:+1}`
- Post-tick DB state (`D:/QM/reports/pipeline/mt5_queue.db`):
  - `counts={"dispatched":1}`
  - row `id=1` moved to `status=dispatched`
  - `assigned_terminal=T2`
  - `dispatch_decision=scheduled`
  - `dedup_key=QM5_1003|v1|EURUSD.DWX|P2|cfg_qua1540_live_20260515`

## Additional fix applied
- Normalized malformed `dispatch_state.json` shape in adapter before dispatch tick (`recent_runs` list -> dict) to prevent runtime crash.
