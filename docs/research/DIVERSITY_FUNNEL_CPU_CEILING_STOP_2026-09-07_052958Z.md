# Diversity funnel — paced CPU-ceiling stop

Date: 2026-09-07 UTC (`2026-09-07T05:29:58.9546989Z`); 07:29 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `731035fc795f93f5be5d3cfadd35536e42a3829e`

Status: stopped at the explicit factory CPU ceiling before backlog selection,
claim, build, compile, smoke, Q02 enqueue, dispatch, or terminal control.

## Binding capacity result

A fresh five-sample whole-host CPU window measured `88%`, `90%`, `100%`,
`88%`, and `84%`. Average CPU was `90%` and maximum CPU was `100%`. The
paced admission rule requires both measures to remain strictly below `97%`,
so the maximum dimension bound.

The supported farm view concurrently reported eight active work items: five
`OPT_CENSUS`, two `Q04`, and one `Q07`. The supported MT5 slot scan observed
running factory terminals on T3 through T10 except no gaps in that range;
`T_Live` and an unrelated FTMO process were excluded from the factory roster.
The task view also reported six active and 77 pending `build_ea` tasks.

Machine-readable evidence:
`artifacts/diversity_funnel_cpu_ceiling_stop_20260907T052958Z_board_advisor.json`.

## Collision recheck

The previous paced receipt's proposed next build,
`QM5_41171_wti-mturnpoint-tr`, is no longer eligible. The canonical farm DB now
contains three `COMPILE_OK` rows, three Q02 `PASS` rows, three Q04
`PASS_LOWFREQ` rows, and a terminal Q07 `FAIL` for that EA. The supported
compile-status view reports a current compiled EX5 with SHA-256
`1eb203082384ddd3212c6eb4f3bda8617a26fa02828db56decb41f73ce5c22f2`.
Rebuilding or re-enqueueing it would be duplicate work.

No replacement candidate was selected or claimed after the capacity gate
bound. A later unsaturated wake must rerank against the then-current farm DB
rather than inherit the stale September 5 candidate.

## Mutation boundary

Because the ceiling bound, no task or work item was created, claimed,
reprioritized, advanced, or re-enqueued. No EA source, EX5, setfile, Strategy
Card, registry, magic resolver, build result, pipeline evidence, or verdict was
changed. No compile, smoke, backtest, dispatch tick, terminal control, or
worker control was started.

The portfolio gate, portfolio-admission surfaces, `T_Live`, AutoTrading, live
manifests, and deploy manifests were untouched. Existing unrelated shared-
worktree changes were preserved and excluded from this receipt.

## Continuation condition

Take a fresh five-sample whole-host CPU window. Only rank and atomically claim
one current high-diversity unit when both average and maximum CPU are strictly
below `97%`. Do not select `QM5_41171` again.
