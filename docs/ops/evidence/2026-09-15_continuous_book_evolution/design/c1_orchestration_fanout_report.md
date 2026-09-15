# Slice c1_orchestration_fanout — implementation report

Directive §24 (controlled parallelism) + §35 (fix Claude-lane fan-out).
Audit: `audit/claude_lane_fanout_defect.md`, `audit/quota_tasks_routing_resources.md`.
Date: 2026-09-15. Worktree branch base: `ab9c2f1e09`.

## What the defect was

The Claude orchestration lane spawned N parallel `claude -p` sessions
(`--max-sessions 3`) that differed ONLY by worktree slot + model tier and were
each handed the SAME task-agnostic prompt ("work every IN_PROGRESS task assigned
to claude"). With N sessions and M tasks up to N×M executions happened; one
ticket was worked by two sessions (audit F1–F5). No pid-owned lease bound a
worker session to a specific task (`agent_task:<id>` router leases carry a NULL
owner tuple, F4).

## Fix design chosen (least invasive path per the audit)

Additive per-task exec-lease using the EXISTING `spawn_leases` table (owner
columns already present, `agent_scopes.py:190-266`) with a NEW key
`agent_task_exec:<task_id>` — the router's own `agent_task:<id>` path is left
completely untouched. This was chosen over a lease FILE under
`D:/QM/strategy_farm/state/agent_exec_leases/` because the DB table already
provides atomic claim (`INSERT ... ON CONFLICT DO UPDATE WHERE expires_at <=
acquired_at`), owner tuple, and TTL-expiry steal — no new storage, no schema
change, and the same fail-closed guarantee the headless-session lease already
relies on. The launcher claims a distinct exec-lease per intended slot BEFORE
spawning; it spawns a slot only for a task it won, pins the task id into the
child (env `QM_ASSIGNED_TASK_ID` + prompt), renews the lease in the heartbeat,
and releases it on exit (clean) / at TTL (crash). `--max-sessions` is now an
UPPER BOUND on concurrently leased tasks, never an N×M multiplier.

## Files changed

- `tools/strategy_farm/run_agent_orchestration_task.py`
  - `agent_env(agent, assigned_task_id=None)` — exports `QM_ASSIGNED_TASK_ID` when pinned.
  - `build_prompt(agent, cwd, assigned_task_id=None)` — pinned prompt names exactly
    one task and forbids the "work every IN_PROGRESS task" loop; default (unpinned)
    text is byte-unchanged for the codex/gemini lanes.
  - New: `_task_exec_lease_key`, `acquire_task_exec_lease`, `renew_task_exec_lease`,
    `release_task_exec_lease`, `claim_task_exec_leases` (fail-closed, owner-scoped,
    TTL = `HEADLESS_SESSION_LEASE_TTL_MINUTES` = 30).
  - `run_agent_slot(..., assigned_task_id=None, exec_lease=None)` — threads the pin
    into prompt/env, renews the exec-lease in the heartbeat callback, and releases it
    in `finally` and on the two early-return branches (worktree-fail / lock-skip).
  - `_refresh_headless_ownership(..., exec_lease=None)` — renews the exec-lease too.
  - `_run_agent_with_session_lease` — Claude lane claims distinct exec-leases from the
    assigned candidate set before spawning; spawns one slot per won lease; skips with
    reason `no_unpinned_claude_task` when every eligible task is already pinned (safe
    throughput failure, never a duplicate); backstop-releases leases in `finally`.
    Non-claude lanes keep their existing single, task-agnostic session (audit F6).
- `tools/strategy_farm/agent_router.py` — `DEFAULT_AGENT_REGISTRY` docstring records
  the §24 controlled-parallelism authorization and the pins (kimi 1 / owner 0).
- `tools/strategy_farm/install_agent_orchestration_scheduled_tasks.ps1` — new
  documented `-ClaudeMaxSessions` parameter (default 1, interim mitigation).
- `tools/strategy_farm/tests/test_run_agent_orchestration_fanout.py` — new regression suite.
- `tools/strategy_farm/tests/test_codex_model_tiers.py` — updated two stub lambdas
  (`build_prompt`, `agent_env`) to accept the new optional arg (signature change only).

## Contracts changed (directive §70 list)

- Launcher public functions gained backward-compatible OPTIONAL params
  (`agent_env`, `build_prompt`, `run_agent_slot`, `_refresh_headless_ownership`):
  every existing caller still works with the old arity; new callers pass the pin.
  Verified callers via grep — only `run_agent_orchestration_task.py` itself and the
  test stubs call these; `farmctl.py`/`mailbox_source_intake.py` `build_prompt` are
  unrelated same-named functions.
- New additive lease key `agent_task_exec:<id>` in `spawn_leases`. No schema change;
  the router's `agent_task:<id>` path is unchanged (regression-guarded by the key-
  distinctness test).
