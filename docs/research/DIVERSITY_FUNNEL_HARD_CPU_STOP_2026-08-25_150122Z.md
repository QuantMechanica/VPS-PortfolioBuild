# Diversity funnel — hard CPU stop

Date: 2026-08-25 UTC (`2026-08-25T15:01:22Z`)

Branch: `agents/board-advisor`

Status: stopped before farm claim, build, repair, compile, smoke, or Q02/Q03
enqueue because the explicit backtest CPU ceiling is binding

## Outcome

Five one-second whole-host CPU samples were `99.52%`, `100.00%`, `100.00%`,
`97.00%`, and `100.00%`. Their average was `99.304%` and their maximum was
`100.00%`, so both measurements bind the governed `97%`
average-or-maximum ceiling. No CPU-consuming or queue-mutating work was
admitted.

The supported farm status command encountered `database is locked`; the
authoritative database was therefore inspected through a SQLite read-only URI.
It contained eight active and 3,628 pending work items. The active topology was
one Q07 `USDJPY.DWX` row and seven Q10_NEWS rows across `GDAXI.DWX`,
`SP500.DWX`, and `XAUUSD.DWX`. Seven matching pipeline terminal processes were
visible; the T8-claimed active database row had no matching terminal process in
that scan. The discrepancy is recorded for a later capacity-safe reconciliation
and was not repaired under the stop condition.

There were 46 pending legacy `build_ea` tasks. The newly reserved
`QM5_41157_xauxag-mtheilsen-rv` identity is not yet an approved Strategy Card,
so it is not eligible for the standard Q01 build workflow and was not claimed.

## Non-duplicate delta

The previous receipt at
`docs/research/DIVERSITY_FUNNEL_HARD_CPU_STOP_2026-08-24_105118Z.md` observed
3,832 pending work items and an active mix spanning Q02, Q07, Q08, and Q10_NEWS.
This snapshot has 204 fewer pending rows and a materially changed active mix:
Q07 plus Q10_NEWS only, with no active Q02 or Q08 row. It also captures the new
registry-only `QM5_41157` eligibility boundary.

Machine-readable evidence is
`artifacts/diversity_funnel_hard_cpu_stop_20260825T150122Z_board_advisor.json`.

## Safety

- Farm inspection used a read-only SQLite URI after the normal controller path
  hit a database lock; no task or work-item row changed.
- No Strategy Card, EA, registry row, magic resolver, binary, or setfile was
  changed.
- No compile, smoke test, backtest, terminal reservation, or enqueue was run.
- The portfolio gate, T_Live manifest, T_Live, and AutoTrading were untouched.
- Concurrent unrelated worktree edits were left unstaged and uncommitted.
