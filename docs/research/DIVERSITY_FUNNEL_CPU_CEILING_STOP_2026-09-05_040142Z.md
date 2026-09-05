# Diversity funnel — paced CPU-ceiling stop

Date: 2026-09-05 UTC (`2026-09-05T04:01:42.5304006Z`); 2026-09-05
06:01 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `95a7c9e44c1e1490c7c4dc2c1df011474b3da7f3`

Status: stopped at the explicit backtest CPU ceiling before backlog claim,
build, infrastructure repair, compile, smoke, Q02/Q03 enqueue, or dispatch.

## Binding capacity result

A fresh five-sample whole-host CPU window measured `100.000%`, `100.000%`,
`100.000%`, `100.000%`, and `99.024%`. Average CPU was `99.805%` and maximum
CPU was `100.000%`. The paced admission rule requires both measures to remain
strictly below `97%`; both dimensions bound.

The supported farm view independently reported six active work items: two
`Q08` and four `OPT_CENSUS`. Those rows were claimed by `T2`, `T3`, `T6`,
`T8`, `T9`, and `T10`. The supported MT5 slot scan, explicitly excluding
`T_Live` from the factory roster, observed running factory terminals on `T2`,
`T6`, `T8`, and `T10`. The `T3` and `T9` farm claims were in process
transitions at the snapshot boundary; `T3` also had a current smoke
reservation. No claim was treated as stale. The farm task view also showed six
active and 83 pending `build_ea` tasks. This is not an admission window for
another tester-backed handoff.

## Collision and mutation boundary

The farm DB was consulted before selection, as required by the paced-fleet
mission. Because the ceiling bound first, no approved card, diverse
infrastructure repair, or new structural edge was claimed. No task or work item
was created, reprioritized, reclaimed, advanced, or re-enqueued.

The `qm-build-ea-from-card` procedure and the standard `codex_build_ea`
contract were used only to establish the build admission and capacity boundary.
No Strategy Card, EA source or binary, setfile, registry, magic resolver, build
result, pipeline evidence, or verdict was changed. No compile, smoke, backtest,
dispatch tick, terminal control, or worker control was started.

The portfolio gate, portfolio-admission surfaces, `T_Live`, AutoTrading, live
manifests, and deploy manifests were untouched. Existing unrelated shared-
worktree changes were preserved and excluded from this receipt.

## Continuation condition

A later paced wake must repeat both the DB collision check and a fresh
five-sample capacity window. It may select and atomically claim one highest-
diversity eligible unit only when both average and maximum CPU remain strictly
below `97%`. It must not infer that any observed active row is stale or
reclaimable without separate authenticated evidence.
