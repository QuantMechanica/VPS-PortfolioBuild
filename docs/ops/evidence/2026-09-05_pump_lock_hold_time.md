# Pump mutation-lock hold-time implementation — 2026-09-05

Router task: `d7cedd80-558a-40d3-8b22-cd886723b855`

Verdict: **PASS — REVIEW required.** The change does not alter verdict rules,
claim ordering, or the DL-089 K/L/G scheduling constants. It adds per-stage
lock telemetry, moves whole-population read/classification work outside the
global mutation lock, and uses exact-primary-key revalidation for short writes.

## Implementation

- `PumpCycleBudget` now attributes each `FACTORY_MUTATION.lock` acquisition to
  the active stage and reports `lock_held_seconds`, `lock_acquisitions`, and
  `lock_owners` in both the compatibility `stage_timings` object and the new
  `pump_stage_timings` object.
- The pump attempts a bounded two-second append of a structured
  `pump_stage_timings` event. Contention is explicit in
  `pump_stage_timing_event`; it never stalls the next scheduled cycle.
- Q08 stream recovery performs its full Q14 discovery and bundle/identity
  classification on a read-only connection outside the lock. Each selected
  Q14 primary key is then re-read under a short lock before append-only enqueue,
  event, and watermark writes. The lock is released between triggers.
- The DL-089 matrix wrapper performs full recovery/Q02/candidate/K-window
  classification read-only. It preserves the resulting K-sized slot-owner
  order, then revalidates and writes one exact Q12 program (or recovery) per
  lock acquisition, releasing the lock between programs. Non-PASS Q02
  prerequisites retain their previous seeding behavior; PASS candidates beyond
  K are not materialized.
- The scheduled wrapper's 55-repository/10k-file worktree audit was already
  before the `farmctl pump` process and therefore outside the mutation lock.
  Measurement-sibling resolution, queue/recovery classification, and health
  were likewise confirmed not to be enclosed by a pump-wide mutation lock.
  No extra lock was introduced around them.

Stages moved out of a long hold by this patch:

1. `dl089_matrix_service`: recovery discovery, Q02 prerequisite discovery,
   program binding checks, active-program snapshot, and K/L/G owner selection.
2. `q08_stream_auto_rerun`: Q14 population scan, retry/new split, and bundle
   eligibility checks.

## Live before/after observation

The comparison uses adjacent scheduler-owned cycles; no terminal or backtest
was interrupted and no manual pump was started.

| Stage | Before `070801Z` (s) | After `071801Z` (s) | After lock held (s) |
|---|---:|---:|---:|
| dispatch_tick | 1.125 | 0.750 | 0.000 |
| process_reap | 0.000 | 0.000 | 0.000 |
| magic_resolver | 0.000 | 0.015 | 0.000 |
| artifact_auto_commit | 0.656 | 0.500 | 0.000 |
| dl089_frontier_refill | 1.500 | 1.204 | 0.000 |
| optimization_fork | 7.547 | 7.312 | 0.000 |
| dl089_matrix_service | 35.828 | 41.953 | 0.000 |
| optimization_fork_service | 0.188 | 0.203 | 0.000 |
| q08_stream_auto_rerun | 0.312 | 0.328 | 0.000 |
| measurement_sibling_resolution | 0.922 | 0.969 | 0.000 |
| measurement_sibling_hold_record | 4.359 | 4.250 | 0.000 |
| promotions | 8.078 | 8.985 | 0.000 |
| pre_promotion_automation | 1.953 | 2.281 | 0.000 |
| news_expansions | 31.219 | 23.828 | 0.000 |
| owner_source_lineage_backfill | 0.110 | 0.094 | 0.000 |
| queue_maintenance_and_intake | 63.922 | 46.921 | 0.000 |
| build_dispatch | 53.344 | 62.469 | 0.000 |
| reviews_and_research | 80.047 | 75.250 | 0.000 |
| q09_autoseal | 7.828 | 6.328 | 0.000 |
| **whole cycle** | **299.594** | **284.578** | **0.000** |

The after cycle needed no matrix program mutation and no Q08 enqueue, so the
new telemetry correctly reports zero acquisitions instead of treating the
41.953-second matrix classification as lock-held time. The before version had
no stage-level hold telemetry. In the matching worker-log windows,
`claim_declined/factory_mutation_lock_busy` fell from 5 (`07:08:01Z` through
`07:13:18Z`) to 3 (`07:18:01Z` through `07:23:03Z`). This is a short live
observation, not a throughput claim.

## Verification

- `python -m py_compile` on `farmctl.py`, `pump_budget.py`,
  `factory_mutation_lock.py`, and `q08_stream_rerun.py`: PASS.
- `pytest test_pump_lock_scope.py test_q08_stream_rerun.py
  test_dl089_matrix_service.py test_factory_mutation_lock.py -q`: 52 PASS after
  the single test correction for the existing Factory-OFF fast path.
- `pytest test_farmctl_cascade.py -q`: 58 PASS plus 13 subtests; no cascade
  policy or ordering regression.
- Commit `8e1703cd8f`: implementation and tests.
- Commit `7222a58cb1`: bounded structured-event retry.

Rollback is the two commits above. No K/L/G constant, verdict, hold, claim
predicate, or running work item was changed.
