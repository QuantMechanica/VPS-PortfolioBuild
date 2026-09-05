# Claim-lock cost review

RESULT: REVIEW. Isolated implementation commit `04e9f2337f` on `agents/codex-claim-lock-cost-20260905`. Router task `f22f9a8c-1ef1-4897-8ab5-1644c7457030`. No worker restart, production schema change, terminal run, routing or main integration occurred.

## Measured cause and result

The expensive section is the full claim-order SELECT under the shared factory file lock, not BEGIN IMMEDIATE through commit. On one 734,773,248-byte online SQLite backup of the current factory DB, the controlled baseline spent 3.849 seconds selecting candidates. EXPLAIN shows correlated census probes scanning earlier derived rows and active programs. Each SQL statement executed under the shared lock has its timing and query plan in the receipts; DDL/transaction statements legitimately have empty plans.

| Replay | Shared factory lock | SQLite write transaction |
|---|---:|---:|
| Controlled baseline | 3.9484 s | 0.0136 s |
| Indexes alone | 2.1207 s | 0.0142 s |
| Final code | 0.1889 s | 0.0133 s |

Final and baseline select the same item `31f12573-d903-4386-a857-cad2b445d63a` and preclaim payload SHA-256 `957994dd62e6db1149fecf539e000a600a624b1b9d7bba2f237b3004ccba5231`. The final replay meets the under-one-second target on this snapshot. These are controlled replay timings, not a measured production throughput improvement. Initial exploratory and intermediate receipts remain available and are labelled separately.

The replay makes a read-only online backup, then refuses every SQLite connection outside its disposable copy root. It stubs OS resource measurements, news/history and external sealed-ledger preflights to isolate the claim path. It uses a synthetic terminal identifier and invokes no runner. Cache TTL is forced to zero to reproduce the cold/full-order cost. Actual admission, hold, final CAS and spacing code still execute against the copy.

## Implementation

Two partial expression indexes match the existing census predicates exactly. The full order and its unchanged SQL semantics are prepared before taking the shared lock. The consumer verifies database identity, persistent data-version poller identity, version, SQL identity and age-boundary expiry under the lock. Changed or expired snapshots refuse cheaply and refresh outside the lock, sharing the existing eight-retry ceiling. Final claim CAS and all existing admission checks remain authoritative. A cold sort exceeding the five-second snapshot lifetime defers rather than rebuilding under the shared lock.

Ephemeral high-resolution arrival tickets provide FIFO admission among updated claim workers. Expired or crashed waiters cannot hold up the queue; cleanup deletes only nonce-matching ticket files. The existing nonce-bound factory mutex still provides mutual exclusion and OFF checks. Each claim cycle has one cumulative five-second acquisition-wait budget across preflight retries, replacing repeated five-second budgets that could accumulate around forty seconds. Work under the lock is accounted separately. Other global-lock writers do not join this FIFO: an outside holder can still force a bounded refusal. Eventual service under arbitrary competing writers is not claimed.

## Verification and integration boundary

`python -m pytest tools/strategy_farm/tests/test_claim_lock_cost.py tools/strategy_farm/tests/test_claim_order_memo.py tools/strategy_farm/tests/test_claim_spacing.py tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py tools/strategy_farm/tests/test_factory_mutation_lock.py -q`: **132 passed in 61.47 seconds**. Tests cover index equivalence and plans, malformed JSON, ten FIFO contenders, expired/changed-ownership tickets, cumulative wait exhaustion, stale/version/SQL/poller snapshots, sorting outside the shared lock, concurrent capacity and stale-claim recovery. Two existing runner-monitor tests now stub staging explicitly, removing dependence on real EA and terminal files in isolated worktrees. `git diff --check` passes.

[Verification](2026-09-05_claim_lock_cost/verification.json), [replay program](2026-09-05_claim_lock_cost/profile_claim.py), [baseline](2026-09-05_claim_lock_cost/before_controlled.json), [final replay](2026-09-05_claim_lock_cost/after_review.json), [implementation patch](2026-09-05_claim_lock_cost/claim_lock_cost.patch). Reproduce receipt checks with `python C:/QM/repo/docs/ops/evidence/2026-09-05_claim_lock_cost/verify.py`. A fresh replay requires the same snapshot for before/after comparison; the disposable DB itself is not committed.

Code stays on the isolated branch. Index creation is an integration-time migration cost outside the claim lock and should be observed at the normal controlled worker close-out. Existing workers have not adopted these changes.

## Batch-claim boundary

No batch claim is implemented. Claiming three rows in one immediate transaction would violate the existing ten-second fleet claim spacing unless it held the global lock for at least twenty seconds, defeating this task. A future design could cache three candidates, then separately reacquire and revalidate each at its eligible claim time; that is candidate prefetch, not preclaiming work. Any relaxation of per-event spacing or reservation of future work requires a separate OWNER decision. The current change needs no such relaxation.
