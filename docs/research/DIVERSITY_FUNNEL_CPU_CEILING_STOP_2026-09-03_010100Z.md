# Diversity funnel — CPU-ceiling stop before farm claim

Date: 2026-09-03 UTC (`2026-09-03T01:01:00.1377808Z`); 03:01 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `f5e942be408c9f581eb77af5f6ce331c7e5af674`

Status: stopped at the explicit backtest CPU ceiling before candidate selection,
farm claim, compile, smoke, Q02 enqueue, dispatch, or terminal control.

## Binding capacity result

The fresh five-sample whole-host CPU window measured `100.00%`, `100.00%`,
`99.61%`, `99.80%`, and `96.49%`. Average CPU was `99.18%` and maximum CPU was
`100.00%`. The paced admission rule requires both measures to remain strictly
below `97%`; both dimensions bound.

The capacity result was treated as a pre-claim gate. No confirmation window was
used to reopen this wake after the OWNER's stop condition fired.

## Farm coordination snapshot

The read-only farm snapshot at `2026-09-03T01:01:00Z` contained seven active
work items: one Q07, two Q09, three Q10_NEWS, and one OPT_CENSUS. They were
claimed by T1, T2, T4, T5, T7, T8, and T9. Farm task status also showed six
active and 77 pending `build_ea` tasks, so creating an uncoordinated build would
have carried material collision risk.

The immediately preceding MT5 process scan at `01:00:27Z` observed eight
path-anchored factory terminals, T1-T5 and T7-T9. T3's OPT_CENSUS row completed
between that scan and the work-item snapshot. The separate T_Live and FTMO
processes were observed but excluded from factory capacity and not controlled.

Because the CPU ceiling bound before selection, no priority-1 approved card,
priority-2 diverse infrastructure repair, or priority-3 edge was claimed. This
preserves the farm DB as the collision authority and leaves no ambiguous partial
ownership for the next paced wake.

## Scope and safety boundary

No farm row, Strategy Card, EA source or binary, setfile, registry, resolver,
build result, task, work item, priority, verdict, or pipeline evidence was
mutated. No compile, smoke, backtest, enqueue, dispatch tick, reservation,
release, process stop, or worker control was attempted.

The portfolio gate, T_Live, AutoTrading, deploy manifests, and live manifests
were untouched. Existing unrelated shared-worktree changes were preserved and
excluded from this evidence commit.

Machine-readable evidence is in
`artifacts/diversity_funnel_cpu_ceiling_stop_20260903T010100Z_board_advisor.json`.

## Continuation condition

A later paced wake must take a new five-sample whole-host CPU window and proceed
only when both its average and maximum are strictly below `97%`. It must then
re-read current approved-card, registry, build-task, and work-item state and
atomically claim exactly one distinct highest-diversity eligible unit before
changing any EA artifact.
