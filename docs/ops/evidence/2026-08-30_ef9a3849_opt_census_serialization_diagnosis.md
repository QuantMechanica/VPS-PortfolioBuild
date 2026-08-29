# OPT_CENSUS effective-single-slot diagnosis

Date: 2026-08-30 (Europe/Berlin; live evidence captured 2026-08-29 23:02-23:12 UTC)
Router task: `ef9a3849-d8a4-4d88-8f6b-e78332a76295`
Scope: diagnosis and governed proposal only; no queue, selection-rule, pruning-rule, EA, terminal, or live-state mutation

## Verdict

The observed one-cell effective parallelism is real. The immediate serialization point is the interaction of the new claim-boundary pruning preflight with the pre-existing duplicate `(ea_id, symbol)` gate:

1. `terminal_worker.claim_atomic()` encounters the first unchecked `OPT_CENSUS` row before it evaluates cheap active-pair eligibility (`terminal_worker.py:2173-2188` versus `2247-2256`).
2. It returns that row for out-of-transaction pruning inspection. All workers converge on the same queue-head row.
3. `_prune_candidate_outside_factory_lock()` admits only one inspector through the single farm-wide non-blocking `DL089_CLAIM_PRUNING.lock`; peers receive `busy` (`terminal_worker.py:4746-4771`).
4. Whether the inspection was `checked`, `busy`, `stale`, or errored, the caller sets the process-local scalar `skip_unchecked_pruning=True` after this one attempt (`terminal_worker.py:2464-2489`). On the retry, every other unchecked census row is skipped (`terminal_worker.py:2175-2182`).
5. If one cell for the queue-head census pair is already active, the checked next row reaches the later `(ea_id, symbol)` test and is skipped. Because `skip_unchecked_pruning` is now global to the claim cycle rather than scoped to that candidate/program, the worker cannot reach an independent GBP/EUR program in the same cycle.

This creates an emergent farm-wide one-census-slot clamp even though the intended duplicate gate is only per `(ea_id, symbol)`. Commit `68b8acfc75` introduced the relevant pruning preflight/skip code on 2026-08-29; the duplicate-pair guard predates it. The 10-second fleet claim-spacing guard is not the limiting rate when cells take roughly 6-13 minutes.

Two additional clamps exist but do not explain the exact last-six-hour single-slot trace by themselves:

- `dl089_matrix_service.service_pending()` deliberately elects one `existing_owner`, maintains only that ledger, and reports every other ready Q12 program as `PAIR_SERIALIZATION_WAIT:<owner>` (`dl089_matrix_service.py:981-1048`). This prevents the governed service from advancing/top-up-maintaining multiple programs.
- `opt_census.boost()` is a queue-priority window, not an execution semaphore (`opt_census.py:626-690`). It counts active plus pending flagged rows and only adds `priority_track`; it creates no cell dependency. Furthermore, the live USDJPY and GBP queues have a later orchestrator-wide priority override on essentially every pending cell, so the normal eight-cell window is not their current bottleneck. EUR still exposes normal window behavior: five unresolved priority cells remain after three measurements and twelve deterministic skips, with no top-up while GBP owns the serial service.

## Live evidence

### Queue and throughput snapshot

Read-only queries against `D:/QM/strategy_farm/state/farm_state.sqlite` found:

| Program | Measurement EA / symbol | MEASURED | SKIPPED_EXCLUDED | Pending | Latest measured at capture |
|---|---|---:|---:|---:|---|
| `DL089_QM5_41097_USDJPY_DWX_2019_2025` | `QM5_41097 / USDJPY.DWX` | 231 | 0 | 854 | `2026-08-29T23:08:35+00:00` |
| `DL089_QM5_10706_GBPUSD_DWX_2019_2025` | `QM5_41161 / GBPUSD.DWX` | 74 | 0 | 1,011 | `2026-08-29T16:40:00+00:00` |
| `DL089_QM5_11421_EURUSD_DWX_2019_2025` | `QM5_41162 / EURUSD.DWX` | 3 | 12 | 1,070 | `2026-08-29T12:21:38+00:00` |
| `DL089_QM5_20266_XTIUSD_DWX_2019_2025` | `QM5_41198 / XTIUSD.DWX` | 0 | 0 | 1,085 | not started |

