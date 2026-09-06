# Diversity funnel — paced CPU-ceiling and collision stop

Date: 2026-09-06 UTC (`2026-09-06T14:32:13.8404822Z`); 2026-09-06
16:32 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `b5ee7138f23982398c37a2c0fe1455d899bf80d1`

Status: stopped before claim, compile, smoke, Q02 enqueue, or dispatch because
the explicit host-CPU ceiling bound and the previously preserved build target
had already been advanced by another paced worker.

## Binding capacity result

A fresh five-sample whole-host CPU window measured `91.846%`, `85.514%`,
`93.167%`, `96.047%`, and `98.926%`. Average CPU was `93.100%` and maximum
CPU was `98.926%`. The paced admission rule requires both measures to remain
strictly below `97%`, so the maximum dimension bound.

The canonical farm DB concurrently held seven active work items: three
`OPT_CENSUS`, two `Q04`, one `Q06`, and one `Q08`. They occupied T2, T3, T4,
T5, T6, T9, and T10. The database also held 11,178 pending work items; that
count is queue context, not dispatch authority.

Machine-readable evidence:
`artifacts/diversity_funnel_cpu_ceiling_stop_20260906T143213Z_board_advisor.json`.

## Collision result

The preceding paced receipt preserved `QM5_41171_wti-mturnpoint-tr` as the next
candidate only after a mandatory fresh collision check. That check now fails:
the EX5 exists and farm work item `b4e7bad6-cf55-4483-bbcb-1624f5d865a6`
is active at `Q06` on `XTIUSD.DWX`, claimed by T2. Its EA source, EX5, SPEC,
and setfiles also carry concurrent shared-worktree changes. Rebuilding or
re-enqueueing it would duplicate live fleet work, so this wake left the entire
candidate tree untouched.

Because CPU admission failed first, no replacement candidate was claimed.
Selection must be repeated from current DB truth after capacity clears rather
than relying on the now-stale continuation candidate.

## Mutation boundary

No task or work item was created, claimed, reprioritized, advanced, or
re-enqueued. No EA source, EX5, setfile, Strategy Card, registry, magic
resolver, build result, pipeline evidence, or verdict was changed. No compile,
smoke, backtest, dispatch tick, terminal control, or worker control was
started.

The portfolio gate, portfolio-admission surfaces, `T_Live`, AutoTrading, live
manifests, and deploy manifests were untouched. Existing unrelated shared-
worktree changes were preserved and excluded from this receipt.

## Continuation condition

The next paced wake must repeat the live DB collision screen and take a fresh
five-sample CPU window. It may claim one different highest-diversity eligible
unit only when both CPU average and maximum remain strictly below `97%`.
