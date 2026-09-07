# Diversity funnel — paced CPU-ceiling stop

Date: 2026-09-07 UTC (`2026-09-07T10:30:41.6551759Z`); 12:30 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `8fcc4bf1867aa8c0bb0d12c66f6183f3dd60020d`

Status: stopped at the binding CPU ceiling before backlog ranking, farm claim,
generated-source write, compile enqueue, smoke, Q02 enqueue, dispatch, or
terminal control.

## Binding capacity result

A fresh five-sample whole-host CPU window measured `97.758693%`, `95.256887%`,
`98.539742%`, `93.467687%`, and `90.050188%`. Average CPU was `95.014639%`
and maximum CPU was `98.539742%`. The paced admission rule requires both
measures to remain strictly below `97%`, so the maximum dimension bound.

The supported farm view concurrently reported nine active work items: five
`OPT_CENSUS`, and one each at `Q02`, `Q04`, `Q08`, and `Q10_NEWS`. The task
summary reported six active and 74 pending `build_ea` tasks. The supported MT5
slot scan observed seven running factory terminals (`T2`, `T3`, `T4`, `T7`,
`T8`, `T9`, and `T10`), exactly the seven-terminal ceiling. `T_Live` and the
unrelated FTMO terminal were excluded from the factory count.

Machine-readable evidence:
`artifacts/diversity_funnel_cpu_ceiling_stop_20260907T103041Z_board_advisor.json`.

## Collision and selection boundary

No candidate was selected or claimed after the admission gate bound. This is
intentional: the 74-row pending build view is volatile and already has six
active builders, while today's WTI/XTI sequence has advanced through at least
`QM5_41380`. A later unsaturated wake must rerank the live farm DB for the
highest-diversity non-duplicate unit instead of inheriting a stale candidate
from this receipt.

## Mutation boundary

Because the ceiling bound, no farm task or work item was created, claimed,
reprioritized, advanced, released, or enqueued. No Strategy Card, EA source,
EX5, setfile, registry, magic resolver, build result, pipeline evidence, or
verdict was changed. Since no generated MQ5 was written, the mandatory PACER
framework-input-pin audit was not applicable and no compile command was
considered.

No smoke, backtest, dispatch tick, process control, terminal reservation, or
worker control was started. The portfolio gate, portfolio-admission surfaces,
`T_Live`, AutoTrading, live manifests, and deploy manifests were untouched.
Existing unrelated shared-worktree changes were preserved and excluded from
this receipt.

## Continuation condition

Take a fresh five-sample whole-host CPU window. Only rank and atomically claim
one current high-diversity unit when both average and maximum CPU remain
strictly below `97%` and the running factory-terminal count is below its
ceiling. Recheck all identities against current tasks, work items, registry
rows, EA directories, and recent commits before selecting the unit.
