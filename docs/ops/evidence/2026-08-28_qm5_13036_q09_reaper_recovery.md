# QM5_13036 / GDAXI Q09 stale-claim recovery and reaper availability fix

Router task: `8e3ff055-a0f4-482e-a56a-7e620fae224f`

## Root cause

The EA/tester was not hung. Work item
`8ac4dd37-4d59-4721-bf19-da6a8e34e384` published a complete authenticated
run-smoke summary and Q09 aggregate on 2026-08-27 at 06:00 UTC:

- result/verdict `PASS`;
- PF `1.04`, 1,352 trades, DD `8.08168%`;
- report SHA-256 `70225316fd8f3f8655ce3aeca889c76ef7d70e65136f1fbf4657c596997c9eae`;
- phase-runner PID `12772` had exited and no T5 `terminal64.exe` or
  `metatester64.exe` process remained.

The database finalization was missed, leaving the row `active` and claimed by
T5. The progress-aware detector correctly measured the last canonical artifact
at 06:00:33 UTC and classified more than 1,500 minutes without progress as
`NO_FORWARD_PROGRESS` against the 120-minute Q09 ceiling.

The detector did not run because the scheduled pump was stuck before `farmctl
pump`: `run_pump_task.py` found a fresh `pump_task.lock` owned by dead PID
`37968`, treated it as live solely because it was younger than 20 minutes, and
returned 0. Repeated scheduler launches therefore skipped the detector while
appearing successful. A later scheduled attempt reclaimed the dead lock with
this fix, but an external SYSTEM task re-registration terminated its wrapper
while the read-only kill-safety audit was still scanning; that separate event
is visible in Task Scheduler events 111/140/142 at 09:10 local.

## Class fix

`run_pump_task._acquire_lock` now probes the recorded owner PID through the
read-only exact process-identity API. A definitely dead owner is reclaimed
immediately, while an unreadable identity fails closed and the existing
20-minute age ceiling remains as the fallback.

`farmctl._detect_active_age_timeout` also accepts an optional exact item-id set.
The scheduled pump remains unchanged (all active rows); targeted incident
recovery can no longer accidentally reap unrelated stalled rows.

## Safe recovery

Immediately before recovery, PID `12772` was absent and the count of T5 tester
processes was zero. The exact-scoped detector then released only `8ac4dd37`:

- status `failed`, verdict `INFRA_FAIL` (the existing active-timeout taxonomy,
  not an economic/pipeline verdict);
- evidence sentinel `EVIDENCE_UNAVAILABLE:active_timeout:NO_FORWARD_PROGRESS`;
- `worker_stopped=false`; no child process was killed;
- `terminal_stopped=true` records release of the empty T5 slot;
- the completed report and aggregate files remain immutable on disk.

T5 has no active row after the release. Existing Q09 successor
`16fd7a9e-46bd-4e05-a7d6-a04e4d9bdc88` remains pending and unclaimed, so the
pair is enqueued without inventing a duplicate while the factory mutation lock
is busy. Two attempts to create an additional exact
`--append-only-rerun-of 8ac4dd37...` through the canonical CLI failed before
mutation at `init_db` with `sqlite3.OperationalError: database is locked`; no
manual SQLite clone was substituted.

## Verification

```text
python -m pytest \
  tools/strategy_farm/tests/test_progress_aware_reaper.py \
  tools/strategy_farm/tests/test_run_pump_task_lock.py -q
15 passed in 3.39s
```

Coverage proves immediate dead-owner lock reclamation, preservation of a live
owner lock, age-ceiling recovery for unreadable lock content, and exact-scoped
reaping that leaves another equally stalled row active.

No T_Live/AutoTrading setting was touched, no terminal was manually started,
and no other T1-T10 row was interrupted.
