# Diversity funnel: hard CPU ceiling stop after fleet rotation

Date: 2026-08-27 UTC (`2026-08-27T04:30:24.7850869Z`); 2026-08-27 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `9149cfeac8650b002a5d0e8cba52287c826ef86f`

Status: stopped at the explicit backtest CPU ceiling before backlog ranking,
farm claim, build, repair, compile, smoke, or Q02 enqueue

## Binding result

Five fresh whole-host CPU readings were 100%, 100%, 100%, 96%, and 100%.
The average was 99.2% and the maximum was 100%. The mission's ceiling binds
when either measure reaches 97%, so the immediate stop condition applied
before candidate selection or any farm mutation.

The supported `farmctl mt5-slots` snapshot at `2026-08-27T04:30:38Z`
observed six governed factory terminals actively testing: T1, T2, T5, T6,
T7, and T9. Six terminal reservations were active, all ten terminal-worker
daemons were present, and no orphaned factory terminal process was reported.
`T_Live` and the unrelated FTMO terminal were observed only to exclude them;
neither was controlled.

The canonical farm DB was opened through SQLite URI `mode=ro`. It contained
actionable throughput work: 43 pending `build_ea` tasks, 33 pending
`backtest_p2` tasks, 146 pending `backtest_q03` tasks, and 62 pending
`backtest_q04` tasks. Two agent tasks were already `IN_PROGRESS`, so this turn
created no claim and did not collide with either assigned unit.

## Non-duplicate delta

The immediately preceding source-build receipt at `2026-08-27T04:20:35Z`
observed all seven permitted factory terminals active: T2, T4, T5, T6, T7,
T9, and T10, with five CPU readings at 100%. This later snapshot records a
rotated six-terminal cohort in which T1 joined while T4 and T10 left. The
terminal-count ceiling cleared, but the independent whole-host CPU ceiling
remained binding at 99.2% average and 100% maximum. This is changed governed-
capacity evidence, not a duplicate queue insertion.

## Actions and safety

Per the hard-stop instruction, no approved card or stuck diverse EA was
ranked or claimed. No source, Card, EA, registry row, magic row, resolver,
binary, setfile, basket manifest, farm task, work item, queue priority,
verdict, dispatch, reservation, worker, terminal, tester, or backtest was
created or changed. No build check, compile, smoke test, or pipeline phase was
started.

- No portfolio gate or Q08-contribution path was touched.
- No T_Live manifest, T_Live control, or AutoTrading surface was touched.
- Concurrent unrelated worktree changes were preserved and excluded from
  this evidence-only commit.

Machine-readable evidence is
`artifacts/diversity_funnel_hard_cpu_stop_20260827T043024Z_board_advisor.json`.

## Continuation condition

On a later paced turn, repeat the five-reading preflight. Only when both the
average and maximum are below 97% should an agent atomically claim one
distinct, highest-diversity approved card or diverse Q02-Q03 infrastructure
repair.
