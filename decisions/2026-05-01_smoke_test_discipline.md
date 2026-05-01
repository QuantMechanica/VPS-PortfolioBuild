# ADR: Smoke Test Discipline for V5 Pipeline

Date: 2026-05-01  
Owners: CTO (`241ccf3c-ab68-40d6-b8eb-e03917795878`), Quality-Tech (`c1f90ba8-d637-46d9-8895-ead705bb4933`)
Issue: QUA-674 (QUA-665 D4)

## Context

The current smoke fixture (`framework/tests/smoke/QM5_1001_framework_smoke.mq5`) validates framework lifecycle hooks (`init` / first tick path / `deinit`) and event-log contract (`framework/tests/smoke/expected_events.json`). It does not exercise strategy behavior or diagnostic pseudo-trade paths. Running it as a frequent cadence step consumes T1 and Pipeline-Operator runtime without meaningful regression discovery.

## Decision

Adopt **Option B**: demote smoke discipline to strict compile checks for framework-touching changes.

- Primary gate command: `framework/scripts/compile_one.ps1 -EAPath <ea_folder> -Strict`
- Keep the existing smoke fixture for targeted diagnostics only (manual/investigative), not cycle cadence.
- Remove long smoke execution from default pipeline loops and any filler cycle usage.

## Trigger Condition

Run strict compile gate only when one or more of the following change classes are touched:

1. `framework/include/QM/*.mqh`
2. `framework/src/*` framework runtime logic
3. `framework/scripts/compile_one.ps1` or `framework/scripts/build_check.ps1`
4. Framework-level set/header contract components that affect compile/load boundaries

Do not run smoke as a periodic keep-busy task.

## Consequences

- Faster feedback and lower token/tester burn for no-op cycles.
- Compile-warnings-as-fail remains enforced at the gate boundary.
- Behavioral checks move to real pipeline phases (P1+), where evidence contains actual strategy/runtime behavior rather than fixture-only hooks.

## Hard-Rule Alignment

- No change to Model 4 Every Real Tick requirement for baseline backtests.
- No change to risk enum contract (`RISK_FIXED` + `RISK_PERCENT`).
- No external API or ML introduction.

## Implementation Notes

- Pipeline-Operator should call `compile_one.ps1 -Strict` for in-scope framework changes and skip long smoke unless explicitly requested for diagnosis.
- Quality-Tech retains authority to request a targeted smoke run when diagnosing framework lifecycle regressions.
