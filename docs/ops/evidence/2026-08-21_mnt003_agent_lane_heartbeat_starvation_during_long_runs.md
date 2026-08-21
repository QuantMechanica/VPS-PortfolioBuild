# MNT-003: 0x800710E0 on CodexOrchestration/Pump — root cause proven benign at the Task Scheduler layer, real bug found and fixed one layer up

**Date:** 2026-08-21
**Router task:** `9226799b-8dd0-4097-bcb4-3dee7eda862a`
**Disposition:** root cause proven; genuine self-trip risk found and fixed (not the oscillation itself, but its downstream consequence)

## What 0x800710E0 actually is here

`0x800710E0` decodes to `HRESULT_FROM_WIN32(ERROR_ARENA_TRASHED... )` — in Task
Scheduler terms, "the operator or administrator has refused the request", the
generic code Task Scheduler stamps on a **skipped launch attempt**, not a
process crash.

Direct proof from the operational event log
(`Microsoft-Windows-TaskScheduler/Operational`), filtered to
`QM_StrategyFarm_CodexOrchestration_15min`:

```
12:30:01 PM  Task Scheduler did not launch ... because instance
             {87255ade-d8d9-4819-8532-536083ef75fc} of the same task is already running.
12:15:01 PM  ... same instance GUID ...
12:00:01 PM  ... same instance GUID ...
11:45:01 AM  ... same instance GUID ...
11:30:01 AM  ... same instance GUID ...
11:15:01 AM  ... same instance GUID ...
11:00:01 AM  ... same instance GUID ...
```

The **same** instance has been legitimately running, uninterrupted, since before
11:00 AM. Cross-checked against the live process table: `pythonw.exe
run_agent_orchestration_task.py --agent codex --max-sessions 1`, PID 24872,
`CreationDate = 2026-08-21T10:00:01`. The task's own config
(`run_agent_slot`) intentionally allows a single invocation up to
**225 minutes** (near the Task Scheduler `ExecutionTimeLimit=PT4H` ceiling) so
that one Codex session can run to completion. Every 15 minutes, the new
trigger finds the old instance still alive and — because
`MultipleInstances=IgnoreNew` — correctly declines to start a second one,
logging 0x800710E0 for that declined attempt. **This part of the system is
working exactly as designed; it is not a failure.**

The pump (`QM_StrategyFarm_Pump_5min`) showed `LastTaskResult=0` at the time of
this investigation — its own oscillation, if it recurs, is the PS5.1-stderr
class documented separately and was not reproduced here.

## The real bug this surfaced

`agent_router.LANE_HEARTBEAT_STALE_HOURS = 2`. `_write_lane_heartbeat()`
(`run_agent_orchestration_task.py`) was, before this fix, written **once**, at
spawn time, and never again for the rest of that invocation. Because a single
codex invocation can legitimately run up to 225 minutes — **longer than the
2-hour heartbeat staleness window** — a genuinely busy, correctly-functioning
codex lane goes heartbeat-stale roughly 45+ minutes before its own permitted
run budget even ends.

Two consumers read that same stale signal:

1. `health.chk_agent_lane_heartbeat` — cosmetic: WARNs with a misleading
   action_hint ("0x800710E0 indicates interactive-queue death") that isn't
   true for this instance.
2. `agent_router.release_stale_in_progress` — **not cosmetic**: releases
   (recycles) an `IN_PROGRESS` `agent_tasks` row once `task_age > 2h AND
   lane_heartbeat_stale`. A codex task that has been `IN_PROGRESS` for over 2
   hours as part of the *same* long-running, still-healthy invocation is
   exposed to being released out from under the agent that is still actively
   working it — the exact "self-trip" failure class this shop has hit
   repeatedly (reason-token-trip, symbol-conflation reaper, etc.), just with a
   different trigger this time.

This directly contradicts `_write_lane_heartbeat`'s own docstring intent
("Lane heartbeat = 'this lane's scheduled infrastructure is alive'... Stuck
lanes are handled by the 6h stale-IN_PROGRESS release, not by heartbeat
staleness") — the 2h heartbeat-coupled release path in
`release_stale_in_progress` (trigger 2) exists in the code today and is not
gated by the 6h floor.

## The fix

`tools/strategy_farm/run_agent_orchestration_task.py`:

- Added `_wait_with_heartbeat_refresh(proc, timeout_seconds,
  refresh_interval_seconds, refresh_fn)`: polls `proc.wait()` in
  `HEARTBEAT_REFRESH_INTERVAL_SECONDS` (600s) slices instead of one long
  blocking wait, calling `_write_lane_heartbeat(agent, slot=slot)` between
  slices. Still raises `subprocess.TimeoutExpired` once the *overall*
  `timeout_minutes * 60` budget is exhausted, so the existing timeout/kill
  path in `run_agent_slot` is unchanged.
- `run_agent_slot` now calls this helper instead of a bare
  `proc.wait(timeout=timeout_minutes * 60)`.

10-minute refresh cadence keeps the heartbeat at most ~10 minutes old
throughout a run, comfortably inside the 2-hour staleness window regardless of
how long the underlying Codex/Claude/Gemini session legitimately takes.

## Tests (fail before / pass after)

`tools/strategy_farm/tests/test_run_agent_orchestration_heartbeat.py` — 4
cases, all passing against the fixed code:

- a fake process that times out 3 times before exiting gets exactly 3
  heartbeat refreshes and returns the real exit code;
- a process that exits on the first poll triggers zero refreshes (no wasted
  work on the fast path);
- exceeding the *overall* timeout budget still raises
  `subprocess.TimeoutExpired`, preserving the existing kill/timeout branch in
  `run_agent_slot`;
- a regression case documents the pre-fix shape directly: a bare
  `proc.wait(timeout=...)` call gives the caller no hook to refresh anything
  while the process is still running — that absence is exactly the bug this
  ticket closes.

Also reran the pre-existing `test_agent_orchestration_lock.py` and
`test_health_agent_lane_heartbeat.py` (10 tests) — all pass, no regression.

## What was not done

- No scheduled task, Task Scheduler setting, or Factory state was touched.
- `release_stale_in_progress`'s trigger logic was left exactly as-is — the fix
  makes the heartbeat honest rather than changing what consumes it, which is
  the smaller, safer lever and needed no gate/verdict-logic change.
- Nothing was reset, restarted, or force-terminated; the currently-running
  codex instance (PID 24872) was observed only, never touched.

## Recommendation for the Entscheidungsschlange

`_write_lane_heartbeat`'s docstring claim that stuck lanes are "handled by
the 6h stale-IN_PROGRESS release, not by heartbeat staleness" is inaccurate
against the current `release_stale_in_progress` code (2h heartbeat-coupled
trigger 2 exists and fires independently of the 6h floor). Worth a follow-up
to either fix the docstring or decide the 2h coupled trigger should not exist
now that heartbeats refresh continuously — not touched here to keep this
change to the smallest correct fix.
