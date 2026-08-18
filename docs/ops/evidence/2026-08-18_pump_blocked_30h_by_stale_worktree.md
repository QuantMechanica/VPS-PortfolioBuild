# The pump has not run for 30 hours — one stale worktree blocks all factory maintenance

Found while verifying the poison-pill fix
(`docs/ops/evidence/2026-08-18_poison_pill_quarantine_had_no_operator.md`). The fix wires
`refresh_pending()` into `_pump_unlocked()`. Checking that it fired revealed that
**`farmctl.py pump` itself has not executed since 2026-08-17T00:03:01Z.**

## Measurement

`run_pump_task.py` runs a kill-safety audit before the pump and aborts with exit 86 if it fails:

```python
audit = subprocess.run([_console_python(), str(CODEX_KILL_SAFETY_AUDIT), "--json"], ...)
if audit.returncode != 0:
    log.write("\nPUMP_BLOCKED: unsafe process lifecycle code found in a local worktree\n")
    return 86
```

Counting pump logs by day — `PUMP_BLOCKED` against logs containing any `farmctl pump` output:

| day | pump logs | blocked | **actually ran the pump** |
|---|---:|---:|---:|
| 2026-08-12 | 56 | 0 | 7 |
| 2026-08-13 | 58 | 1 | 9 |
| 2026-08-14 | 55 | 3 | 21 |
| 2026-08-15 | 46 | 1 | 8 |
| 2026-08-16 | 70 | 0 | 17 |
| **2026-08-17** | 85 | **38** | **1** |
| **2026-08-18** | 21 | **10** | **0** |

Last log containing pump output: `pump_task_20260817T000301Z.log`. First `PUMP_BLOCKED` ever:
`pump_task_20260813T171301Z.log` — intermittent from 08-13, **continuous since 08-17T00:03Z**.

The remaining logs are 0-byte: `run_pump_task.py` takes a lock and returns 0 without writing when a
previous pump is still running. The audit scans 12,674 files across 92 repo roots and takes ~11
minutes, so roughly half the 5-minute triggers are lock-skipped. **`LastTaskResult` is 0 for those
skips, so Task Scheduler reports the pump as healthy while it has not run in 30 hours.**

## Cause — exactly one worktree, and the canonical repo is clean

Running the audit against each root separately:

| root | safe | unsafe | files |
|---|---|---:|---:|
| `C:\QM\repo` (canonical) | **True** | 0 | 259 |
| `C:\QM\worktrees\claude-orchestration-1` | **False** | **5** | 40 |

The five findings:

| file | reason |
|---|---|
| `framework/scripts/mt5_worker.py` | `windows_destructive_os_kill_zero:acquire_terminal_lock:243` |
| `scripts/aggregator/standalone_aggregator_loop.py` | `windows_destructive_os_kill_zero:is_pid_alive:83` |
| `tools/strategy_farm/farmctl.py` | `identity_less_persisted_pid_force_kill:2519` |
| `tools/strategy_farm/run_agent_orchestration_task.py` | `windows_destructive_os_kill_zero:process_alive:130` |
| `tools/strategy_farm/start_terminal_workers.py` | `identity_less_persisted_pid_force_kill:92` |

All five differ from `main`. The branch is **10,453 commits behind main** and 412 ahead — the 412
are almost entirely ops cycle logs (165 `docs/ops/cycle_logs`, 77 `docs/ops/orchestration_cycles`)
and generated setfiles. Canonical `mt5_worker.py` already carries the repaired identity-based check
(`get_process_identity`, `is_running`), so **the worktree simply never received the kill-safety
repair** and has been carrying the pre-repair code ever since.

The audit's breadth is deliberate — its docstring says it scans every local worktree because the
original incident involved a worktree *no longer in `git worktree list`*. Narrowing its scope would
undo that. The offending worktree must be made safe instead.

## Blast radius — what `_pump_unlocked()` owns and has not done for 30h

- `_detect_active_age_timeout()` — the 60-minute stuck-claim detector. **Two rows are over it right
  now**: QM5_20234 (basket, Q02) at **294 minutes**, holding T1; QM5_10123 (Q08) at 78 minutes.
- `_normalize_pending_work_item_verdicts()` — currently 0 backlog, so no damage here.
- `dispatch_tick()` — legacy bundled-task dispatch.
- `_detect_zerotrade_dead_eas()` — zero-trade rework flagging.
- the poison-pill refresh just added — which is why the quarantine stayed unwritten even after
  the code fix landed.

Backtests themselves are unaffected: the per-terminal worker daemons claim independently and the
91-pair Q08 batch is progressing normally (42 done / 7 active / 29 pending at the time of writing).
What is lost is every piece of *maintenance* the pump owns.

## The two defects are independent and compound

The poison-pill refresh had no caller **and** the pump that would have carried the repaired caller
is itself blocked. Fixing only the first would have looked correct in code review and changed
nothing in production — which is exactly why the verification step mattered more than the fix.

## Remediation — blocked on OWNER

