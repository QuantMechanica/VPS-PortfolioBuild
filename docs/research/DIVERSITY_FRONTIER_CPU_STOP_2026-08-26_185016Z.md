# Diversity frontier mission: CPU hard stop after QM5_41171 approval

Date: 2026-08-26 UTC (`2026-08-26T18:50:16Z`)

Branch: `agents/board-advisor`

Observation base: `80e971014cde3b3bd58e71eca36759e73a7df619`

Status: stopped at the explicit backtest CPU ceiling without claiming or
mutating a candidate

## Binding capacity result

Five fresh one-second whole-host readings were `98.7701%`, `98.0326%`,
`100.0%`, `99.9035%`, and `100.0%`. Their average was `99.3412%` and their
maximum was `100.0%`. The governed hard stop binds when either statistic is at
least `97%`, so both tests bound independently.

The farm-DB-backed `farmctl mt5-slots` snapshot found six active, reserved
factory terminals: T1, T4, T5, T6, T9, and T10. They held six distinct work
items across Q03, Q07, Q09, and Q10_NEWS; no orphaned factory terminal process
was reported. `T_Live` and the unrelated FTMO terminal were observed only for
exclusion and were not controlled.

## Non-duplicate coordination result

This snapshot is after commit `80e971014`, which added the APPROVED QM5_41171
WTI monthly turning-point card after the earlier capacity receipts. The farm
DB had no task or work-item row for QM5_41170 or QM5_41171. During the check,
QM5_41171 EA paths and its magic row were already materializing elsewhere in
the shared worktree. This run therefore created no competing claim and left
those concurrent files untouched.

The CPU stop bound before any build, repair, smoke, or Q02 action. Reserving a
different card would have stranded a claim; taking QM5_41171 would also have
collided with the observed filesystem work. A later unsaturated turn must
repeat both the DB and filesystem claim checks before selecting the next
diversity candidate.

## Safety boundary

No registry, resolver, EA, setfile, EX5, farm task, work item, queue row,
verdict, terminal reservation, or worker process was changed by this run. No
portfolio gate or admission state changed. AutoTrading, `T_Live`, and the
T_Live manifest were untouched.

Machine-readable receipt:
`artifacts/diversity_frontier_cpu_stop_20260826T185016Z_board_advisor.json`.