Total at the snapshot was 308 `MEASURED`, 12 governed `SKIPPED_EXCLUDED`, and 4,020 pending. A point-in-time active census row may disappear between queries because a cell completes, but the six-hour terminal history is stable: exactly 40 `OPT_CENSUS/MEASURED` completions, all USDJPY, from `17:17:01` through `23:08:35` UTC. The cells advanced serially through the USDJPY 2020 sell arm sequence. That is 6.67 census cells/hour.

At 23:12 UTC the correctly normalized six-hour all-phase count was 152 `done` plus 3 `failed` rows, or 25.83 terminal rows/hour. This corroborates the task's approximately 26/hour total-farm finding and rejects the previously reported hundreds-per-hour interpretation.

The initial `farmctl health` snapshot at 23:02 UTC reported 10/10 worker daemons alive, 8 active rows, and 6 fresh work-item logs. A later read-only DB point found only five active terminal rows while 4,020 census cells remained pending. Capacity therefore existed; backlog absence was not the explanation.

### Governed matrix service dry-run

The read-only command

```powershell
python -u C:/QM/repo/tools/strategy_farm/farmctl.py service-dl089-matrix
```

returned:

- `pair_mode: SERIAL`, `priority_window_cap: 8`;
- maintained owner `1a92b33e-e34f-532e-80b3-e0144f3b3755` (GBP), state `ENQUEUED`, `measured: 74`, `pending: 1011`, `waiting: true`;
- EUR row `c4bc189b-372d-54c9-be45-046ac77b245b` deferred with `PAIR_SERIALIZATION_WAIT:1a92b33e-e34f-532e-80b3-e0144f3b3755`;
- both measurement Q02 prerequisites exist and are `done/PASS`: GBP `7cd3787a-39df-5ac2-8e7d-c2e29bd258bc` (`QM5_41161`) and EUR `77544e3e-93b8-5690-9cf9-a174b7db2091` (`QM5_41162`).

## GBP/EUR parent-chain classification

The aggregate `parent_missing` signal is true only in the wrong table namespace; it does not mean the governed Q12 parents are absent.

| Program | Q12 parent row | Live row state | Generic `tasks` row with same ID | Classification |
|---|---|---|---|---|
| GBP | `work_items.id=1a92b33e-e34f-532e-80b3-e0144f3b3755` | `analytic/Q12`, pending, governed matrix row, active rollout hold | absent | **wedged/starved owner**, not missing-parent wait |
| EUR | `work_items.id=c4bc189b-372d-54c9-be45-046ac77b245b` | `analytic/Q12`, pending, governed matrix row, active rollout hold | absent | **intentionally waiting under current SERIAL service**, not missing-parent wait |

Every materialized matrix cell stores the Q12 `work_items.id` in `work_items.parent_task_id` and also carries `q12_work_item_id` in its payload. When a terminal finishes a cell, `_finish_work_item()` calls `_aggregate_finished_parent()` (`terminal_worker.py:3929-3944`). That delegates to `farmctl.aggregate_finished_parent_cas()`, which looks exclusively in `tasks WHERE id=?` (`farmctl.py:10997-11001`). The lookup therefore emits `parent_missing` for a Q12 work-item parent that demonstrably exists. Claim ordering does not check parent existence, and the DL-089 service advances/finalizes from its ledger and Q12 work-item directly, so this misleading aggregate result is not the claim blocker.

These rows are not produced by a generic "Pattern-Kette v5 50er-Schritte" dependency chain. The OWNER-approved Q12 misrun disposition names `1a92b33e...` and `c4bc189b...` as the authorized measuring successors (`decisions/2026-08-26_owner_q12_disposition_ftmo_position.md`). `dl089_matrix_service` validates/seeds a measurement-sibling Q02 prerequisite, then materializes the sealed census ledger beneath the Q12 work item (`dl089_matrix_service.py:807-867`). The sealed plan is 155 annual cells per year (one baseline plus 77 predicates times two directions) over seven years = 1,085 cells, followed by four walk-forward combination checks and two final confirmations (`PATTERN_FILTER_WF_OPT_PLAN_V3_2026-08-21.md:52-75`). There is no database parent chain from one census cell to the next. The only data dependency relevant to pruning is an earlier measured year for the same `(program_id, arm)`.

