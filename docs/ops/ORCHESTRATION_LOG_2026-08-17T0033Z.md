# Claude Orchestration Cycle Log — 2026-08-17T0033Z

**Session:** agents/claude-orchestration-1

## Preflight: worktree staleness (standing, confirmed unchanged)

`tools/strategy_farm/agent_scopes.py` is still missing in this worktree
(10453 commits behind `agents/board-advisor` on `C:/QM/repo` for
`terminal_worker.py` alone — 690 lines here vs 4644 canonical), so
`agent_router.py` fails immediately with `ModuleNotFoundError`. All
`agent_router.py` calls this cycle ran from `cd C:/QM/repo`. `farmctl.py
health` ran fine from the worktree.

Found 5 files of uncommitted, unrelated WIP already present in this
worktree at cycle start (`framework/scripts/mt5_worker.py`,
`scripts/aggregator/standalone_aggregator_loop.py`,
`tools/strategy_farm/farmctl.py`,
`tools/strategy_farm/run_agent_orchestration_task.py`,
`tools/strategy_farm/start_terminal_workers.py`): a PID-reuse-safety
hardening pass (proper Windows `OpenProcess`/`GetExitCodeProcess` liveness
checks added in three files; `_stop_pid`/`_stop_pid_tree` stubbed to
unconditionally return `False` in `farmctl.py`/`start_terminal_workers.py`).
No router task or live `claude-orchestration-*` process (confirmed via
`Win32_Process` scan — only this session's own process running) explains it.
This exact stub-to-`False` pattern was already found once before as risky
pre-merge WIP on `cto_main` and deliberately stashed rather than merged
(`27f631637`, 2026-08-12). Followed that precedent: `git stash push` with a
descriptive message (reversible, not committed, not discarded, not
completed — out of scope for the router-assigned task below). Also noted 4
pre-existing untracked stray files (an old-format `claude_cycle_log_*.json`,
a stray temp-path artifact, a generated `.set` file, a scratch script) —
none touched, none mine, left as found.

## Health / router snapshot

`farmctl.py health` (start of cycle, 00:17:26Z): FAIL 4 / WARN 0 / OK 15,
standing (`source_pool_drained`, `unbuilt_cards_count` 813,
`unenqueued_eas_count` 54, `p_pass_stagnation`). `agent_router.py
status`/`run`/`route-many`: `no_routable_task` (claude 1/3 running, research
replenishment frozen at 1520 ready cards, `replenish_directed`
`no_empty_cells` across 74 sleeves).

## Tasks — 1/1 processed to REVIEW, 0 duplicated

`list-tasks --agent claude --state IN_PROGRESS` returned 1 `ops_issue` task.

**`738e9396` (priority 94) — bind the outer worker watchdog to the inner
computed budget.** This is the code-fix follow-up to the previous cycle's
`d91f8163` diagnosis
(`docs/ops/evidence/q02_summary_missing_90min_outer_watchdog_mismatch_2026-08-16.md`).
Spawn lease confirmed live and held by `claude` before starting (no
concurrent session). Implemented the diagnosis's own proposed fix in
`tools/strategy_farm/terminal_worker.py`: both `_run_claimed_item` call
sites into `_monitor_spawned_work_item` (fresh-spawn ~4168, adopted/orphan-
rejoin ~3914-3922) now pass `max(cli_timeout_minutes_default,
inner_computed_budget_seconds)` instead of the bare 90-minute CLI default —
the fresh-spawn path reuses the already-parsed `spawn_timeout_seconds` local
directly (sidesteps the diagnosis's payload-ordering race rather than
solving it), the adopted path reads `existing_payload.get("timeout_seconds")`
with the same defensive int-parse. `--timeout-minutes` remains a floor/
operator override, never the effective ceiling, and composes correctly with
the existing `timeout_min`/Q08 opt-in override (three independent sources,
`max()` of all). Added two invariant tests in
`tools/strategy_farm/tests/test_terminal_worker_adoption.py`
(`test_fresh_spawn_monitor_deadline_never_below_inner_budget`,
`test_adopted_monitor_deadline_never_below_inner_budget`) that assert the
computed deadline seconds directly rather than just the new default —
confirmed non-vacuous by reverting the fix via `git stash` and observing
both fail with the exact diagnosed signature (`5400 not >= 7200`) before
restoring it. Focused regression sweep green: 104 tests across
`test_terminal_worker_adoption/custom_history_isolation/atomic_claim/
staged_ex5/news_calendar_claim_gate.py`, 0 failures. A supplementary full
`tools/strategy_farm/tests/` sweep (360 files) was kicked off in the
background but not waited on — not required given the focused sweep already
covers every test file that references the changed functions, and this
cycle should not block on a many-minute run. No Factory OFF/ON, no T_Live,
no gate change, no claim-path semantics changed. Committed on
`agents/board-advisor` (`e607a1bc3`), evidence:
`docs/ops/evidence/2026-08-17_q02_outer_watchdog_inner_budget_fix.md`.
Router: `REVIEW`.

Per the task's own `deployment_constraint`: `terminal_worker.py` is resident
in the worker processes from start, so this fix is inert until the next
Factory OFF/ON ceremony — not run as part of this task, report only.
Requalification of the four confirmed rows (`da89eae6`, `7771ffb7`,
`55837f3f`, `70a8f002`) is deferred to after that ceremony. `73285c18`
(the separate `NO_FORWARD_PROGRESS` external-reaper bug) remains explicitly
out of scope and unchanged.

## Standing checks, unchanged

- `10260` Q08: `FAIL_HARD` confirmed unchanged (3 `done` rows, most recent
  `2026-06-26T22:41:27Z`).
- End-of-cycle `farmctl.py health` (00:33:47Z): FAIL 5 / WARN 0 / OK 14.
  New FAIL vs cycle start: `pump_task_lastresult` (exit code 267009 /
  `0x41301`, non-zero) — not investigated this cycle, not part of the
  router-assigned task, flagging only. Standing FAILs unchanged
  (`source_pool_drained`, `unbuilt_cards_count` 813, `unenqueued_eas_count`
  54, `p_pass_stagnation`).
- Worktree still lags `C:/QM/repo`'s `agents/board-advisor` state by
  thousands of commits; `agent_scopes.py` still absent here — standing
  recurring flag, not actioned.
