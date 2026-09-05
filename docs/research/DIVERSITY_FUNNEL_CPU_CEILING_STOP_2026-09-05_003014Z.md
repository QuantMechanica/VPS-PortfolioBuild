# Diversity funnel — paced CPU-ceiling stop

Date: 2026-09-05 UTC (`2026-09-05T00:30:14.6244069Z`); 2026-09-05
02:30 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `64f8610e3bfe2b02cea53597b4c3380a5b8b9726`

Status: stopped at the explicit backtest CPU ceiling before backlog claim,
build, infrastructure repair, compile, smoke, Q02/Q03 enqueue, or dispatch.

## Binding capacity result

A fresh five-sample whole-host CPU window measured `100.0000%`, `98.6343%`,
`97.0706%`, `95.9174%`, and `91.2153%`. Average CPU was `96.5675%` and maximum
CPU was `100.0000%`. The paced admission rule requires both measures to remain
strictly below `97%`; the maximum side therefore bound.

The DB and process views independently confirmed saturation. The supported farm
view reported ten active work items: four `Q04`, one `Q07`, one `Q08`, and four
`OPT_CENSUS`. All ten factory slots were claimed by `T1` through `T10`. The
process scan already observed seven running/reserved factory terminals (`T1`,
`T2`, `T4`, `T6`, `T7`, `T9`, and `T10`) while the other claims were entering
their worker lifecycle. This is not an idle-capacity window suitable for a
bounded Q01 smoke or any additional tester-backed handoff.

## Collision and mutation boundary

The farm DB was consulted before selection, as required by the paced-fleet
mission. Because the ceiling bound first, no approved card, diverse
infrastructure repair, or new structural edge was claimed. No task or work item
was created, reprioritized, reclaimed, advanced, or re-enqueued, avoiding a
duplicate or stranded reservation while all slots were already owned.

The `qm-build-ea-from-card` procedure and the standard `codex_build_ea` contract
were used only to establish the build admission and capacity boundary. No
Strategy Card, EA source or binary, setfile, registry, magic resolver, build
result, pipeline evidence, or verdict was changed. No compile, smoke, backtest,
dispatch tick, terminal control, or worker control was started.

The portfolio gate, portfolio-admission surfaces, `T_Live`, AutoTrading, live
manifests, and deploy manifests were untouched. The visible `T_Live` process was
read-only inventory evidence and was not controlled. Existing unrelated shared-
worktree changes were preserved and excluded from this receipt.

## Continuation condition

A later paced wake must repeat both the DB collision check and a fresh five-
sample capacity window. It may select and atomically claim one highest-diversity
eligible unit only when both average and maximum CPU remain strictly below
`97%`. It must not infer that any of the ten active rows observed here is stale
or reclaimable without separate authenticated evidence.
