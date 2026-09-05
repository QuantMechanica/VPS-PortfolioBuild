# DL-089 L=2 lane-preflight decline-loop root cause and fix

Date: 2026-09-05  
Router task: `a128d596-4146-44c1-a81c-c35a080fc63c`  
Verdict: `FIX_IMPLEMENTED_INERT — CANARY NOT ACTIVATED`

## Root cause

The first repair (`ac5a29c9`) correctly moved cold ledger/frontier authentication behind capacity, duplicate, and RAM gates. That removed the inert-default L=1 loop, but it did not constrain the queue row selected when L=2 made a second lane admissible.

`farmctl.pending_claim_order_sql()` ranks programs, queue order, phases, and row age; it does not order governed annual cells by `(program_id, arm, year)`. With one arm already active and L=2 enabled, a pending later year from a distinct arm could therefore appear before that arm's first nonterminal year. It passed the program/lane/cell caps and the narrow duplicate-pair exception. `_opt_census_lane_preflight_outside_factory_lock()` then loaded the sealed ledger and `dl089_scheduling.arm_frontier()` correctly rejected it as `candidate_not_arm_frontier`.

The failed preflight was outside `FACTORY_MUTATION.lock`, but the caller reacquired that global lock to scan the queue again. Suppression was lane-only, so another wrong arm/year row from the same program could repeat this cycle up to `CLAIM_PREFLIGHT_MAX_CANDIDATES=8` for every worker poll. The correctness guard held—no wrong cell was claimed—but the repeated lock acquisitions created a fleet-wide decline convoy.

## Reconstructed incident evidence

The 2026-09-02 canary closeout records the observed throughput fall from about 88 to 21 cells/hour and rollback at 09:42Z. Direct parsing of the retained worker JSON logs for `09:25Z <= at_utc < 09:42Z` finds exactly 57 `factory_mutation_lock_busy` events:

| Worker log | Events | First UTC | Last UTC |
|---|---:|---|---|
| T1 | 8 | 09:29:46 | 09:40:35 |
| T2 | 6 | 09:30:56 | 09:40:33 |
| T3 | 6 | 09:30:03 | 09:35:21 |
| T4 | 8 | 09:30:15 | 09:40:33 |
| T5 | 9 | 09:31:43 | 09:35:57 |
| T7 | 4 | 09:30:56 | 09:33:58 |
| T8 | 6 | 09:32:24 | 09:35:19 |
| T9 | 6 | 09:33:37 | 09:35:50 |
| T10 | 4 | 09:30:40 | 09:33:06 |

Representative retained lines:

```text
terminal_worker_T1.log  2026-09-02T09:29:46Z  next_cell_prestage  factory_mutation_lock_busy
terminal_worker_T3.log  2026-09-02T09:30:03Z  claim_declined      factory_mutation_lock_busy
terminal_worker_T10.log 2026-09-02T09:30:40Z  claim_declined      factory_mutation_lock_busy
terminal_worker_T5.log  2026-09-02T09:35:57Z  factory_mutation_lock_busy
```

This is the exact 57-event/15-minute symptom in the decision context. The retained logs no longer contain the detailed `candidate_not_arm_frontier` payload, so that causal link is reconstructed from the prior closeouts plus the current control flow and is proven directly by the regression below; it is not presented as a recovered verbatim log field.

## Fix

`terminal_worker.claim_atomic()` now derives a cheap database-only frontier map from the already materialized canonical pending order. For every governed `(program_id, arm)`, only the smallest `(year, work_item_id)` may reach the cold ledger/hash preflight. A later-year sibling is skipped as `PROGRAM_ARM_FRONTIER_WAIT`. The sealed-ledger `arm_frontier()` check remains authoritative and unchanged.

In addition, a cold preflight refusal increments a per-claim-cycle program counter. After one refusal, all further rows for that program are skipped as `PROGRAM_PREFLIGHT_SUPPRESSED`; another program or ordinary work can flow. A later worker cycle may retry, so a transient lane-lock busy result is not made durable and no row/verdict is rewritten. This bounds one malformed/stale program to one cold refusal and removes the eight-reacquisition stampede shape.

No K, L, G, symbol cap, duplicate-pair rule, declared trial count, selection rule, ledger, cell identity, or Q verdict changed. Exact token revalidation and predecessor fingerprints remain mandatory immediately before the claim CAS.

## Reproducing tests

`test_l2_skips_later_year_and_preflights_actual_arm_frontier` creates one active governed arm plus a later-year row deliberately ordered before its first-year sibling. Under allow-listed L=2 the patched claimant calls cold preflight exactly once for the true first-year head and claims that row.

`test_l2_suppresses_program_after_one_lane_preflight_refusal` creates three distinct candidate arms in one active program and an ordinary tail row. A planted `candidate_not_arm_frontier` refusal is invoked once—not eight times—and the ordinary row is claimed.

Focused regression:

```text
test_terminal_worker_atomic_claim.py
test_dl089_matrix_service.py
test_dl089_same_program_replay.py

120 passed in 100.30s
```

The smaller exact reproducer selection passed `4 passed, 93 deselected`. `py_compile` and `git diff --check` also pass.

## Canary protocol — not executed by this ticket

Current machine scope still contains `DL089_LANES_PER_PROGRAM=2` and the historical three-program allow-list, but the worker spawn environment deliberately does not forward those canary variables. This ticket did not change machine or worker environment, reload workers, or activate a canary.

Any future OWNER-authorized validation must be a fresh, bounded protocol:

1. Select exactly one non-index program from the approved allow-list with at least two authenticated arm heads and no active infrastructure issue.
2. Capture a comparable 60-minute L=1 baseline: `MEASURED` cells/hour, claim attempts, `factory_mutation_lock_busy`, lane-preflight refusal reasons, per-program active lane maximum, and completion/error counts.
3. Through the governed idle-worker reload only, forward `DL089_LANES_PER_PROGRAM=2` and an allow-list containing that one exact program. Keep existing K and G unchanged.
4. Observe for at most 60 minutes. PASS requires: two distinct arms overlap at least once; no same-arm overlap; no token/Q12/declaration mismatch; no `candidate_not_arm_frontier`; at most 10 `factory_mutation_lock_busy` events per rolling 15 minutes; zero `PROGRAM_PREFLIGHT_SUPPRESSED` after the first 10-minute warm-up; and cells/hour at least 90% of the L=1 baseline (with the L=2 program itself not slower).
5. Stop immediately on any correctness violation, any lane-preflight error, more than 10 lock-busy events in 15 minutes, two consecutive 10-minute windows below 80% of baseline throughput, an active-lane count above 2, an active-cell count above G, or a worker/terminal orphan.
6. Roll back by unsetting `DL089_LANES_PER_PROGRAM` and `DL089_SAME_PROGRAM_PARALLEL_ALLOWLIST`, then perform only the governed stopped/idle-worker reload. Never interrupt an active T1–T10 backtest. Verify all reloaded workers report effective L=1 and an empty allow-list.

The canary must produce a separate execution receipt. This implementation receipt alone does not authorize activation.
