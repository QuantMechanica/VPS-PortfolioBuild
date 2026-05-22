# WS-3 Orchestration Hardening Artifact - 2026-05-22

Task: `1ae6833f-56e9-4fbb-ab83-b248ca1b109d`

## Changes

- Staggered active Windows scheduled-task triggers:
  - `QM_StrategyFarm_AgentRouter_5min`: `00:01`, `PT5M`
  - `QM_StrategyFarm_Pump_5min`: `00:03`, `PT5M`
  - `QM_StrategyFarm_Health_15min`: `00:07`, `PT15M`
  - `QM_StrategyFarm_Cockpit_2min`: `00:09`, `PT2M`
  - `QM_StrategyFarm_CodexOrchestration_15min`: `00:11`, `PT15M`
  - `QM_StrategyFarm_GeminiOrchestration_15min`: `00:13`, `PT15M`
  - `QM_StrategyFarm_Repair_Hourly`: `00:14`, `PT5M`
- Added `agent_router.release_stale_in_progress()`.
  - Releases `IN_PROGRESS` `agent_tasks` older than 6 hours back to `TODO`.
  - Clears `assigned_agent` so the router cannot deadlock on abandoned work.
  - Preserves the last five stale-release events in task payload.
  - `route_once()` runs the release pass before capacity checks.
- Folded the generic task-watch notifier into `farmctl.py` pump output.
  - This also provides a reusable pattern for future one-shot owner notifications.

## Existing Circuit Breaker Signal

The Codex auth circuit breaker was already explicit in the hot path:

- `farmctl.py` emits `result["codex_auth_broken"]` and zeros Codex caps when tripped.
- `health.py` exposes the `codex_auth_broken` health check with an operator action hint.
- Cockpit/dashboard presentation still has historical wording cleanup left in places; no verdict semantics were changed.

## Verification

- `python -m py_compile tools/strategy_farm/farmctl.py tools/strategy_farm/agent_router.py tools/strategy_farm/task_watch_notifier.py tools/strategy_farm/ws0_notifier.py`: PASS
- `python -m unittest tools.strategy_farm.tests.test_task_watch_notifier tools.strategy_farm.tests.test_agent_router_stale_release tools.strategy_farm.tests.test_ws0_notifier tools.strategy_farm.tests.test_basket_work_items`: PASS, 5 tests
- Scheduled-task trigger readback after update confirmed the staggered start boundaries and Codex/Gemini `PT15M` repetition.

## Verdict

`WS3_REVIEW_READY_PARTIAL`

The router deadlock fix, pump-integrated one-shot notification surface, and scheduled-task staggering are implemented and verified. Full pump de-monolithing into independently timed internal sub-jobs remains a larger follow-up because `farmctl pump` is still a single function-level transaction surface; this artifact does not claim that part is complete.
