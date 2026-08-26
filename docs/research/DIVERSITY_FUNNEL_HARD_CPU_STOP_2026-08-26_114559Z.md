# Diversity funnel: five-terminal hard CPU stop

Date: 2026-08-26 UTC (`2026-08-26T11:45:59Z`), Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `563957af5ddf8777a3185ccc2c521a56fedb0717`

Status: stopped before backlog inspection, farm claim, card selection, build,
compile, smoke, or Q02 enqueue because the explicit backtest CPU ceiling was
binding

## Binding capacity result

The supported `farmctl mt5-slots` snapshot at `2026-08-26T11:45:34Z`
observed five governed factory terminals actively testing: T1, T5, T7, T8,
and T9. Ten terminal-worker daemons were alive, five reservations were active,
and no orphaned factory terminal process was reported. Four active rows were
Q10 news runs and one was the diverse `QM5_20203` EURUSD/AUDJPY basket at Q03.
`T_Live` and the unrelated FTMO terminal were observed only to exclude them;
neither was controlled.

Five fresh one-second whole-host CPU readings were `98.83%`, `98.44%`,
`91.04%`, `86.43%`, and `93.76%`. Their average was `93.70%` and their maximum
was `98.83%`. The governed ceiling binds when either average or maximum is at
least `97%`; the maximum triggered the stop. Five `metatester64` processes were
present at sample completion.

Per the mission stop condition, no approved-card claim, EA or Strategy Card,
registry or magic mutation, compile, build check, smoke, Q02 enqueue/requeue,
priority change, dispatch tick, terminal reservation, terminal control, or
backtest followed. The read-only farm census had reported 43 pending build
tasks, but capacity bound before any backlog identity was inspected or claimed.

Machine-readable evidence is in
`artifacts/diversity_funnel_hard_cpu_stop_20260826T114559Z_board_advisor.json`.

## Non-duplicate delta

The immediately preceding fleet receipt at `2026-08-26T11:16:19Z` observed
four factory terminals (T1, T7, T8, and T9), a `99.92%` average, and a `100%`
maximum. This receipt observes T5 joining that cohort; average CPU eased to
`93.70%`, while the `98.83%` peak alone kept the ceiling binding. It documents
a changed governed cohort and binding measure, not another pair, card, EA,
claim, or queue item.

## Safety and worktree isolation

- No portfolio gate, portfolio KPI, Q08-contribution path, or live-use state changed.
- No T_Live manifest, terminal, or AutoTrading state changed.
- No farm DB, Strategy Card, EA, EX5, setfile, basket manifest, registry row, or magic row changed.
- Concurrent unrelated worktree changes were preserved and excluded from this receipt.
