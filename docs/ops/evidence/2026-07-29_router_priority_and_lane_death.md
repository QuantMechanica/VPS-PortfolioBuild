# Router priority semantics and lane-death observability

- Date: 2026-07-29
- Router task: `3d5647ad-5afb-4fc3-bec5-898d0be509a6`
- Scope: deterministic agent router and health observability only
- Verdict: READY_FOR_REVIEW

## Outcome

The agent-task router now follows the operator convention that a higher numeric
priority is more urgent. Waiting tasks are selected with `priority DESC`, while
age remains the tie-breaker (`updated_at ASC`, then `created_at ASC`). The task
that authorized this correction was changed from priority 5 to priority 95 in
the live router database, with a `priority_semantics_flip` event recording the
old/new values.

Health now emits `agent_lane_heartbeat_stale=WARN` when an enabled lane has an
existing heartbeat older than the router's two-hour suppression threshold. This
makes the same condition that removes a lane from routing operator-visible.
Missing heartbeat files retain the router's existing "no prior evidence"
semantics and disabled lanes are excluded.

## Enqueue-site audit

Every production `enqueue_task(...)` site in
`tools/strategy_farm/agent_router.py` was checked:

| Site | Priority behavior after correction | Disposition |
|---|---:|---|
| `enqueue_task` default | 50 | Retained as neutral default. CLI help now states "higher values route earlier." |
| Matrix-directed research | 70 | Retained as normal elevated research work. |
| Friday restart smoke | 5 | Changed to 95 because the old value intentionally exploited low-first routing to run early. |
| Mandatory Codex review of Gemini code | parent priority + 1 | Retained; under high-first semantics the mandatory review correctly receives slightly greater urgency. |

The remaining `enqueue_task(...)` occurrences are tests. Historical operator
documents containing priorities 30/50 were not mutated: they remain valid
numeric inputs, and this task changes ordering rather than rewriting old
records. The separate source-intake queue in `farmctl.py` explicitly defines
lower-number-first semantics and is not the `agent_tasks` router, so it was not
changed.

`list_tasks(...)` already displayed rows by priority descending. Routing and
display order are now consistent.

## Lane-death evidence and cleanup

Read-only process checks confirmed:

- The reported lane-runner PID 1292 did not exist.
- PID 6652 was `codex.exe`, created `2026-07-28 20:22:08+02:00`.
- PID 8204 was its `codex-code-mode-host.exe` child, created
  `2026-07-28 20:25:24+02:00`.
- CPU was unchanged over a three-second sample:
  PID 6652 stayed at `188.421875` seconds and PID 8204 stayed at `6.421875`
  seconds.
- The surviving wrapper ancestry terminated at a missing parent:
  `6652 -> node 10152 -> cmd 1260 -> pwsh 8496
  (codex_session_supervisor.ps1) -> pwsh 6440 -> WindowsTerminal 10204
  -> missing PID 10092`.

Only the two named stale Codex processes were stopped, child first. A
post-action check confirmed PIDs 8204 and 6652 were both absent. No MT5
terminal, backtest worker, Factory switch, `T_Live`, or AutoTrading state was
touched.

At `2026-07-29 08:39+02:00`, the read-only Scheduled Task census showed
`QM_StrategyFarm_CodexOrchestration_15min` Ready with last result
`0x800710E0`; the same result affected the router, health, pump, and multiple
other scheduled jobs. This confirms the broader interactive-queue-death class.
The scheduler itself was not mutated by this ticket.

## Verification

Focused automated verification:

```text
python -m pytest \
  tools/strategy_farm/tests/test_agent_router.py::AgentRouterTests::test_routes_highest_priority_first_by_capability_and_wip_limit \
  tools/strategy_farm/tests/test_agent_router.py::AgentRouterTests::test_route_once_skips_temporarily_unavailable_head_task \
  tools/strategy_farm/tests/test_agent_router.py::AgentRouterTests::test_friday_smoke_tasks_route_to_all_three_workers_when_enabled \
  tools/strategy_farm/tests/test_agent_router.py::AgentRouterTests::test_gemini_build_review_creates_codex_review_task \
  tools/strategy_farm/tests/test_agent_router_stale_release.py \
  tools/strategy_farm/tests/test_health_agent_lane_heartbeat.py -q

7 passed in 1.56s
```

Additional checks:

- `python -m py_compile` passed for `agent_router.py`, `health.py`, and the new
  health test.
- `git diff --check` passed.
- Live read-only execution of `chk_agent_lane_heartbeat` returned WARN for the
  enabled Gemini lane at 63.2 hours stale and did not report the disabled Claude
  lane.
- The authorizing router row reads `state=IN_PROGRESS`,
  `assigned_agent=codex`, `priority=95`.

The broader router test file currently has five unrelated pre-existing failures
in card inventory/schema and directed-replenishment cases (19 tests passed).
The focused tests above isolate and pass all behavior changed by this ticket;
no unrelated card/replenishment code was modified.

## Files

- `tools/strategy_farm/agent_router.py`
- `tools/strategy_farm/health.py`
- `tools/strategy_farm/tests/test_agent_router.py`
- `tools/strategy_farm/tests/test_health_agent_lane_heartbeat.py`
- `docs/ops/evidence/2026-07-29_router_priority_and_lane_death.md`
