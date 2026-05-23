# QUA-1540 Production Tick Evidence (2026-05-15T04:41:12Z)

Command:
`python C:/QM/paperclip/tools/ops/multi_ea_scheduler.py --once --evidence-out D:/QM/reports/pipeline/mt5_saturation_scheduler_summary_prod_20260515_2.json`

Pre-check on production DB `D:/QM/reports/pipeline/mt5_queue.db`:
- db_exists: true
- counts: {}
- queued_top: []
- dispatched_top: []

Result:
- scheduler_summary.status: ok
- scheduler_summary.dry_run: false
- queued_scanned: 0
- scheduled: 0
- queue_depth: 0

Unblock owner/action:
- Owner: upstream queue producer (CTO / Head-of-Pipeline dispatch producer)
- Action: enqueue real `status=queued` rows into `D:/QM/reports/pipeline/mt5_queue.db` and rerun same command.
