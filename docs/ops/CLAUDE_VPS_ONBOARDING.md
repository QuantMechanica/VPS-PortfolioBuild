# Claude VPS Onboarding

Status: active, 2026-07-22

This document onboards a reasoning worker before it performs repository, pipeline,
or custom-symbol work on the QuantMechanica VPS.

## Authority

- OWNER is the sole human approval authority.
- A worker may investigate, implement within an authorized task, and recommend.
- Deterministic build and phase rules decide technical PASS/FAIL.
- T6/live promotion requires explicit OWNER approval and its complete evidence
  contract. Never toggle AutoTrading.

## Read order

1. `C:\QM\repo\CLAUDE.md`
2. `C:\QM\repo\docs\ops\OPTION_A_STRATEGY_FARM_RUNBOOK.md`
3. `C:\QM\repo\processes\process_registry.md`
4. `C:\QM\repo\docs\ops\PROJECT_CHARTER.md`
5. `C:\QM\repo\docs\ops\PIPELINE_PHASE_SPEC.md`
6. The task-specific runbook or skill

Private server records may be read when the task requires them, but credentials
must never enter committed files, evidence output, logs, or chat.

## Operational sources of truth

1. Actual filesystem, process, terminal, task, and runtime database state
2. Task-specific immutable evidence bound to exact artifacts
3. Current repository runbooks and process registry
4. OWNER instructions
5. External notes only to fill a documented gap

Do not treat old issue snapshots, generated dashboards, expected metrics, or author
claims as current runtime truth.

## Hard boundaries

- Do not touch `T_Live` unless the task and approved manifest explicitly require
  read-only verification or OWNER-authorized deployment.
- Never enable or toggle AutoTrading.
- Do not expose credentials or account secrets.
- Do not assume DST, broker time, commission, spread, tester model, or date range.
- Treat environment/data mismatch as an infrastructure result, not strategy failure.
- Bind every important result to actual source/binary/setfile hashes and tester dates.
- Preserve negative and zero-trade evidence.

## Strategy gate interpretation

`g0_status: APPROVED`, recorded by OWNER after R1-R4, authorizes build,
instrumentation, debugging, compilation, T1-T5 deployment, and non-live tests.
A separate `status: DRAFT` field does not create another approval gate. G0 does not
mean that the strategy is successful, and it never authorizes T6/live promotion.

## Initial report

After reading the required sources, report:

- the task and exact authority boundary;
- system components affected;
- evidence sources and any provenance gaps;
- safety constraints;
- the next concrete action.

Then continue autonomously when the task is authorized and the next action is safe.
