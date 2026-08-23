# rb-pump-latency-dblock evidence — 2026-08-23

## Scope and safety

- Worktree: `C:/QM/worktrees/rb-pump-latency-dblock`.
- Runtime evidence was read from `D:/QM/strategy_farm`; all live-state SQL used the URI `file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro` with `PRAGMA query_only=ON`.
- The pump was **not** run against the live database. Profiling used a SQLite backup copy at `%TEMP%/rb-pump-profile-root/state/farm_state.sqlite`.
- No factory toggle, enqueue/delete operation, verdict rewrite, gate threshold change, or `C:/QM/mt5/T_Live` access was performed.

## Baseline evidence

### Slow pump

- `D:/QM/strategy_farm/logs/pump_task_20260823T160302Z.log` was created at 18:03:02 local and last written at 18:29:53 local. Its pump result is stamped `2026-08-23T16:10:31Z` at line 4098, the resume scan is stamped `16:13:03Z` at line 5655, the lifetime zero-trade census reports 298,164 rows at line 5675, and the backup result appears at line 3823.
- Read-only live-DB timing before adding the covering index:

  ```text
  lifetime event census: 1.128202 s -> (298164 rows, 49 entities)
  query plan: SCAN events; USE TEMP B-TREE FOR count(DISTINCT)
  rolling event census: 0.129260 s
  events: 364907 rows; work_items: 111780 rows
  ```

- A copied-DB `ea_metrics.build(full=False)` run took 10.827 s, scanning 61,475 and upserting 53,273 rows; 114,750 filesystem `stat` calls accounted for 4.895 s. This work did not need to sit in the five-minute dispatch path.

### Lock crash

- `D:/QM/strategy_farm/logs/terminal_worker_T10.log:20225-20226` records item `494651b2-75cd-485c-b889-23545f26e2f1` claimed at `16:24:25Z`, followed by `OperationalError: database is locked` at `16:25:02Z`.
- Read-only item lookup showed phase `Q10_NEWS`, terminal `T10`, status `failed`, verdict `INFRA_FAIL`, and `verdict_reason=EVIDENCE_UNAVAILABLE:worker_crashed_handling_item`; the traceback ended at the pre-spawn payload update in `terminal_worker.py`.
- The new 24-hour health predicate found two historical matching rows on the live read-only database: the incident above and `ce16e40a` (`QM5_20085`, `EURUSD`, `Q07`, `16:12:36Z`). These rows were not changed.

## Changes

### Bounded, dispatch-first pump

- `tools/strategy_farm/pump_budget.py:21-112` provides the monotonic cycle/stage budget and records elapsed, over-budget, and skipped-stage evidence. Required dispatch must be the first stage.
- `tools/strategy_farm/farmctl.py:16766-16806` sets a 270-second admission budget and runs `dispatch_tick` first, before artifact commit, scans, promotions, or build dispatch. Checkpoints at lines 17108, 17654, 18003, 18268, and 18571 stop admitting optional work while 15 seconds remain.
- Promotion work is capped by a 60-second deadline (`farmctl.py:18276-18280`), uses smaller candidate batches, and commits bounded progress. Paired news promotion is limited and commits each row (`farmctl.py:18536-18542`). Q09 autoseal is limited to two dispatch-time and four late-cycle rows, with a deadline (`farmctl.py:18558-18570`). Gate predicates and verdict criteria are unchanged.
- Aggregate/statistics and backup work is marked deferred in the pump (`farmctl.py:16952-16956`, `18098-18102`, `18641-18645`) and is exposed as the non-dispatching `pump-maintenance` command (`farmctl.py:18663-18696`, CLI at `26866-26868`).
- Additive indexes support the measured scans: `idx_events_event_ts_entity` (`farmctl.py:1764`) and `idx_work_items_verdict_updated` (`farmctl.py:1824`).

### Consistent SQLite contention handling

- `tools/strategy_farm/sqlite_busy.py:20-78` is the shared policy: 750 ms SQLite busy timeout plus bounded exponential jitter/retry (8 attempts by default), recognizing SQLite BUSY/LOCKED error codes and messages.
- Farm control connections/writes use it at `farmctl.py:1241-1256`.
- Terminal worker claim and completion use the shared policy. Previously direct pre-spawn writes now go through `_record_active_payload` (`terminal_worker.py:4206`); bounded BUSY exhaustion returns an unspawned active item to `pending` without a verdict through `_defer_item_after_sqlite_busy` (`terminal_worker.py:4829-4874`) and the dedicated run-loop branch (`terminal_worker.py:4980-5001`). A post-spawn record collision never launches a duplicate.
- Q09 binder and adjudication writers use retryable `BEGIN IMMEDIATE` and persistence at `q09_news_runner.py:65-66`, `1133`, `1376`, and `3363`.
- Autonomous agent audit writes use the same policy at `agent_scopes.py:153` and `163`; other Codex paths using `farmctl.connect` inherit it.
- `backfill_planner` is not a direct writer: it opens `mode=ro` at `backfill_planner.py:93` and `--apply` delegates governed commands to `farmctl` (`backfill_planner.py:809-832`).

