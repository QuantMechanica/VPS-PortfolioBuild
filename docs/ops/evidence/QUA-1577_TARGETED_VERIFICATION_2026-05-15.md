# QUA-1577 Targeted Verification (2026-05-15)

Command run:

```powershell
python -m unittest framework/scripts/tests/test_qua1577_worker_pool.py
```

Observed:

- `Ran 2 tests ... OK`

Coverage in this test module:

1. Queue schema bootstrap creates `jobs` and `worker_heartbeat`.
2. Required job indexes exist: `idx_jobs_status`, `idx_jobs_claimed_by` (partial), `idx_jobs_dedup`.
3. `mt5_worker.py --terminal T6` returns exit code `2` and prints `[REFUSED] T6 is OFF LIMITS`.
