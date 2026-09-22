# Codex pinned fan-out — implementation ready, rollout held

Task: `0d64aba8-12c7-4ea5-8d24-1aa0ed38bafd`  
Decision: `OWNER-DEC-FTMO-FULL-THROTTLE-20260921`  
Verdict: `REAL_BLOCKER_ROLLOUT_NOT_ACTIVATED`

## Outcome

The Codex multi-session path is implemented and verified on
`agents/board-advisor` in commit
`f0b94aa4a52dccb3910b49878ec263b9081a9301`. A read-only production dry-run
successfully planned three distinct pinned sessions on isolated slots 2, 3 and
4. The scheduled task was deliberately left at `--max-sessions 1` because the
binding rollout requires two observed real cycles, but the task was already
running under `MultipleInstancesPolicy=IgnoreNew`. While this controller is
alive, its 15-minute triggers cannot start either observation cycle. Activating
max 3 without the required observations would be an unverified rollout.

No T_Live, FTMO demo, AutoTrading, factory worker, terminal, EA, registry, or
pipeline state was touched.

## Implemented contract

- `--agent codex --max-sessions > 1` uses the pid-owned pinned session-chain
  path. Only assigned `IN_PROGRESS` Codex rows are eligible.
- Every child receives one distinct `agent_task_exec:<task_id>` lease before
  spawn, its pinned prompt, and `QM_ASSIGNED_TASK_ID`. A slot can then lease the
  next eligible task sequentially, bounded by the per-session task cap and run
  deadline.
- Candidate-query errors fail closed. A transient failure in the quota gate
  cannot reopen the continuity/fail-open branch for fan-out.
- An expired exec lease is reclaimed only when its recorded local owner PID is
  proven dead. Live, remote, or unverifiable owners remain held.
- The quota gate's `allowed_task_count` bounds concurrent sessions and its
  allowed task IDs/invocations remain task-bound. Model-ledger attribution uses
  the pinned task ID.
- Codex slots must be clean and at the exact canonical launch commit. Clean
  stale slots may only fast-forward; dirty, ahead, diverged, or wrong-branch
  slots are skipped without reset or deletion.
- Codex `--max-sessions 1` retains the established task-agnostic call path.
  Gemini and Kimi remain hard-capped to one session.

## Verification

| Check | Result |
|---|---|
| Python compile | PASS |
| Focused fan-out suite | `26 passed` |
| Broader orchestration, selection, quota, heartbeat, Kimi and health suites | `293 passed in 47.30s` |
| `git diff --check` on implementation paths | PASS (line-ending notices only) |
| Production read-only dry-run | PASS; three distinct tasks on slots 2/3/4 |
| Dry-run worktree side effects | none; slots 2/3/4 remained absent |
| Dry-run exec-lease side effects | none; zero `agent_task_exec:%` rows after run |

Commands:

```text
python -m py_compile tools/strategy_farm/run_agent_orchestration_task.py tools/strategy_farm/tests/test_run_agent_orchestration_fanout.py
python -m pytest tools/strategy_farm/tests/test_run_agent_orchestration_fanout.py -q -p no:cacheprovider
python -m pytest tools/strategy_farm/tests/test_agent_orchestration_lock.py tools/strategy_farm/tests/test_agent_selection_skill_contract.py tools/strategy_farm/tests/test_antigravity_backend_contract.py tools/strategy_farm/tests/test_codex_tiers_enforce_preconditions.py tools/strategy_farm/tests/test_codex_model_tiers.py tools/strategy_farm/tests/test_run_agent_orchestration_kimi.py tools/strategy_farm/tests/test_run_agent_orchestration_heartbeat.py tools/strategy_farm/tests/test_run_agent_orchestration_fanout.py tools/strategy_farm/tests/test_task_contract_fix_package.py tools/strategy_farm/tests/test_video_analysis_ai_lanes.py tools/strategy_farm/tests/test_quota_spawn_gate.py tools/strategy_farm/tests/test_orchestration_health_readmodel.py -q -p no:cacheprovider
python tools/strategy_farm/run_agent_orchestration_task.py --agent codex --max-sessions 3 --dry-run
```

The dry-run selected these distinct `IN_PROGRESS` rows:

1. `d6189118-c2e7-4517-a914-049c89d19a75` → slot 2
2. `7088da77-9e03-45cf-a568-581863f03ef1` → slot 3
3. `a36a5983-8cfc-4528-8277-8b5d21787f82` → slot 4

Slot 1 was correctly rejected as dirty (`162` porcelain rows); it was neither
reset nor modified. The full machine result is in [dry_run.json](dry_run.json).

## Rollout blocker

At the rollout decision point, Windows Task Scheduler reported:

- task state: `Running`
- action: `...run_agent_orchestration_task.py --agent codex --max-sessions 1`
- multiple-instance policy: `IgnoreNew`
- active controller: PID `8456`, created `2026-09-21T22:45:01.802837+02:00`
- next trigger then advertised: `2026-09-22T00:15:15+02:00`

This invocation is the active controller and cannot exit until its assigned
single-pass queue work is complete. With `IgnoreNew`, changing the action now
would not create two real post-change cycles for observation during this task;
the upcoming triggers are ignored while PID 8456 remains alive. Therefore the
required sequence “update action → observe two real cycles → report leased IDs
and conflicts” cannot be completed atomically in this cycle.

