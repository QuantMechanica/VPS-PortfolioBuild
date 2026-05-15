# QUA-1587 acceptance rerun evidence (2026-05-15)

Objective: prove post-fix worker-pool path can reach `status=done` with populated `summary.json` result path.

## Commands

1) Create fresh queue DB + one queued job (QM5_1001 smoke)

```powershell
python - <<'PY'
import sqlite3, uuid
from pathlib import Path
from framework.scripts.queue_init import ensure_schema
name=f'qua1587_done_proof_{uuid.uuid4().hex[:8]}.db'
p=Path(r'C:\QM\repo\.scratch')/name
conn=sqlite3.connect(str(p)); ensure_schema(conn)
conn.execute("""
INSERT INTO jobs(job_id,ea_id,version,symbol,period,year,phase,sub_gate_config_hash,setfile_path,status,retry_count,enqueued_at,enqueued_by)
VALUES(?,?,?,?,?,?,?,?,?,'queued',0,strftime('%Y-%m-%dT%H:%M:%SZ','now'),'manual_proof')
""",('qua1587-proof-1','QM5_1001','v1','EURUSD.DWX','H1',2024,'P1','qua1587_doneproof_20260515T1122Z',r'C:/QM/repo/framework/tests/smoke/QM5_1001_framework_smoke.set'))
conn.commit(); print(p)
PY
```

2) Run worker once

```powershell
python C:\QM\repo\framework\scripts\mt5_worker.py \
  --terminal T5 \
  --sqlite "C:\QM\repo\.scratch\qua1587_done_proof_5bfbb220.db" \
  --report-root "D:\QM\reports\pipeline\qua1587_done_proof" \
  --timeout-seconds 60 \
  --once
```

## Worker stdout

```json
{"job_id": "qua1587-proof-1", "status": "done", "terminal": "T5", "verdict": "FAIL"}
```

## Queue DB row (post-run)

DB: `C:\QM\repo\.scratch\qua1587_done_proof_5bfbb220.db`

```json
{
  "job_id": "qua1587-proof-1",
  "status": "done",
  "verdict": "FAIL",
  "invalidation_reason": "run_smoke_fail",
  "result_path": "D:\\QM\\reports\\pipeline\\qua1587_done_proof\\QM5_1001\\20260515_111428\\summary.json",
  "finished_at": "2026-05-15T11:16:28Z"
}
```

This satisfies the acceptance requirement: at least one worker job reaches `done` with a summary path.
