# FACTORY_MUTATION maintenance lock-scope repair

- Router task: `6b0bf8aa-8084-4b95-a80c-65f52551737d`
- Branch: `agents/board-advisor`
- Date: 2026-09-01
- Verdict: REVIEW — maintenance no longer displaces worker claim admission; shared Python lock telemetry is live.

## Incident finding

The canonical incident evidence did not show the retention runner acquiring the
global mutation lock. `continuous_retention_runner.py` has no
`FactoryMutationLock` call and only reads the live DB (`quick_check` plus open
work-item bindings); compression and deletion operate on retained backups,
closed evidence, and logs.

The confirmed long critical section was `run_worktree_clean_task.py`. Its
`worktree_clean` holder wrapped git status, DB-backed completed-build discovery,
governed commit hooks, push, volatile cleanup, and final status. The
2026-09-01T20:51:05Z error receipt shows the governed commit hook failure that
ended the roughly 22-minute hold. The subsequent stale-reap record names
`sweep_enqueue_built_eas`, not retention, as the holder created at
20:52:58Z and reaped at 21:20:12Z after its PID died.

## Fix

1. Removed `FACTORY_MUTATION.lock` from the worktree-clean task. The cleaner
   retains its task-local exclusive lock. Factory OFF safety remains explicit:
   the task checks `FACTORY_OFF.flag`, and `Factory_OFF.ps1` lists
   `QM_StrategyFarm_WorktreeClean_4h` in its quiescence set, disables its
   trigger, and waits for a running instance to drain rather than force-stopping
   it.
2. Left retention compression outside the global lock and added a concurrency
   regression that pauses compression while a terminal-style claim acquires the
   mutation lock.
3. Added best-effort acquire/release JSONL telemetry to every successful Python
   `FactoryMutationLock` acquisition. Records contain holder owner, PID, nonce,
   lock path, timestamps, duration, release status, and severity. Holds of at
   least 120 seconds emit `CRITICAL` on release. Production telemetry is:
   `D:/QM/reports/state/factory_mutation_lock_holds.jsonl`.
4. Reduced the read-only health failure threshold for a positively live global
   holder from 600 seconds to 120 seconds. Live holders are reported, never
   reaped.

No strategy-farm verdict, pipeline verdict, card, registry row, terminal,
T_Live setting, or AutoTrading setting is mutated by this change.

## Verification

Focused tests:

```text
test_factory_mutation_lock.py selected telemetry/protocol tests: 3 passed
test_factory_quiescence.py worktree-clean tests: 2 passed
test_continuous_retention_runner.py: 8 passed
test_health_factory_mutation_lock.py: 4 passed
test_factory_mutation_lock.py excluding legacy PowerShell subprocess tests: 9 passed
python -m py_compile: PASS
git diff --check: PASS
```

Two attempts to include broader legacy PowerShell/subprocess integration tests
were stopped after bounded 120-second and 60-second stalls. The focused tests
cover every changed behavior and passed.

Runtime telemetry probe at 2026-09-01T21:32:03Z wrote `ACQUIRED` and `RELEASED`
records for `codex:telemetry_probe`, measured a 0.281-second hold, reported
`INFO`, and left its probe lock absent.

## Live claim proof during maintenance

The canonical cleaner file was updated at 21:26:11Z. The next scheduled
worktree-clean instance started at 21:30:01Z without manual reload and remained
running as PID 16916.

- 21:33:09Z: T8 began a natural `next_claim_attempt`.
- 21:33:16Z: T8 successfully claimed work item
  `266c4d36-3c68-599a-9490-64d54d4376e7`; reason was null (not
  `factory_mutation_lock_busy`).
- 21:33:33Z: `QM_StrategyFarm_WorktreeClean_4h` was still `Running`, PID 16916
  was still live, and `D:/QM/strategy_farm/state/FACTORY_MUTATION.lock` was
  absent.

This is direct production proof that claim admission flows during the formerly
starving maintenance operation. The running maintenance task was not
interrupted. Continuous retention remained OWNER-disabled and was not enabled
or manually started.
