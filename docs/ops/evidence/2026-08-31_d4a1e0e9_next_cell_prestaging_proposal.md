# Next-cell pre-staging overlap proposal

- Date: 2026-08-31
- Router task: `d4a1e0e9-52ad-444e-8d22-b08f4e70b3ec`
- Scope: proposal and measurement plan only
- Runtime changes in this task: none
- DL-089 semantics: unchanged

## Decision summary

Introduce, only after separate approval and implementation review, an opt-in detached-cache pre-staging path. While a terminal's current tester process is running, its worker may prepare immutable inputs for one *possible* next queue item. Pre-staging creates no ownership, reservation, queue mutation, launch right, pruning disposition, or live-terminal mutation. The ordinary post-finish claim path remains the sole authority that chooses and claims the next item.

The proposal can reduce the 60-120 second inter-cell gap without weakening the queue CAS, mutation locks, custom-history isolation, or DL-089 same-program parallelism controls. A cache hit is useful only if the unmodified selector later claims the same item and every bound fingerprint remains current. Otherwise the worker discards the speculative plan and follows today's path.

## Current boundary and source observations

The current `terminal_worker.py` loop claims an item and then blocks in `_run_claimed_item` through preparation, spawn, monitoring, and finish before looking for another item. The preparation path includes work that is partly immutable and partly authoritative:

- `_prepare_staged_ex5` hashes the canonical EX5 and copies it into the live terminal tree.
- `_privatize_custom_history_claim` copies verified archives into the live terminal's `Bases/Custom` tree and writes a claim receipt. MT5 opens custom-history archives for write, so the live tree must not be modified while its tester is running.
- `_opt_census_lane_preflight_outside_factory_lock` authenticates DL-089 lane evidence and may call `_prune_candidate_outside_factory_lock`.
- The pruning function is not a pure preflight: it can commit queue dispositions and receipts under the per-lane lock.
- `claim_atomic` performs the authoritative queue selection and compare-and-swap under `FACTORY_MUTATION.lock` and `BEGIN IMMEDIATE`, then writes the claim ledger.
- The runner hashes the set file immediately before spawn, so cached material cannot replace final identity validation.

These boundaries make detached, content-addressed preparation safe in principle. They make early claiming, early pruning, and writes into a running terminal unsafe.

## Proposed state machine

```text
current child durably spawned
          |
          v
  speculative SELECTED       (read-only; no queue rights)
          |
          v
     PREPARED cache          (detached immutable bytes)
          |
 current child finishes and current lease is released
          |
          v
 ordinary gates + new history lease + unchanged claim_atomic
          |
     +----+------------------------------+
     | exact item and fingerprints match | different/stale/no candidate
     v                                    v
 ADOPTED after claim                 MISS / EXPIRED
     |                                    |
     v                                    v
 existing final live mutations       existing cold path
 and spawn path
```

`SELECTED` and `PREPARED` are cache states only. They must never appear as queue statuses and must not influence queue ordering. `ADOPTED` is a local, idempotent cache transition after a successful ordinary claim.

## Work that may overlap the current tester

One bounded background job per worker may perform only the following work:

1. Read and parse a snapshot of one likely next pending item without reserving or pinning it.
2. Resolve and hash the set file and canonical EX5 source.
3. Run read-only syntax and guardrail checks whose result is advisory until repeated or revalidated after claim.
4. Resolve the custom symbol, activation record, manifest, verified-master paths, source identities, sizes, and hashes.
5. Read and authenticate the DL-089 declaration, amendment, ledger, frontier, and predecessor state without applying a disposition.
6. Copy immutable EX5, set-file, and verified-master archive bytes into a detached per-terminal cache on the same volume. Cache names are content hashes, and publication uses a temporary file plus atomic replace.
7. Prepare an in-memory command/report plan without creating a live report path or starting a process.

The background job must be low priority and cancellable. A fleet-wide I/O budget should limit large archive copies and census parsing, because stealing disk or CPU from the active tester would erase the intended gain. Pre-staging should decline when resource thresholds are exceeded, the immutable input exceeds a configured byte cap, or the candidate becomes stale.

## Work that must remain after finish and claim

The following operations remain on the existing serial authority path, after the current child tree has exited:

