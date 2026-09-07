# Idle terminal-worker claim-scan CPU repair

Date: 2026-09-07

Router task: `8c53213e-b920-4daa-b4c2-ef82a5a33ddc`

Disposition: **IMPLEMENTED AND VERIFIED; REVIEW REQUIRED; WORKERS NOT RESTARTED**

## Result

`terminal_worker.claim_atomic()` now memoizes only a completed negative
`no_pending_claimable` decision. A hit bypasses the full Python candidate walk;
a miss still executes the unchanged canonical claim order and all existing
admission checks. Positive claim decisions are never cached.

The cache has an eight-second hard ceiling. With the worker's two-second poll
cadence, a condition which changes only in memory or by elapsed time is revisited
within at most ten seconds, below the task's 15-second requirement. Any durable
queue change invalidates immediately through a persistent SQLite
`PRAGMA data_version` poller.

No claim order, phase priority, RAM threshold, drain rule, cap, admission mode,
verdict, or gate criterion changed.

## Reproduction

The task intake measured T1 making 53 claim/prestage polls in ten minutes while
only two cells were active, with idle `pythonw terminal_worker` processes each
using approximately one logical core and six `cpu_high_pause` events. The T1
log independently shows repeated negative attempts around the incident window;
for example, 11:46:08Z through 11:47:11Z contains six consecutive
`no_pending_claimable` results, each preceded by a fresh `next_claim_attempt`.

The cause is structural: `_claim_queue_may_need_mutation()` returns true if
*any* pending row exists. With thousands of permanently pending census/Q02 rows,
that test cannot distinguish "queue contains rows" from "this terminal can claim
one now." Every idle poll therefore builds/reuses the ordered row list and then
walks the candidates through JSON parsing, active-symbol serialization, long-run,
RAM-class, drain, and lane checks.

`benchmark_idle_claim_cache.py` opens the production database with SQLite URI
`mode=ro` plus `PRAGMA query_only=ON`, creates an online backup under a disposable
`D:/QM/tmp` root, and calls the real `claim_atomic` against only that copy. A
deterministic zero-free-RAM fixture makes all candidates inadmissible and prevents
a claim or spawn. The copied database SHA-256 is checked before and after.

Command:

```powershell
python C:/QM/repo/tools/strategy_farm/benchmark_idle_claim_cache.py `
  --iterations 5 `
  --output C:/QM/repo/docs/ops/evidence/2026-09-07_idle_claim_scan_cpu/benchmark.json
```

Snapshot result (`9,047` pending, `8` active):

| Measurement | Cache disabled | Cache hit |
|---|---:|---:|
| median wall per call | 927.945 ms | 1.094 ms |
| p95 wall per call | 3,020.731 ms | 1.484 ms |
| median process CPU per call | 703.125 ms | 0.000 ms (timer resolution) |
| measured calls / cache hits | 5 / 0 | 5 / 5 |
| projected steady idle use of one core | 24.014% | 7.876% |

The steady projection includes one full negative pass per eight-second memo
lifetime; it is not the near-zero cost of hits alone. Projected steady reduction
is `67.205%`. The isolated DB hash stayed byte-identical:
`1d5bd3769556d25daa6385476ef0bbf05672ce0e55a5ba74dc9b71c4a3a6bea3`.
Raw samples and the calculation are in `benchmark.json`.

## Cache proof and invalidation

The process-local entry is keyed by farm root and terminal and fingerprints:

- the exact database file, persistent poller identity, and whole-database
  `data_version` (work items, holds, supersedes, quarantine, claim ledger, and
  every other committed table change);
- two-GB free-RAM and commit-headroom buckets;
- byte-independent stat identities for the drain window, watchdog-reset marker,
  and custom-history activation;
- all `QM_*` feature flags and the process-local RAM-latch mode.

An unreadable file, database/poller ambiguity, invalid resource probe, disabled
TTL, fingerprint mismatch, or expiry bypasses the memo. A successful claim or
any non-idle result clears the entry. The worker also clears it explicitly after
the local claimed-item lifecycle, including exceptional exits.

`QM_IDLE_CLAIM_CACHE_TTL_SECONDS=0` is the rollback switch. Positive values are
hard-clamped to eight seconds; configuration cannot silently widen the latency
bound.

## Verification

- `python -m py_compile tools/strategy_farm/terminal_worker.py tools/strategy_farm/benchmark_idle_claim_cache.py`: PASS.
- Idle-cache + claim-order memo tests: `26 passed` (17 cache tests, including
  T1-T10 differential selection, plus 9 claim-order memo tests).
- Atomic claim, drain, census-first RAM, phase-RAM floor, and idle-cache suite:
  `235 passed in 83.62s`.
- Differential coverage compares cache-enabled misses with cache-disabled
  claims for each of T1 through T10 and gets the same first row. A warmed
  negative entry is also invalidated by a DB commit, a resource-bucket change,
  and a `QM_*` flag change before the original selector runs.
- `git diff --check`: PASS.
- LF/terminal-newline and Python compile checks: PASS.

A broader exploratory run included `test_longrun_scheduling_policy.py` and
reported `226 passed, 2 failed`. Both failures are the pre-existing dummy-Q10
"policy disabled" integration fixtures: with
`QM_IDLE_CLAIM_CACHE_TTL_SECONDS=0` they still end in the independent current
claim-time path rather than claiming. The cache-focused and full atomic suites
above are green; this change does not modify that Q10 guard.

## Governed reload plan (not executed)

After Claude+OWNER integration, use the established `reload_chunk58.py` pattern
to prepare the next numbered reload artifact. Its required procedure is:

1. Re-run the 235-test suite and the benchmark from the integrated checkout.
2. Select only a terminal with no active work item and no child tester. Recheck
   immediately before termination; if none is idle, wait without touching the
   fleet.
3. Reload exactly one worker, let `start_terminal_workers.py` restore only the
   missing daemon, verify the new PID/generation and one claim loop, then wait at
   least 150 seconds.
4. Repeat one terminal at a time for T1-T10. Abort on a missing replacement,
   active-item ambiguity, factory interlock, or health regression.
5. Compare idle CPU/poll timing after at least two freshly loaded workers before
   continuing the cohort. Set the rollback environment value to `0` and perform
   the same idle-only stagger if the selector or latency check regresses.

This cycle did not create or run a reload script, stop a worker, call a terminal,
change AutoTrading, touch `T_Live`, or mutate the production farm database.

## Files

- `tools/strategy_farm/terminal_worker.py` — bounded negative-result memo and
  lifecycle invalidation.
- `tools/strategy_farm/benchmark_idle_claim_cache.py` — reproducible read-only
  snapshot timing harness.
- `tools/strategy_farm/tests/test_terminal_worker_idle_claim_cache.py` — cache,
  invalidation, latency, and T1-T10 differential tests.
- `docs/ops/evidence/2026-09-07_idle_claim_scan_cpu/benchmark.json` — raw timing
  receipt.
