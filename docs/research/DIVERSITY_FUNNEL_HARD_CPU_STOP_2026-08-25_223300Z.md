# Diversity funnel — changed gate mix / hard CPU stop

Date: 2026-08-25 UTC (`2026-08-25T22:33:00Z`)

Branch: `agents/board-advisor`

Observation base: `b74ac598878813a14692791cd9861e86c5a94c89`

Status: stopped before farm claim, candidate ranking, build, repair, compile,
smoke, or Q02/Q03 enqueue because the explicit backtest CPU ceiling is binding

## Outcome

Five fresh one-second whole-host CPU samples were `100.00%`, `96.79%`,
`92.00%`, `90.66%`, and `99.90%`. Their average was `95.87%`, below the
governed `97%` ceiling, but their maximum was `100.00%`. The admission rule
binds when either the average or maximum is at least `97%`, so the maximum
required an immediate stop. The sample was not repeated in search of a lower
reading, and no CPU-consuming or queue-mutating work was admitted.

No approved card, built-but-stuck EA, or new structural edge was selected.
The `qm-build-ea-from-card` workflow therefore did not enter its card,
registry, magic, compile, setfile, or handoff stages.

## Read-only coordination snapshot

The farm database held seven active work items and 3,731 pending items. The
active gate mix was one Q03, one Q07, one Q09, and four Q10_NEWS rows. The
supported `farmctl mt5-slots` view saw five running factory terminals and five
matching reservations on T2, T4, T6, T7, and T9, plus all ten terminal-worker
processes.

Two database claims had no matching terminal process in the non-atomic scan:
T1 held Q09 work item `e6bef83e-8ce1-4b53-b9e1-5d07fa09024d`, and T8 held
Q10_NEWS work item `14e2dbb2-c2fc-49f3-b7e5-8e6b853d0867`. These observations
were recorded without diagnosis or reconciliation under the capacity stop.

The two `build_ea` tasks already in `IN_PROGRESS` remain separately owned by
the Gemini lane: QM5_20065 (`7e8c9eaa-1af5-40ca-9f49-4c785b5ae07d`) and
QM5_20077 (`6c35c3ec-b576-4919-a321-796b7c813350`). No competing EA claim was
created.

## Non-duplicate delta

The preceding diversity receipt at
`artifacts/diversity_funnel_hard_cpu_stop_20260825T183325Z_board_advisor.json`
observed eight active rows split between two Q07 and six Q10_NEWS runs. The
current snapshot has seven active rows spanning Q03, Q07, Q09, and Q10_NEWS.

The latest general receipt at
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260825T214742Z_board_advisor.json`
observed six running factory terminals and seven reservations. The current
snapshot has five of each; T4 joined while T5 and T8 left the running roster.
Average CPU fell from `99.98%` to `95.87%`, but maximum CPU remained `100.00%`,
so this is a changed gate/terminal state rather than a duplicate queue action.

Machine-readable evidence is
`artifacts/diversity_funnel_hard_cpu_stop_20260825T223300Z_board_advisor.json`.

## Safety

- Farm DB inspection used a SQLite read-only URI; the terminal census used the supported read-only operator view.
- No Strategy Card, EA, registry row, magic resolver, binary, or setfile changed.
- No compile, build check, smoke test, backtest, terminal reservation, dispatch, enqueue, requeue, reconciliation, or terminal control ran.
- The portfolio gate, T_Live manifest, T_Live, and AutoTrading were untouched.
- Concurrent unrelated worktree changes were left unstaged and uncommitted.