- disk, RAM, CPU, news-calendar, history, and launch-capacity gates;
- acquisition and binding of the next item's custom-history lease;
- claim spacing and the authoritative selector;
- queue status/`claimed_by` mutation, `BEGIN IMMEDIATE` CAS, and claim-ledger write;
- commit reservations, Q09 helper reservations, and launch-slot decisions;
- any priority change, candidate reservation, or queue pin;
- DL-089 lane eligibility, duplicate-pair, K/L/G, allowlist, frontier, and same-arm checks;
- pruning disposition, pruning receipt, or any other database mutation;
- writes to the live terminal's `MQL5/Experts`, configuration, reports, or `Bases/Custom` tree;
- final set-file/EX5 hashes, post-copy archive audit, receipt publication, and process spawn.

In particular, a speculative DL-089 parse cannot authorize a claim. The existing lane lock and transaction-time authentication remain mandatory. The existing pruning implementation remains after finish; a future refactor may reuse only a pure parse result, and only after revalidating the payload, ledger, predecessor, and frontier fingerprints under the existing locks.

## Pre-stage token and adoption rules

The local plan token should bind at least:

- terminal identifier and worker generation;
- candidate item ID, full payload SHA-256, phase, EA, symbol, period, and year;
- set-file absolute path, size, mtime, and SHA-256;
- canonical EX5 path, size, mtime, and SHA-256;
- custom-history activation ID, manifest ID/hash, verified-master identity, and archive member hashes;
- DL-089 declaration/amendment/ledger hashes, `(program, arm, year)`, cell key, Q12 identity, predecessor IDs, and predecessor-status fingerprint;
- selector/policy schema generation, creation time, and a short TTL.

After the current item finishes, the worker starts the ordinary loop, obtains a fresh history lease, and calls the unchanged authoritative selector. Cache adoption is allowed only when that selector independently claims the exact candidate and all bound identities still match. A miss, timeout, changed payload, changed predecessor, changed ledger, changed source, or failed audit discards the plan and uses the current cold path.

After claim, cached bytes may be promoted into live paths only through the existing temporary-file/atomic-replace pattern followed by re-hashing. Custom-history bytes may be promoted only while the terminal is inactive and the new history lease is held. The worker then performs the existing post-copy audit and publishes the one canonical privatization receipt. A pre-stage must never publish `PASS_PRIVATIZED` or any equivalent receipt.

Adoption should use a local `PREPARED -> ADOPTED` compare-and-swap keyed by terminal, item, and token. Re-entry with the same key is idempotent; a different key is a miss. This prevents a retry from double-promoting archives or publishing two receipts.

## Safety and replay argument

The proposed optimization preserves the following invariants:

1. **No claim before finish.** Pre-staging creates no queue-visible state and cannot satisfy a claim or launch gate. The next claim occurs only after the current child exits and the normal loop resumes.
2. **No candidate privilege.** The cache does not reserve, pin, boost, or skip an item. The ordinary selector may choose another item; that outcome is a cache miss.
3. **One authoritative mutation path.** Queue CAS, claim ledger, pruning, reservations, receipts, and launch remain under their current locks and transactions.
4. **No live-tree overlap.** Speculative bytes stay outside the terminal tree. Live EX5 and history replacement occurs after the terminal is inactive and after claim.
5. **No double privatization.** A pre-stage has no privatization receipt. The single post-claim adoption CAS, lease, audit, and canonical receipt remain authoritative.
6. **Fail closed on staleness.** Every mutable dependency is fingerprinted and revalidated. Any mismatch falls back to the existing path.
7. **DL-089 remains unchanged.** Defaults, allowlist behavior, K/L/G gates, same-arm exclusion, authenticated frontier, per-lane locks, declaration and UUID identities, set files, verdicts, and pruning semantics are untouched.

For deterministic replay, feed the same queue insertions, current-cell completions, policy inputs, and resource-gate outcomes to the current scheduler and to a pre-stage-enabled scheduler. Ignore cache-event timestamps. The two runs must produce the same authoritative claim decisions, queue status transitions, claim-ledger rows, pruning dispositions/receipts, payload and evidence hashes, and verdicts. A speculative candidate may miss, but it cannot alter the selector result. Inject changes to every token-bound dependency between `PREPARED` and claim; each case must discard the cache and converge to the current cold path.

## Expected gain