### Health signal

- `tools/strategy_farm/health.py:785-827` counts the exact last-24-hour combination of `INFRA_FAIL`, `worker_crashed_handling_item`, and a `database is locked` payload; registration is at line 4069. It fails visibly at any nonzero count without modifying historical verdicts or gate criteria.

## Measurements after the change

The copied database was initialized with the additive indexes; no pump ran against live state.

```text
init_db(copy):                      1.726366 s
indexed lifetime event census:     0.121994 s -> (298164 rows, 49 entities)
query plan: SEARCH events USING COVERING INDEX idx_events_event_ts_entity
pump_maintenance(copy):            14.136126 s total
  ea_metrics incremental:          11.927 s
  hourly backup:                    2.074 s
dispatch_performed:                false
verdicts_changed:                  false
```

The latency-sensitive pump now has a 270-second (<5-minute) admission ceiling, emits per-stage timings, and checks remaining time between major stages. Individual legacy calls are cooperative rather than forcibly interrupted; that residual risk is documented below.

Copied-DB writer collision test: one connection held `BEGIN IMMEDIATE` for 1.1 seconds; the shared wrapper succeeded after two attempts in 1.132688 seconds.

## Tests

```text
python -m py_compile tools/strategy_farm/sqlite_busy.py tools/strategy_farm/pump_budget.py tools/strategy_farm/farmctl.py tools/strategy_farm/terminal_worker.py tools/strategy_farm/q09_news_runner.py tools/strategy_farm/agent_scopes.py tools/strategy_farm/health.py
exit 0

python -m pytest -q tools/strategy_farm/tests/test_sqlite_busy_retry.py tools/strategy_farm/tests/test_pump_stage_budget.py tools/strategy_farm/tests/test_terminal_worker_sqlite_busy_defer.py tools/strategy_farm/tests/test_health_sqlite_lock_crash.py
8 passed in 2.52s

# Ticket and touched-module regression batch
200 passed, 18 subtests passed in 90.38s

python -m pytest -q tools/strategy_farm/tests/test_q09_news_runner_v2.py
46 passed in 78.96s

# Entire requested directory was attempted; deterministic first-failure rerun:
python -m pytest -q -x tools/strategy_farm/tests
1 failed, 78 passed in 9.09s
FAIL: test_agent_router.py::AgentRouterTests::test_claude_disabled_flag_removes_claude_from_routing
Reason: pre-existing fixture assumes a Claude entry exists and raises StopIteration; the failure occurs outside all ticket-touched modules.
```

The full non-`-x` run was interrupted after prolonged silence in a later integration test; it had already exposed the same unrelated baseline failures. Ticket-specific and touched-module suites are green.

Tests added at `test_sqlite_busy_retry.py:10-55`, `test_pump_stage_budget.py:16-48`, `test_terminal_worker_sqlite_busy_defer.py:27-66`, and `test_health_sqlite_lock_crash.py:23-57` cover bounded jitter, non-BUSY propagation, short timeout configuration, dispatch-first budget behavior, no-INFRA worker deferral, and the 24-hour health count.

## Rollback

Revert the ticket commit. That restores the former inline pump maintenance and writer behavior. The two added SQLite indexes are additive schema objects; if code rollback alone leaves them in an already-initialized runtime database, they are semantically harmless and may be left in place. No live data migration or verdict rewrite was performed by this ticket.

## Risks and operator follow-up

- Schedule `farmctl pump-maintenance` at a lower frequency (hourly is intended). This ticket adds the command but deliberately does not mutate Windows scheduled tasks or live factory state.
- The 270-second budget prevents new optional stages from starting and bounds promotion/autoseal loops, but Python cannot forcibly preempt a single legacy stage already executing. Stage telemetry will identify any remaining non-cooperative overrun.
- The new health check will remain FAIL while the two historical lock-crash rows are inside its 24-hour window; this is intentional evidence, not a request to overwrite them.

## Review fixes (2026-08-23, FIXER verdict FIX_REQUIRED)

The branch did not merge cleanly onto `agents/board-advisor` (the factory branch,
17 commits ahead). Resolved deliberately and re-tested on the merged tree.

### P1 — deliberate merge conflict resolution in `farmctl.py`

Two content conflicts, both semantic:

1. **Q09 autoseal signature vs board-advisor's new spawn function.** Kept BOTH
   board-advisor's `_spawn_q09_replacements_for_regenerated_q08` /
   `_supersede_stale_q09_holds_after_rebind` AND this branch's
   `auto_seal_pending_q09_news(..., deadline_monotonic=...)` signature. The
   merged function body (auto-merged by git) references both additions
   (`predecessor_refresh = _spawn_q09_replacements_for_regenerated_q08(...)` and
   the `deadline_monotonic` budget break), so dropping either would have caused a
   `NameError`. Verified no conflict markers remain and the module parses.