[scheduler_before.xml](scheduler_before.xml) and
[scheduler_after_unmodified.xml](scheduler_after_unmodified.xml) show that the
action stayed at max 1. [scheduler_runtime_observation.json](scheduler_runtime_observation.json)
binds the running-state evidence. This is a rollout hold, not a claim that two
cycles passed.

## Safe continuation and rollback

After the current scheduled controller exits, a later OWNER/close-out action can:

1. confirm no Codex controller is running;
2. change only the scheduled-task action from `--max-sessions 1` to
   `--max-sessions 3` and export the actual after XML;
3. observe two genuine scheduler-started cycles and bind each slot's
   `leased_task_ids`, worktree commit, and lease-conflict result;
4. revert the action to `--max-sessions 1` immediately if any duplicate,
   unpinned prompt, stale-code slot, model-ledger, or lock anomaly appears.

Until those steps are evidenced, max 1 is the effective rollback and production
setting.

## Bound files

| File | SHA-256 |
|---|---|
| `tools/strategy_farm/run_agent_orchestration_task.py` | `72db2d5eb26cc67a4a93233074e9b2d7a3e88cf05b0c59ad5f284dec0123a390` |
| `tools/strategy_farm/tests/test_run_agent_orchestration_fanout.py` | `b0ba190428885dcc5fae58e4e66abedbca3b381ea1bba6a9e02738577bd61fd7` |

## Fable activation (2026-09-21T22:28:16Z)

Review: implementation accepted (commit `f0b94aa4a5` in HEAD ancestry; focused suite re-run by Fable `26 passed`; production
read-only dry-run re-run by Fable: `safe_slots_ready`, slots 2/3/4 planned, slot 1 refused as dirty (162 porcelain rows,
`worktree_dirty_refuse_update`), required head `6f5ff19f5d`). Rollout step 2 executed under OWNER-DEC-FTMO-FULL-THROTTLE-20260921
section 7/8 (Codex on production AND research in parallel): the scheduled-task action of `QM_StrategyFarm_CodexOrchestration_15min`
was changed from `--max-sessions 1` to `--max-sessions 3` while the single-session controller started 2026-09-21T20:45Z was still
running (`IgnoreNew`; the change binds at the next scheduler-started instance after that controller exits).
Evidence: `scheduler_before_fable_activation.xml`, `scheduler_after_fable_activation.xml`.

Observation plan (Fable hourly watch): the first two scheduler-started max-3 cycles are read from
`D:/QM/strategy_farm/logs/codex_orchestration_slot{2,3,4}_*.json` — leased task ids per slot, worktree commit, lease-conflict
result, model-ledger attribution. **Rollback** on any duplicate lease, unpinned prompt, stale-code slot, ledger or lock anomaly:
set the action back to `--max-sessions 1` (before-XML is the exact restore point).

## Observation cycle 1 (2026-09-22T01:29:00Z) — first scheduler-started `--max-sessions 3` controller (2026-09-22T00:47:35Z)

| Slot | Leased task | Result |
|---|---|---|
| 2 | `d6189118` (KS/Prague rollover) | running, productive (spawn lease `agent_task_exec:d6189118…` owner pid 18280, renewed 01:27Z) |
| 3 | `7088da77`, then chained `08d62fa7` | both refused in < 0.1 s: `ManagedCodexAlreadyRunning('managed Codex launch already in progress for dedupe=2028d7c4ebae')`; leases released |
| 4 | `a36a5983`, then chained `01806354` | same refusal; leases released |

No duplicate lease, no unpinned prompt, no stale-code slot: the pinning worked, but the managed Codex launcher's single-flight
`dedupe_key="orchestration:codex"` (constant for the whole lane, `run_agent_orchestration_task.py` spawn call) made every
concurrent pinned session refuse, so the effective parallelism stayed at 1. **Fix (Fable, this commit):** the dedupe key is
per task for pinned sessions (`orchestration:codex:<assigned_task_id>`) and unchanged for the task-agnostic single session;
the exec-lease already guarantees one session per task. Tests: fan-out / lock / heartbeat suites green. Observation continues
with cycle 2 (next controller start after the current one exits); rollback unchanged (`--max-sessions 1`).

## Observation cycle 2 (2026-09-22T02:27:01Z) — controller started 2026-09-22T02:15:14Z with the per-task dedupe key (commit 4d69cf643b)

| Slot | Leased task | State at 02:25Z |
|---|---|---|
| 2 | `7088da77` (harness v2) | running (live log 2.9 MB) |
| 3 | `a36a5983` (news/time archive audit) | running (live log 0.66 MB) |
| 4 | `5de65240` (Q08 promotion window fix) | running (live log 1.5 MB) |

`spawn_leases`: three distinct `agent_task_exec:<task>` rows, one owner pid (8652), all renewed 02:25Z; no duplicate lease, no
`ManagedCodexAlreadyRunning`, no unpinned prompt. **Three concurrent pinned Codex sessions confirmed** — the fan-out delivers the
intended parallelism. Rollout complete; `--max-sessions 3` is the production setting, rollback unchanged.
