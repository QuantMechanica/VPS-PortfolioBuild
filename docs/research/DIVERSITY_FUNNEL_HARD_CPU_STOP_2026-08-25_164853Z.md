# Diversity funnel — refreshed topology hard CPU stop

Date: 2026-08-25 UTC (`2026-08-25T16:48:53Z`)

Branch: `agents/board-advisor`

Observation base: `ce99ed6736ba261df6645d14b769031ba88ee3a4`

Status: stopped before farm claim, build, repair, compile, smoke, or Q02/Q03
enqueue because the explicit backtest CPU ceiling is binding

## Outcome

Five fresh one-second whole-host CPU samples were `100.00%`, `100.00%`,
`100.00%`, `99.71%`, and `99.71%`. Their average was `99.883%` and their
maximum was `100.00%`, so both measurements exceed the governed `97%`
average-or-maximum ceiling. No CPU-consuming or queue-mutating work was
admitted.

The live farm database was inspected through a SQLite read-only URI. It held
eight active and 3,621 pending work items. All eight active rows were
`Q10_NEWS`; they span `GBPUSD.DWX`, `GDAXI.DWX`, `SP500.DWX`, and
`XAUUSD.DWX`. The supported `farmctl mt5-slots` census saw five matching
factory terminal processes on T1, T3, T4, T9, and T10, while the database also
carried active claims on T6, T7, and T8 without matching terminal processes in
that scan. Six terminal reservations were active. The discrepancy is recorded
for later capacity-safe reconciliation and was not repaired under the stop
condition.

Farm coordination also showed 46 pending legacy `build_ea` tasks. The paced
agent queue already assigned `QM5_20065` and `QM5_20077` to Gemini, so those
identities remain separately owned. No card or EA was claimed by this run.

## Non-duplicate delta

The preceding diversity receipt at
`docs/research/DIVERSITY_FUNNEL_HARD_CPU_STOP_2026-08-25_150122Z.md` observed
3,628 pending work items and an active mix of one Q07 row plus seven Q10_NEWS
rows. This snapshot has seven fewer pending rows and eight Q10_NEWS rows, with
no active Q07 row.

The most recent general fleet receipt at
`docs/research/FX_COINTEGRATION_FRONTIER_HARD_CPU_STOP_2026-08-25_161713Z.md`
saw governed terminal processes on T1, T4, T6, T7, and T9 and average CPU of
`94.96%`. The current set is T1, T3, T4, T9, and T10 and average CPU is
`99.883%`; the maximum remains `100.00%`. This is a changed execution topology,
not a duplicate capacity sample.

Machine-readable evidence is
`artifacts/diversity_funnel_hard_cpu_stop_20260825T164853Z_board_advisor.json`.

## Safety

- Farm inspection used a read-only SQLite URI; no task or work-item row changed.
- No Strategy Card, EA, registry row, magic resolver, binary, or setfile changed.
- No compile, build check, smoke test, backtest, terminal reservation, dispatch,
  enqueue, requeue, or terminal control was run.
- The portfolio gate, T_Live manifest, T_Live, and AutoTrading were untouched.
- Concurrent unrelated worktree changes were left unstaged and uncommitted.
