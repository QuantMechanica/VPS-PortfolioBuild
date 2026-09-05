# Diversity funnel — paced CPU-ceiling stop

Date: 2026-09-05 UTC (`2026-09-05T03:00:58.6635212Z`); 2026-09-05
05:00 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `9aba19bd1f308db15de38daf968cdb19952534ed`

Status: stopped at the explicit backtest CPU ceiling before backlog claim,
build, infrastructure repair, compile, smoke, Q02/Q03 enqueue, or dispatch.

## Binding capacity result

A fresh five-sample whole-host CPU window measured `98.634%`, `98.929%`,
`93.952%`, `86.824%`, and `94.827%`. Average CPU was `94.633%` and maximum
CPU was `98.929%`. The paced admission rule requires both measures to remain
strictly below `97%`; the maximum side therefore bound.

The farm snapshot independently reported eight active work items: one `Q06`,
two `Q08`, and five `OPT_CENSUS`. Those rows were claimed by `T1` through `T7`
and `T10`. The path-anchored MT5 factory scan, explicitly excluding `T_Live`,
observed running terminals on `T1`, `T2`, `T4`, `T5`, `T6`, and `T10`; the
`T3` and `T7` farm claims were in process transitions at the snapshot boundary.
No claim was treated as stale. This is not an admission window for another
tester-backed handoff.

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
