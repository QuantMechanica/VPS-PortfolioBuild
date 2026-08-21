# Built-but-never-gated skip audit — 2026-08-21

## Scope

Router task `a3ba2414-0248-4aed-ae47-e60d30a02a35` requested a guarded pass over the built-but-never-gated backlog. The existing `sweep_enqueue_built_eas.py` mechanism was used in its default dry-run mode. No registry, queue, verdict, or work-item state was changed.

## Dry-run result

The sweep reported one otherwise-enqueueable never-tested candidate and one stranded candidate, but refused the remaining candidates under existing guards:

| Cohort / reason | Count |
|---|---:|
| Part 1 candidates enqueued by dry-run simulation | 1 |
| Part 1 candidates skipped | 769 |
| Part 2 candidates enqueued by dry-run simulation | 1 |
| Part 2 candidates skipped | 664 |
| `review_entry_gate` | 49 |
| `registry_status=retired` | 8 |
| `no_ex5` | 200 |
| `requeue_excluded_q0223` | 23 |
| `no_setfiles` | 234 |
| `registry_status=None` | 239 |
| `registry_status=allocated` | 1 |
| `symbol_not_in_dwx_matrix` | 1 |
| `registry_status=pending` | 12 |
| `registry_status=build_test` | 1 |
| `registry_status=backtest-only` | 1 |

The part-2 refusal summary included one `Q07` candidate. Deferred promotion changed no rows (`promoted=0`, `kept=8`).

## Missing-registry classification

The 239 `registry_status=None` rows were evaluated against the compiled artifact, setfile, approved-card, and active-magic prerequisites:

- 100 have a compiled EX5.
- 5 have setfiles.
- 230 have an approved card.
- 7 have an active magic row.
- Only four satisfy all four conditions: `QM5_1627`, `QM5_1628`, `QM5_1630`, and `QM5_2245`.

Those four are plausible deterministic registry-backfill candidates, but the registry is authoritative and must not be hand-edited. The remaining 235 missing-registry rows fail at least one prerequisite and are not safe enqueue candidates.

## Before / after

| Measure | Before | After | Delta |
|---|---:|---:|---:|
| Persisted work items enqueued by this task | 0 | 0 | 0 |
| Registry rows changed by this task | 0 | 0 | 0 |
| Existing verdicts overwritten | 0 | 0 | 0 |

## Disposition

`PARTIAL_DEFER_REGISTRY_BACKFILL`. The dry run produced an explicit refusal audit without weakening any guard. Applying the two simulated queue writes before resolving authoritative registry identity would not drain the stated 304-EA cohort safely. The four plausible missing-registry candidates are deferred to a deterministic, auditable backfill path; all other skip classes remain upstream build, setfile, approval, status, symbol-matrix, or review-gate work.
