# Audit — Claude-lane session fan-out defect (directive §35)

Read-only diagnosis to the point of a minimal safe fix plan. NOT implemented.
Author: board-advisor auditor · 2026-09-15 · repo `C:/QM/repo` @ `agents/board-advisor`.

## Headline

1. The Claude orchestration lane spawns N parallel `claude -p` sessions (`--max-sessions 3`) that differ **only** by worktree slot and model tier; every session is handed the **same** generic prompt ("work every IN_PROGRESS task assigned to claude"), so with N sessions and M tasks up to N×M executions happen instead of M — one ticket is worked by two sessions.
2. No lease binds a *worker session* to a *specific task*: the `agent_task:<id>` rows are written by the **router** (`agent_scopes.acquire_spawn_lease` called with no owner tuple) so `owner_pid`/`owner_host` are NULL and cannot tell sibling sessions apart; the only pid-bound lease is lane-level (`headless_orchestration:claude`, one per launcher) and is shared by reference across all slots.
3. Confirmed live: tasks `3e0c8b83` (the fix ticket itself) and `42a437a4` (FTMO demo-v2 census) both carry `agent_task:` leases acquired at the same instant (2026-09-15T10:32:32Z) with `owner_pid=NULL`; `42a437a4` was worked twice and its verdict already records the collision (RECYCLE→merge). The defect is Claude-only, does not block portfolio/FTMO/Kimi, and the interim mitigation is `--max-sessions 1`.

## Findings

### F1 — Fan-out has no task partition; the prompt tells every session to do everything
`_run_agent_with_session_lease` sets `session_count = max_sessions` for Claude (capped by budget/quota), then, when `session_count > 1`, submits one `run_agent_slot(agent, slot, …)` per slot to a `ThreadPoolExecutor`.
Evidence: `tools/strategy_farm/run_agent_orchestration_task.py:2103-2144` (`session_count`, the `ThreadPoolExecutor` loop `for slot in range(1, session_count+1)`).
Each slot launches `claude -p` with a prompt built by `build_prompt(agent, cwd)` that contains **no task id and no partition filter**; its cycle §2 says: "For every IN_PROGRESS task assigned to {agent}, in ascending numeric priority: … produce a durable artifact … update-task … to REVIEW."
Evidence: `tools/strategy_farm/run_agent_orchestration_task.py:296-334` (generic prompt, identical for every slot); `command_for` claude branch `:559-570` (argv carries only `--model` and `--add-dir`, no task pin).
The only per-slot difference is the worktree (`worktree_path(agent, slot)` → `C:\QM\worktrees\claude-orchestration-{slot}`, `:691-696`, `:1004-1005`) and the model tier drawn from `slot_invocation(slot-1)` (`:2110-2115`). Nothing routes a distinct task to a distinct slot.

### F2 — The per-slot file lock is slot-scoped, not task-scoped
`acquire_lock` creates `{agent}_orchestration_{slot}.lock` under `D:/QM/strategy_farm/locks/`. It guarantees only one process per (agent, slot); it never mentions a task, so two sibling slots (slot 1 and slot 3) each take their own lock and proceed independently.
Evidence: `tools/strategy_farm/run_agent_orchestration_task.py:392-464` (lock name = `f"{agent}_orchestration_{slot}.lock"`).

### F3 — The lane session lease is per-agent, acquired once by the parent, shared across slots
`run_agent` acquires exactly one lease `headless_orchestration:{agent}` (`acquire_headless_session_lease`) and passes the **same** `session_lease` dict into every slot; slots only *renew* it in the heartbeat callback. So the pid-bound lease that does exist (real `owner_pid`, `fail_open_on_error=False`) discriminates *launcher processes*, not *sessions within one launcher*.
Evidence: `run_agent_orchestration_task.py:2186-2209` (single `acquire_headless_session_lease(agent)`, one `session_lease` handed to `_run_agent_with_session_lease`); `:1560-1620` (`task_key = f"headless_orchestration:{agent}"`, lane-level); `:2030-2036` + `:2139-2141` (all slots share and renew the one lease).

