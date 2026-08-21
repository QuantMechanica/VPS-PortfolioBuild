# Diversity funnel hard CPU stop

Date: 2026-08-21 UTC

Branch: `agents/board-advisor`

Status: stopped before farm claim, build, smoke, or Q02 enqueue because the
explicit backtest CPU ceiling is binding

## Outcome

No Strategy Card or EA was claimed or changed. The read-only farm snapshot
contained 37 pending `build_ea` tasks, but the mandatory capacity preflight
fired before candidate selection. This preserves distinct ownership across the
paced fleet and avoids starting a standard build whose required Model-4 smoke
cannot be admitted safely.

The live farm database was opened through SQLite read-only mode and returned
`quick_check=ok`. At `2026-08-21T04:04:14Z` it contained eight active work
items and 2,223 pending work items. The active mix was one Q02, one Q03, one
Q05, three Q07, and two Q08 items. The two Q08 jobs were already consuming
funnel capacity on `NDX.DWX` and `GDAXI.DWX`; neither was disturbed.

## Binding capacity stop

Five fresh one-second whole-host CPU samples from `04:03:58Z` through
`04:04:02Z` were `100.00%`, `99.81%`, `98.64%`, `99.61%`, and `100.00%`.
Their average was `99.61%` and their maximum was `100.00%`, both above the
explicit `97%` hard ceiling.

A nearby path-anchored process census found six factory terminals: T2, T3,
T4, T6, T7, and T9. The database concurrently showed eight active claims,
including recently transitioning T1 and T8 rows. The process and database
observations are intentionally reported separately rather than treated as an
atomic slot reconciliation; the host CPU reading independently binds the stop.
No terminal reconciliation or control followed.

This is a fresh observation 32.70 minutes after the preceding branch evidence
at `03:31:32Z`. Active work changed from six to eight and pending work changed
from 2,225 to 2,223. Six active identities arrived and four departed, so this
record captures a materially different fleet state rather than restating the
prior snapshot.

Per the mission stop condition, no farm claim, Card, EA, registry row, magic
row, resolver output, build check, compile, smoke, queue enqueue/requeue,
dispatch tick, tester launch, terminal reservation, or priority mutation was
performed.

Machine-readable evidence is
`artifacts/diversity_funnel_hard_cpu_stop_20260821T040414Z_board_advisor.json`.

## Safety

No portfolio gate, portfolio KPI, Q08 contribution, T_Live manifest, T_Live
terminal, AutoTrading state, or live deployment surface was queried or
changed. T_Live was excluded by the factory-path filter. Concurrent unrelated
worktree changes were left unstaged and untouched.
