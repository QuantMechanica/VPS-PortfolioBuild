# Codex review — task 3e0c8b83 orchestration fan-out fix

Task: `3e0c8b83-90d7-45b5-8780-fcf3460e44d6`  
Disposition: **REVIEW_READY — collision prevention verified; one named contract deviation disclosed below.**

## Bound implementation

- Core fix commit: `ac2db161ef21b40b84adca006ebae8296f6ba361`.
- Follow-up commit: `7951787c50` (candidate-query failure now fails closed; one session can drain several distinct tasks sequentially).
- Both commits are ancestors of the reviewed `agents/board-advisor` HEAD.
- The reviewed implementation paths were clean before this review:
  `run_agent_orchestration_task.py`, `agent_router.py`,
  `install_agent_orchestration_scheduled_tasks.ps1`, and
  `test_run_agent_orchestration_fanout.py`.

The implementation claims one additive, pid-owned
`agent_task_exec:<task_id>` lease before each Claude session starts, passes the
single task id in both the prompt and `QM_ASSIGNED_TASK_ID`, renews the lease
while the child runs, and releases it only for the matching owner tuple or by
TTL expiry. Candidate-query failure spawns no unpinned session. When fewer
tasks are claimable than configured slots, no extra session is started.

## 09:45Z incident reconstruction

The committed audit
`docs/ops/evidence/2026-09-15_continuous_book_evolution/audit/claude_lane_fanout_defect.md`
and the surviving prompt files bind the recurrence to one launcher invocation
at `2026-09-15T09:45:01Z`, with three child slots created at `09:45:04Z` and
three router task leases whose owner tuple was null. Ticket
`42a437a4-9674-47ce-9ca9-80eba8a2bc91` was consequently worked by more than one
slot. The three original prompt-file SHA-256 values are:

- slot 1: `43c46d963bb2c2d33713a599ba33fe81b9619af77f81a1ae5ef53d884a32c4aa`
- slot 2: `e263c98d395986558d18cf582e4e911ddcd0883065fc26f2baa1f00f1493181`
- slot 3: `edf67da29691e00548003806de21fce5e8093f95568bdf7499066540ee87da57`

The files remain at
`D:/QM/strategy_farm/logs/claude_orchestration_slot*_prompt_20260915T094501Z.md`.

## Acceptance review

| Requirement | Result | Evidence |
|---|---|---|
| One distinct task pin per launched slot | PASS | `claim_task_exec_leases`, `_run_claude_session_chains`; concurrency regressions |
| `QM_ASSIGNED_TASK_ID` in the child environment | PASS | `agent_env`; `test_assigned_task_id_is_exported_to_child_env` |
| Stale/live foreign pin does no work | PASS | fail-closed exec-lease acquisition and no-unpinned-session exit; second-launcher regression |
| Three tasks / three slots remain disjoint | PASS | `test_launcher_claims_distinct_tasks_before_spawn` and concurrency drain regression |
| Two tasks / three slots start no third worker | PASS | `test_launcher_claims_distinct_tasks_before_spawn` |
| Ownership mismatch cannot renew/release another session's claim | PASS | owner-token/pid/host tuple in `spawn_leases`; `test_agent_scopes.py` owner tests |
| Literal additive task-payload field `claimed_by_session`, checked by `update-task` / `close-review` | DEVIATION | The landed design keeps the claim in `spawn_leases.owner_token`; those CLI paths do not expose a literal `claimed_by_session` field. The pre-spawn lease prevents the duplicate worker, but this exact defence-in-depth wording is not implemented. Reviewer/OWNER must accept the equivalent lease design or RECYCLE a narrow follow-up. |

## Independent verification

Run from `C:/QM/repo`:

```text
python -X utf8 -m pytest \
  tools/strategy_farm/tests/test_run_agent_orchestration_fanout.py \
  tools/strategy_farm/tests/test_agent_router.py \
  tools/strategy_farm/tests/test_agent_router_state_exits.py \
  tools/strategy_farm/tests/test_agent_router_sqlite_retry.py \
  tools/strategy_farm/tests/test_agent_orchestration_lock.py \
  tools/strategy_farm/tests/test_run_agent_orchestration_heartbeat.py -q

92 passed in 44.63s
```

The installed Claude scheduled task currently invokes canonical
`run_agent_orchestration_task.py --agent claude --max-sessions 1`. No task was
re-registered or restarted during this review.

## Rollback / boundaries

Keep the installed lane at `--max-sessions 1` if the fix is recycled. Code
rollback is by reverting the two bound commits; additive exec-lease rows expire
without a schema migration. This review did not route work, change priority or
quota semantics, touch a pipeline verdict, start/stop a terminal, or modify
T_Live/AutoTrading.
