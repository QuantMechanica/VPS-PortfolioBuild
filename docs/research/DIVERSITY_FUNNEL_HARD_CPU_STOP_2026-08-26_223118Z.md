# Diversity funnel — rotated cohort at hard CPU ceiling

Date: 2026-08-26 UTC (`2026-08-26T22:31:18Z`), Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `e9ae07157fd6a5bc2ab98ce20b732a2828a305ed`

Status: stopped at the explicit backtest CPU ceiling before backlog selection,
farm claim, build, repair, compile, smoke, or Q02 enqueue.

## Binding result

Five fresh whole-host CPU readings were `100%`, `100%`, `99%`, `94%`, and
`97%`. Their average was `98%` and their maximum was `100%`. The mission's
ceiling binds when either measure reaches `97%`, so both the average and the
maximum independently required a stop.

The supported read-only `farmctl mt5-slots` scan immediately before sampling
found five governed factory terminals actively testing: T1, T4, T5, T6, and
T7. All ten terminal-worker daemons were present, five terminal reservations
were active, five `metatester64` processes were present, and no orphaned
factory terminal process was reported. `T_Live` and the unrelated FTMO
terminal were observed only to exclude them; neither was controlled.

The canonical farm DB was opened read-only. It reported 43 pending `build_ea`
tasks, 33 pending `backtest_p2` tasks, 146 pending `backtest_q03` tasks, and 62
pending `backtest_q04` tasks. No agent task was open and no claim was inserted.
This confirms there is work available, but capacity—not build supply—is the
binding constraint in this paced turn.

## Non-duplicate delta

The preceding branch receipt at `2026-08-26T21:45:53Z` observed five running
factory terminals: T1, T4, T6, T7, and T9, with `97.6%` average CPU. This later
snapshot records a rotated cohort in which T5 replaced T9 and average CPU rose
to `98%`. It therefore captures changed farm state without duplicating a claim,
compile, or queue insertion.

## Actions and safety

Per the hard-stop instruction, no approved card or stuck diverse EA was
selected or claimed. No source, card, EA, registry row, magic row, resolver,
binary, setfile, basket manifest, farm task, work item, queue priority, verdict,
dispatch, reservation, worker, terminal, tester, or backtest was created or
changed. No build check, compile, smoke test, or pipeline phase was started.

- No portfolio gate or Q08 contribution path was touched.
- No T_Live manifest, T_Live control, or AutoTrading surface was touched.
- Concurrent unrelated worktree changes were preserved and excluded from this
  evidence-only commit.

Machine-readable evidence is
`artifacts/diversity_funnel_hard_cpu_stop_20260826T223118Z_board_advisor.json`.

## Continuation condition

On a later paced turn, repeat the five-reading preflight. Only when both the
average and maximum are below `97%` should an agent claim one distinct,
highest-diversity approved card or diverse Q02-Q03 infrastructure repair.
