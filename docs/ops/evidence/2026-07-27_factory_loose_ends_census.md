# Factory loose-ends census

Date/time sampled: 2026-07-27 12:09-12:25 UTC  
Router task: `621d3c75-83a7-4dae-9d61-d5bd446b23ab`  
Scope: census only; no work-item requeue or mutation

## Operational definition

A row is stuck when it cannot make progress without an out-of-band event:

1. `pending` longer than its queue service horizon;
2. `active` without its recorded live process;
3. terminal-state evidence labelled as retryable infrastructure, or retryable
   infrastructure with no bounded retry/repair route;
4. an agent task in a state the deterministic router does not select;
5. a gate whose dominant output is missing/invalid evidence rather than a
   strategy measurement;
6. any workflow dependent on a human noticing, launching, approving, or
   repairing it.

This distinguishes old rows from stuck rows: an old work item may be actively
running after a requeue, and an old terminal verdict is closed rather than
stuck.

## Ranked findings

| Rank | Volume | Loose end | Operational impact |
|---:|---:|---|---|
| 1 | 43,422 failed Q02 rows | `summary_missing_retries_exhausted` labelled `INFRA_FAIL` | Dominates all recorded factory failures; neither strategy verdict nor useful retry classification |
| 2 | 49,888 Q02 rows overall | Q02 `INFRA_FAIL` (68.3% of all Q02 rows) | Historical evidence production overwhelms strategy measurement |
| 3 | 2,063 pending; 1,458 >14d; 325 >30d | Old open queue, principally Q02 | Queue is draining recently, but inherited tail is not FIFO-resolving |
| 4 | 430 tasks | `RECYCLE` has no router exit | 411 are `build_ea`; oldest 2026-05-28 |
| 5 | 206 tasks | `APPROVED` has no router exit | Oldest 2026-05-29; state diagram and implementation disagree |
| 6 | 209/530 Q08 rows | `INFRA_FAIL`; 70/189 evaluated streams lack `entry_time` | Late-stage evidence remains incomplete; screening score is unavailable for 37.0% of known streams |
| 7 | 94 + 81 known cases | Q08 `8.5_neighborhood artifact_missing`; `8.7_pbo got=0` | Systematic evidence defects can wear strategy verdicts |
| 8 | 59 tasks | `PIPELINE` has no router exit | Oldest 2026-05-26; requires a separate pump/manual transition |
| 9 | 9 approved + 4 pipeline artifact paths | Directory used where a file artifact is expected | Broad guardrail scans/timeouts and ambiguous review evidence |
| 10 | 8 interactive scheduled jobs currently `0x800710E0` | Interactive tasks queue but do not execute | Includes worker dedupe, self-heal/governor, mailbox and live supervisor dependencies |
| 11 | 84 latest Q09 EA verdicts: 53 FAIL, 25 PASS, 6 NEED_MORE_DATA | Latest Q09 failure rate 63.1% | Q09 is selective, not literally rejecting everything, but its current qualifying book can still be all-fail |
| 12 | 1 task type | `pipeline_run` requires capability `pipeline`; no enabled agent declares it | Deterministically unroutable |

## 1. Work-item flow

### Current inventory

| Phase | Pending | Active | Done | Failed |
|---|---:|---:|---:|---:|
| Q02 | 2,004 | 2 | 23,940 | 47,048 |
| Q03 | 26 | 0 | 11,917 | 731 |
| Q04 | 23 | 2 | 15,169 | 144 |
| Q05 | 1 | 2 | 764 | 93 |
| Q06 | 1 | 0 | 373 | 0 |
| Q07 | 9 | 1 | 312 | 1 |
| Q08 | 0 | 1 | 489 | 40 |
| Q09 | 0 | 0 | 111 | 0 |
| Q10 | 0 | 0 | 41 | 0 |

There are 2,063 pending and eight active rows. Counts changed during the sample
because the fleet remained saturated; this document uses a consistent query
snapshot for each table rather than pretending the DB was quiescent.