- Scheduled-task installer contract: Claude MaxSessions is now parameterised (default 1).

## Tests added + result

New file `tests/test_run_agent_orchestration_fanout.py` (8 tests): distinct-task
claim before spawn; --max-sessions bound with disjoint task sets; second launcher
cannot reclaim a pinned task (helper + end-to-end); crashed owner's lease stolen
only after TTL; owner-tuple persisted + clean release removes the row; exec key
distinct from the router key; pinned prompt names a single task only; env export.

Pytest summary lines:

```
tools/strategy_farm/tests/test_run_agent_orchestration_fanout.py + lock + heartbeat:
  29 passed, 1 warning in 5.39s
tools/strategy_farm/tests/test_codex_model_tiers.py: 130 passed in 9.79s
router suites (test_agent_router.py, canonical_writer_contract, run_agent_router_task,
  auto_build_routing): 71 passed, 12 subtests passed in 21.37s
combined final run (fanout+lock+heartbeat+codex_tiers+router+writer_contract):
  196 passed in 31.41s
```

## §24 controlled parallelism — what was (and was not) changed

The registry `max_parallel` VALUES are UNCHANGED (codex 5, claude 3, gemini 2,
owner 0; this worktree has no `kimi` lane yet). I recorded the §24 authorization
in the `DEFAULT_AGENT_REGISTRY` docstring and did NOT raise any number, because:
(a) the audits do not specify a numeric raise — `quota_tasks_routing_resources.md`
states "Routing config — no change required", and `claude_lane_fanout_defect.md`
says the scheduled task/router are "unchanged" and to re-raise Claude only to 3
after the fix; (b) the directive-era canonical registry (the shared checkout at
`C:/QM/repo`, which is ahead of this worktree and already carries the §24 era)
keeps these exact caps (codex 5, claude 3, gemini 2, kimi 1, owner 0), so raising
above them would contradict truth precedence and is a separate OWNER decision;
(c) the existing router tests pin claude==3 / codex==5 / owner==0 and stay green.
Net: claude=3 is now SAFE controlled parallelism (fan-out fix), documented as
such; kimi (when the lane is added) stays 1 (single-flight adapter); owner stays 0.

## Rollback

- Code: `git revert` the launcher commit. The additive `agent_task_exec:*` rows
  TTL-expire on their own; no migration/cleanup. The router and scheduled task are
  untouched by the code change, so behaviour returns to prior exactly.
- Operational (no code): re-register the Claude task at `--max-sessions 1`
  (already the new installer default) — see notes_for_orchestrator.
- Registry doc change is comment-only; reverting is cosmetic.

## Items I could NOT do (with exact reason)

- **Kimi lane fix in the shared code path:** this worktree's
  `run_agent_orchestration_task.py` (base `ab9c2f1e09`) predates Kimi — `--agent`
  choices are `codex/gemini/claude` only, there is no `KIMI_MAX_SESSIONS`, and
  `agent_router.py` `DEFAULT_AGENT_REGISTRY` has no `kimi` row. So there is no kimi
  code path here to fix. The fix is written generically (only the claude lane can
  reach `session_count>1`), so when kimi is merged it inherits the single-session
  posture (`session_count=1` for any non-claude agent) with no fan-out; my registry
  docstring already states kimi must stay `max_parallel 1`.
- **Live re-registration of the scheduled task:** not performed — RED/ops boundary
  and it belongs to the orchestrator. The exact command is in notes_for_orchestrator.
