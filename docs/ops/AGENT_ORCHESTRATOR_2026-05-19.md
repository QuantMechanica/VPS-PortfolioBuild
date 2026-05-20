# Agent Orchestrator - 2026-05-19

This is the deterministic control layer for agent work. It is not an AI agent.
Agents are workers; the router owns state, capability matching, budget limits,
and guardrails.

## State Model

`agent_tasks` uses:

`BACKLOG -> TODO -> IN_PROGRESS -> REVIEW -> APPROVED -> PIPELINE -> PASSED/FAILED/RECYCLE`

Additional terminal states:

- `OPS_FIX_REQUIRED`
- `BLOCKED`

`APPROVED` means "the next system may execute this ticket". It does not mean
the strategy or EA is good. For EAs, real approval remains the QM5 pipeline.

## Task Types

- `research_strategy`: create source-backed strategy cards.
- `review_strategy`: check strategy cards against QM5 constraints.
- `build_ea`: implement an EA inside the framework.
- `review_ea`: code, registry, and framework review.
- `pipeline_run`: enqueue real phase testing.
- `triage_failure`: decide dead, recycle, or ops fix.
- `ops_issue`: repair infrastructure or runners.

## Agent Registry

`agent_registry` stores:

- `agent_id`
- `enabled`
- `capabilities_json`
- `max_parallel`
- `cost_rank`
- `budget_class`

Default capabilities:

- `codex`: code, tests, repo edits, review, ops, research, strategy
- `claude`: research, review, strategy, summary
- `gemini`: research, strategy, source discovery

If `D:\QM\strategy_farm\CLAUDE_DISABLED.flag` exists, Claude is synchronized as
`enabled=0`, `max_parallel=0`. The router will not assign Claude work while
that flag exists.

## Commands

```powershell
cd C:\QM\repo
python tools/strategy_farm/agent_router.py init
python tools/strategy_farm/agent_router.py status
python tools/strategy_farm/agent_router.py replenish
python tools/strategy_farm/agent_router.py enqueue research_strategy --priority 30
python tools/strategy_farm/agent_router.py route-once
python tools/strategy_farm/agent_router.py run
```

## Current Integration Boundary

The first implementation creates and routes tickets only. It does not spawn
agents yet. Existing `farmctl.py pump` remains responsible for current Codex
build/review spawning and real MT5 pipeline execution.

As of 2026-05-20, the router has an autonomous Scheduled Task wrapper:

```powershell
cd C:\QM\repo
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\strategy_farm\install_agent_router_scheduled_task.ps1 -RunNow
Get-ScheduledTaskInfo -TaskName QM_StrategyFarm_AgentRouter_5min
```

The task runs `tools\strategy_farm\run_agent_router_task.py` every 5 minutes
under `pythonw.exe`. Each tick writes
`D:\QM\strategy_farm\logs\agent_router_task_<UTC>.json`.

This makes replenish + capability routing autonomous. It still deliberately
does not execute arbitrary agent work by itself; execution must remain
artifact-producing and guardrail-aware.

## Research Replenish Policy

OWNER directive 2026-05-19: research is not continuous while there is enough
strategy/card/pipeline backlog to process. The orchestrator and pump may create
new `research_strategy` work only when the combined strategy reservoir drops
below 5. With the current reservoir above 1000, research stays paused and
existing approved cards/builds/pipeline work have priority.

Next integration step: have the pump call `agent_router.replenish()` and
`route_once()` before the existing specialized spawn lanes, then replace those
lanes one by one with artifact-driven `agent_tasks` transitions.
