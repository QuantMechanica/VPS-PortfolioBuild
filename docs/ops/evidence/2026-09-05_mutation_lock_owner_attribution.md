# Mutation lock owner attribution — Codex review artifact

Task: e7599281-2ed8-420d-9d90-98a7f5f10543. Status: PATCH_TESTED / HISTORICAL_WINDOW_MEASURED; post-deployment acceptance remains pending. No worker restart or production deployment occurred.

Code commit: `cd454369fb` on `agents/codex-lock-attribution-20260905`, based on canonical `0e28f3bb0f`. The existing `agents/codex` checkout is divergent and contains an unrelated modified include, so the code is isolated in a new Codex branch. The adjacent patch is the reviewable handoff. Evidence is committed in the canonical checkout on `agents/board-advisor` as required by this cycle. Main and cto_main were not changed.

## Implementation and checks

The lock record already contained pid, owner, nonce and creation time. The patch adds executable basename, argv0 basename, pump stage/reason and acquired_at, and puts those fields in the existing hold journal. Windows holds the lock with sharing disabled; a second process cannot read the live file. The observer preserves those exclusive-lock semantics and falls back to the capped journal tail, explicitly labeled diagnostic observation rather than current-owner proof.

A single daemon reader per process has a 35 ms wait budget, a 4096-byte marker cap and 64 KiB journal-tail cap. There is no reader queue, PID probing or database write. Busy claims receive owner detail; every busy attempt emits claim_lock_busy while the existing human-log throttle remains unchanged. Claim order, verdicts, backoff, containment and stale-lock ownership checks are unchanged. OS scheduling cannot offer a hard real-time guarantee; the focused blocked-I/O test verifies return below 50 ms in this environment.

Validation: 20 tests passed in test_mutation_lock_observation.py, test_mutation_lock_attribution.py and test_factory_mutation_lock.py; 4 existing terminal_worker_atomic_claim tests passed (93 deselected), covering Factory OFF before and after acquisition, admitted-before-OFF and the empty queue fast path. git diff --check passed. Tests include real Windows exclusive locks, stale receipt races, bounded/failed reads, single-flight behavior, event-vs-log throttling, attribution ambiguity and duplicate prevention.

## Two-hour historical measurement

Window: 2026-09-05T06:17:07.774588+00:00 to 2026-09-05T08:17:07.774588+00:00 (UTC), captured before deployment. JSON receipt contains byte-read SHA-256 hashes for the hold journal and worker logs. These are **110 logged declines**, not a count of all attempts: the old human log was throttled at 60 seconds. 63/110 (57.3%) uniquely overlap a completed hold interval for the same lock path; those joins are inference. 47/110 (42.7%) remain UNKNOWN, including absent/incomplete or ambiguous receipts. No process names are invented for historical rows.

| Recorded owner | Logged declines | Median hold age (seconds) | PID(s) |
|---|---:|---:|---|
| UNKNOWN | 47 | None |  |
| terminal_worker.claim_atomic:T6 | 13 | 1.423828 | 19320 |
| terminal_worker.claim_atomic:T7 | 8 | 3.125479 | 6132 |
| terminal_worker.claim_atomic:T10 | 7 | 4.302105 | 22912 |
| terminal_worker.claim_atomic:T4 | 7 | 2.46287 | 29244 |
| terminal_worker.claim_atomic:T1 | 6 | 3.443933 | 7536 |
| dl089_matrix_service:40e69c26-1ddb-5728-99a1-02b08f83c284 | 4 | 0.812736 | 19776 |
| terminal_worker.claim_atomic:T3 | 4 | 3.426092 | 24408 |
| dl089_matrix_service:d824e8cb-8397-5aa3-b6fa-fec9b0c375eb | 3 | 3.449188 | 26084 |
| terminal_worker.claim_atomic:T2 | 3 | 1.940062 | 26424 |
| dl089_matrix_service:a8b2dd82-ab11-5df9-a68b-f6da871d2995 | 2 | 2.480856 | 888, 30952 |
| release_compile_wave.apply | 2 | 9.654542 | 14904, 23940 |
| terminal_worker.claim_atomic:T5 | 2 | 4.636105 | 31392 |
| dl089_matrix_service:5c1085ce-b76a-594d-973e-6080e27711b1 | 1 | 2.940279 | 888 |
| dl089_matrix_service:9102ff97-a450-5cd3-8e13-0f61144ffa5d | 1 | 3.02761 | 8688 |

Terminal-worker claim holders account for 50/110 logged declines (45.5%), or 50/63 attributable declines (79.4%). Matrix-service holders account for 11 and compile release for 2. These counts do not establish the root cause of all contention or reproduce the older 8–16/min report.

The next measured target should be time spent inside terminal_worker.claim_atomic: instrument its existing critical-section substeps and identify which reads can safely move before acquisition. The observed worker medians range about 1.4–4.6 seconds. Do not change lock granularity or choose jitter from this baseline alone; first use the new events to reduce the 47 unknowns and check whether worker holds dominate unthrottled declines too.

## Remaining post-deployment acceptance

Claude/CEO reviews the code patch and integrates/reloads it at a safe natural worker boundary; this task does not interrupt active backtests. Record deployment revision, UTC time and worker coverage. At least two hours after all intended workers load that revision, run the following read-only collector (with a new artifact filename and explicit end time):

```powershell
python C:/QM/repo/tools/strategy_farm/mutation_lock_attribution.py --hours 2 --end-utc '<UTC end at least two hours after deployment>' --output C:/QM/repo/docs/ops/evidence/mutation_lock_postdeploy_2h.json
```

Join the output to deployment/coverage receipts before declaring the post-deployment window proven. The collector intentionally cannot self-certify deployment. This scheduled cycle does not sleep for two hours and leaves the artifact in REVIEW.

Patch SHA-256: 6c6d1645c182a282e589858c2c94a622684cfd370adf8e3d0cd8963e46d0cfdb.
