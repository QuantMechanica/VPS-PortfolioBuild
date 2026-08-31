# ac5a29c9 — DL-089 lane-preflight decline-loop repair

Date: 2026-08-31  
Branch: `agents/board-advisor`  
Router task: `ac5a29c9-57b2-4153-889b-ae96258179dd`  
Verdict: **FIX FORWARD VERIFIED; ONE-HOUR 60-CELL/H ACCEPTANCE NOT PROVEN**

## Outcome

The inert/default claim path introduced by `4362ebb4dd` was not inert.  A
governed census candidate was sent through its ledger/pruning lane preflight
before the transaction-local `G`, `K`, `L`, active-lane, duplicate-pair, and
resource gates decided whether that row could be admitted.  With the default
`L=1` and an already-active row for a program, every pending row for that
program was necessarily serialized, but the claimant authenticated it first.

`claim_atomic()` permits eight cold preflight candidates per call.  The new
ordering could therefore authenticate eight rows that the later `L=1` gate
rejected, reach a ninth unchecked governed row, and return
`opt_census_lane_preflight_required`.  Repeating the worker loop reproduced the
global decline shape and prevented lower-ranked ordinary work from being
reached.

The fix moves the governed lane-token check behind all transaction-local
capacity, duplicate, and resource rejection checks.  A candidate which those
checks reject is skipped immediately.  A candidate they admit still must
produce and revalidate the exact ledger-bound eligibility token before the
claim CAS; no authentication, frontier, predecessor, pruning, or fail-closed
condition was weakened.

## Live incident evidence

Source logs:

- `D:/QM/strategy_farm/logs/terminal_worker_T2.log`
- `D:/QM/strategy_farm/logs/terminal_worker_T6.log`

For `05:45Z <= at_utc < 08:14Z`, direct JSON-event counts were:

| Worker | Claims | `opt_census_lane_preflight_required` declines | Other declines |
|---|---:|---:|---:|
| T2 | 9 | 34 | 9 |
| T6 | 10 | 33 | 6 |

The canary environment ended at 08:14Z.  The old-generation T2 worker still
logged two lane-preflight declines between 08:14Z and its 08:40:26Z recycle,
proving that rollback to the empty allow-list / `L=1` defaults did not remove
the defect.

The read-only concurrency harness gives these one-hour comparison anchors:

| Window | MEASURED cells/hour | Execution rows | Slot utilization |
|---|---:|---:|---:|
| 04:45–05:45Z pre-incident anchor | 28 | 37 | 53.78% |
| 07:14–08:14Z incident | 21 | 23 | 56.74% |
| 08:16–08:46Z recovery sample (30 minutes) | 20 | 11 | 63.82% |

Reproducible read-only reports and CSVs are under
`D:/QM/reports/ops/ac5a29c9_throughput/` (`baseline`, `incident`,
`recovery_partial`, and `rolling_hour`).

These canonical metrics do **not** establish the ticket's `>=60 cells/h for
one hour` acceptance.  The pre-incident measured-cell anchor is itself 28/h,
not the 88/h figure stated in the ticket context, so the ticket mixed a
different cell-rate definition with the canonical MEASURED-cell metric.  This
receipt deliberately leaves the rate SLO unpassed rather than substituting a
short sample or a different numerator.

## Missing acceptance test and regression

The prior inert-default test used a legacy payload containing only
`program_id`; `_is_governed_dl089_census_payload()` therefore returned false
and the new lane preflight was never exercised.  The allow-listed test mocked
both the cold preflight and token match.  The deterministic replay tested lane
semantics but did not drive the live `claim_atomic()` queue scan through more
than its eight-candidate preflight budget with ordinary work behind governed
rows.  Consequently all earlier tests could pass while the default runtime
path looped.

`test_inert_default_skips_serialized_governed_rows_before_lane_preflight`
adds the omitted shape: one active governed row, ten governed pending rows
(more than `CLAIM_PREFLIGHT_MAX_CANDIDATES`), an empty allow-list, `L=1`, and
an ordinary tail row.  It asserts that the ordinary row is claimed and the
cold lane preflight is never called for rows already rejected by serialization.

## Verification

- New regression plus adjacent K/L cases: `3 passed, 82 deselected`.
- Complete atomic-claim module: `85 passed in 58.06s`.
- DL-089 focused pack (`test_terminal_worker_atomic_claim`, matrix service,
  census, dispatch, pruning, selection, and same-program replay):
  `155 passed in 74.58s`.
- `python -m py_compile` passed for the runtime and test modules.
- `git diff --check` passed for both changed tracked files.

## Safe live rollout evidence

No terminal process, `terminal64.exe`, AutoTrading setting, or active backtest
was touched.  Only worker daemons with no active work item and no child process
were recycled through the existing `QM_StrategyFarm_WorkerDedupe` task:

| Worker | Old PID | New PID | Pre-action evidence event |
|---|---:|---:|---|
| T2 | 24320 | 19272 | `c47f0c15-d5ae-4abb-a016-e8dd3f826c51` |
| T3 | 18204 | 9960 | `e8c5813e-371b-43bd-9438-057abbdf27f3` |

The durable pre-action records are in
`D:/QM/reports/state/manual_process_kills.jsonl`.

After loading the fixed source, T2 claimed governed cells at 08:42:56Z and
again before 08:50Z with zero lane-preflight declines.  T3 reached ordinary
work and claimed Q08 item `bdee654a-73e8-461c-b2a5-2af8319237c8` at
08:47:30Z, also with zero post-restart lane-preflight declines.  This is direct
live proof that the claim-path loop is removed for fixed-generation workers,
but it is not a substitute for the outstanding one-hour rate SLO.

Workers owning active rows were intentionally not recycled.  They will load
the canonical fix only through a later idle, governed lifecycle restart; this
receipt does not claim a full-fleet hot reload.

## Review boundary

Code, tests, and the live claim-path defect are ready for review.  The reviewer
must keep the throughput acceptance open until one exact, preregistered
60-minute window using the canonical MEASURED-cell definition reaches the
agreed threshold, or OWNER corrects the ticket's metric definition.  No
pipeline verdict or live authorization follows from this repair.
