# Diversity funnel — hard CPU-ceiling stop

Date: 2026-08-21 UTC

Branch: `agents/board-advisor`

Status: stopped before farm claim, card selection, build, smoke, or Q02 enqueue

## Outcome

The mandatory capacity preflight bound before candidate selection. No EA or
task was claimed, and no build-backlog row was advanced. This avoids colliding
with the paced fleet and avoids starting a standard build whose required
Model-4 smoke cannot be admitted safely.

The farm database was opened through SQLite read-only mode with
`PRAGMA query_only=ON`; `quick_check=ok`. At
`2026-08-21T10:02:49.163787Z`, it held 8 active and 2,234 pending work items.
The active mix was one Q02, one Q03, one Q05, two Q06, and three Q07 items.
There were 37 pending `build_ea` tasks, but none was inspected for ownership or
claimed after the capacity gate fired.

## Binding capacity stop

Five one-second whole-host CPU samples ending at
`2026-08-21T10:01:48.1607362Z` were `99.62%`, `99.73%`, `99.32%`, `99.23%`,
and `99.90%`. Their average was `99.56%` and their maximum was `99.90%`, both
above the explicit 97% hard ceiling.

A path-filtered process census found seven governed factory terminals: `T1`,
`T2`, `T4`, `T5`, `T6`, `T7`, and `T8`. The nearby database snapshot also had
an active `T9` claim. These observations are intentionally not presented as an
atomic slot reconciliation; the CPU result independently binds the stop, so no
terminal reconciliation or process control followed.

This is a non-duplicate fleet observation 42.45 minutes after the nearby
`09:20:22Z` evidence. Active work changed from 9 to 8, pending work from 2,237
to 2,234, and the factory process roster replaced `T3`/`T10` with `T6`/`T8`.
The active phase mix also changed. The ceiling nevertheless remains binding.

Per the mission stop condition, no farm claim, Strategy Card selection, EA or
registry mutation, resolver regeneration, build check, compile, smoke,
backtest, Q02 enqueue/requeue, dispatch, terminal reservation, or priority
mutation was performed.

Machine-readable evidence is
`artifacts/diversity_funnel_hard_cpu_stop_20260821T100249Z_board_advisor.json`.

## Safety

No portfolio gate, portfolio KPI, deploy manifest, T_Live-specific state, or
AutoTrading action was queried or changed. T_Live was excluded from the
factory census by the numeric `T1`-`T10` path filter. Concurrent unrelated
worktree changes were left unstaged and untouched.

## Continuation

After sustained whole-host CPU remains below 97% with maximum headroom, rerun
the farm ownership preflight and claim exactly one highest-diversity eligible
build or diverse Q02-Q03 infrastructure repair.
