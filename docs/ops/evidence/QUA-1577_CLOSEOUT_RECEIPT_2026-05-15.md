# QUA-1577 Closeout Receipt (2026-05-15)

Issue: QUA-1577
Scope: MT5 worker-pool step 1+2 (schema + queue_init + single-worker T1 prototype)

## Deliverables and Evidence Mapping

1. Queue schema bootstrap script implemented
- File: `framework/scripts/queue_init.py`
- Commit: `a99850b74`
- Contract: creates `jobs` + `worker_heartbeat` using idempotent `CREATE TABLE IF NOT EXISTS`, plus:
  - `idx_jobs_status`
  - `idx_jobs_claimed_by` (partial, `WHERE claimed_by IS NOT NULL`)
  - `idx_jobs_dedup`

2. Single-worker prototype implemented (`--terminal T1..T5`)
- File: `framework/scripts/mt5_worker.py`
- Commit: `a99850b74`
- Includes loop behavior required by directive step 2:
  - heartbeat UPSERT
  - atomic claim (`UPDATE ... RETURNING`)
  - preflight checks (terminal/profile/ex5/setfile)
  - run invocation via existing smoke runner
  - write-back (`done`/`failed`) and release

3. T6 hard refusal contract enforced
- File: `framework/scripts/mt5_worker.py`
- Commit: `d2a3af2d3`
- Contract verified:
  - prints `[REFUSED] T6 is OFF LIMITS`
  - exits with code `2`

4. Manual T1 prototype evidence captured
- Evidence: `docs/ops/evidence/QUA-1577_T1_WORKER_PROTOTYPE_2026-05-15.md`
- Commit: `d2a3af2d3`
- Shows queued dummy row processed by `--once` and SQLite write-back fields populated.

5. Regression coverage for scope safeguards
- Test file: `framework/scripts/tests/test_qua1577_worker_pool.py`
- Commits: `fabdc16c9`, `698d8e5d2`, `65432036a`, `6932be205`
- Coverage:
  - schema tables/indexes present
  - schema columns pinned (contract drift guard)
  - T6 refusal log + exit code
  - once-cycle claim + write-back
  - atomic oldest-row claim ordering

6. Unexpected external commit audited
- Evidence: `docs/ops/evidence/QUA-1577_AUDIT_6932be205_2026-05-15.md`
- Commit: `c5cfb70d2`
- Verdict: compatible with QUA-1577 scope, no rollback needed.

## Latest Verification

Command:

```powershell
python -m unittest framework/scripts/tests/test_qua1577_worker_pool.py
```

Observed:
- `Ran 5 tests ... OK`

## Status

- QUA-1577 step 1+2 scope is implemented and evidenced.
- Ready for CTO review/dispatch to next stage.