### Arrival versus completion

Arrival = `created_at` in window. Completion = `updated_at` in window while
status is `done` or `failed`. A completion may drain a row created before the
window, so completion greater than arrival is the desired backlog-drain signal.

| Phase | 7d arrivals | 7d completions | Net | 30d arrivals | 30d completions | Net |
|---|---:|---:|---:|---:|---:|---:|
| Q02 | 2,233 | 3,918 | -1,685 | 10,238 | 11,351 | -1,113 |
| Q03 | 456 | 462 | -6 | 2,306 | 2,289 | +17 |
| Q04 | 688 | 800 | -112 | 4,458 | 5,240 | -782 |
| Q05 | 92 | 120 | -28 | 597 | 746 | -149 |
| Q06 | 52 | 60 | -8 | 291 | 292 | -1 |
| Q07 | 50 | 66 | -16 | 255 | 248 | +7 |
| Q08 | 54 | 80 | -26 | 380 | 394 | -14 |
| Q09 | 21 | 22 | -1 | 85 | 86 | -1 |
| Q10 | 39 | 39 | 0 | 41 | 41 | 0 |

Conclusion: the queue is draining overall now. Q03 and Q07 grew by 17 and
seven rows over 30 days, but both reversed to drain over seven days. The
primary leak is historical failure classification and tail selection, not
current aggregate arrival rate.

### Age and stranded pairs

- 1,458 pending rows are older than 14 days; 325 are older than 30 days.
- Q02 accounts for 1,429 of the >14-day pending rows and 318 of the >30-day
  rows.
- Open rows date to 2026-05-23. Examples include QM5_10718 EURUSD, QM5_10028
  XAUUSD, QM5_10091 XAUUSD, and the multi-symbol fan-out of QM5_10050.
- Deep-stage old rows exist: six pending Q04 rows and one pending Q07 row are
  >30 days by `created_at`.

Many rows have recent `updated_at` due to requeue/parking while retaining their
original `created_at`. This proves repeated handling but not forward progress.
The queue needs a surfaced `age_since_last_claim`/`last_terminal_attempt`
metric, not only creation age.

### Active-claim liveness

All eight active rows had a live recorded runner PID at the process-scan
instant:

| Phase | EA | Terminal | Runner PID live |
|---|---|---|---|
| Q02 | QM5_10360 | T2 | yes |
| Q02 | QM5_20144 | T3 | yes |
| Q04 | QM5_11063 | T8 | yes |
| Q04 | QM5_20146 | T10 | yes |
| Q05 | QM5_10115 | T1 | yes |
| Q05 | QM5_20010 | T7 | yes |
| Q07 | QM5_12834 | T4 | yes |
| Q08 | QM5_10440 | T6 | yes |

Orphaned active claims at this instant: **zero**. This validates the brief's
warning that DB PIDs alone are insufficient; the result came from a live
process scan.

## 2. Failed-row classification

`status=failed` contains no genuine PASS/FAIL strategy verdicts in Q02-Q08.
It is almost entirely recoverable infrastructure, deterministic invalid input,
explicit retirement/supersession, or parked symbol repair. Therefore these
48,057 rows must not be counted as terminal strategy judgments.

| Phase | Failed | Recoverable infra | Deterministic invalid/retired/parked | Largest class |
|---|---:|---:|---:|---|
| Q02 | 47,048 | 44,760 | 2,288 | 43,422 `summary_missing_retries_exhausted` |
| Q03 | 731 | 625 | 106 | 299 `summary_missing_retries_exhausted` |
| Q04 | 144 | 7 | 137 | 80 obsolete symbol; 56 parked/NULL |
| Q05 | 93 | 3 | 90 | 90 parked NDX rebuild |
| Q07 | 1 | 0 | 1 | parked NDX repair |
| Q08 | 40 | 40 | 0 | 35 `phase_runner_invalid_report` |

Q02's recoverable bucket is not homogeneous:

