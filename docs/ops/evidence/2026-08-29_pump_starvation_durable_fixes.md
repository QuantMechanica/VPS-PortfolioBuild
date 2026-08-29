# Pump starvation durable fixes — 2026-08-29

- Router task: `f7a6975d-0c42-46bd-adfb-ae931667e406`
- Scope: scheduler/maintenance/process-lifecycle reliability only
- Pipeline verdict logic changed: **no**

## Delivered controls

1. `health.chk_pump_task_health` now persists distinct Task Scheduler run
   outcomes over a rolling two-hour window. Two consecutive `267014 /
   0x00041306` terminations emit a `FAIL` check whose detail is explicitly
   `CRITICAL`; a successful run breaks the sequence. The existing immediate
   non-zero failure remains intact.
2. `tester_cache_purge.ps1` retains the ceremony guard from commit
   `dcc75e46c` and now sizes eligible, evidence-unprotected idle-cache targets
   before stopping Pump/Tick or any worker. A full teardown is skipped below a
   1.0 GB reclaim floor; BusyScratch continues independently. This prevents the
   observed full teardown for approximately 10 MB of reclaimable data.
3. `worktree_janitor.py` plus
   `install_worktree_janitor_scheduled_task.ps1` provide a six-hour scheduled
   janitor. Removal requires every predicate: exact resolved path below
   `C:/QM/worktrees`, age at least 48 hours, clean Git state, no process command
   line referencing the root, and no Git lock. Canonical/outside/dirty/live/
   young roots fail closed. Registered worktrees use `git worktree remove`;
   unregistered repo copies use recursive removal only after the same resolved
   containment and safety checks.
4. `codex_kill_safety_audit.py` caches each root/HEAD audit with a cheap runtime
   file stat fingerprint. `NO_HEAD` orphan roots use the same fingerprint
   invalidation. Git identity and fingerprints are collected concurrently.
   Runtime-source size or mtime changes invalidate a cache entry, including
   untracked source changes.
5. `codex_fleet_pacer.py` now scans blocked `build_ea` rows before pacing and
   terminates only the exact live farm-managed process lease named by
   `payload.build_dispatch.pid`. PID identity is revalidated by
   `terminate_managed_codex_pid`; stale/reused/unmanaged PIDs are not killed.
6. The durable Pump installer now specifies `PT1H`. This retains headroom for a
   legitimate cold safety scan while the normal cache-hit path is sub-second.
   The installed task was already observed at `PT1H / IgnoreNew` during this
   cycle, so no temporary drift remains.

## Verification

- Focused Python tests: `43 passed in 3.41s`.
- Python syntax: `py_compile` PASS for all changed Python runtime modules.
- PowerShell parser: PASS for purge, Pump installer, and janitor installer.
- Kill-safety cold baseline before full caching: 52 roots, 9,219 files,
  safety PASS, 394.64 seconds.
- Cache rebuild after fingerprint hardening: safety PASS, 293.64 seconds.
- Final true warm run: 52 roots, safety PASS, **0.88 seconds**.
- Janitor dry-run evidence:
  `D:/QM/reports/maintenance/worktree_janitor_20260829_dry_run.json`; 51
  registered worktrees assessed, zero eligible, zero failures, zero removals.
  The result demonstrates fail-closed handling of the currently dirty fleet.
- Blocked-build managed-tree probe after implementation returned `[]`: no live
  identity-matching blocked build process remained to terminate at verification
  time.

The cache state is operational data at
`D:/QM/strategy_farm/state/codex_kill_safety_cache.json`; it is not a pipeline
artifact and carries no economic verdict.
