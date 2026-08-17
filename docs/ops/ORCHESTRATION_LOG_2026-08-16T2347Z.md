# Claude Orchestration Cycle Log — 2026-08-16T2347Z

**Session:** agents/claude-orchestration-1

## Preflight: worktree staleness (standing, confirmed unchanged)

`tools/strategy_farm/agent_scopes.py` is still missing in this worktree, so
`agent_router.py` fails immediately with `ModuleNotFoundError`. All
`agent_router.py` calls this cycle ran from `cd C:/QM/repo` (checked out on
`agents/board-advisor`). `farmctl.py health` ran fine from the worktree. Only
this log is written from the worktree. The worktree also carries pre-existing
uncommitted changes on 5 files (`framework/scripts/mt5_worker.py`,
`scripts/aggregator/standalone_aggregator_loop.py`,
`tools/strategy_farm/farmctl.py`,
`tools/strategy_farm/run_agent_orchestration_task.py`,
`tools/strategy_farm/start_terminal_workers.py`) plus a few untracked files —
not touched this cycle, not mine, left as found.

## Health / router snapshot

`farmctl.py health` (start of cycle): FAIL 5 / WARN 0 / OK 14, standing
(`source_pool_drained`, `unbuilt_cards_count` 813, `unenqueued_eas_count` 54,
`p_pass_stagnation`, `pump_task_lastresult` non-zero). `agent_router.py
status`/`run`/`route-many`: `no_routable_task` (claude 2/3 running, research
replenishment frozen at 1520 ready cards, `replenish_directed` `no_empty_cells`
across 74 sleeves).

Confirmed via `Win32_Process` scan: no concurrent `claude-orchestration-N`
sibling process running at cycle start (only this session's own
`claude.exe --add-dir ...claude-orchestration-1`, one unrelated long-running
interactive `claude.exe` since 08-16 09:01Z, and unrelated `codex.js`
processes). The two `spawn_leases` rows for the tasks below were freshly
re-acquired by the router's own stale-release-reassign path moments before
this cycle's first `status` call (released from `codex` on a >2h-stale lane
heartbeat) — normal router activity, not a collision signal.

## Tasks — 2/2 processed to REVIEW, 0 duplicated, 0 deferred

`list-tasks --agent claude --state IN_PROGRESS` returned 2 `triage_failure`
tasks. Processed both in ascending priority order.

**`d91f8163` (priority 90) — Q02 `summary_missing`/`UNCLASSIFIED` ~90min
run-abandonment.** Root cause confirmed and is *not* the router payload's own
stale-claim/duplicate-work hypothesis: `terminal_worker.py`'s in-process
monitor watchdog uses the worker's global `--timeout-minutes` CLI default
(90.0min, `terminal_worker.py:4589`) instead of the per-item budget
`farmctl._p2_full_timeout_seconds` already computed and handed to
run_smoke.ps1's own `-TimeoutSeconds` (120min for these rows,
`farmctl.py:4778-4809`, `5913`). The outer net kills a still-healthy run
~30min before the inner net's own timeout would fire, so run_smoke.ps1 never
logs its own `terminal_exit` and `classify_summary_missing_run` fails open to
`UNCLASSIFIED`. Confirmed on 4 rows (not the 3 the payload measured — a
broader DB survey found a 4th, `70a8f002`/`WS30.DWX`, with the identical
signature). Also found and separated out a second, distinct bug the payload
had conflated in: `73285c18` died via the *external* active-row reaper's
`NO_FORWARD_PROGRESS` stall detector at ~30min despite a correctly-computed
130min ceiling — flagged as its own follow-up, not folded into this fix.
Proposed fix: thread `spawn["timeout_seconds"]` into the watchdog's deadline
(`terminal_worker.py:4152-4168` fresh-spawn path and `3895-3922` adopted
path) instead of the bare CLI default. Evidence:
`docs/ops/evidence/q02_summary_missing_90min_outer_watchdog_mismatch_2026-08-16.md`
(committed `agents/board-advisor` `e58a379a7`). Router: `REVIEW`.

**`9e6b271a` (priority 92) — QM5_20177 early-target-at-fill defect.**
Confirmed. `Strategy_ManageOpenPosition` (`QM5_20177...mq5:332-337`) computes
T1/T2 from the pre-entry projected D/C harmonic levels only, never against
`PositionGetDouble(POSITION_PRICE_OPEN)`; since entry requires a
confirmation-bar close beyond the touch extreme, the fill routinely lands
past T1 already. Verified against 6 real trades from two live report.htm
runs (USDJPY x4, GBPUSD x2, four different regimes/years) — partial and full
close fire 0-8s after every single entry, one case on the identical broker
timestamp per the structured logger. The EA's frequency-floor RETIREMENT is
therefore invalid (computed from defect-produced trade counts); the
OWNER-authorized variant must wait for the fix. Proposed fix: reject the
signal (not just suppress the partial) in `Strategy_EntrySignal` when the
computed T1 already lies behind the ask/bid at signal time, both branches.
Audited 11 of ~34 pattern/harmonic-projection EAs for the generic class named
in the task: only `QM5_20177` has it — 2 correctly anchor to
`POSITION_PRICE_OPEN` already (`QM5_11902`, `QM5_1376`), 8 including its 3
`-r1-recovery` cohort siblings have an empty `Strategy_ManageOpenPosition`
(not exposed to this bug). ~23 EAs remain unaudited, flagged as a follow-up
ops_issue rather than claimed clear. Evidence:
`docs/ops/evidence/qm5_20177_early_target_at_fill_defect_2026-08-16.md`
(committed `agents/board-advisor` `bb9466744`). Router: `REVIEW`.

No claim-path code changed, no EA code changed, no Factory OFF/ON, no T_Live
for either task — both were explicitly scoped read-only diagnosis this cycle.

## Standing checks, unchanged

- `10260` Q08: `FAIL_HARD` confirmed unchanged (3 `done` rows, most recent
  `2026-06-26T22:41:27Z`).
- End-of-cycle `farmctl.py health`: FAIL 3 / WARN 6 / OK 31 (a larger check
  set than the start-of-cycle run — checks appear to have been added
  mid-cycle by other activity on the canonical repo). New standing FAIL vs
  start of cycle: `q02_stranded_exhausted_pairs` (278 Q02/P2 pairs with no
  terminal disposition and >=12 `INFRA_FAIL` rows) — not investigated this
  cycle, flagging for a future pass. `unbuilt_cards_count` improved from
  FAIL 813 to WARN 443 and `q02_summary_missing_unclassified` is OK (8
  recent, under the 20-volume signal floor) between the two health snapshots
  — factory is actively draining, not wedged.
- Worktree still lags `C:/QM/repo`'s `agents/board-advisor` state;
  `agent_scopes.py` still absent here.
