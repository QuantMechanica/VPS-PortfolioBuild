# Diversity funnel — changed-topology CPU-ceiling stop

Date: 2026-08-30 UTC (`2026-08-30T02:00:53.8893031Z`); 2026-08-30
04:00 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `2213944c5c83b34f8b719b7bb9277dd632bd6a8c`

Status: stopped at the explicit backtest CPU ceiling before approved-backlog
ranking, farm claim, EA selection, build, infrastructure repair, mechanization,
or Q02 enqueue.

## Binding capacity result

The fresh five-sample whole-host CPU window measured `99.124349%`,
`98.309268%`, `96.251223%`, `96.192186%`, and `95.468789%`. Average CPU was
`97.069163%` and maximum CPU was `99.124349%`. The governed admission rule
requires both measures to remain strictly below `97%`; both sides of the rule
therefore bound.

No confirmation window was used to reopen this wake. Once the explicit stop
condition bound, work admission remained closed.

## Farm coordination state

The supported read-only farm view contained six active rows: one `OPT_CENSUS`,
one `Q04`, two `Q09`, and two `Q10_NEWS`. Three tester processes were visible
on `T2`, `T3`, and `T10`, with matching reservations; `T9` also held a fresh
reservation but had no visible tester in the point-in-time scan. Ten worker
daemons were present, with no duplicate worker and no orphaned factory terminal
process.

The three active rows without a visible process were not treated as stale: the
two Q09 claims had just updated, and T9 had a fresh reservation. Nothing was
reclaimed, repaired, re-enqueued, or reprioritized.

Farm status exposed two active and 58 pending `build_ea` tasks. They were not
ranked after the capacity trigger, avoiding collision with the other paced
agents.

## Non-duplicate delta

The preceding capacity receipt at `2026-08-30T00:45:05Z` observed six running
testers on `T1`, `T3`, `T4`, `T5`, `T8`, and `T9`, nine active farm rows, and a
57-row pending build backlog. The current visible roster contracted to `T2`,
`T3`, and `T10`, active rows fell to six, and the pending build backlog rose to
58. Despite the smaller tester roster, the longer five-second sample window
still averaged above the hard ceiling. This changed saturation topology is the
new evidence recorded by this unit.

## Scope and safety boundary

No Strategy Card, G0 decision, EA source or binary, setfile, basket manifest,
registry, magic row, resolver, build result, queue row, claim, priority, status,
verdict, or pipeline evidence was mutated. No compile, build check, smoke,
backtest, dispatch tick, terminal control, or worker control was started. The
portfolio gate, portfolio-admission surfaces, `T_Live`, AutoTrading, and
live/deploy manifests were untouched. Existing unrelated shared-worktree
changes were preserved and excluded from this commit.

Machine-readable evidence is in
`artifacts/diversity_funnel_cpu_ceiling_stop_20260830T020053Z_board_advisor.json`.

## Continuation condition

On a later paced wake, take a new five-sample capacity window. Proceed only
when both average and maximum are strictly below `97%`; then rank and atomically
claim exactly one distinct diversity-first unit through the farm DB, prefer an
approved forex, crypto-if-available, non-XNG energy, rates, or market-neutral
Card, keep backtest setfiles at `RISK_FIXED`, and enqueue Q02 without
dispatching or touching portfolio/live surfaces.