Both remediation paths were refused by the tooling classifier (correctly: one deletes a directory,
the other writes into another agent's worktree). Preparation that *did* complete:

- the 412 commits are preserved under a permanent ref: `archive/claude-orchestration-1-20260818`
  → `732904c9f`, so nothing is lost if the worktree is recreated
- the worktree's 3 untracked files are copied to the session scratchpad (`claude-orch-1-untracked`);
  the 4th had a corrupt filename (`C:UsersAdministratorAppDataLocalTemppipeline_out.json`) and is
  not recoverable or worth recovering
- no scheduled task points at the worktree — `QM_StrategyFarm_ClaudeOrchestration_15min` runs from
  `C:\QM\repo` with cwd `C:\QM\repo`, and `ensure_worktree()` recreates a missing worktree from
  **current HEAD** (`git worktree add -B <branch> <path> HEAD`), i.e. from safe code

So removal is self-healing rather than destructive. The command:

```
git -C C:/QM/repo worktree remove --force C:/QM/worktrees/claude-orchestration-1
```

Verification after it runs: `python tools/strategy_farm/codex_kill_safety_audit.py --json` must
report `safe: true`, then the next pump log must contain `active_timeouts`, and
`poison_pill_quarantine` must gain rows with a fresh `updated_at`.

## Evidence

- `D:\QM\strategy_farm\logs\pump_task_2026081*.log` — 21 logs today, 10 `PUMP_BLOCKED`, 0 with pump output
- `tools/strategy_farm/run_pump_task.py:70` — the audit gate; `:78` — the exit-86 path
- `tools/strategy_farm/codex_kill_safety_audit.py:15,24` — `WORKTREE_PARENT`, `discover_repo_roots`
- `tools/strategy_farm/run_agent_orchestration_task.py:550` — `ensure_worktree`, recreate-from-HEAD
- audit re-run per root, in-process, 2026-08-18


---

# Addendum, same day — the outage had two causes, and the second only became visible after the first was fixed

OWNER removed the worktree. The pump's own audit run then reported, in production
(`pump_task_20260818T062301Z.log`):

```
{ "files_scanned": 12634, "repo_roots_scanned": 93, "safe": true, "unsafe": [] }
```

**Cause 1 is closed.** The verdict passes; `PUMP_BLOCKED` no longer fires.

The pump still did not run. The log ends immediately after that JSON, and the process (pid 6812,
started 08:23 local) is gone.

## Cause 2: the audit consumes most of the task's budget, and the pump gets the remainder

Timed directly, on the same host and with the worktree gone:

| | |
|---|---:|
| audit wall time | **383 s = 6.4 min** |
| roots scanned | 93 |
| files scanned | 12,635 |
| verdict | `safe=True`, 0 unsafe |
| task `ExecutionTimeLimit` (before) | **PT10M** |

**Correction to my own reporting.** In the round before this one I wrote that the audit "takes
~11 minutes" and "exceeds the 10-minute limit". That was an inference from a poll that still showed
the process running, not a measurement. The measurement says 6.4 minutes, and the audit alone does
**not** exceed the limit. I stated it as fact; it was not.

The corrected mechanism is sharper than the wrong one:

- 08:23:01 — task starts, audit begins
- ~08:29:30 — audit finishes, `safe: true`, **6.4 min of the 10-minute budget spent**
- ~08:29:30 — `farmctl.py pump` starts with **~3.5 minutes left**
- 08:33 — `ExecutionTimeLimit` expires, Task Scheduler terminates the task mid-pump
  (`LastTaskResult 267014` = `SCHED_S_TASK_TERMINATED`)

So the audit never had to overrun the limit for the pump to die; it only had to eat most of it.
That also explains the missing `PUMP_BLOCKED` line in the pre-removal logs: those runs were
terminated rather than reaching the block path.

Raising the limit is therefore **load-bearing, not hardening**: `ExecutionTimeLimit` changed
`PT10M → PT30M`. `MultipleInstances=IgnoreNew` plus the file lock (`LOCK_STALE_SECONDS = 20*60`)
already prevent overlap, so the time limit was protecting nothing and truncating everything. After a
30-hour backlog the first pump cycle in particular needs more than 3.5 minutes.

## A second false alarm of mine, checked before reporting

Nine concurrent processes matched `*kill_safety*` in the process list, which looked like the audit
fanning out across all cores against the MT5 fleet. The process tree shows two four-deep chains with
one shared parent — Git-Bash wrapper layers from my *own* background invocation, whose command line
contains the script path. `codex_kill_safety_audit.py` contains no `multiprocessing`,
`concurrent.futures`, or pool of any kind. No finding.

## Open verification

The end-to-end proof is still pending and is deliberately two independent signals, so silence cannot
read as success: a pump log containing `active_timeouts`, **or** a `poison_pill_quarantine` row with
an `updated_at` newer than `2026-08-17T10:59:52`. The latter would simultaneously confirm the
poison-pill fix from the same morning, since `QM5_11287/USDJPY/Q04` currently holds a pending row
and both its triples are `scan()`-eligible.
