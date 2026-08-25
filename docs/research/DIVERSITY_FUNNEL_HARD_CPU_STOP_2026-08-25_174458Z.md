# Diversity funnel — maximum-only hard CPU stop

Date: 2026-08-25 UTC (`2026-08-25T17:44:58Z`)

Branch: `agents/board-advisor`

Observation base: `598a3e3221b2e273ff161763cf439c3b56ba08dd`

Status: stopped before farm claim, candidate ranking, build, repair, compile,
smoke, or Q02/Q03 enqueue because the explicit backtest CPU ceiling is binding

## Outcome

Five fresh one-second whole-host CPU samples were `79.01%`, `93.15%`,
`97.28%`, `96.58%`, and `84.20%`. Their average was `90.04%`, below the
governed `97%` ceiling, but their maximum was `97.28%`. The admission rule
binds when either the average or maximum is at least `97%`, so the maximum
alone required an immediate stop. The sample was not repeated in search of a
lower reading, and no CPU-consuming or queue-mutating work was admitted.

The farm database was then inspected through a SQLite read-only URI solely to
leave coordination evidence. It held six active and 3,609 pending work items.
All six active rows were `Q10_NEWS`, spanning `GBPUSD.DWX`, `GDAXI.DWX`, and
`XAUUSD.DWX`. The supported `farmctl mt5-slots` census saw five matching
factory terminal processes on T3, T4, T7, T8, and T9. The database also held
one active T6 claim without a matching T6 terminal process in that scan; this
was recorded but not reconciled under the stop condition.

The only `build_ea` tasks in `IN_PROGRESS` remain separately owned by Gemini:
`QM5_20065` (`7e8c9eaa-1af5-40ca-9f49-4c785b5ae07d`) and `QM5_20077`
(`6c35c3ec-b576-4919-a321-796b7c813350`). No EA was claimed or advanced by
this run. Concurrent pre-existing branch work and dirty generated setfiles
were preserved and excluded from the evidence commit.

## Non-duplicate delta

The preceding diversity receipt at
`artifacts/diversity_funnel_hard_cpu_stop_20260825T164853Z_board_advisor.json`
observed eight active and 3,621 pending work items. The current farm has two
fewer active rows and twelve fewer pending rows.

The most recent general fleet receipt at
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260825T171613Z_board_advisor.json`
saw T4, T6, T7, T8, and T9 at `99.95%` average and `100.00%` maximum CPU. The
current roster instead has T3, T4, T7, T8, and T9; average CPU fell to
`90.04%` and maximum CPU fell to `97.28%`. This records the transition from
both CPU measures binding to a maximum-only stop, rather than duplicating the
earlier saturation receipt.

Machine-readable evidence is
`artifacts/diversity_funnel_hard_cpu_stop_20260825T174458Z_board_advisor.json`.

## Safety

- Farm inspection used a read-only SQLite URI; no task or work-item row changed.
- No Strategy Card, EA, registry row, magic resolver, binary, or setfile changed.
- No compile, build check, smoke test, backtest, terminal reservation, dispatch,
  enqueue, requeue, reconciliation, or terminal control was run.
- The portfolio gate, T_Live manifest, T_Live, and AutoTrading were untouched.
- Concurrent unrelated worktree changes were left unstaged and uncommitted.
