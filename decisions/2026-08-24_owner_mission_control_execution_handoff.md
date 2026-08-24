# OWNER decision — Mission Control receipts commission implementation

Date: 2026-08-24

Authority: OWNER chat instruction: Mission-Control decisions must be implemented
by a Claude job or equivalent governed worker.

## Decision

A terminal OWNER answer (`YES` or `NO`) is no longer documentation-only. It
first creates the immutable decision receipt and then commissions exactly one
deterministic `agent_tasks` row. The task is bound to the selected effect shown
on the card and targets the existing headless Claude orchestration lane through
the capability router. `DEFERRED` creates no implementation task.

The receipt, router task and eventual evidence artifact form one visible chain
in Mission Control. A missed service-side handoff is repaired idempotently by
the existing five-minute router tick. The receipt hashes the complete
OWNER-visible card and records the selected effect; changed card content makes
recovery fail closed instead of silently changing the commissioned work.

## Authority boundary

This decision authorizes commissioning and execution only inside each curated
card's pre-reviewed YES/NO plan. It does not authorize:

- Factory OFF/ON or interrupting T1-T10;
- T_Live, chart, preset, process, account or AutoTrading mutation;
- deployment, live orders or live-book construction;
- gate-threshold, criterion or candidate-universe changes;
- deleting or overwriting verdicts, trade streams or immutable evidence.

OWNER notes are context, not a scope-expansion mechanism. Any selected effect
that still needs a separately named ROT action must stop at preparation or
verification until that exact authority exists.

## Execution contract

- Plans: `tools/strategy_farm/config/owner_decision_execution.v1.json`
- Handoff: `tools/strategy_farm/owner_decision_execution.py`
- Intake: `tools/strategy_farm/owner_decision_service.py`
- Recovery: `tools/strategy_farm/run_agent_router_task.py`
- Worker: existing `QM_StrategyFarm_ClaudeOrchestration_15min`
- Status surface: Mission Control `Entscheidung → Umsetzung`

No second agent operating system or competing Factory scheduler is introduced.