### F4 — Why `owner_pid` is NULL on the `agent_task:<id>` rows
The `agent_task:<id>` leases are written by the **router** at route time (when a task moves to IN_PROGRESS), via `_acquire_task_lease` → `agent_scopes.acquire_spawn_lease(conn, task_key, agent_id, now_iso, expires_iso)` with **no** `owner_token`/`owner_pid`/`owner_host` kwargs, so they default to `None`. It is also fail-open on error. This lease exists to stop the router double-assigning; it says nothing about which worker session later does the work.
Evidence: `tools/strategy_farm/agent_router.py:1524-1561` (`_task_lease_key`, `_acquire_task_lease` call with no owner tuple); `tools/strategy_farm/agent_scopes.py:224-266` (`acquire_spawn_lease` signature; `owner_pid` defaults None; `ON CONFLICT(task_key) DO UPDATE … WHERE spawn_leases.expires_at <= excluded.acquired_at` — TTL-expiry replacement only).
Live DB confirmation (read-only, `mode=ro`): both colliding tasks have NULL owner:
```
agent_task:42a437a4-...  agent_id=claude  owner_pid=None  acquired=2026-09-15T10:32:32Z  expires=11:02:32Z
agent_task:3e0c8b83-...  agent_id=claude  owner_pid=None  acquired=2026-09-15T10:32:32Z  expires=11:02:32Z
```
Query: `sqlite3 file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro` → `select task_key,owner_pid,acquired_at,expires_at from spawn_leases`. Every historical `agent_task:*` row (codex and claude) has `owner_pid=None`, confirming this is the router's uniform behaviour, not a one-off.

### F5 — The collision is real and already visible in the two named tasks
`42a437a4` (task_type `ops_issue`, priority 78, IN_PROGRESS) is the FTMO demo-v2 census. Its `verdict` field records verbatim: "Two sessions worked this ticket (COLLISION.md, --max-sessions 3 race, ticketed separately)… Base = slot-1 v2 …". Its `artifact_path` points at `…/2026-09-15_ftmo_demo_v2_census/slot1_census_v2/README_slot1.md` — i.e. a slot-scoped subdir workaround was applied by hand.
`3e0c8b83` (task_type `ops_issue`, priority 74, IN_PROGRESS) IS the remediation ticket for this defect; its acceptance criteria already state the intended fix shape: "per-slot prompt names exactly one task id from the spawn lease; QM_ASSIGNED_TASK_ID set in the session env; session refuses any task other than the pinned one and exits idle when the pin is stale."
Evidence: `agent_tasks` rows `3e0c8b83-90d7-45b5-8780-fcf3460e44d6` and `42a437a4-9674-47ce-9ca9-80eba8a2bc91` (query above, `payload_json`/`verdict`/`artifact_path`).
Historical recurrence trail: `docs/ops/evidence/2026-08-30_legacy-cohort-dispo-20260830_68a58c95_execution.md:130-138`; `2026-09-07_dukascopy-backfill-20260829_3032534e_execution.md:191-200`; `2026-09-09_orchestration_cycle_1355Z.md:20`; memory `project_qm_claude_orchestration_duplicate_session_race_2026-09-15.md` (6th recurrence, structurally diagnosed — matches this audit).

### F6 — Scope: only Claude fans out; Codex/Gemini/Kimi are structurally single-session
`_run_agent_with_session_lease` forces `session_count = 1` for any `agent != "claude"`, and Kimi is additionally hard-capped at `KIMI_MAX_SESSIONS = 1` (OAuth refresh race) plus a machine-wide single-flight lock in `kimi_adapter`.
Evidence: `run_agent_orchestration_task.py:2104-2109`; `:127` (`KIMI_MAX_SESSIONS = 1`); scheduled tasks confirm `--max-sessions 1` for codex/gemini and `--max-sessions 3` for claude (see Drift table).

## Precise mechanism (summary)

1. `QM_StrategyFarm_ClaudeOrchestration_15min` runs `run_agent_orchestration_task.py --agent claude --max-sessions 3`.
2. `run_agent` → one lane lease (`headless_orchestration:claude`) → `_run_agent_with_session_lease`, where `session_count = 3` (bounded by budget cap 5 and `quota_gate.allowed_task_count`).
3. Three `run_agent_slot` calls run concurrently. Each takes its own **slot** file lock (F2) and launches `claude -p` in its own worktree with the **identical, task-agnostic** prompt (F1).
4. Each session independently lists `IN_PROGRESS` claude tasks and works them all. The router's `agent_task:<id>` leases (F4) are NULL-owner and collective, so nothing stops two sessions from claiming the same task; the shared lane lease (F3) does not distinguish siblings.
5. Two sessions produce divergent artifacts for the same ticket and race on `update-task`/`git`; the faster commit is silently overwritten by the slower session (`git status` shows `M` on files the second session thought it created — memory note, F5).

The race is: **no atomic per-task, pid-owned claim exists between "session starts" and "session does the work."**

## Minimal fix design (NOT implemented — for the implementing phase)

Goal: make each spawned session own exactly one task before it does any work, and never touch a task another live session owns.

