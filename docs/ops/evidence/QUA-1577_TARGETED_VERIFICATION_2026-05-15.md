# QUA-1577 Targeted Verification (2026-05-15)

Command run:

```powershell
python -m unittest framework/scripts/tests/test_qua1577_worker_pool.py
```

Observed:

- `Ran 5 tests ... OK`

Coverage in this test module:

1. Queue schema bootstrap creates `jobs` and `worker_heartbeat`.
2. Required job indexes exist: `idx_jobs_status`, `idx_jobs_claimed_by` (partial), `idx_jobs_dedup`.
3. `mt5_worker.py --terminal T6` returns exit code `2` and prints `[REFUSED] T6 is OFF LIMITS`.
4. `mt5_worker.py --once` claims a queued row and writes failed verdict metadata back to SQLite (`status=failed`, `claimed_by=T1`, `verdict=INVALID`) in a deterministic temp MT5 root harness.
5. Atomic claim ordering: with two queued rows (`job-oldest`, `job-newer`) and one `--once` execution, only `job-oldest` is claimed/processed; `job-newer` remains `queued`.
6. Schema contract pinning: `PRAGMA table_info` verifies exact column order/names for both `jobs` and `worker_heartbeat`.