Consequently:

- GBP is the service's elected owner and should be progressing, but its last measurement was more than six hours old while another program monopolized the census claim path: it is wedged/starved.
- EUR is correctly deferred according to the currently coded serial-owner policy. That policy is itself the governed throughput clamp proposed for review below; EUR is not waiting for a missing row.
- The `Q12_DL089_MATRIX_WORKER_ROLLOUT_PENDING` holds protect the analytic Q12 declarations from generic terminal claims. They do not hold the already-materialized `OPT_CENSUS` children.

## Governed parallelization proposal — do not implement without review

### Bounded program parallelism (recommended first change)

Introduce a fixed `DL089_PROGRAM_SLOTS` cap, initially 4 and never larger than available ordinary terminal capacity. Keep **one active cell per `(program_id, measurement ea_id, symbol)`**. This permits independent programs to use separate workers while retaining the existing duplicate `(ea_id, symbol)` protection inside each program.

Required claim-path changes:

1. Apply deterministic cheap eligibility checks (active duplicate pair, symbol cap, terminal avoidance, launch cooldown, and holds) before requesting the expensive pruning preflight. A currently active USDJPY pair must not consume the only pruning budget for an idle worker.
2. Replace scalar `skip_unchecked_pruning` with candidate-scoped deferral. A busy/stale candidate may be skipped for that claim attempt, but it must not make every other program's unchecked census rows invisible.
3. Key pruning coordination by `program_id` (or by authenticated ledger identity) rather than one farm-wide lock. Retain compare-and-set fingerprint validation. Permit at most one pruning inspector per program and at most `DL089_PROGRAM_SLOTS` concurrent program owners.
4. Change the matrix service from one `existing_owner` to the first K governed owners in canonical `_queue_order`; maintain/top up each owner's eight-cell window. Do not bulk-mark all cells priority. Report explicit per-program slot ownership and deferral.
5. Preserve the existing within-program candidate order. Do not introduce same-program parallel cells in this first change.

### Invariants argument

This proposal changes only cross-program interleaving:

- Pruning reads and writes are scoped by `program_id` and `arm` (`opt_census_pruning.py:492-523`). Different programs have disjoint work-item IDs, ledgers, receipt directories, and selection states, so their transactions commute.
- One active cell per program preserves the current within-program execution order and prevents a later same-arm year from racing its earlier-year pruning trigger.
- The authenticated amendment hash, activity floor, years, walk-forward windows, `declared_trial_count=154`, cell identities, setfiles, and selection driver are untouched.
- A cell remains claimable only after the same authenticated pruning backstop. Candidate fingerprint revalidation and the pending-row compare-and-set remain mandatory.
- `SKIPPED_EXCLUDED` receipts remain append-only and identical in content rules. Active downstream rows remain untouched as required by Amendment 1.
- Selection still runs independently from each sealed ledger only after its required evidence is terminal. Cross-program completion order is not an input to any ledger's selection rule.
- Existing global claim spacing, commit/RAM admission, symbol cap, news limits, Factory OFF lock, and terminal reservations remain binding. The K cap is an additional ceiling, not a bypass.

Acceptance can therefore compare a replay of the same sealed fixture under serial and K-program scheduling and require byte-identical per-program terminal dispositions, pruning receipts (apart from permitted timestamps), selected cells, and evidence hashes before rollout. A second stage that allows multiple cells within one program would require a separate proof and is not proposed here.

## Mixed-timestamp audit

`work_items.updated_at` currently contains 115,965 `T`-separated values and 84 space-separated values. The known canonical writer still capable of producing a space-separated value is `reclassify_invalid_reports.py:138` (`updated_at=datetime('now')`); historical/operator SQL can do the same.

SQLite text comparison does not parse timestamps. For a same-day comparison, every string beginning `YYYY-MM-DDT...` sorts after `YYYY-MM-DD ...`, regardless of hour. Conversely, a space-formatted recent row sorts before an ISO-`T` cutoff and can be dropped. At 23:11 UTC:

| Window/query | All rows | `done` | `failed` | `OPT_CENSUS MEASURED` |
|---|---:|---:|---:|---:|
| naive `updated_at >= datetime('now','-1 hour')` | 2,623 | 311 | 7 | 94 |
| normalized one hour | 51 | 24 | 1 | 7 |
| naive `updated_at >= datetime('now','-6 hours')` | 2,623 | 311 | 7 | 94 |
| normalized six hours | 1,276 | 152 | 3 | 40 |

