# Diversity funnel — peak-only CPU-ceiling stop during tester turnover

Date: 2026-08-30 UTC (`2026-08-30T03:00:31.9381664Z`); 2026-08-30
05:00 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `fcc265521b7ea0a87abb18da678c79ab0f29ab34`

Status: stopped at the explicit backtest CPU ceiling before approved-backlog
ranking, farm claim, EA selection, build, infrastructure repair, mechanization,
or Q02 enqueue.

## Binding capacity result

The fresh five-sample whole-host CPU window measured `98.711199%`,
`85.925090%`, `70.842886%`, `65.824059%`, and `74.045748%`. Average CPU was
`79.069796%`, but maximum CPU was `98.711199%`. The governed admission rule
requires both measures to remain strictly below `97%`, so the maximum bound and
closed this paced wake.

No confirmation window was used to reopen the wake after the explicit stop
condition bound.

## Farm coordination state

The supported read-only farm view contained seven active rows: three
`OPT_CENSUS`, one `Q04`, one `Q09`, and two `Q10_NEWS`. The farm also exposed
two active and 58 pending `build_ea` tasks. Those build tasks were not ranked or
claimed after the capacity trigger.

Immediately before the CPU window, factory processes were visible on `T1`,
`T4`, `T6`, `T9`, and `T10`. Immediately afterward, `T6`, `T9`, and `T10`
remained visible while `T3` held a newly created reservation. The supported
slot view reported ten worker daemons, no duplicate worker, and no orphaned
factory process. This was active tester turnover, not a stale-row repair signal,
so no process, reservation, claim, queue row, or work item was altered.

## Non-duplicate delta

The preceding receipt at `2026-08-30T02:00:53Z` recorded sustained saturation:
both its `97.069163%` average and `99.124349%` maximum bound, with six active
rows and three visible factory terminals. This window is materially different:
average CPU fell to `79.069796%`, only the `98.711199%` peak bound, active rows
increased from six to seven, and the visible tester roster contracted from five
to three during the sample while a new reservation appeared.

That peak-only failure during live farm turnover is the new evidence in this
unit; it does not repeat the earlier sustained-load observation.

## Scope and safety boundary

No Strategy Card, G0 decision, EA source or binary, setfile, basket manifest,
registry, magic row, resolver, build result, queue row, claim, priority, status,
verdict, or pipeline evidence was mutated. No compile, build check, smoke,
backtest, dispatch tick, terminal reservation, terminal control, or worker
control was started. The portfolio gate, portfolio-admission surfaces,
`T_Live`, AutoTrading, and live/deploy manifests were untouched. Existing
unrelated shared-worktree changes were preserved and excluded from this commit.

Machine-readable evidence is in
`artifacts/diversity_funnel_cpu_ceiling_stop_20260830T030031Z_board_advisor.json`.

## Continuation condition

On a later paced wake, take a new five-sample capacity window. Proceed only
when both average and maximum are strictly below `97%`; then rank and atomically
claim exactly one distinct diversity-first unit through the farm DB, prefer an
approved forex, crypto-if-available, non-XNG energy, rates, or market-neutral
Card, keep backtest setfiles at `RISK_FIXED`, and enqueue Q02 without
dispatching or touching portfolio/live surfaces.
