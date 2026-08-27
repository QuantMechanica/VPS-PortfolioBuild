# Diversity funnel: sustained hard CPU ceiling stop

Date: 2026-08-27 UTC (`2026-08-27T03:30:33Z`); 2026-08-27 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `b36f71804443f615190cc9520a6992d3aca48317`

Status: stopped at the explicit backtest CPU ceiling before backlog ranking,
farm claim, build, repair, compile, smoke, or Q02 enqueue

## Binding result

Five fresh whole-host CPU readings were 100%, 100%, 100%, 100%, and 100%.
Both the average and maximum were 100%. The mission's ceiling binds when
either measure reaches 97%, so the immediate stop condition applied before
candidate selection or any farm mutation.

The supported `farmctl mt5-slots` snapshot at `2026-08-27T03:30:20Z`
observed six governed factory terminals actively testing: T1, T5, T6, T8,
T9, and T10. Seven terminal reservations were active, eight terminal-worker
daemons were present, and no orphaned factory terminal process was reported.
`T_Live` and the unrelated FTMO terminal were observed only to exclude them;
neither was controlled.

The canonical farm DB was opened through SQLite URI `mode=ro`. It still
contained actionable throughput work: 43 pending `build_ea` tasks, 33 pending
`backtest_p2` tasks, 146 pending `backtest_q03` tasks, and 62 pending
`backtest_q04` tasks. Two agent tasks were already `IN_PROGRESS`, so this turn
created no claim and did not collide with either assigned unit.

## Non-duplicate delta

The immediately preceding capacity receipt at `2026-08-27T03:01:34Z`
observed seven active factory terminals (T1, T2, T5, T6, T7, T9, and T10),
all ten worker daemons, seven reservations, and 99.99% average CPU. This later
snapshot records a rotated six-terminal cohort in which T8 joined while T2
and T7 left, only eight worker daemons were visible, reservations remained at
seven, and all five CPU samples reached 100%. It is changed governed-capacity
evidence, not a duplicate queue insertion.

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
`artifacts/diversity_funnel_hard_cpu_stop_20260827T033033Z_board_advisor.json`.

## Continuation condition

On a later paced turn, repeat the five-reading preflight. Only when both the
average and maximum are below 97% should an agent atomically claim one
distinct, highest-diversity approved card or diverse Q02-Q03 infrastructure
repair.
