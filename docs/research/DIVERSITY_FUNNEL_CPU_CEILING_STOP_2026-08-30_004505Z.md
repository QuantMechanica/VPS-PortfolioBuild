# Diversity funnel — six-tester hard CPU stop

Date: 2026-08-30 UTC (`2026-08-30T00:45:05.7779860Z`); 2026-08-30
02:45 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `342cf22ca381724fe234a1074cd9ab396653afb4`

Status: stopped at the explicit backtest CPU ceiling before approved-backlog
ranking, farm claim, EA selection, build, infrastructure repair, mechanization,
or Q02 enqueue.

## Binding capacity result

The fresh five-sample whole-host CPU window measured `78.151816%`,
`99.128181%`, `100.000000%`, `100.000000%`, and `98.732715%`. Average CPU
was `95.202543%` and maximum CPU was `100.000000%`. The governed admission
rule requires both measures to remain strictly below `97%`; the maximum-side
condition therefore bound immediately.

No confirmation window was used to reopen this wake. Once the explicit stop
condition bound, work admission remained closed.

## Farm coordination state

The supported read-only farm view contained nine active rows: four
`OPT_CENSUS`, one `Q04`, two `Q09`, and two `Q10_NEWS`. Six tester processes
were visible on `T1`, `T3`, `T4`, `T5`, `T8`, and `T9`, with matching
reservations. Ten worker daemons were present, with no duplicate worker and no
orphaned factory terminal process.

Three active optimization rows claimed by `T2`, `T7`, and `T10` were not
represented by a tester process in the point-in-time process scan. Their farm
rows had recently updated claims, so absence was not treated as evidence of a
stale claim. Nothing was reclaimed, repaired, re-enqueued, or reprioritized.

The farm status also exposed two active and 57 pending `build_ea` tasks. They
were deliberately not ranked after the capacity trigger, avoiding collision
with the other paced agents.

## Non-duplicate delta

The preceding capacity receipt at `2026-08-30T00:05:08Z` observed three
running testers on `T4`, `T7`, and `T9`, with a `72.604256%` average and a
`98.221967%` maximum. The current visible roster doubled to six testers and
changed to `T1`, `T3`, `T4`, `T5`, `T8`, and `T9`; nine rows were active across
four workloads, and the fresh sample reached `100%` twice. This changed
saturation topology is the new evidence recorded by this unit.

## Scope and safety boundary

No Strategy Card, G0 decision, EA source or binary, setfile, basket manifest,
registry, magic row, resolver, build result, queue row, claim, priority,
status, verdict, or pipeline evidence was mutated. No compile, build check,
smoke, backtest, dispatch tick, terminal control, or worker control was
started. The portfolio gate, portfolio-admission surfaces, `T_Live`,
AutoTrading, and live/deploy manifests were untouched. Existing unrelated
shared-worktree changes were preserved and excluded from this commit.

Machine-readable evidence is in
`artifacts/diversity_funnel_cpu_ceiling_stop_20260830T004505Z_board_advisor.json`.

## Continuation condition

On a later paced wake, take a new five-sample capacity window. Proceed only
when both average and maximum are strictly below `97%`; then rank and
atomically claim exactly one distinct diversity-first unit through the farm
DB, prefer an approved forex, crypto-if-available, non-XNG energy, rates, or
market-neutral Card, keep backtest setfiles at `RISK_FIXED`, and enqueue Q02
without dispatching or touching portfolio/live surfaces.
