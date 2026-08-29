# Terminal worker SQLite self-block repair and guarded re-land — 2026-08-29

Task: `c261d433-b76d-4a06-807f-de428bc29439`
Branch: `agents/board-advisor`
Verdict: `PASS_CODE_READY_STAGGERED_ROLLOUT_REQUIRED`

## Outcome

The launch-path lock was reproduced and repaired. The terminal-process census
now completes before either worker claim path opens `BEGIN IMMEDIATE`, and the
95-line dead-runner recovery from `59037441c` has been re-landed unchanged.

No worker or terminal was manually stopped or started. No active backtest was
interrupted, no pipeline verdict was written, and neither T_Live nor
AutoTrading was touched.

## Forensic finding

The incident was correlated with `59037441c`, but it was not introduced by that
commit's 95-line `terminal_worker.py` delta:

- `59037441c` added only the dead-runner grace/requeue path after spawn.
- The failing fleet sequence was `claimed` followed by
  `run_item_sqlite_busy_deferred`, before that monitor branch could run.
- Worker logs contain the same event before `59037441c` was committed at
  2026-08-29 06:46 UTC. For example, T10 recorded it at 2026-08-28 23:36 UTC,
  and every T1-T10 log has earlier occurrences.
- After the worker-only rollback `71621da1d`, nine workers started together at
  2026-08-29 09:35:33 UTC. Within roughly four minutes they had accumulated
  110-191 seconds of CPU time, so the high worker load also reproduced without
  the 95-line delta.

The built-in, non-interrupting stack request captured the writer-lock site in:

`D:/QM/reports/state/worker_stalldump/T4_27452.txt`

The main thread was in this call chain:

```text
farmctl._running_mt5_terminals()
  -> subprocess.run(powershell.exe Get-CimInstance ...)
  -> terminal_worker.claim_atomic()._claim()
  -> retry_sqlite_busy()
  -> claim_atomic()
```

At that point `_claim()` had already executed `BEGIN IMMEDIATE`. The potentially
15-second PowerShell/CIM census therefore ran while the worker owned SQLite's
writer lock. A same-process pre-spawn connection and every peer writer then
blocked; after their bounded retries, even the small active-to-pending defer
write could fail.

`git blame` identifies the census-inside-transaction line as inherited from
`119655b885` (2026-05-28), not from `59037441c`. The rollback removed the new
dead-runner recovery but necessarily retained this older defect.

## Deterministic reproduction

`test_running_terminal_probe_precedes_claim_write_transaction` models the exact
shape in one process:

1. `claim_atomic()` is in flight on connection A.
2. The patched terminal census opens connection B.
3. Connection B executes `BEGIN IMMEDIATE` and an `UPDATE`.

With the old ordering, connection A already owned `BEGIN IMMEDIATE`, so the
second connection raised `database is locked` and the claim failed. With the
repair, connection B acquires and rolls back the write before connection A
opens its claim transaction, after which the claim succeeds.

## Repair

- Snapshot `farmctl._running_mt5_terminals()` before opening the write
  transaction in both `claim_atomic()` and `claim_specific_atomic()`.
- Use that snapshot inside the transaction; no subprocess is launched while a
  SQLite writer lock is held.
- Restore the `59037441c` dead-runner recovery: after the bounded publication
  grace, stop only the owned factory slot and return a summary-less dead-runner
  claim to pending without manufacturing a Q-phase verdict.

Relative to `59037441c`, the re-landed worker differs only in the corrected
terminal-census transaction boundary.

## Verification

```text
python -m unittest -v \
  ...test_running_terminal_probe_precedes_claim_write_transaction \
  ...test_dead_runner_without_summary_requeues_live_claim \
  ...six existing claim, specific-claim, monitor, launch-fault, and preflight tests

Ran 8 tests in 23.789s — OK
```

`python -m py_compile` passed for the worker and its test module.
`git diff --check` is clean.

## Staggered rollout contract

This commit is code-ready, not permission to disrupt the live fleet.

1. Wait for an idle factory slot with no active work item and no protected
   backtest. Do not kill a runner to make a slot idle.
2. Let the normal worker supervisor load the new code for one idle slot. Never
   launch `terminal64.exe` manually.
3. Canary evidence must show a claim progressing to spawn/monitor or a terminal
   result without `run_item_sqlite_busy_deferred`; also compare worker CPU slope
   and SQLite write-probe success with the incident baseline.
4. Only after the canary is clean, expand to two idle slots, then the remaining
   slots as they become idle. Preserve active T1-T10 work throughout.
5. On any recurrence, hold the remaining rollout and request a reviewed
   worker-only rollback. Do not weaken SQLite evidence, pipeline gates, news
   checks, or live-trading safeguards.
