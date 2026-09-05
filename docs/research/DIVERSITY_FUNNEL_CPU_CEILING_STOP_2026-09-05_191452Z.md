# Diversity funnel — paced CPU-ceiling stop

Date: 2026-09-05 UTC (`2026-09-05T19:14:52.3948967Z`); 2026-09-05
21:14 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `b1dcf2e93fd54113f584144d6590d380175ca02b`

Status: stopped at the explicit backtest CPU ceiling before backlog claim,
build, infrastructure repair, compile, smoke, Q02/Q03 enqueue, or dispatch.

## Binding capacity result

A fresh five-sample whole-host CPU window measured `73.746%`, `74.710%`,
`72.464%`, `82.922%`, and `99.316%`. Average CPU was `80.632%` and maximum
CPU was `99.316%`. The paced admission rule requires both measures to remain
strictly below `97%`; the maximum dimension bound.

The supported farm view independently reported four active work items: one
`Q07` and three `OPT_CENSUS`. Those rows were claimed by `T3`, `T5`, `T6`, and
`T8`. The supported MT5 slot scan, explicitly excluding `T_Live` from the
factory roster, observed running factory terminals on `T5`, `T6`, and `T8` at
`2026-09-05T19:14:37Z`; the `T3` claim was in a process transition at the
snapshot boundary and was not treated as stale. The farm task view also showed
four active and 84 pending `build_ea` tasks.

Machine-readable evidence:
`artifacts/diversity_funnel_cpu_ceiling_stop_20260905T191452Z_board_advisor.json`.

## Collision and mutation boundary

The canonical farm DB was consulted before selection, as required by the
paced-fleet mission. Because the ceiling bound first, no approved card, diverse
infrastructure repair, or new structural edge was claimed. No task or work item
was created, reprioritized, reclaimed, advanced, or re-enqueued.

The `qm-build-ea-from-card` procedure and standard `codex_build_ea` contract
were used only to establish the build admission and tester-backed smoke
boundary. No Strategy Card, EA source or binary, setfile, registry, magic
resolver, build result, pipeline evidence, or verdict was changed. No compile,
smoke, backtest, dispatch tick, terminal control, or worker control was started.

The portfolio gate, portfolio-admission surfaces, `T_Live`, AutoTrading, live
manifests, and deploy manifests were untouched. Existing unrelated shared-
worktree changes were preserved and excluded from this receipt.

## Continuation condition

A later paced wake must repeat both the DB collision check and a fresh
five-sample capacity window. It may select and atomically claim one highest-
diversity eligible unit only when both average and maximum CPU remain strictly
below `97%`. It must not infer that any observed active row is stale or
reclaimable without separate authenticated evidence.