- 43,422 summary missing after retries;
- 358 active timeouts;
- 223 summary missing without exhausted label;
- 205 OnInit/incomplete runs;
- 135 shared-bases lock retry exhaustion;
- 106 EX5 missing incorrectly labelled infra;
- 103 setfile missing incorrectly labelled infra;
- 92 no-history/incomplete.

The 43,422 historical summary-missing rows are the volume-first repair target.
They require cohorting by runner version/date and evidence existence before
any OWNER-authorized requeue. Requeueing all would swamp a 2,004-row Q02 queue
and is expressly out of scope.

## 3. Gate census

Terminal fraction = (`done` + `failed`) / all rows. “Bounce” is the historical
fraction labelled `INFRA_FAIL`; it includes attempts subsequently recovered
and therefore measures evidence friction, not current open rows.

| Gate | Rows | Terminal | Bounce (`INFRA_FAIL`) | Pass-like | Strategy-fail-like | Largest blocker |
|---|---:|---:|---:|---:|---:|---|
| Q02 | 72,995 | 97.3% | 68.3% | 11,862 | 6,256 | summary missing |
| Q03 | 12,674 | 99.8% | 15.6% | 10,146 | 410 | summary missing / OnInit |
| Q04 | 15,338 | 99.8% | 10.1% | 811 | 12,786 | net-PF fold failures; obsolete symbol contamination |
| Q05 | 860 | 99.7% | 7.4% | 325 | 362 | 90 parked NDX rows |
| Q06 | 374 | 99.7% | 1.9% | 321 | 45 | no large infra cohort |
| Q07 | 323 | 96.9% | 3.7% | 242 | 58 | nine pending; one old >30d |
| Q08 | 530 | 99.8% | 39.4% | 18 | 301 | invalid/missing evidence |
| Q09 | 111 | 100% | 0% | 36 | 62 | portfolio qualification |
| Q10 | 41 | 100% | 0% | 40 | 1 | no systemic blocker measured |

Q08 is the clearest late-stage evidence-production defect:

- 209 historical `INFRA_FAIL`;
- 35 of 40 failed rows are `phase_runner_invalid_report`;
- known subgate cohorts: 94 missing neighborhood artifacts and 81 PBO runs
  with zero distinct configs;
- 70 of 189 known streams lack `entry_time`, so FUND_SCORE must correctly
  remain `UNSCORABLE`.

Q09 is not rejecting everything by construction across history: latest-per-EA
results are 53 FAIL, 25 PASS and six NEED_MORE_DATA. The narrower current FTMO
qualifying book may still be all-fail; that is a portfolio-input finding, not
proof the gate is mechanically impossible.

No work-item rows for a separate named Q11 exist in this state database.
Operator-facing phases remain Q-only; Q09/Q10 are the last recorded gates.

## 4. Agent-task census

| State | Count | Oldest update | Router selects it? |
|---|---:|---|---|
| APPROVED | 206 | 2026-05-29 | no |
| BLOCKED | 37 | 2026-06-02 | no |
| FAILED | 1 | 2026-07-10 | no |
| IN_PROGRESS | 3 | 2026-07-27 | already claimed |
| PASSED | 22 | 2026-05-26 | terminal |
| PIPELINE | 59 | 2026-05-26 | no |
| RECYCLE | 430 | 2026-05-28 | no |
| REVIEW | 2 | 2026-07-27 | close-review only |

Mechanism:
`tools/strategy_farm/agent_router.py:520-526` selects only
`state IN ('BACKLOG','TODO')`. Consequently `RECYCLE`, `APPROVED` and
`PIPELINE` have no exit through the deterministic router. Their large, old
populations demonstrate that auxiliary pump/reviewer transitions are not a
reliable exit path in practice.

Largest stranded task cohorts:

- `build_ea/RECYCLE`: 411;
- `ops_issue/APPROVED`: 87;
- `research_strategy/APPROVED`: 48;
- `review_ea/APPROVED`: 32;
- `review_strategy/APPROVED`: 27;
- `triage_failure/PIPELINE`: 26;
- `build_ea/PIPELINE`: 19.

