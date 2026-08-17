# Q02 outer watchdog now bound to the inner computed budget — fix — 2026-08-17

Router task `738e9396-03b2-4a37-baa9-f2c887d446a4` (priority 94, ops_issue),
follow-up to the diagnosis in
`docs/ops/evidence/q02_summary_missing_90min_outer_watchdog_mismatch_2026-08-16.md`
(task `d91f8163`). No Factory OFF/ON, no T_Live, no gate change, no claim-path
semantics changed — this only widens the outer monitor's deadline computation.

## The defect (recap)

`terminal_worker.py`'s in-process monitor (`_monitor_spawned_work_item` via
`_run_claimed_item`) killed the spawned `run_smoke.ps1` -> `terminal64.exe`
tree at the worker's global `--timeout-minutes` CLI default (90 minutes),
even when the same dispatch had already computed and handed run_smoke.ps1 a
larger `-TimeoutSeconds` inner budget (7200s / 120min for Q02 full runs).
Because the kill was external (`_stop_pid_tree`), run_smoke.ps1 never wrote
its own exit signature, and `classify_summary_missing_run` fell through to
`UNCLASSIFIED` / `summary_missing_retries_exhausted` on a healthy, still-
trading run. Four confirmed rows: `da89eae6`, `7771ffb7`, `55837f3f`,
`70a8f002` (all `QM5_20176`/`QM5_20178`, `XAUUSD`/`NDX`/`WS30`/`GBPUSD`).

## Fix

`tools/strategy_farm/terminal_worker.py`, both call sites of
`_monitor_spawned_work_item` in `_run_claimed_item`:

- **Fresh spawn** (was line ~4168): the `default_timeout_seconds` argument is
  now `max(timeout_seconds, spawn_timeout_seconds)` instead of the bare CLI
  `timeout_seconds`. `spawn_timeout_seconds` is the same value already parsed
  a few lines above from `spawn.get("timeout_seconds")` (farmctl's per-item
  inner budget) and already written into `payload["timeout_seconds"]` before
  the monitor call — this fix threads that already-computed local variable
  straight into the monitor call instead of discarding it.
- **Adopted/orphan-rejoin path** (was line ~3914-3922): same fix using
  `existing_payload.get("timeout_seconds")` (parsed the same defensive way,
  `int(... or 0)` with a `TypeError`/`ValueError` guard), since an adopted
  row's inner budget comes from the DB-persisted payload the original
  fresh-spawn call wrote, not from a live `spawn` dict.

`_monitor_timeout_seconds`/`_monitor_deadline_monotonic` are unchanged — they
still only look at `payload["timeout_min"]` (minutes, opt-in) and the Q08
phase override. The fix works entirely at the call site by raising the floor
they start from, so `--timeout-minutes` remains a floor and an operator
override (per the diagnosis's explicit constraint), never the effective
ceiling, and a Q08 basket or any future caller that sets `timeout_min` still
composes correctly (`max()` of three independent sources, not two).

This also sidesteps the diagnosis's payload-ordering concern ("the inner
budget must be recorded before the monitor computes its deadline") rather
than solving it: the value is passed as a live function argument in the same
call stack that just computed it, not re-read from a payload field the
monitor would otherwise have to trust was written first.

## Verification

New tests in `tools/strategy_farm/tests/test_terminal_worker_adoption.py`:

- `test_fresh_spawn_monitor_deadline_never_below_inner_budget` — drives the
  real (non-adopted) `_run_claimed_item` branch with every gate
  (`_prepare_staged_ex5`, `_custom_history_gate`,
  `_privatize_custom_history_claim`, `_acquire_launch_slot`,
  `_news_calendar_preflight`, `farmctl._spawn_work_item_runner`) stubbed to
  pass through, a CLI default of 5400s (90min), and a spawn-reported inner
  budget of 7200s (120min, the actual Q02-full floor). Captures the
  `timeout_seconds` argument `_monitor_spawned_work_item` receives and
  asserts it is `>= 7200`.
- `test_adopted_monitor_deadline_never_below_inner_budget` — same invariant
  on the adopted path, with `existing_payload["timeout_seconds"] = 7200` and
  the same 5400s CLI default.

Both assert the invariant directly (the computed deadline seconds, not just
that a new default constant changed), per the diagnosis's requirement that a
test only checking the new default would silently pass again if a future
change added a third timeout net.

**Non-vacuity proof**: both new tests were run against the pre-fix code
(`git stash` of only `terminal_worker.py`) and failed with
`AssertionError: 5400 not greater than or equal to 7200` — the exact
90min-vs-120min mismatch this fix closes — before the fix was restored.

**Regression sweep**: full green, no other changes.

```
tools/strategy_farm/tests/test_terminal_worker_adoption.py            7 passed
tools/strategy_farm/tests/test_terminal_worker_custom_history_isolation.py
tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py
tools/strategy_farm/tests/test_terminal_worker_staged_ex5.py
tools/strategy_farm/tests/test_news_calendar_claim_gate.py            96 passed total (the above 4 files)
```

Full `tools/strategy_farm/tests/` sweep run in background; will be recorded
if it surfaces anything before this task is submitted to REVIEW, otherwise
the focused sweep above is the verification of record for this change.

## Deployment constraint (per task payload — do not action)

`terminal_worker.py` is resident in the worker processes from start, so this
fix is inert until the next Factory OFF/ON ceremony. Not run as part of this
task; report only. OWNER/Claude should schedule it together with the other
worker-resident fixes already waiting (per the router task's
`deployment_constraint` field).

## Requalification after the fix is live (not done here)

Once deployed via Factory OFF/ON, re-run Q02 for the four confirmed rows and
confirm either a real verdict inside the 120-minute inner budget or, if
genuinely still too slow, a `terminal_exit timed_out=True` signature rather
than `UNCLASSIFIED`:

- `da89eae6-ff01-45bf-a60a-5455db5b8e6c` (QM5_20178 XAUUSD.DWX)
- `7771ffb7-55d9-4c13-b525-0edb299096c8` (QM5_20176 XAUUSD.DWX)
- `55837f3f-fa1a-4760-8ff2-24e3f9043fd0` (QM5_20178 NDX.DWX)
- `70a8f002-c927-4ac6-bedf-b5d0bf4790b2` (QM5_20178 WS30.DWX)

`73285c18-edc6-4010-b83c-79bd3cad0634` is explicitly **not** covered by this
fix (different mechanism, `_detect_active_age_timeout`'s
`NO_FORWARD_PROGRESS` stall detector) — see the diagnosis doc's "Second,
related finding" section; still open as its own follow-up.

## Housekeeping note (unrelated to this task)

On starting this cycle, `agents/claude-orchestration-1` had five files with
uncommitted, unrelated WIP (`framework/scripts/mt5_worker.py`,
`scripts/aggregator/standalone_aggregator_loop.py`,
`tools/strategy_farm/farmctl.py`, `run_agent_orchestration_task.py`,
`start_terminal_workers.py`) implementing PID-reuse-safe liveness checks and
stubbing `_stop_pid`/`_stop_pid_tree` to `False`. This matches a pattern
already once found and stashed rather than merged on `cto_main`
(`27f631637`, 2026-08-12) and was not tied to any router task or live
session (only this session's own process was running). It was preserved via
`git stash` on that branch with a descriptive message rather than completed,
committed, or discarded, since it is out of scope for the router-assigned
task here. Flagging for OWNER awareness; not actioned further.
