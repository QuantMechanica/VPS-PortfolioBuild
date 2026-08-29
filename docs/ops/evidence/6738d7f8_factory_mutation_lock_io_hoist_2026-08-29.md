# FACTORY_MUTATION lock I/O hoist evidence

- Task: `6738d7f8-9e39-47b1-a60a-94363935e562`
- Date: 2026-08-29
- Branch: `agents/board-advisor`
- Scope: bound the global `FACTORY_MUTATION.lock` critical section while preserving claim atomicity and fail-closed behavior.

## Live diagnosis

Windows Restart Manager identified PID 10548 (`Python`, T8 worker) as the live holder of `D:/QM/strategy_farm/state/FACTORY_MUTATION.lock`. A non-interruptive worker stalldump at `2026-08-29T11:10:45Z` showed this call chain:

```text
pathlib.Path.read_text
  -> opt_census.cell_report
  -> opt_census_pruning._default_metric_reader
  -> opt_census_pruning._metric
  -> opt_census_pruning.prune_candidate_if_excluded
  -> terminal_worker._claim
  -> retry_sqlite_busy
  -> terminal_worker.claim_atomic
```

The active convoy was therefore the OPT_CENSUS report parse/hash path inside the global lock. The ticket's suspected custom-history copy and post-copy re-audit were already executed by `_run_claimed_item` after `claim_atomic` released the global lock; those DL-085 / Variant-A operations were not moved or weakened.

## Repair

`terminal_worker.claim_atomic` now performs potentially slow probes before entering the global mutation lock:

- database initialization, process snapshot, commit-headroom and RAM probes;
- watchdog, terminal-reservation, long-run, history, and multisymbol registry reads;
- active-terminal PID/tree validation;
- exact-candidate history eligibility checks; and
- OPT_CENSUS pruning/report reads and hashes under a separate nonblocking `DL089_CLAIM_PRUNING.lock`.

The global lock is limited to the fresh `FACTORY_OFF` reread, a bounded SQLite transaction, exact row/payload revalidation, admission checks over the prepared snapshots, and claim writes. Candidate fingerprints force a fresh preflight if queue state changes between the unlocked probe and locked transaction. Census peers that cannot acquire the dedicated pruning lock defer without blocking ordinary work.

SQLite work while holding the global lock uses one attempt with a 750 ms busy timeout. Transient Windows delete-pending/sharing races on lock-file acquisition are treated as contention until the existing deadline; other interlock errors remain fail-closed and explicit.

Safety invariants retained:

- `FACTORY_OFF` is reread after every global-lock acquisition.
- The exact candidate ID and payload are revalidated inside the SQLite transaction.
- OPT_CENSUS exclusion and receipt semantics remain delegated to `opt_census_pruning` unchanged.
- Custom-history privatization, manifest validation, post-copy re-audit, and receipt logic are unchanged and remain outside the global claim lock.
- No pipeline verdict, live-trading setting, terminal process, or active backtest was changed.

## Focused verification

The regression suite instruments only `FACTORY_MUTATION.lock` acquisitions. It injects a 1.1-second pruning read and a separate 1.1-second custom-history privatization/re-audit delay, and verifies neither runs under the global lock and every measured global-lock hold remains below one second. A SQLite writer-contention test separately verifies the locked wait is bounded below one second.

```text
python -m py_compile tools/strategy_farm/terminal_worker.py tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py
PASS

focused terminal-worker suite
243 passed, 4 subtests passed in 69.84s

git diff --check
PASS (line-ending conversion warnings only)
```

The focused run covered atomic claims, factory admission, SQLite busy/defer behavior, OPT_CENSUS pruning, custom-history isolation, and terminal adoption.

## Operational acceptance status

Implementation and deterministic timing regressions pass. The requested operational observation (more than a 10x decline in long lock holds while at least six testers are concurrent, including privatization-heavy work) is deliberately **not claimed**: existing workers were not restarted or interrupted, so they have not loaded this source revision. That measurement remains pending an approved deployment and representative observation window.