**Change 1 — task-bound lease acquired by the LAUNCHER before spawning (authoritative fix).**
In `run_agent_orchestration_task.py`, between building `slot_invocations` and spawning slots (around `:2110-2144`), have the launcher enumerate the eligible claude tasks (reuse `_quota_lane_candidates("claude")`, already imported/used at `:1312`,`:1941`) and, for each slot it intends to spawn, atomically claim ONE distinct task via a **new** lease key with a real owner tuple:
- key `agent_task_exec:<task_id>` (distinct from the router's `agent_task:<id>` so the router path is untouched);
- call `agent_scopes.acquire_spawn_lease(conn, key, "claude", now_iso, expires_iso, owner_token=<uuid>, owner_pid=os.getpid(), owner_host=socket.gethostname(), fail_open_on_error=False)` — note the signature is `(conn, task_key, agent_id, now_iso, expires_iso, *, owner_token, owner_pid, owner_host, fail_open_on_error)`, ISO strings, **fail-closed** here;
- spawn a slot ONLY for a task whose exec-lease was won; if fewer tasks than slots are won, spawn fewer slots (never spawn an unpinned session);
- pass the won task id into the child as an env var (`QM_ASSIGNED_TASK_ID`) via `agent_env` and name it in the prompt.
Functions to change: `agent_env` (`:203-232`, add the pin), `command_for` claude branch (`:559-570`) or `build_prompt` (`:235-368`, inject the pinned id), `run_agent_slot` signature/body (`:983-1060`, accept + thread the task id and its exec-lease), `_run_agent_with_session_lease` (`:2039-2153`, claim-before-spawn loop + release-on-exit), and `_refresh_headless_ownership` (`:2030-2036`, also renew the per-task exec-lease).

**Change 2 — prompt hard-pin (defence in depth, matches ticket 3e0c8b83 acceptance).**
The per-slot prompt must name exactly one task id and instruct: "Work ONLY task `<id>`. If it is no longer IN_PROGRESS or its exec-lease is not held by this pid, do nothing and exit." Replace the "for every IN_PROGRESS task" loop (`:323-334`) for the claude lane with a single-task cycle. This makes a session refuse foreign work even if the lease layer regresses.

**Change 3 — idempotent artifact slot dirs (removes the overwrite blast even under any residual race).**
Standardise the convention already applied by hand in F5: sessions write under a slot- or task-scoped subdir (`…/<evidence_dir>/slot<N>_*/` or keyed by `QM_ASSIGNED_TASK_ID`), never onto a sibling's committed path. This is prompt/skill-level guidance plus, ideally, a small helper the prompt references; it does not require a code lease but caps the damage of any future regression.

**Change 4 — release semantics.**
Release each `agent_task_exec:<id>` lease with the full owner tuple in the `finally` of the slot (mirror `release_headless_session_lease`, `:1651-1668`), so a crashed session frees its task at TTL expiry (fail-safe) and a clean exit frees it immediately.

TTL: reuse `HEADLESS_SESSION_LEASE_TTL_MINUTES` (30) or the router's `LEASE_TTL_MINUTES`; renew inside the heartbeat callback so a legitimately long single task does not lose its pin.

### Regression test outline — `tools/strategy_farm/tests/test_run_agent_orchestration_fanout.py`
Follow the style of existing `tools/strategy_farm/tests/test_agent_orchestration_lock.py` and `test_run_agent_orchestration_heartbeat.py` (in-memory/temp sqlite via `agent_router.connect`, monkeypatch `run_agent_slot`).
- `test_launcher_claims_distinct_tasks_before_spawn`: seed 2 IN_PROGRESS claude tasks, `--max-sessions 3`; assert exactly 2 slots spawn and each `run_agent_slot` receives a distinct `QM_ASSIGNED_TASK_ID`; a 3rd task-less slot is not spawned.
- `test_second_launcher_cannot_reclaim_pinned_task`: with task T pinned (exec-lease held, non-expired, foreign pid), assert a second launcher's `acquire_spawn_lease(...fail_open_on_error=False)` for `agent_task_exec:T` returns False and no slot for T spawns.
- `test_exec_lease_owner_tuple_persisted`: after claim, read `spawn_leases` and assert `owner_pid == os.getpid()` and `owner_host`/`owner_token` non-NULL (guards the F4 NULL-owner regression).
- `test_lease_released_on_slot_exit`: after a slot returns, its `agent_task_exec:<id>` row is gone (clean release) — and on simulated crash, it is retained until `expires_at` (fail-safe).
- `test_prompt_names_single_task`: `build_prompt`/`command_for` output for a pinned slot contains the task id and the "work ONLY this task" instruction; the generic "for every IN_PROGRESS task" text is absent for the claude lane.
- `test_router_lease_path_unchanged`: `_acquire_task_lease` still writes `agent_task:<id>` (no exec suffix) and remains fail-open — proves the fix does not disturb routing.

## Blast radius & rollback
- **Blast radius (code):** confined to `run_agent_orchestration_task.py` (launcher + prompt + slot plumbing) and one additive lease key in `spawn_leases` (`agent_task_exec:*`). No schema change (the owner columns already exist, `agent_scopes.py:198-210`). The router's `agent_task:*` path is deliberately untouched. Codex/Gemini/Kimi lanes are unaffected (they already run single-session, F6). No pipeline, gate, T_Live, or verdict code is touched.
- **Behaviour risk:** claim-before-spawn could, if a bug over-claims, reduce Claude parallelism (fewer slots) — a safe failure (throughput, never correctness). Fail-closed exec-lease means a DB-visibility incident would spawn fewer sessions, not duplicate ones.
- **Rollback:** revert the launcher commit; the scheduled task and router are unchanged, so behaviour returns to today's exactly. Because `agent_task_exec:*` is additive, stale rows simply TTL-expire; no migration/cleanup needed. Fastest operational rollback without code: set the scheduled task back to `--max-sessions 1` (see mitigation).

## Can the defect block portfolio / FTMO / Kimi work? — No.
- **Kimi:** structurally immune — `session_count` forced to 1 for non-claude and `KIMI_MAX_SESSIONS=1` plus the adapter single-flight lock (F6). Cannot fan out.
- **Portfolio / FTMO:** the defect degrades but does not block. It wastes Claude weekly quota (duplicate premium runs), forces a manual RECYCLE→merge (as on `42a437a4`), and can silently overwrite a sibling's committed artifact (`git checkout HEAD -- <paths>` recovers it). It never stalls the pipeline, never writes a false verdict (verdicts come only from pipeline evidence), and never touches T_Live/AutoTrading. So it is a correctness/efficiency defect on the Claude authoring lane, not a liveness blocker for the two books.
- **Interim mitigation (GRÜN, reversible, recommended until the fix lands):** set `QM_StrategyFarm_ClaudeOrchestration_15min` to `--max-sessions 1`. With one session per launcher there is no sibling to collide with (F1 requires N>1). Cost: single-threaded Claude authoring (slower drain of the claude backlog); this is the same posture Codex/Gemini already run. Re-raise to 3 only after the fix + regression tests are green.

## Drift table
| Doc/Vault says | Runtime says | Path |
|---|---|---|
| Claude uses `--max-sessions 3` (setup doc, presented as safe design) | Scheduled task IS `--max-sessions 3` AND this is the fan-out trigger — the design lacks per-task binding | `docs/ops/CLAUDE_CODE_WORKER_SETUP_2026-05-22.md:16-34`; `Get-ScheduledTask QM_StrategyFarm_ClaudeOrchestration_15min` |
| spawn_leases "owner tuple makes a lease belong to one concrete session … a second claude process cannot renew/release the first" (docstring) | True only for `headless_orchestration:*` (lane) and the *unused-here* exec path; the `agent_task:*` rows that would gate work are written with `owner_pid=NULL` by the router and gate nothing between sibling sessions | `agent_scopes.py:190-266`; `agent_router.py:1535-1561`; live `spawn_leases` (all `agent_task:*` owner_pid NULL) |
| Prompt (cycle §2) instructs each session to acquire the `agent_task:<id>` lease "if launched directly for a specific task" | Sessions are NOT launched for a specific task (no id passed); §2's fallback never triggers, and the router lease it names is NULL-owner/collective anyway | `run_agent_orchestration_task.py:323-334` |
| CEO audit / handoff rule: mitigate by disabling the Claude headless task mid-session, re-enable at handoff | Task is currently `Ready` (enabled) with `--max-sessions 3`; the recurring interactive/headless toggle is a manual band-aid, not a fix | `docs/ops/CEO_AUDIT_2026-09-02.md:32`; `Get-ScheduledTask` (State=Ready) |

## Open questions strictly requiring OWNER
None. The fix is a GRÜN/GELB infra repair that does not touch verdict logic, gates, or the live book; ticket `3e0c8b83` already carries the OWNER-visible acceptance criteria. The interim `--max-sessions 1` change is GRÜN (queue/worker config, reversible).

## Recommended actions (for implementing phases)
1. Implement Change 1–4 in `tools/strategy_farm/run_agent_orchestration_task.py` (functions listed in the fix design), landing `3e0c8b83`. Keep `tools/strategy_farm/agent_router.py:1535-1561` unchanged.
2. Add `tools/strategy_farm/tests/test_run_agent_orchestration_fanout.py` per the outline; run alongside `test_agent_orchestration_lock.py` and `test_run_agent_orchestration_heartbeat.py`.
3. Interim (now, until 1–2 are green): retask `QM_StrategyFarm_ClaudeOrchestration_15min` to `--max-sessions 1`. Command the implementer to record it in `docs/ops/OPEN_ITEMS_STATUS.md`.
4. Codify the slot/task-scoped artifact-dir convention (Change 3) in the claude orchestration prompt/skill so authoring never overwrites a sibling's committed path.
5. On close-out, reconcile the already-collided `42a437a4` per its own RECYCLE→merge verdict (one canonical README + roster + census script), then release its stale `agent_task_exec` pin if the new scheme is live.
