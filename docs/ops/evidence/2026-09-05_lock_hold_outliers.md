# Mutation-lock outliers — REVIEW

Task `62f54fa5-5a0c-4ac9-b33d-d2506cfc4681`. Proposal branch `agents/codex-lock-hold-20260905`, commit `bf73cab0d74b276c5fa31104cb187769ce7c25b3`. No worker restart, live claim, queue mutation, lock deletion or terminal action was performed. Evidence is committed only on agents/board-advisor.

## Findings

The reported T10 median is **not a median of completed critical sections**. Fifteen of its 29 busy observations refer to one orphaned lock, nonce `f0bbe73a96bd4ad68b83dbc8e1cfc71f`, acquired at 13:10:12.781595Z by PID 9980. The old worker has no RELEASED receipt. Its last claim attempt begins at 13:09:58.143Z; the log then records replacement worker PID 16100 and generation initialization at 13:10:44.935Z. The replacement itself observes the dead predecessor's lock. The canonical stale-lock reaper records `pid_state=dead`, `owner_pid_dead` and successful reap at 13:12:18.531118Z, age **125.755 seconds**. The termination initiator is not recorded in these inputs; no attribution to a person or particular killer is inferred.

[The nonce-bound orphan evidence](2026-09-05_lock_hold_outliers/t10_orphan.json) preserves all 15 observations and the reaper receipt. Repeated observations of this single orphan produce the 63.081-second busy-observation median. There is no evidence that 29 ordinary T10 claims each held the lock for about a minute.

| Owner, 11:25:20–13:25:20Z | Completed holds | Median completed hold | Maximum completed hold |
|---|---:|---:|---:|
| T10 claim | 128 | 0.344 s | 8.203 s |
| T5 claim | 90 | 0.6875 s | 14.141 s |
| Sweep | 2 | 79.2655 s | 88.609 s |

Completed-hold statistics exclude the orphan and therefore do not erase its 125.755-second exclusion interval. The sweep's paired holds are 69.922 and 88.609 seconds. Its eight busy observations are likewise not eight complete sweep runs. [Diagnosis](2026-09-05_lock_hold_outliers/diagnosis.json) contains the journal rows, worker events, claim payload summaries and 46 copy-on-claim receipts.

Current stat-only inventory finds 4,329 files / 46,397,816,773 bytes under T10 Bases/Custom, versus 4,329 / 46,397,810,158 under T5. These nearly identical totals do not support a special T10 archive-size cause. No history bytes were copied, hashed in bulk or modified. The worker source runs `_privatize_custom_history_claim` after the atomic claim. Copy-on-claim receipts are separately preserved, not conflated with time under the global claim lock.

The sweep's sustained cost is a **query-plan problem inside its long global-lock scope**. Its latest-INFRA-source SELECT uses `idx_work_items_verdict_updated`, walking fleet failure history for each EA/symbol/setfile and sorting ties. A mechanically read-only canonical dry run spent **52.347 seconds in 352 executions of that exact query**, out of 58.938 seconds total. The first dry profile took 77.146 seconds, with 73.856 in SQLite cursor execution; current storage/load variation is visible. The five grouped candidate SELECTs together cost only about four seconds. Directory reads and strategy-score preparation are not the dominant remaining cost.

## Minimal proposal and verification

The sweep source lookup explicitly uses the existing canonical `idx_work_items_ea_phase` index; its predicates, latest-date/id ordering, payload and chosen source are unchanged. A single read-only SQLite transaction replays **all 352 current stranded candidates** before and after. Results match byte-for-byte after JSON serialization, SHA-256 `9196290dff786a06cce4a7b33425d9a1a9b67e5bc550d01ddd9f346657e07789`. Lookup time drops from **61.102531 to 0.054526 seconds**. [The complete keys, query plans and timings](2026-09-05_lock_hold_outliers/source_lookup_equivalence.json) are frozen. No index was created in the live database.

The sweep also releases the mutation lock immediately after its final guarded DB/sidecar writes, before evidence serialization and console output. Its OFF checks, rollback, sidecar ordering, candidate ordering and verdict logic remain intact. The atexit release remains an idempotent fallback. Using the 58.938-second dry profile, replacing only the measured 52.347-second lookup block predicts about **6.65 seconds** for the same whole dry scan. This is an expectation from component timing, not a measured live lock-duration result; applied writes and concurrent storage pressure can add time.

The worker's long-run RAM calculation accepts the already captured process snapshot and existing read connection. Its claim call supplies both, so an expired process-cache entry cannot trigger another OS census or nested connection under the global lock. Active-row selection and RAM arithmetic still use the claim's connection; the measured OS snapshot has the same pre-lock timing as existing commit/RAM admission. This small scope correction is independent of the historical orphan. It does not alter stale-reap thresholds or claim order, and does not prevent a worker being terminated while owning a lock.

**142 focused tests passed, five known baseline failures excluded.** The complete worker/policy run first produced 129 passes and five failures; those same five failures were reproduced with the unmodified baseline worker. They concern two staged-EX5 test fixtures and three existing census/news-policy fixtures. Both full outputs are retained. The new regressions prove no repeated OS process scan under the global lock and identical RAM facts with supplied inputs. The 13 sweep checks include null/empty path equivalence, tied timestamps, status/verdict filters and existing enqueue/fanout behavior. See [focused results](2026-09-05_lock_hold_outliers/focused_tests.json), [initial full results](2026-09-05_lock_hold_outliers/worker_tests.json), and [baseline reproduction](2026-09-05_lock_hold_outliers/baseline_worker_failures.json).

## Review disposition

The performance evidence supports the narrow lookup/index proposal. The task's premise of a routine 63-second T10 claim median is corrected by nonce/reaper evidence. Integration and operational measurement remain a Claude/OWNER close-out. This packet is REVIEW; no pipeline verdict or live after-number is claimed.