With a representative tester duration of 390 seconds and a current 60-120 second claim/preparation gap, tester duty cycle is approximately 76.5%-86.7%. If detached preparation reduces a hit's residual gap to 15-30 seconds, hit duty cycle is approximately 92.9%-96.3%.

The theoretical throughput improvement for a perfect hit rate is about 7%-26%, depending on the baseline and residual gap. At a 75%-85% cache-hit rate, the simple model yields roughly 5%-21%. A prudent initial expectation is 7%-18%; it must be demonstrated without increasing tester duration or safety failures. Claim spacing is not consumed speculatively: the current 390-second run already exceeds the ten-second spacing, so early consumption adds no benefit.

## Exact future change surface

No code is changed by this proposal. A separately approved implementation should be small and auditable:

- Add a pure `next_cell_prestage.py` module for snapshot selection, token creation, detached cache publication, validation, adoption CAS, and TTL cleanup.
- Add an opt-in hook in `terminal_worker.py` only after the current child is durably spawned, plus a join/cancel and adoption check after child exit.
- Split only demonstrably pure DL-089 parsing from mutation, leaving eligibility revalidation and pruning application in the existing locked path.
- Add structured telemetry events and counters; do not add queue statuses or rewrite existing evidence schemas.
- Add unit, race, fault-injection, and deterministic replay tests before any terminal canary.

Proposed controls:

- `NEXT_CELL_PRESTAGE_ENABLED=0` by default;
- exact terminal allowlist, empty by default;
- one speculative candidate per worker;
- bounded TTL and byte quota;
- one fleet-wide semaphore for heavy archive/census I/O;
- cancellation on resource pressure, current-test completion, policy-generation change, or worker shutdown.

## Measurement and canary plan

Emit monotonic and UTC timestamps for: candidate observed, pre-stage start, prepared, bytes copied, decline/miss reason, current child-tree exit, next claim attempt, successful claim CAS, adoption complete, and next child process creation. Also record candidate/item match, cache age, input class, archive bytes, preparation CPU/I/O, current tester duration, SQLite lock latency, and all final hashes.

Primary metrics:

- idle gap: current child-tree exit to next child process creation;
- tester duty cycle: tester runtime divided by runtime plus idle gap;
- cache prepare, hit, stale, and miss rates by phase/symbol/archive-size class;
- execution-bearing verdicts per terminal-hour, not raw queue-row throughput;
- current tester p50/p95 duration while background preparation is active.

Run a default-off control and an exact-terminal canary only after those terminals become naturally idle and their governed workers are reloaded. Do not interrupt an active T1-T10 test. Collect at least 100 eligible handoffs or six hours in each arm, with paired workload strata where practical.

Canary success criteria:

- median idle gap at most 30 seconds and at least 50% below control;
- p95 idle gap at most 60 seconds;
- at least eight percentage points of duty-cycle improvement, or sustained duty cycle of at least 92%;
- at least 8% improvement in execution-bearing verdicts per terminal-hour;
- current tester p50 and p95 runtime regress by no more than 5%;
- no material increase in SQLite lock wait, disk saturation, launch failure, `REPORT_MISSING`, error 10053, or `0xC0000142` rates.

Immediate stop conditions:

- any duplicate claim or duplicate spawn;
- any early claim, reservation, priority effect, or queue-order effect attributable to pre-staging;
- any write into an active terminal tree;
- any double privatization receipt, shared-history evidence, post-copy audit failure, or hash mismatch;
- any DL-089 frontier, same-arm, K/L/G, allowlist, declaration, pruning, or verdict divergence;
- any unexplained replay mismatch.

## Rollback

Set `NEXT_CELL_PRESTAGE_ENABLED=0` and remove the exact terminal allowlist, then allow active tests to finish before the normal governed worker reload. Detached caches are inert, have no queue rights, and can expire through bounded TTL cleanup. Because the feature does not introduce queue states or authoritative evidence, rollback requires no database repair, history rewrite, verdict change, or claim-ledger edit. Any already prepared cache is ignored; subsequent cells use the current cold path.

## Verdict

Feasible as a detached, default-off preparation cache, provided authoritative claim, pruning, privatization, and launch remain strictly post-finish and post-claim. The modeled utilization gain is meaningful, but runtime adoption should proceed only through replay tests and a stop-on-first-invariant canary. This task made zero runtime changes.
