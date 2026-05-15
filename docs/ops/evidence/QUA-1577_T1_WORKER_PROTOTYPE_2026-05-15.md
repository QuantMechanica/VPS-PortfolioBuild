# QUA-1577 T1 Worker Prototype Evidence (2026-05-15)

## 1) T6 refusal contract

Command:

```powershell
python framework/scripts/mt5_worker.py --terminal T6 --sqlite .scratch/qua1577_worker_proto.db --once
```

Observed:

- stdout line: `[REFUSED] T6 is OFF LIMITS`
- JSON: `{"status":"error","reason":"terminal_out_of_policy","terminal":"T6"}`
- exit code: `2`

## 2) Manual T1 single-worker prototype against dummy queue row

Commands:

```powershell
python framework/scripts/queue_init.py --sqlite .scratch/qua1577_worker_proto2.db
# insert one queued dummy job (missing setfile path)
python framework/scripts/mt5_worker.py --terminal T1 --sqlite .scratch/qua1577_worker_proto2.db --once
```

Observed worker output:

```json
{"job_id":"job-a","reason":"deploy_missing:C:\\QM\\repo\\.scratch\\missing_a.set","status":"failed","terminal":"T1"}
```

DB verification:

```sql
SELECT job_id,status,claimed_by,verdict,invalidation_reason FROM jobs;
```

Result:

- `job-a | failed | T1 | INVALID | deploy_missing:C:\QM\repo\.scratch\missing_a.set`

This confirms claim + write-back path for the T1 prototype in `--once` mode.