The normalized predicate used for the audit was:

```sql
datetime(replace(substr(updated_at,1,19),'T',' ')) >= datetime('now','-6 hours')
```

`datetime(updated_at) >= datetime(...)` is also safe for the timestamp shapes currently stored. Raw `updated_at >= ?` is not format-independent even when the parameter itself is ISO-8601.

### Affected dashboard, alert, and metric surfaces (flagged; no code changed in this task)

| Surface | Raw comparison locations | Impact |
|---|---|---|
| split execution throughput and claim latency | `throughput_telemetry.py:144-152,254-262` | recent execution counts/rates and latency sample can omit space rows; feeds health/cockpit |
| headless heartbeat factory rate and verdict mix | `heartbeat_snapshot.py:108-125` | `done_1h`, low-throughput alarm, and verdict mix can omit space rows |
| mission-control progress windows | `mission_control_v2_data.py:551-563` | 8-day progress buckets can omit same-day space rows; its separate ETA query at 763 is normalized and safe |
| morning brief factory light | `morning_brief.py:1003-1009` | trailing-24h INFRA share can omit space rows |
| health recent-state checks | `health.py:615-619,648-652,735-739,819-829,1755-1759,2112-2116,2347-2364,2402-2414,2532-2536,3770-3782,3830-3834,3934-3940` | auth/build activity, review rate, stagnation, SQLite crashes, Q03+ progress, infra graveyard, task aging/limbo, and Q02 classifier windows use raw lexical cutoffs |
| cockpit next-book frontier | `render_cockpit.py:1175-1195` | fresh-pass frontier uses a raw static ISO cutoff |
| concurrency A/B report | `concurrency_ab_measure.py:139-152` | windowed terminal throughput/occupancy sample can omit space rows |
| near-miss report | `near_miss_register.py:111` | recent terminal candidate set can omit space rows |
| NEWS and optimization service metrics | `news_gate_service.py:155`, `optimization_fork_driver.py:976` | trailing completion rates can omit space rows |
| Q08 book reoptimizer pool | `portfolio/book_reoptimizer.py:39` | selection pool uses a raw date cutoff; less separator-sensitive at a midnight date boundary but still lexical |
| evidence cohort watch | `evidence_cohort_watch.py:97-105` | recent evidence sample uses a raw date-only cutoff; same boundary caveat |
| WS0 notification | `ws0_notifier.py:51` | first-verdict alert can misorder/omit a mixed-format boundary row |
| work-item log pruner | `prune_workitem_logs.py:158` | not a dashboard, but raw age classification affects cleanup scope and must be normalized before any destructive retention decision |

Additional raw lexical comparisons used for operational ordering rather than a recent-window dashboard (for example `blocked_backlog_retest.py:161` and raw `ORDER BY updated_at` tie-breaks) should be included in the same follow-up normalization ticket, but they did not produce the broken throughput number analyzed here.

Known normalized/safe examples that should be used as the pattern are `factory_watchdog.ps1:934`, `farmctl.py:14508`, `health.py:1807`, `mission_control_v2_data.py:763`, and `health.py:3999`.

## Focused verification

The diagnosis was checked without queue mutation:

1. `farmctl health` completed from the canonical script and reported the live worker/queue snapshot summarized above.
2. `farmctl service-dl089-matrix` was run without `--apply`; it returned the GBP serial owner, EUR serialization wait, and both PASS prerequisites.
3. Read-only SQLite queries established the per-program counts, exact row IDs, Q12 parent existence, absent same-ID `tasks` rows, active holds, six-hour program identity, and timestamp-format distribution.
4. Focused tests for Amendment 1 pruning, OPT_CENSUS dispatch/window behavior, and the out-of-global-lock pruning preflight completed `28 passed in 34.17s`.

## Review decision requested

Approve a separate implementation ticket for bounded cross-program parallelism plus timestamp normalization/regression fixtures. Do not change DL-089 selection rules, declared trial count, activity floor, pruning amendment, cell definitions, or pipeline verdict logic. The present task intentionally leaves runtime code and live queue state unchanged.
