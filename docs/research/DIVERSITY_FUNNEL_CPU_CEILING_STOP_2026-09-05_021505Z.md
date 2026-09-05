# Diversity funnel — paced CPU-ceiling stop

Date: 2026-09-05 UTC (`2026-09-05T02:15:05.4447017Z`); 2026-09-05
04:15 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `5037994d419871f9fd3a6fdb3904cf5fd8f3a5af`

Status: stopped at the explicit backtest CPU ceiling before backlog claim,
build, infrastructure repair, compile, smoke, Q02/Q03 enqueue, or dispatch.

## Binding capacity result

A fresh five-sample whole-host CPU window measured `87.1934%`, `95.7841%`,
`95.9639%`, `99.9514%`, and `100.0000%`. Average CPU was `95.7786%` and
maximum CPU was `100.0000%`. The paced admission rule requires both measures
to remain strictly below `97%`; the maximum side therefore bound.

The supported farm view independently reported seven active work items: one
`Q05`, one `Q07`, one `Q08`, and four `OPT_CENSUS`. Those rows were claimed by
`T1`, `T3`, `T6`, `T7`, `T8`, `T9`, and `T10`. The supported MT5 slot scan
observed running factory terminals on `T1`, `T3`, `T6`, `T8`, `T9`, and `T10`;
the `T7` farm claim was in a process transition at the snapshot boundary. This
is not an admission window for another tester-backed handoff.

## Collision and mutation boundary

The farm DB was consulted before selection, as required by the paced-fleet
mission. Because the ceiling bound first, no approved card, diverse
infrastructure repair, or new structural edge was claimed. No task or work item
was created, reprioritized, reclaimed, advanced, or re-enqueued. The `T7`
claim/process mismatch was recorded without inferring that the claim was stale.

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