`pipeline_run` is structurally unroutable:
`agent_router.py:63` requires capability `pipeline`, while no enabled agent in
the status registry declares `pipeline`. Its sole row is already in RECYCLE,
another state the router never selects.

The schema permits task types not present in `TASK_TYPE_CAPABILITIES` when
explicit capabilities are supplied. No other currently queued BACKLOG/TODO
row exposed `no_available_agent`; `route-many` returned `no_routable_task`.
This does not absolve old non-routable states.

## 5. Artifact-contract failures

Direct filesystem classification of task artifact fields found:

- nine APPROVED tasks whose artifact is a directory;
- four PIPELINE tasks whose artifact is a directory;
- one PASSED and one RECYCLE task whose artifact is a directory;
- 87 artifact paths in non-review states that do not currently resolve
  (74 RECYCLE, eight APPROVED, three PASSED, two PIPELINE).

The close-review multi-path bug was fixed, but artifact type is still not
enforced. A directory passed to build guardrails expands validation scope to a
whole EA tree and can time out. The contract needs `artifact_kind` or
task-type-specific path validation before guardrail invocation.

## 6. Manual intervention census

Current manual or session-coupled dependencies:

1. Eight relevant Interactive scheduled tasks show `0x800710E0`, including:
   `QM_Live_MT5_SessionSupervisor`, `QM_StrategyFarm_AgyGovernor`,
   `QM_StrategyFarm_CodexFleetPacer`,
   `QM_StrategyFarm_GeminiOrchestration_15min`,
   `QM_StrategyFarm_MailboxSourceIntake_Daily`,
   `QM_StrategyFarm_WorkerDedupe`, `QM_T_Live_AtLogon`, and
   `QM_WorkItemLogPruner_Daily_0310`.
2. The SYSTEM watchdog succeeds, but delegates a healing action to the
   Interactive live supervisor, which queues rather than starts.
3. T5 remains disabled after a fresh tester-tree probe failed identically; a
   staged whole-instance comparison/rebuild needs an explicit rollback
   manifest.
4. Q02's 43k summary-missing cohort needs OWNER capacity authorization after
   evidence-aware classification; bulk requeue is unsafe.
5. The 25 fabricated build tasks were triaged separately this cycle: four
   source-backed cards were unblocked, two require source, and 19 should
   retire. The individual BLOCKED rows still require governed disposition.
6. Review close and APPROVED/PIPELINE promotion depend on auxiliary processes,
   not the router state machine.

## 7. What to fix next

Measured-volume order:

1. **Q02 summary-missing classifier and detector.** Split rows into evidence
   exists/runner-version defect/transient/no-artifact; add a health counter.
   Do not requeue in the fix.
2. **RECYCLE exit semantics.** Define whether RECYCLE returns to BACKLOG,
   creates a child, or retires; implement one bounded transition with age
   detection.
3. **Old pending selection.** Surface last-claim age and verify claim ordering
   does not indefinitely bypass the 325 >30-day rows.
4. **APPROVED/PIPELINE reconciliation.** Make the owning transition explicit
   and alert on age; do not let 265 tasks rely on invisible pump behavior.
5. **Q08 evidence contract.** Enforce required subgate artifacts/config count
   and `entry_time` at production, classifying deterministic insufficiency as
   INVALID rather than retryable infra.
6. **Artifact path type validation.** Refuse a directory where a task requires
   one evidence file before starting broad guardrail checks.
7. **Scheduled-task principal repair.** Move headless self-heal work to a
   runnable principal; leave truly interactive/live-session actions explicit.
8. **pipeline_run capability.** Either add a governed pipeline operator or
   stop creating this task type; agents must not manufacture pipeline verdicts.

Per the brief, the census consumed this task. No Stage-2 code fix was started.
This is intentional: the ranked evidence is committed before any future fix.
