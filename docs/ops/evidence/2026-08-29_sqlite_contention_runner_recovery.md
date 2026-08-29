# SQLite contention and runner-recovery repair — 2026-08-29

Task: `34858637-bfaf-4073-aa28-ebd902a64fb2`  
Scope: strategy-farm control-plane contention, EA-metrics refresh, router writes,
terminal runner liveness, and steady-state schema initialization.

## Measured failure shape

- `ea_metrics.build()` described itself as incremental but only skipped an
  unchanged row when `evidence_mtime` was non-null. Missing or purged evidence
  therefore caused the same rows to be extracted and upserted on every pass.
  Extraction and all upserts also shared one implicit transaction.
- `farmctl._pid_exists()` spawned `powershell.exe Get-Process` for every runner
  liveness probe. Resident workers execute that probe every two seconds and can
  also reach it while a claim transaction owns `BEGIN IMMEDIATE`.
- `ensure_work_item_gate_contract_schema()` unconditionally dropped and recreated
  five triggers on every `init_db()` call, including idle claim cycles.
- Router `update-task` and `close-review` writes did not retry the complete
  transaction after `SQLITE_BUSY`/`SQLITE_LOCKED`.
- A runner which exited after publishing output could leave its work item active
  while `terminal64.exe` remained resident. The worker waited for the ordinary
  run timeout rather than releasing a summary-less dead-runner claim.

The live database was confirmed to be WAL and rejected a read-only diagnostic
`BEGIN IMMEDIATE` for ten consecutive one-second probes. Windows Restart Manager
reported open database handles in six resident terminal workers. Those workers
started before this repair and retain the old imported code; they were not
interrupted because active T1-T10 work is operator-protected.

For the named cohorts, repeated pending rows carried
`worker_process_missing_released_stale_claim` or
`worker_restart_released_stale_claim`. Later runs for both cohorts produced valid
summaries. The current QM5_41161 runner log reached `run_smoke.result=PASS` and
published `summary.json`, but its work item remained active while the resident
worker was still alive: this is a finish-write/liveness reconciliation failure,
not strategy evidence.

## Repair

1. EA metrics now uses a complete incremental watermark (mtime, verdict, status,
   path, EA, phase, symbol), including null mtimes. It extracts outside a write
   transaction, commits bounded batches, rolls back failed batches, and uses the
   shared jittered SQLite-busy retry policy.
2. Router update and review-close operations now reopen and retry their complete
   transaction, with a bounded contention window long enough to cross the
   observed writer bursts.
3. Gate-contract backfill first checks whether any row needs migration. Canonical
   trigger SQL is compared with `sqlite_master`; only absent or changed triggers
   are replaced. A steady-state call performs no write or DDL.
4. Windows PID liveness now uses `OpenProcess` and `GetExitCodeProcess`; it creates
   no child process. Non-Windows uses `os.kill(pid, 0)`.
5. A dead runner without summary receives a five-minute publication grace. If
   the terminal is still resident afterward, the worker stops only its owned
   slot and append-safely returns the item to pending with
   `runner_process_died_without_summary`, clears stale runtime identity, and does
   not invent a pipeline verdict. If a summary exists, ordinary evidence-bound
   completion remains authoritative.

## Verification

- `python -m py_compile` passed for `ea_metrics.py`, `agent_router.py`,
  `farmctl.py`, and `terminal_worker.py`.
- Focused test suite: **87 passed** (`test_ea_metrics_incremental.py`,
  `test_agent_router_sqlite_retry.py`, `test_gate_contract_version.py`, and
  `test_terminal_worker_atomic_claim.py`).
- The steady-state gate-schema test installs a SQLite authorizer which denies
  INSERT, UPDATE, DELETE, ALTER TABLE, CREATE TRIGGER, and DROP TRIGGER; the
  second schema ensure still passes.
- Direct PID probe benchmark: 10,000 live-process checks in **0.041 s**. One old
  PowerShell `Get-Process` launch measured **1.396 s** on the same host.
- Live incremental metrics repair run: **54.34 s**; immediate no-change rerun:
  **15.63 s**. The latter includes scanning the large source table but no longer
  rewrites unchanged missing-evidence rows.

No terminal, AutoTrading control, T_Live setting, or pipeline verdict was
changed by this repair.