2. **Late Q09 autoseal / budget-return block vs the mandatory optimization
   fork.** This branch inserts `if cycle_budget.remaining_seconds <= 15.0:
   return result` right after the late autoseal; board-advisor inserts
   `advance_opt_fork(root, apply=True)` there as a MANDATORY promotion-class
   stage that "runs on every cycle after autoseal". Naive resolutions either
   starve the fork permanently (placed after the return) or blow the 270s
   ceiling (placed unbudgeted). Resolved by wrapping the fork as a budgeted
   `cycle_budget.run("optimization_fork", ..., budget_seconds=30.0,
   minimum_start_seconds=10.0)` placed BEFORE the post-promotion early return.
   It is append-only/idempotent, so a tight cycle DEFERS it (self-skips via its
   own minimum_start guard and resumes next cycle) instead of starving or
   overrunning. New constant `PUMP_OPT_FORK_BUDGET_SECONDS = 30.0`. The fork's
   own try/except (one analytic routing defect must not stop the pump) is
   preserved inside the stage closure.

`test_q09_news_farmctl_integration.py::test_pump_retries_autoseal_after_regenerated_q08_promotion`
was a board-advisor source-inspection test asserting the pre-budget call form
`result["q09_autoseal"] = auto_seal_pending_q09_news(root)`. Updated its anchor
to the merged budgeted form `result["q09_autoseal"] = cycle_budget.run(` while
preserving its intent (late autoseal still ordered AFTER
`_promote_paired_q09_portfolio_passes_to_news`).

### P1 — restore hourly DB backups + make the outage observable

`_hourly_db_backup` now runs only from `pump-maintenance`; the 5-min pump leaves
a `{"deferred": true}` marker. Without a schedule, `farm_state.sqlite` backups
silently stop. Fix ships the replacement schedule and an alarm:

- `run_pump_maintenance_task.py` — scheduled-task wrapper (per-run log,
  stale-tolerant lock, honors `FACTORY_OFF.flag`), mirrors `run_pump_task.py`.
- `install_pump_maintenance_scheduled_task.ps1` — registers
  `QM_StrategyFarm_PumpMaintenance_Hourly` (SYSTEM, hourly, 30-min limit,
  IgnoreNew), mirrors `install_pump_scheduled_task.ps1`.
- `qm_tasks.manifest.ps1` — added the task to the ALWAYS_ON managed set so
  `Factory_ON`/`Factory_OFF` keep it enabled.
- `health.py::chk_db_backup_fresh` — new no-con check registered in
  `ALL_CHECKS`. FAILs when the newest `state/backups/farm_state_*.sqlite` is
  older than 150 min (hourly cadence + 50-min guard) or absent; returns OK when
  `FACTORY_OFF.flag` is set (maintenance writer intentionally quiesced).
  Smoke-run against the live runtime: `OK — 7 snapshots, newest 67m ago`.

Operator activation step (must accompany the merge/activation window, like the
other scheduled tasks): run
`tools/strategy_farm/install_pump_maintenance_scheduled_task.ps1`.

### P2 — accepted residuals (no code change)

- **terminal_worker.py post-spawn completion-lock re-run.** The run_loop
  `except sqlite3.OperationalError` deferral does not distinguish pre-spawn from
  post-spawn: if a completion write (`_finish_work_item` / `_record_log_bomb` /
  `_defer_launch_fault`) exhausts the 8-attempt retry after the MT5 child already
  ran, the item is reset to pending and re-claimed → a rare wasted re-run.
  Verified NOT a double-completion (each completion writer is a single atomic
  transaction under `_with_sqlite_retry`; a committed write raises nothing, so
  only one verdict is ever written) and backtests are cost-free. Threading a
  spawn-boundary signal through `_run_claimed_item` is not a cheap/low-risk
  change to the worker hot path; shipped as-is per the fixer, residual documented
  here.
- **Q09 autoseal (6 rows/cycle) + cascade (50/phase) throughput.** Deliberate
  latency-vs-throughput trade; both remain bounded and resumable
  (`ORDER BY updated_at ASC`), gate semantics unchanged. If the Q09_NEWS dam
  drains too slowly, raise `PUMP_LATE_AUTOSEAL_LIMIT` or add a dedicated
  higher-throughput drain pass in `pump-maintenance`. No change required now.

### Tests on the merged tree

```
python -m pytest tools/strategy_farm/tests/test_pump_stage_budget.py \
  tools/strategy_farm/tests/test_farmctl_cascade.py \
  tools/strategy_farm/tests/test_cascade_chain_p2_to_p8.py \
  tools/strategy_farm/tests/test_optimization_fork_driver.py \
  tools/strategy_farm/tests/test_q09_news_farmctl_integration.py
-> 60 passed, 6 subtests passed (after the test-anchor update above)

python -m pytest tools/strategy_farm/tests/test_q09_news_farmctl_integration.py \
  tools/strategy_farm/tests/test_pump_stage_budget.py \
  tools/strategy_farm/tests/test_health_sqlite_lock_crash.py
-> 24 passed
```
